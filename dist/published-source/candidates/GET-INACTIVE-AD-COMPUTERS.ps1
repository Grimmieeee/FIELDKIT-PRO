#Requires -Version 5.1
# .VERSION 0.2.1
# OBJECTIVE: Find AD computer accounts with old or missing replicated logon timestamps for review.
<#
.SYNOPSIS
Read-only AD computer inactivity candidates from one domain controller.
.DESCRIPTION
Defaults to 90 days. Uses replicated lastLogonTimestamp, which is approximate
and may lag actual logons. Missing timestamps are not proof of no use; newly
created computers inside the selected window are excluded from that group.
Does not disable, delete, ping, or query endpoint activity. Optional CSV creates
a new file only. Requires the ActiveDirectory module and directory read access.
#>
[CmdletBinding()]
param(
    [ValidateRange(1,36500)][int]$Days = 90,
    [string]$Server,
    [string]$SearchBase,
    [string]$ExportPath,
    [switch]$NoPause,
    [switch]$PassThru
)
Write-Host 'GET-INACTIVE-AD-COMPUTERS.ps1 // READ ONLY'
Write-Host ''
Write-Host 'Objective: Find AD computer accounts with old or missing replicated logon timestamps for review.'
Write-Host ''
$ErrorActionPreference = 'Stop'
$outcome = 'FAILED'
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
    Write-Host 'INACTIVE AD COMPUTERS // READ ONLY'
    Write-Host ''
    if ($env:OS -ne 'Windows_NT') { throw 'Windows with the ActiveDirectory module is required.' }
    Import-Module ActiveDirectory -ErrorAction Stop
    if (-not $PSBoundParameters.ContainsKey('Days') -and -not $NoPause) {
        $answer = Read-Host 'Days [90]'
        if (-not [string]::IsNullOrWhiteSpace($answer)) {
            $number = 0
            if (-not [int]::TryParse($answer,[ref]$number) -or $number -lt 1 -or $number -gt 36500) { throw 'Enter a whole number from 1 through 36500.' }
            $Days = $number
        }
    }
    if ([string]::IsNullOrWhiteSpace($Server)) {
        $Server = [string](Get-ADDomainController -Discover -Writable -ErrorAction Stop).HostName
    }
    if ([string]::IsNullOrWhiteSpace($Server)) { throw 'No domain controller was resolved. Specify -Server.' }
    # Resolve a single controller, then bind all remaining reads to its hostname.
    $dc = Get-ADDomainController -Identity $Server -Server $Server -ErrorAction Stop
    $Server = [string]$dc.HostName
    if ([string]::IsNullOrWhiteSpace($Server)) { throw 'Domain-controller identity is unavailable.' }
    $domain = Get-ADDomain -Server $Server -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($SearchBase)) { $SearchBase = $domain.DistinguishedName }
    $base = Get-ADObject -Identity $SearchBase -Server $Server -ErrorAction Stop
    if ($base.ObjectClass -notin @('domainDNS','organizationalUnit','container')) { throw 'SearchBase must identify a domain, OU, or container.' }
    $SearchBase = $base.DistinguishedName
    $cutoff = (Get-Date).AddDays(-$Days)
    $ticks = $cutoff.ToUniversalTime().ToFileTimeUtc().ToString([Globalization.CultureInfo]::InvariantCulture)
    $created = $cutoff.ToUniversalTime().ToString('yyyyMMddHHmmss.0Z',[Globalization.CultureInfo]::InvariantCulture)
    $filter = "(|(&(lastLogonTimestamp<=$ticks)(lastLogonTimestamp>=1))(&(|(!(lastLogonTimestamp=*))(lastLogonTimestamp=0))(whenCreated<=$created)))"
    Write-Host "Controller: $Server"
    Write-Host "Scope: $SearchBase"
    Write-Host ('Before: {0:yyyy-MM-dd}' -f $cutoff)
    $computers = @(Get-ADComputer -LDAPFilter $filter -SearchBase $SearchBase -SearchScope Subtree -Server $Server -Properties lastLogonTimestamp,whenCreated,PasswordLastSet,OperatingSystem,DNSHostName -ErrorAction Stop)
    $rows = @(
        foreach ($computer in $computers) {
            $last = $null
            $basis = 'No recorded timestamp'
            if ($computer.lastLogonTimestamp -and [long]$computer.lastLogonTimestamp -gt 0) {
                $last = [datetime]::FromFileTimeUtc([long]$computer.lastLogonTimestamp)
                $basis = 'Old timestamp'
            }
            [pscustomobject][ordered]@{
                Name=$computer.Name; DNSHostName=$computer.DNSHostName; Enabled=$computer.Enabled
                LastLogonTimestampUtc=$last; WhenCreated=$computer.whenCreated
                PasswordLastSet=$computer.PasswordLastSet; OperatingSystem=$computer.OperatingSystem
                ReviewBasis=$basis; ObjectGuid=[string]$computer.ObjectGuid
                DistinguishedName=$computer.DistinguishedName; DomainController=$Server
            }
        }
    )
    $rows = @($rows | Sort-Object Name,DistinguishedName)
    if ($rows.Count -eq 0) { Write-Host 'No matching computers in this scope.' }
    else { $rows | Select-Object @{Name='COMPUTER';Expression={$_.Name}},@{Name='ENABLED';Expression={$_.Enabled}},@{Name='LAST LOGON (UTC)';Expression={$_.LastLogonTimestampUtc}},@{Name='REVIEW';Expression={$_.ReviewBasis}} | Format-FkTable | Out-Host }
    Write-Host 'AD timestamps are approximate. Confirm actual use before cleanup.'
    if ($ExportPath) {
        if ($rows.Count -eq 0) { Write-Warning 'No rows to export; no file created.' }
        else { $rows | Export-Csv -LiteralPath $ExportPath -NoTypeInformation -Encoding UTF8 -NoClobber -ErrorAction Stop; Write-Host "EXPORT: $ExportPath" }
    }
    $outcome = 'COMPLETE'
    Write-Host ('{0} computers for review. No changes made.' -f $rows.Count)
    if ($PassThru) { $rows }
} catch {
    Write-Host ('FAILED: {0}' -f $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Check the AD module, controller, permissions, and any scope/export path.'
    if ($NoPause) { throw }
} finally {
    if (-not $NoPause) { [void](Read-Host 'Press Enter to finish.') }
}
