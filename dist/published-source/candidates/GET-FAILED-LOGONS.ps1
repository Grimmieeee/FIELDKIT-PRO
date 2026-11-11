#Requires -Version 5.1
# .VERSION 0.2.1
# OBJECTIVE: Review recorded failed Windows logons on this computer within a selected time window.
<#
.SYNOPSIS
Review Security event 4625 on the local Windows computer.
.DESCRIPTION
Read-only. Defaults to 24 hours and at most 1000 events, newest first.
Does not query Entra sign-ins or all domain controllers, change auditing, or
prove an absence of failures when logs are missing, cleared, or incomplete.
Optional CSV export creates a new file only. No prerequisites are installed.
.EXAMPLE
.\GET-FAILED-LOGONS.ps1 -Hours 48 -MaxEvents 2000 -NoPause
#>
[CmdletBinding()]
param(
    [ValidateRange(1,8760)][int]$Hours = 24,
    [ValidateRange(1,100000)][int]$MaxEvents = 1000,
    [string]$ExportPath,
    [switch]$NoPause,
    [switch]$PassThru
)
Write-Host "Failed Logons"
$ErrorActionPreference = 'Stop'

function Convert-FkLogonEvent {
    param([Parameter(Mandatory=$true)]$Event)
    [xml]$xml = $Event.ToXml()
    $data = @{}
    foreach ($node in $xml.Event.EventData.Data) { $data[[string]$node.Name] = [string]$node.'#text' }
    if (-not $data.ContainsKey('TargetUserName')) { throw 'Event 4625 is missing TargetUserName.' }
    [pscustomobject][ordered]@{
        TimeCreated = $Event.TimeCreated
        Computer = $Event.MachineName
        RecordId = $Event.RecordId
        UserName = $data['TargetUserName']
        Domain = $data['TargetDomainName']
        SourceAddress = $data['IpAddress']
        SourcePort = $data['IpPort']
        Workstation = $data['WorkstationName']
        LogonType = $data['LogonType']
        Status = $data['Status']
        SubStatus = $data['SubStatus']
        FailureReason = $data['FailureReason']
        ProcessName = $data['ProcessName']
        AuthenticationPackage = $data['AuthenticationPackageName']
    }
}

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
    Write-Host 'FAILED LOGONS // READ ONLY'
    Write-Host ''
    if ($env:OS -ne 'Windows_NT') { throw 'Windows is required.' }
    if (-not (Get-Command Get-WinEvent -ErrorAction SilentlyContinue)) { throw 'Get-WinEvent is unavailable. Use Windows PowerShell 5.1 or a supported Windows PowerShell host.' }
    if (-not $PSBoundParameters.ContainsKey('Hours') -and -not $NoPause) {
        $answer = Read-Host 'Hours [24]'
        if (-not [string]::IsNullOrWhiteSpace($answer)) {
            $parsed = 0
            if (-not [int]::TryParse($answer, [ref]$parsed) -or $parsed -lt 1 -or $parsed -gt 8760) { throw 'Enter a whole number from 1 through 8760.' }
            $Hours = $parsed
        }
    }
    $end = Get-Date
    $start = $end.AddHours(-$Hours)
    $events = @()
    try {
        $events = @(Get-WinEvent -FilterHashtable @{LogName='Security';Id=4625;StartTime=$start;EndTime=$end} -MaxEvents $MaxEvents -ErrorAction Stop)
    } catch {
        if ($_.FullyQualifiedErrorId -notlike 'NoMatchingEventsFound*') { throw }
    }
    $rows = New-Object 'System.Collections.Generic.List[object]'
    $unreadable = 0
    foreach ($event in $events) {
        try { $rows.Add((Convert-FkLogonEvent -Event $event)) }
        catch { $unreadable++; Write-Warning ('Record {0} could not be decoded: {1}' -f $event.RecordId,$_.Exception.Message) }
    }
    if ($rows.Count -gt 0) {
        $rows | Select-Object @{Name='TIME';Expression={$_.TimeCreated.ToString('MM-dd HH:mm')}},@{Name='USER';Expression={if ($_.Domain -and $_.Domain -ne '-') { $_.Domain + '\' + $_.UserName } else { $_.UserName }}},@{Name='SOURCE';Expression={$_.SourceAddress}},@{Name='STATUS';Expression={$_.Status}},@{Name='SUBSTATUS';Expression={$_.SubStatus}} | Format-FkTable | Out-Host
    } elseif ($unreadable -eq 0) { Write-Host 'No matching events in the local log.' }
    if ($events.Count -ge $MaxEvents) { Write-Warning 'Result limit reached. Showing newest events only.' }
    Write-Host 'Local log only. Log coverage may be incomplete.'
    $outcome = if ($unreadable -gt 0) { 'PARTIAL' } elseif ($events.Count -ge $MaxEvents) { 'LIMIT REACHED' } else { 'COMPLETE' }
    if ($ExportPath) {
        if ($rows.Count -eq 0) { Write-Warning 'No decoded rows to export; no file created.' }
        else {
            $rows | Export-Csv -LiteralPath $ExportPath -NoTypeInformation -Encoding UTF8 -NoClobber -ErrorAction Stop
            Write-Host "EXPORT: $ExportPath"
        }
    }
    Write-Host ('{0} events shown; {1} unreadable.' -f $rows.Count,$unreadable)
    if ($PassThru) { $rows.ToArray() }
} catch {
    $outcome = 'FAILED'
    Write-Host ('FAILED: {0}' -f $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Check Security log access and any export path. Try an authorized elevated window if needed.'
    if ($NoPause) { throw }
} finally {
    if (-not $NoPause) { [void](Read-Host 'Press Enter to finish.') }
}
