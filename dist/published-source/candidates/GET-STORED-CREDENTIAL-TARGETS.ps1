#Requires -Version 5.1
# .VERSION 0.2.0
# OBJECTIVE: List stored Windows credential targets for the current execution identity.
<#
.SYNOPSIS
List credential target references using cmdkey.exe.
.DESCRIPTION
Read-only. Preserves native localized text. Does not retrieve passwords or
list every user's credential store. An elevated or service session can have a
different identity and store. No credentials are added, deleted, or exported.
#>
[CmdletBinding()]
param([switch]$NoPause,[switch]$PassThru)
Write-Host "Stored Credential Targets"
$ErrorActionPreference = 'Stop'
$outcome = 'FAILED'
try {
    Write-Host 'READ ONLY'
    Write-Host ''
    if ($env:OS -ne 'Windows_NT') { throw 'Windows is required.' }
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    try { Write-Host ('User: {0}' -f $identity.Name) }
    finally { $identity.Dispose() }
    $command = Get-Command cmdkey.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1
    $saved = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $result = @(& $command.Source /list 2>&1)
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $saved }
    $lines = @($result | ForEach-Object { [string]$_ })
    foreach ($line in $lines) { Write-Host $line }
    if ($code -ne 0) { throw "cmdkey exited with code $code. Credential-store contents are unconfirmed." }
    if ($lines.Count -eq 0) { throw 'cmdkey returned no output. Credential-store contents are unconfirmed.' }
    Write-Host 'This user only. Passwords are not shown.'
    $outcome = 'COMPLETE'
    if ($PassThru) { $lines }
} catch {
    Write-Host ('FAILED: {0}' -f $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Run as the intended user. Check that cmdkey.exe is available.'
    if ($NoPause) { throw }
} finally {
    if (-not $NoPause) { [void](Read-Host 'Press Enter to finish.') }
}
