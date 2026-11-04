#Requires -Version 5.1
# .VERSION 0.2.0
# OBJECTIVE: Show logged-on Windows user sessions on one computer.
<#
.SYNOPSIS
Show Windows user sessions using quser.exe.
.DESCRIPTION
Read-only. Blank input means this computer. Preserves native localized output,
including console and disconnected user sessions. Does not enumerate PowerShell
remoting sessions, SMB sessions, or log anyone off. A nonzero native exit code
is unavailable evidence, never an empty or clean result. No installation occurs.
.EXAMPLE
.\GET-REMOTE-SESSIONS.ps1 -ComputerName '<computer>' -NoPause
#>
[CmdletBinding()]
param(
    [string]$ComputerName,
    [switch]$NoPause,
    [switch]$PassThru
)
$ErrorActionPreference = 'Stop'
$outcome = 'FAILED'
try {
    Write-Host 'USER SESSIONS // READ ONLY'
    Write-Host ''
    if ($env:OS -ne 'Windows_NT') { throw 'Windows is required.' }
    if (-not $PSBoundParameters.ContainsKey('ComputerName') -and -not $NoPause) {
        $ComputerName = Read-Host 'Computer [this computer]'
    }
    $ComputerName = ([string]$ComputerName).Trim()
    if ($ComputerName -and $ComputerName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,252}$') {
        throw 'Use one hostname, FQDN, or IPv4 address without spaces, slashes, or switches.'
    }
    $target = if ($ComputerName) { $ComputerName } else { $env:COMPUTERNAME }
    Write-Host "Computer: $target"
    $native = Get-Command quser.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $native) { throw 'quser.exe is unavailable on this Windows installation.' }
    $nativeArgs = @()
    if ($ComputerName) { $nativeArgs = @("/server:$ComputerName") }
    # Native stderr can become a terminating NativeCommandError in Windows PS 5.1.
    # Capture it with Continue, then evaluate the actual process exit code.
    $savedPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $nativeOutput = @(& $native.Source @nativeArgs 2>&1)
        $nativeCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $savedPreference }
    $lines = @($nativeOutput | ForEach-Object { [string]$_ })
    foreach ($line in $lines) { Write-Host $line }
    if ($nativeCode -ne 0) { throw "quser exited with code $nativeCode. Session state is unconfirmed; review its message above." }
    if ($lines.Count -eq 0) { throw 'quser returned no output; session state is unconfirmed.' }
    $outcome = 'COMPLETE'
    if ($PassThru) { $lines }
} catch {
    $outcome = 'FAILED'
    Write-Host ('FAILED: {0}' -f $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Check the computer name, permissions, and remote connectivity.'
    if ($NoPause) { throw }
} finally {
    if (-not $NoPause) { [void](Read-Host 'Press Enter to finish.') }
}
