#Requires -Version 5.1
# .VERSION 0.1.1
# OBJECTIVE: Review expired and soon-expiring secret and certificate metadata on app registrations.
<#
.SYNOPSIS
Review expired and soon-expiring secret and certificate metadata on app registrations.
.DESCRIPTION
Defaults to expired credentials and those ending within 30 days; unknown end
dates remain visible. Reads local tenant app registrations, not service-principal
credentials, federated credentials or external applications. Does not retrieve
secret values/private keys, renew credentials or test integrations. Dates are
metadata, not proof that a credential is in use or that an integration is healthy.
Requires Microsoft.Graph.Authentication and Microsoft.Graph.Applications.
Requested delegated scope: Application.Read.All. Public cloud only. Requires an explicit
tenant GUID; validates tenant, cloud, auth type and scope after connection.
A matching delegated session is reused; new login is process-scoped. The host
may retain that session after completion. No service changes or module installs.
CSV export is optional and creates a new file only.
#>
[CmdletBinding()]
param([ValidateRange(1,3650)][int]$Days=30,[string]$TenantId,[string]$ExportPath,[switch]$NoPause,[switch]$PassThru)
$ErrorActionPreference='Stop'
function Convert-FkCredentialDate {
    param($Value)
    if ($null -eq $Value) { return $null }
    try { return ([datetimeoffset]$Value).ToUniversalTime() }
    catch { return $null }
}

# Display-only formatter: keeps all selected columns and wraps complete values.
function Format-FkTable {
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline=$true)][object]$InputObject,[int]$Width=0)
    begin {
        $items=New-Object 'System.Collections.Generic.List[object]'
        function Convert-FkCell {
            param($Value)
            if ($null -eq $Value) { return '' }
            if ($Value -is [datetime]) { return $Value.ToString('yyyy-MM-dd HH:mm',[Globalization.CultureInfo]::InvariantCulture) }
            if ($Value -is [datetimeoffset]) { return $Value.ToString('yyyy-MM-dd HH:mm zzz',[Globalization.CultureInfo]::InvariantCulture) }
            $text=([string]$Value).Replace("`r`n","`n").Replace("`r","`n").Replace("`t",'    ')
            $text=$text -replace '\x1b\[[0-?]*[ -/]*[@-~]',''
            return ($text -replace '[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]','')
        }
        function Get-FkElementWidth {
            param([string]$Element)
            $cp=[char]::ConvertToUtf32($Element,0)
            $category=[Globalization.CharUnicodeInfo]::GetUnicodeCategory($Element,0)
            if ($category -in @([Globalization.UnicodeCategory]::NonSpacingMark,[Globalization.UnicodeCategory]::EnclosingMark,[Globalization.UnicodeCategory]::Format)) { return 0 }
            if ($cp -ge 0x1100 -and ($cp -le 0x115f -or $cp -eq 0x2329 -or $cp -eq 0x232a -or ($cp -ge 0x2e80 -and $cp -le 0xa4cf -and $cp -ne 0x303f) -or ($cp -ge 0xac00 -and $cp -le 0xd7a3) -or ($cp -ge 0xf900 -and $cp -le 0xfaff) -or ($cp -ge 0xfe10 -and $cp -le 0xfe19) -or ($cp -ge 0xfe30 -and $cp -le 0xfe6f) -or ($cp -ge 0xff00 -and $cp -le 0xff60) -or ($cp -ge 0xffe0 -and $cp -le 0xffe6) -or ($cp -ge 0x1f300 -and $cp -le 0x1faff) -or ($cp -ge 0x20000 -and $cp -le 0x3fffd))) { return 2 }
            return 1
        }
        function Get-FkCellWidth {
            param([string]$Text)
            $length=0
            $iterator=[Globalization.StringInfo]::GetTextElementEnumerator($Text)
            while ($iterator.MoveNext()) { $length+=Get-FkElementWidth $iterator.GetTextElement() }
            return $length
        }
        function Split-FkCell {
            param([string]$Text,[int]$Limit)
            foreach ($paragraph in $Text.Split([char]10)) {
                $buffer=[Text.StringBuilder]::new();$used=0
                $iterator=[Globalization.StringInfo]::GetTextElementEnumerator($paragraph)
                while ($iterator.MoveNext()) {
                    $element=$iterator.GetTextElement();$size=Get-FkElementWidth $element
                    if ($used+$size -gt $Limit -and $buffer.Length -gt 0) { $buffer.ToString();[void]$buffer.Clear();$used=0 }
                    [void]$buffer.Append($element);$used+=$size
                }
                $buffer.ToString()
            }
        }
    }
    process { if ($null -ne $InputObject) { $items.Add($InputObject) } }
    end {
        if ($items.Count -eq 0) { return }
        if ($Width -eq 0) {
            try { $Width=$Host.UI.RawUI.WindowSize.Width } catch { $Width=80 }
            if ($Width -lt 20) { $Width=80 }
        }
        if ($Width -lt 20 -or $Width -gt 500) { throw 'Display width must be 20 through 500.' }
        $headers=@($items[0].PSObject.Properties | ForEach-Object {$_.Name})
        if ($headers.Count -eq 0) { return }
        $values=New-Object 'System.Collections.Generic.List[object]'
        $sizes=New-Object 'System.Collections.Generic.List[int]'
        $desired=New-Object 'System.Collections.Generic.List[int]'
        foreach ($header in $headers) { $size=[math]::Max(3,(Get-FkCellWidth $header));$sizes.Add($size);$desired.Add($size) }
        foreach ($item in $items) {
            $cells=@(foreach ($header in $headers) { Convert-FkCell $item.PSObject.Properties[$header].Value })
            $values.Add($cells)
            for ($i=0;$i -lt $headers.Count;$i++) {
                foreach ($part in $cells[$i].Split([char]10)) { $desired[$i]=[math]::Max($desired[$i],(Get-FkCellWidth $part)) }
            }
        }
        $minimum=2*($headers.Count-1)
        foreach ($size in $sizes) { $minimum+=$size }
        $lines=New-Object 'System.Collections.Generic.List[string]'
        if ($minimum -gt $Width) {
            # Very narrow hosts use aligned labels rather than dropping columns.
            $labelWidth=0
            foreach ($header in $headers) { $labelWidth=[math]::Max($labelWidth,(Get-FkCellWidth $header)) }
            $labelWidth=[math]::Min($labelWidth,[math]::Max(3,[int]($Width/3)))
            foreach ($cells in $values) {
                for ($i=0;$i -lt $headers.Count;$i++) {
                    foreach ($label in @(Split-FkCell $headers[$i] $Width)) { $lines.Add($label) }
                    foreach ($part in @(Split-FkCell $cells[$i] ($Width-2))) { $lines.Add('  '+$part) }
                }
                $lines.Add('')
            }
            return $lines.ToArray()
        }
        $remaining=$Width-$minimum
        while ($remaining -gt 0) {
            $grew=$false
            for ($i=0;$i -lt $sizes.Count -and $remaining -gt 0;$i++) {
                if ($sizes[$i] -lt $desired[$i]) { $sizes[$i]++;$remaining--;$grew=$true }
            }
            if (-not $grew) { break }
        }
        $parts=@(for ($i=0;$i -lt $headers.Count;$i++) { $headers[$i]+(' '*($sizes[$i]-(Get-FkCellWidth $headers[$i]))) })
        $lines.Add(([string]::Join('  ',[string[]]$parts)).TrimEnd())
        $parts=@(foreach ($size in $sizes) { '-'*$size })
        $lines.Add([string]::Join('  ',[string[]]$parts))
        foreach ($cells in $values) {
            $chunks=New-Object 'System.Collections.Generic.List[object]';$height=1
            for ($i=0;$i -lt $headers.Count;$i++) {
                $column=@(Split-FkCell $cells[$i] $sizes[$i]);$chunks.Add($column);$height=[math]::Max($height,$column.Count)
            }
            for ($row=0;$row -lt $height;$row++) {
                $parts=@(for ($i=0;$i -lt $headers.Count;$i++) {
                    $part=if ($row -lt $chunks[$i].Count) { [string]$chunks[$i][$row] } else { '' }
                    $part+(' '*($sizes[$i]-(Get-FkCellWidth $part)))
                })
                $lines.Add(([string]::Join('  ',[string[]]$parts)).TrimEnd())
            }
            if ($height -gt 1) { $lines.Add('') }
        }
        return $lines.ToArray()
    }
}

try {
    Write-Host 'APPLICATION CREDENTIAL EXPIRY // READ ONLY'
    Write-Host ''
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Import-Module Microsoft.Graph.Applications -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($TenantId)) {
        if ($NoPause) { throw 'Specify -TenantId.' }
        $TenantId=Read-Host 'Tenant ID'
    }
    $tenantGuid=[guid]::Empty
    if (-not [guid]::TryParse($TenantId,[ref]$tenantGuid) -or $tenantGuid -eq [guid]::Empty) { throw 'Enter a valid tenant ID.' }
    $TenantId=$tenantGuid.ToString()
    $requiredScope='Application.Read.All'
    $acceptedScopes=@('Application.Read.All','Application.ReadWrite.All')
    $context=Get-MgContext -ErrorAction Stop
    $hasScope=$false
    if ($context) { $hasScope=@($context.Scopes | Where-Object { $_ -in $acceptedScopes }).Count -gt 0 }
    if (-not $context -or $context.TenantId -ne $TenantId -or $context.AuthType -ne 'Delegated' -or $context.Environment -ne 'Global' -or -not $hasScope) {
        Connect-MgGraph -TenantId $TenantId -Scopes $requiredScope -ContextScope Process -Environment Global -NoWelcome -ErrorAction Stop | Out-Null
        $context=Get-MgContext -ErrorAction Stop
    }
    if (-not $context -or $context.TenantId -ne $TenantId -or $context.AuthType -ne 'Delegated' -or $context.Environment -ne 'Global') { throw 'Graph session does not match the requested tenant and delegated public-cloud context.' }
    if (@($context.Scopes | Where-Object { $_ -in $acceptedScopes }).Count -eq 0) { throw "Graph permission missing: $requiredScope" }
    Write-Host "Tenant: $TenantId"
    if (-not $PSBoundParameters.ContainsKey('Days') -and -not $NoPause) {
        $answer=Read-Host 'Expiry window in days [30]'
        if (-not [string]::IsNullOrWhiteSpace($answer)) {
            $number=0
            if (-not [int]::TryParse($answer,[ref]$number) -or $number -lt 1 -or $number -gt 3650) { throw 'Enter a whole number from 1 through 3650.' }
            $Days=$number
        }
    }
    $now=[datetimeoffset]::UtcNow
    $cutoff=$now.AddDays($Days)
    $apps=@(Get-MgApplication -All -Property Id,DisplayName,AppId,PasswordCredentials,KeyCredentials -ErrorAction Stop)
    $rows=@(
        foreach ($app in $apps) {
            foreach ($kind in @('Secret','Certificate')) {
                $credentials=if ($kind -eq 'Secret') { @($app.PasswordCredentials) } else { @($app.KeyCredentials) }
                foreach ($credential in $credentials) {
                    if ($null -eq $credential) { continue }
                    $end=Convert-FkCredentialDate $credential.EndDateTime
                    $start=Convert-FkCredentialDate $credential.StartDateTime
                    if ($null -ne $end -and $end -gt $cutoff) { continue }
                    $state='End date unavailable'
                    $daysLeft=$null
                    if ($null -ne $end) {
                        $daysLeft=[math]::Floor(($end-$now).TotalDays)
                        $state=if ($end -le $now) { 'Expired' } elseif ($null -ne $start -and $start -gt $now) { 'Not active yet' } else { 'Expires soon' }
                    }
                    [pscustomobject][ordered]@{
                        Application=$app.DisplayName; Type=$kind; State=$state
                        EndsUtc=if ($null -ne $end) { $end.UtcDateTime } else { $null }
                        StartsUtc=if ($null -ne $start) { $start.UtcDateTime } else { $null }
                        DaysLeft=$daysLeft; CredentialName=$credential.DisplayName
                        KeyId=[string]$credential.KeyId; AppId=[string]$app.AppId
                        ApplicationObjectId=[string]$app.Id; TenantId=$TenantId
                    }
                }
            }
        }
    )
    $rows=@($rows | Sort-Object EndsUtc,Application,Type,KeyId)
    if ($rows.Count -eq 0) { Write-Host 'No returned credentials matched this expiry window.' }
    else {
        $rows | Select-Object @{Name='APPLICATION';Expression={$_.Application}},@{Name='TYPE';Expression={$_.Type}},@{Name='ENDS (UTC)';Expression={$_.EndsUtc}},@{Name='STATE';Expression={$_.State}} | Format-FkTable | Out-Host
        Write-Host ('{0} credentials for review.' -f $rows.Count)
    }
    Write-Host 'App-registration metadata only. Credential use and integration health were not tested.'
    if ($ExportPath) {
        if ($rows.Count -eq 0) { Write-Warning 'No rows to export.' }
        else {
            $rows | Export-Csv -LiteralPath $ExportPath -NoTypeInformation -Encoding UTF8 -NoClobber -ErrorAction Stop
            Write-Host "Export: $ExportPath"
        }
    }
    if ($PassThru) { $rows }
} catch {
    Write-Host ('FAILED: {0}' -f $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Check the Graph modules, tenant, required consent/role, and any export path.'
    if ($NoPause) { throw }
} finally {
    $context=$null
    if (-not $NoPause) { [void](Read-Host 'Press Enter to finish.') }
}
