#Requires -Version 5.1
# .VERSION 0.1.1
# OBJECTIVE: List service principal names and their AD objects in one directory scope.
<#
.SYNOPSIS
List service principal names and their AD objects in one directory scope.
.DESCRIPTION
Includes user, computer and managed-service-account objects where visible,
plus other matching object classes. One row per SPN. Does not request Kerberos
tickets, access service credentials, test services, or assess exploitability.
This is one directory scope, not a forest-wide duplicate-SPN search. Blank
account state means the userAccountControl attribute was unavailable.
No directory settings are changed. Uses the current Windows identity; requires
ActiveDirectory and directory-read access. No prerequisites are installed.
CSV export is optional and creates a new file only.
#>
[CmdletBinding()]
param([string]$Server,[string]$SearchBase,[string]$ExportPath,[switch]$NoPause,[switch]$PassThru)
Write-Host 'GET-AD-SPN-INVENTORY.ps1 // READ ONLY'
Write-Host ''
Write-Host 'Objective: List service principal names and their AD objects in one directory scope.'
Write-Host ''
$ErrorActionPreference = 'Stop'
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
    Write-Host 'AD SPN INVENTORY // READ ONLY'
    Write-Host ''
    if ($env:OS -ne 'Windows_NT') { throw 'Windows with the ActiveDirectory module is required.' }
    Import-Module ActiveDirectory -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($Server)) {
        $Server = [string](Get-ADDomainController -Discover -Writable -ErrorAction Stop).HostName
    }
    if ([string]::IsNullOrWhiteSpace($Server)) { throw 'No controller found. Specify -Server.' }
    $dc = Get-ADDomainController -Identity $Server -Server $Server -ErrorAction Stop
    $Server = [string]$dc.HostName
    if ([string]::IsNullOrWhiteSpace($Server)) { throw 'Controller identity is unavailable.' }
    $domain = Get-ADDomain -Server $Server -ErrorAction Stop
    Write-Host "Controller: $Server"
    if ([string]::IsNullOrWhiteSpace($SearchBase)) { $SearchBase = $domain.DistinguishedName }
    $base = Get-ADObject -Identity $SearchBase -Server $Server -ErrorAction Stop
    if ($base.ObjectClass -notin @('domainDNS','organizationalUnit','container')) { throw 'SearchBase must be a domain, OU, or container.' }
    $SearchBase = $base.DistinguishedName
    Write-Host "Scope: $SearchBase"
    $objects = @(Get-ADObject -LDAPFilter '(servicePrincipalName=*)' -SearchBase $SearchBase -SearchScope Subtree -Server $Server -Properties sAMAccountName,servicePrincipalName,userAccountControl -ErrorAction Stop)
    $rows = @(
        foreach ($object in $objects) {
            $account = if ($object.sAMAccountName) { [string]$object.sAMAccountName } else { [string]$object.Name }
            $enabled = $null
            if ($null -ne $object.userAccountControl) { $enabled = (([long]$object.userAccountControl -band 2) -eq 0) }
            foreach ($spn in @($object.servicePrincipalName)) {
                if ([string]::IsNullOrWhiteSpace([string]$spn)) { throw "SPN data unavailable for $account. Review incomplete." }
                [pscustomobject][ordered]@{
                    Account=$account; Type=[string]$object.ObjectClass
                    Enabled=$enabled; SPN=[string]$spn
                    ObjectGuid=[string]$object.ObjectGuid; DistinguishedName=$object.DistinguishedName
                    DomainController=$Server
                }
            }
        }
    )
    $rows = @($rows | Sort-Object Account,DistinguishedName,SPN)
    if ($rows.Count -eq 0) { Write-Host 'No visible SPNs returned in this scope.' }
    else {
        $rows | Select-Object @{Name='ACCOUNT';Expression={$_.Account}},@{Name='TYPE';Expression={$_.Type}},@{Name='SPN';Expression={$_.SPN}} | Format-FkTable | Out-Host
        Write-Host ('{0} objects; {1} SPNs.' -f $objects.Count,$rows.Count)
    }
    Write-Host 'Inventory only. Services and duplicate SPNs across the forest were not tested.'
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
    Write-Host 'Check the AD module, controller, permissions, and any scope/export path.'
    if ($NoPause) { throw }
} finally {
    if (-not $NoPause) { [void](Read-Host 'Press Enter to finish.') }
}
