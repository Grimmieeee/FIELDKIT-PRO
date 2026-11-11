#Requires -Version 5.1
# .VERSION 0.1.1
# OBJECTIVE: Inventory permanent WMI event filters, consumers and bindings in root/subscription.
<#
.SYNOPSIS
Read-only local permanent WMI subscription inventory.
.DESCRIPTION
Reads __EventFilter, __EventConsumer and __FilterToConsumerBinding independently.
Preserves binding references without resolving or executing consumers. Does not
register/delete subscriptions, invoke CIM methods, print consumer scripts or
command lines, inspect other namespaces, or classify entries as malicious.
-Details shows filter WQL and binding references. -PassThru returns Sources and
Entries; CSV includes entries only. Unavailable classes remain visible on screen
and in Sources. Export creates a new file only.
#>
[CmdletBinding()]
param([string]$ExportPath,[switch]$Details,[switch]$NoPause,[switch]$PassThru)
Write-Host 'GET-WMI-SUBSCRIPTIONS.ps1 // READ ONLY'
Write-Host ''
Write-Host 'Objective: Show persistent Windows event triggers, what actions they run, and how they are linked. Use this to review automation or investigate persistence.'
Write-Host ''
Write-Host "WMI Subscriptions"
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
    Write-Host 'WMI SUBSCRIPTIONS // READ ONLY'
    Write-Host ''
    if ($env:OS -ne 'Windows_NT') { throw 'Windows is required.' }
    Write-Host "Computer: $env:COMPUTERNAME"
    $namespace='root/subscription'
    $sources=New-Object 'System.Collections.Generic.List[object]'
    $rows=New-Object 'System.Collections.Generic.List[object]'
    foreach ($class in @('__EventFilter','__EventConsumer','__FilterToConsumerBinding')) {
        try {
            $instances=@(Get-CimInstance -Namespace $namespace -ClassName $class -ErrorAction Stop)
            foreach ($instance in $instances) {
                $kind=if ($class -eq '__EventFilter') { 'Filter' } elseif ($class -eq '__EventConsumer') { 'Consumer' } else { 'Binding' }
                $rows.Add([pscustomobject][ordered]@{
                    Computer=$env:COMPUTERNAME; Namespace=$namespace; Kind=$kind
                    Class=[string]$instance.CimClass.CimClassName; Name=[string]$instance.Name
                    Query=[string]$instance.Query; QueryLanguage=[string]$instance.QueryLanguage
                    EventNamespace=[string]$instance.EventNamespace
                    FilterReference=[string]$instance.Filter; ConsumerReference=[string]$instance.Consumer
                })
            }
            $sources.Add([pscustomobject]@{Class=$class;Status='AVAILABLE';Count=$instances.Count;Error=''})
        } catch {
            $sources.Add([pscustomobject]@{Class=$class;Status='UNAVAILABLE';Count=$null;Error=$_.Exception.Message})
            Write-Warning ('{0} unavailable: {1}' -f $class,$_.Exception.Message)
        }
    }
    $output=@($rows | Sort-Object Kind,Name,Class)
    foreach ($kind in @('Filter','Consumer','Binding')) {
        $items=@($output | Where-Object {$_.Kind -eq $kind})
        if ($kind -eq 'Binding') {
            Write-Host ('Bindings returned: {0}' -f $items.Count)
            if ($Details -and $items.Count -gt 0) { $items | Select-Object FilterReference,ConsumerReference | Format-FkTable | Out-Host }
        } elseif ($items.Count -gt 0) {
            $items | Select-Object @{Name='KIND';Expression={$_.Kind}},@{Name='NAME';Expression={$_.Name}},@{Name='CLASS';Expression={$_.Class}},@{Name='EVENT NAMESPACE';Expression={$_.EventNamespace}} | Format-FkTable | Out-Host
            if ($Details -and $kind -eq 'Filter') { $items | Select-Object Name,QueryLanguage,Query | Format-FkTable | Out-Host }
        }
    }
    $failed=@($sources | Where-Object {$_.Status -eq 'UNAVAILABLE'}).Count
    if ($failed -gt 0) { Write-Host ('{0} of 3 class queries unavailable. Counts are incomplete.' -f $failed) }
    elseif ($output.Count -eq 0) { Write-Host 'No permanent subscriptions returned in root/subscription.' }
    Write-Host 'This namespace only. Consumers were not executed or classified.'
    if ($ExportPath) {
        if ($output.Count -eq 0) { Write-Warning 'No entry rows to export.' }
        else {
            $output | Export-Csv -LiteralPath $ExportPath -NoTypeInformation -Encoding UTF8 -NoClobber -ErrorAction Stop
            Write-Host "Export: $ExportPath"
        }
    }
    if ($PassThru) { [pscustomobject]@{Entries=$output;Sources=$sources.ToArray()} }
    if ($failed -eq 3) { throw 'All subscription queries failed. No WMI inventory established.' }
} catch {
    Write-Host ('FAILED: {0}' -f $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Check WMI namespace permissions and any export path.'
    if ($NoPause) { throw }
} finally {
    if (-not $NoPause) { [void](Read-Host 'Press Enter to finish.') }
}
