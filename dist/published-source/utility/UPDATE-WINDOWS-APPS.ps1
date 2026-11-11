<#
.VERSION 1.1.0
#>
# OBJECTIVE: Review and update installed applications using WinGet.

#Requires -Version 5.1

<#
.SYNOPSIS
Review and install normal WinGet application updates.

.DESCRIPTION
Shows available WinGet upgrades, asks for typed confirmation, applies selected or all
eligible updates, then shows anything still remaining. Does not force pinned or
unknown-version packages.
#>

[CmdletBinding()]
param(
    [switch]$ReviewOnly,
    [switch]$NoPause
)
Write-Host 'UPDATE-WINDOWS-APPS.ps1 // MAKES CHANGES'
Write-Host ''
Write-Host 'Objective: Review and update installed applications using WinGet.'
Write-Host ''

$ErrorActionPreference = 'Stop'

function Write-Ok   { param([string]$Message) Write-Host "[OK]   $Message" -ForegroundColor Green }
function Write-Info { param([string]$Message) Write-Host "[INFO] $Message" }
function Write-Warn { param([string]$Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Fail { param([string]$Message) Write-Host "[FAIL] $Message" -ForegroundColor Red }
function Show-Section { param([string]$Title) Write-Host ''; Write-Host ("{0} " -f $Title) -ForegroundColor White -BackgroundColor DarkGray }
function Pause-End { if (-not $NoPause) { Write-Host ''
                                          Write-Host 'SESSION COMPLETE'
                                          Write-Host ''; Read-Host 'Press ENTER to close.' | Out-Null } }

function Confirm-Type {
    param([string]$Required)
    $answer = Read-Host "Type $Required to continue"
    return (-not [string]::IsNullOrWhiteSpace($answer) -and $answer.Trim().ToUpperInvariant() -eq $Required)
}

try {
    Write-Host 'Review and update installed applications using WinGet.'
    Write-Host 'Uses WinGet to review and update installed applications.'

    $wingetCommand = Get-Command winget -ErrorAction Stop
    $winget = if ($wingetCommand.Source) { $wingetCommand.Source } else { 'winget' }

    Show-Section 'AVAILABLE UPDATES'
    $listing = @(& $winget upgrade --accept-source-agreements)
    if ($LASTEXITCODE -ne 0) { throw "WinGet review failed with exit code $LASTEXITCODE." }
    $listing | ForEach-Object { Write-Host $_ }
    if ($ReviewOnly) { return }

    $packages = @()
    $columns = $null
    foreach ($line in $listing) {
        if ($line -match '^Name\s+Id\s+Version\s+Available(?:\s+Source)?\s*$') {
            $columns = @{ Id = $line.IndexOf('Id'); Version = $line.IndexOf('Version') }
            continue
        }
        if (-not $columns -or $line.Length -le $columns.Version) { continue }
        $id = $line.Substring($columns.Id, $columns.Version - $columns.Id).Trim()
        if ($id -notmatch '^[A-Za-z0-9][A-Za-z0-9._+-]*$') { continue }
        $packages += [pscustomobject]@{ Name = $line.Substring(0,$columns.Id).Trim(); Id = $id }
    }
    $packages = @($packages | Group-Object Id | Where-Object Count -eq 1 | ForEach-Object { $_.Group[0] })
    if ($packages.Count) {
        Show-Section 'SELECTABLE UPDATES'
        for ($i=0; $i -lt $packages.Count; $i++) {
            Write-Host ('{0}. {1} [{2}]' -f ($i+1), $packages[$i].Name, $packages[$i].Id)
        }
    } else {
        Write-Info 'No individual packages could be numbered. Review the WinGet listing above.'
    }

    $choice = (Read-Host 'Enter numbers (1,2,5), ALL, or press Enter to cancel').Trim()
    if (-not $choice) { return }
    $all = $choice -ieq 'ALL'
    $selected = @()
    if (-not $all) {
        foreach ($token in ($choice -split ',')) {
            $number = 0
            if (-not [int]::TryParse($token.Trim(),[ref]$number) -or $number -lt 1 -or $number -gt $packages.Count) {
                throw 'Invalid selection. No updates installed.'
            }
            $selected += $packages[$number-1].Id
        }
        $selected = @($selected | Select-Object -Unique)
    }
    if ($all) { Write-Warn 'WinGet will attempt all normally eligible updates.' }
    else { Write-Info ('Selected: ' + ($selected -join ', ')) }
    if (-not (Confirm-Type -Required 'UPDATE')) {
        Write-Warn 'Cancelled. No updates installed.'
        return
    }

    Show-Section 'UPDATE'
    $updateExit = 0
    $options = @('--silent','--accept-source-agreements','--accept-package-agreements','--disable-interactivity')
    if ($all) {
        & $winget upgrade --all @options
        $updateExit = $LASTEXITCODE
    } else {
        foreach ($id in $selected) {
            & $winget upgrade --id $id --exact @options
            if ($LASTEXITCODE -ne 0) {
                $updateExit = $LASTEXITCODE
                Write-Warn "$id returned exit code $updateExit."
            }
        }
    }
    if ($updateExit -eq 0) { Write-Ok 'WinGet update command completed.' }
    else { Write-Warn "WinGet completed with exit code $updateExit." }

    Show-Section 'REMAINING UPDATES'
    & $winget upgrade --accept-source-agreements
    $verifyExit = $LASTEXITCODE
    if ($verifyExit -eq 0) { Write-Ok 'Post-update review completed.' }
    else { Write-Warn "Post-update review returned exit code $verifyExit." }

    Show-Section 'RESULTS'
    Write-Info "Update command exit: $updateExit"
    Write-Info "Review command exit: $verifyExit"
    if ($updateExit -eq 0 -and $verifyExit -eq 0) { Write-Info 'STATUS: Update pass finished; review remaining packages above. This does not prove every application is current.' }
    else { Write-Warn 'STATUS: Incomplete - update or post-update review failed. Review the WinGet output before closing the task.' }
} catch {
    Write-Host ''
    Write-Fail $_.Exception.Message
} finally {
    Pause-End
}
