#Requires -Version 5.1
# .VERSION 0.1.1
# OBJECTIVE: Review local PowerShell script-block event metadata within a selected time window.
<#
.SYNOPSIS
Read-only event 4104 metadata from Windows PowerShell and PowerShell Core logs.
.DESCRIPTION
Defaults to 24 hours and the newest 1000 records per channel. Each channel is
queried independently. Missing or unreadable channels remain unavailable, not
empty. Reports record time, script-block ID, path and fragment numbers without
printing/exporting ScriptBlockText or full event messages. Does not enable
logging, decrypt protected events or establish successful script execution.
-PassThru returns one envelope containing Events and Sources. CSV contains event
metadata only. Source failures remain on screen and in the PassThru envelope.
#>
[CmdletBinding()]
param(
    [ValidateRange(1,8760)][int]$Hours=24,
    [ValidateRange(1,100000)][int]$MaxEvents=1000,
    [string]$ExportPath,[switch]$NoPause,[switch]$PassThru
)
Write-Host 'GET-POWERSHELL-LOG-ACTIVITY.ps1 // READ ONLY'
Write-Host ''
Write-Host 'Objective: Review local PowerShell script-block event metadata within a selected time window.'
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
    Write-Host 'POWERSHELL LOG ACTIVITY // READ ONLY'
    Write-Host ''
    if ($env:OS -ne 'Windows_NT') { throw 'Windows is required.' }
    if (-not $PSBoundParameters.ContainsKey('Hours') -and -not $NoPause) {
        $answer = Read-Host 'Hours [24]'
        if (-not [string]::IsNullOrWhiteSpace($answer)) {
            $number=0
            if (-not [int]::TryParse($answer,[ref]$number) -or $number -lt 1 -or $number -gt 8760) { throw 'Enter a whole number from 1 through 8760.' }
            $Hours=$number
        }
    }
    $end=Get-Date
    $start=$end.AddHours(-$Hours)
    $rows=New-Object 'System.Collections.Generic.List[object]'
    $sources=New-Object 'System.Collections.Generic.List[object]'
    foreach ($source in @(
        [pscustomobject]@{Label='Windows';Log='Microsoft-Windows-PowerShell/Operational'},
        [pscustomobject]@{Label='Core';Log='PowerShellCore/Operational'}
    )) {
        $events=@()
        $sourceError=''
        $state='AVAILABLE'
        $unreadable=0
        try {
            $events=@(Get-WinEvent -FilterHashtable @{LogName=$source.Log;Id=4104;StartTime=$start;EndTime=$end} -MaxEvents $MaxEvents -ErrorAction Stop)
        } catch {
            if ($_.FullyQualifiedErrorId -notlike 'NoMatchingEventsFound*') {
                $state='UNAVAILABLE'
                $sourceError=$_.Exception.Message
                Write-Warning ('{0} log unavailable: {1}' -f $source.Label,$sourceError)
            }
        }
        foreach ($event in $events) {
            try {
                [xml]$xml=$event.ToXml()
                $data=@{}
                foreach ($node in $xml.Event.EventData.Data) {
                    if ([string]$node.Name -in @('ScriptBlockId','Path','MessageNumber','MessageTotal')) { $data[[string]$node.Name]=[string]$node.'#text' }
                }
                if (-not $data['ScriptBlockId']) { throw 'Missing metadata.' }
                $rows.Add([pscustomobject][ordered]@{
                    Computer=$env:COMPUTERNAME; Time=$event.TimeCreated; Log=$source.Label
                    LogName=$source.Log; RecordId=$event.RecordId; ScriptBlockId=$data['ScriptBlockId']
                    Path=$data['Path']; Fragment=$data['MessageNumber']; TotalFragments=$data['MessageTotal']
                })
            } catch {
                $unreadable++
                Write-Warning ('{0} record {1}: metadata unreadable.' -f $source.Label,$event.RecordId)
            }
        }
        $capped=$events.Count -ge $MaxEvents
        if ($capped) { Write-Warning ('{0} log: result limit reached.' -f $source.Label) }
        if ($state -eq 'AVAILABLE' -and $unreadable -gt 0) { $state='PARTIAL' }
        $sources.Add([pscustomobject]@{Log=$source.Log;Status=$state;Records=$events.Count;Unreadable=$unreadable;LimitReached=$capped;Error=$sourceError})
    }
    $output=@($rows | Sort-Object Time -Descending)
    if ($output.Count -gt 0) {
        $output | Select-Object @{Name='TIME';Expression={$_.Time.ToString('MM-dd HH:mm')}},@{Name='LOG';Expression={$_.Log}},@{Name='PATH';Expression={$_.Path}},@{Name='PART';Expression={$_.Fragment + '/' + $_.TotalFragments}} | Format-FkTable | Out-Host
    } elseif (@($sources | Where-Object {$_.Status -ne 'AVAILABLE'}).Count -eq 0) { Write-Host 'No matching records returned from either channel.' }
    else { Write-Host 'No decoded records. Some log data was unavailable.' }
    Write-Host ('{0} records shown. Fragments can repeat; script contents are not shown.' -f $output.Count)
    Write-Host 'Retained logs only. Logging coverage and execution success were not verified.'
    if ($ExportPath) {
        if ($output.Count -eq 0) { Write-Warning 'No event rows to export.' }
        else {
            $output | Export-Csv -LiteralPath $ExportPath -NoTypeInformation -Encoding UTF8 -NoClobber -ErrorAction Stop
            Write-Host "Export: $ExportPath"
        }
    }
    if ($PassThru) { [pscustomobject]@{Events=$output;Sources=$sources.ToArray()} }
    if (@($sources | Where-Object {$_.Status -eq 'UNAVAILABLE'}).Count -eq 2) { throw 'Both logs were unavailable. No log review established.' }
} catch {
    Write-Host ('FAILED: {0}' -f $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Check the time window, event-log permissions, and any export path.'
    if ($NoPause) { throw }
} finally {
    if (-not $NoPause) { [void](Read-Host 'Press Enter to finish.') }
}
