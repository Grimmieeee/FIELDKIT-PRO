#Requires -Version 5.1
# .VERSION 0.2.1
# OBJECTIVE: Inventory visible scheduled tasks and their last-run information on this computer.
<#
.SYNOPSIS
Review all visible local Windows scheduled tasks.
.DESCRIPTION
Read-only. Includes task paths, state, run identity, actions, trigger summaries,
and last-run information. Per-task runtime failures produce PARTIAL results.
Access-limited task visibility cannot establish a complete system inventory.
CSV export is optional, creates a new file only, and may contain sensitive task
arguments. This is an inventory, not a restorable task-definition backup.
.EXAMPLE
.\GET-SCHEDULED-TASK-INVENTORY.ps1 -ExportPath '<new-file.csv>' -NoPause
#>
[CmdletBinding()]
param([string]$ExportPath,[switch]$Details,[switch]$NoPause,[switch]$PassThru)
Write-Host "Scheduled Task Inventory"
$ErrorActionPreference = 'Stop'

function Convert-FkTaskDetails {
    param([object[]]$Items,[string[]]$Fields)
    $result = @(
        foreach ($item in $Items) {
            $record = [ordered]@{}
            if ($item.CimClass) { $record['Type'] = [string]$item.CimClass.CimClassName }
            foreach ($field in $Fields) {
                if ($item.PSObject.Properties[$field]) { $record[$field] = $item.$field }
            }
            [pscustomobject]$record
        }
    )
    ConvertTo-Json -InputObject $result -Depth 6 -Compress
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
    Write-Host 'SCHEDULED TASKS // READ ONLY'
    Write-Host ''
    if ($env:OS -ne 'Windows_NT') { throw 'Windows is required.' }
    foreach ($command in @('Get-ScheduledTask','Get-ScheduledTaskInfo')) {
        if (-not (Get-Command $command -ErrorAction SilentlyContinue)) { throw "$command is unavailable. The Windows ScheduledTasks module is required." }
    }
    Write-Host "Computer: $env:COMPUTERNAME"
    $tasks = @(Get-ScheduledTask -ErrorAction Stop | Sort-Object TaskPath,TaskName)
    $rows = New-Object 'System.Collections.Generic.List[object]'
    $failed = 0
    foreach ($task in $tasks) {
        $info = $null
        $infoStatus = 'AVAILABLE'
        $infoError = ''
        try { $info = Get-ScheduledTaskInfo -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction Stop }
        catch { $failed++; $infoStatus = 'UNAVAILABLE'; $infoError = $_.Exception.Message }
        $rows.Add([pscustomobject][ordered]@{
            Computer = $env:COMPUTERNAME
            TaskPath = $task.TaskPath
            TaskName = $task.TaskName
            State = [string]$task.State
            RunAs = $task.Principal.UserId
            GroupId = $task.Principal.GroupId
            LogonType = [string]$task.Principal.LogonType
            RunLevel = [string]$task.Principal.RunLevel
            ActionsJson = Convert-FkTaskDetails -Items @($task.Actions) -Fields @('Execute','Arguments','WorkingDirectory','ClassId','Data')
            TriggersJson = Convert-FkTaskDetails -Items @($task.Triggers) -Fields @('Enabled','StartBoundary','EndBoundary','DaysInterval','WeeksInterval','DaysOfWeek','MonthsOfYear','DaysOfMonth','UserId','Delay','RandomDelay','Subscription','Repetition')
            LastRunTime = if ($info) { $info.LastRunTime } else { $null }
            LastTaskResult = if ($info) { $info.LastTaskResult } else { $null }
            NextRunTime = if ($info) { $info.NextRunTime } else { $null }
            NumberOfMissedRuns = if ($info) { $info.NumberOfMissedRuns } else { $null }
            RuntimeStatus = $infoStatus
            RuntimeError = $infoError
        })
    }
    if ($rows.Count -eq 0) { Write-Host 'No visible tasks returned. Permissions may limit results.' }
    else {
        $rows | Select-Object @{Name='TASK';Expression={$_.TaskPath + $_.TaskName}},@{Name='STATE';Expression={$_.State}},@{Name='RUN AS';Expression={$_.RunAs}},@{Name='LAST RESULTS';Expression={$_.LastTaskResult}},@{Name='DATA';Expression={$_.RuntimeStatus}} | Format-FkTable | Out-Host
        if ($Details) {
        foreach ($row in $rows) {
            Write-Host ($row.TaskPath + $row.TaskName)
            Write-Host ('Actions: ' + $row.ActionsJson)
            Write-Host ('Triggers: ' + $row.TriggersJson)
            if ($row.RuntimeStatus -eq 'UNAVAILABLE') { Write-Warning ('  Runtime unavailable: ' + $row.RuntimeError) }
        }
    }
    }
    Write-Host 'Visible tasks only. Last result is a Windows code.'
    $outcome = if ($failed -gt 0) { 'PARTIAL' } else { 'COMPLETE' }
    if ($ExportPath) {
        if ($rows.Count -eq 0) { Write-Warning 'No rows to export; no file created.' }
        else {
            $rows | Export-Csv -LiteralPath $ExportPath -NoTypeInformation -Encoding UTF8 -NoClobber -ErrorAction Stop
            Write-Host "EXPORT: $ExportPath"
        }
    }
    Write-Host ('{0} tasks; {1} with unavailable run data.' -f $rows.Count,$failed)
    if ($PassThru) { $rows.ToArray() }
} catch {
    $outcome = 'FAILED'
    Write-Host ('FAILED: {0}' -f $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Check the ScheduledTasks module, permissions, and any export path.'
    if ($NoPause) { throw }
} finally {
    if (-not $NoPause) { [void](Read-Host 'Press Enter to finish.') }
}
