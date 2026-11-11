#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z]:?\\?$')]
    [string]$Drive,
    [ValidateRange(1, 50)]
    [int]$Top = 10
)
Write-Host 'GET-DISK-SPACE-USAGE.ps1 // READ ONLY'
Write-Host ''
Write-Host 'Objective: Show free space on local drives and rank the largest readable locations on one selected drive.'
Write-Host ''

$ErrorActionPreference = 'Stop'
$volumes = @([IO.DriveInfo]::GetDrives() | Where-Object {
    $_.DriveType -eq [IO.DriveType]::Fixed -and $_.IsReady
})
if (-not $volumes.Count) { throw 'No ready fixed volumes were found.' }

Write-Host 'FIND WHAT IS USING DISK SPACE'
Write-Host ''
Write-Host 'VOLUMES'
foreach ($volume in $volumes) {
    Write-Host ('{0} Free: {1:N2} GiB of {2:N2} GiB' -f $volume.Name, ($volume.TotalFreeSpace / 1GB), ($volume.TotalSize / 1GB))
}
if (-not $Drive) { $Drive = Read-Host 'Drive letter to inspect (blank cancels)' }
if ([string]::IsNullOrWhiteSpace($Drive)) { return }
$letter = $Drive.Trim().TrimEnd(':', '\')
if ($letter -notmatch '^[A-Za-z]$') { throw 'Enter one drive letter, such as C.' }
$root = $letter.ToUpperInvariant() + ':\'
if ($root -notin $volumes.Name) { throw 'Choose a ready fixed volume from the list.' }

$totals = @{}
$unreadable = 0
$reparse = 0
$stack = [System.Collections.Generic.Stack[object]]::new()
$stack.Push([pscustomobject]@{ Path = $root; Bucket = $null })
while ($stack.Count) {
    $entry = $stack.Pop()
    $readErrors = @()
    $children = @(Get-ChildItem -LiteralPath $entry.Path -Force -ErrorAction SilentlyContinue -ErrorVariable readErrors)
    if ($readErrors.Count) { $unreadable++ }
    foreach ($child in $children) {
        if ($child.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            $reparse++
            continue
        }
        $bucket = if ($entry.Bucket) { $entry.Bucket } elseif ($child.PSIsContainer) { $child.FullName } else { 'Files at drive root' }
        if (-not $totals.ContainsKey($bucket)) { $totals[$bucket] = [long]0 }
        if ($child.PSIsContainer) {
            $stack.Push([pscustomobject]@{ Path = $child.FullName; Bucket = $bucket })
        } else {
            $totals[$bucket] += [long]$child.Length
        }
    }
}

Write-Host ''
Write-Host "LARGEST LOCATIONS ON $root"
foreach ($location in ($totals.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First $Top)) {
    Write-Host ('{0:N2} GiB  {1}' -f ($location.Value / 1GB), $location.Key)
}
if (-not $totals.Count) { Write-Host 'No readable file locations were measured.' }
Write-Host ''
Write-Host "Directories with read errors: $unreadable"
Write-Host "Reparse points skipped: $reparse"
Write-Host 'Sizes reflect readable file lengths. Compare with volume free space separately.'
