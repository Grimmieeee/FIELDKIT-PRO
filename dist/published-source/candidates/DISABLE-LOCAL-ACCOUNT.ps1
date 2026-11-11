#Requires -Version 5.1
# .VERSION 0.2.0
# OBJECTIVE: Disable one explicitly confirmed non-administrator local account on this computer.
<#
.SYNOPSIS
Guarded local account disable by immutable SID.
.DESCRIPTION
Requires elevation and Microsoft.PowerShell.LocalAccounts. Refuses the current
execution identity, built-in Administrator, and direct members of local
Administrators. Does not log off sessions, terminate processes, or change domain
accounts. Rechecks identity and eligibility after typed confirmation and verifies
Enabled afterwards. No automatic elevation, prerequisite install, or export.
#>
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Medium')]
param([string]$Name,[switch]$NoPause)
Write-Host "Disable Local Account"
$ErrorActionPreference = 'Stop'
$outcome = 'FAILED'
$attempted = $false

function Test-FkDisableEligibility {
    param([Parameter(Mandatory=$true)]$Account,[Parameter(Mandatory=$true)][string]$CurrentSid)
    $sid = [string]$Account.SID.Value
    if ([string]::IsNullOrWhiteSpace($sid)) { throw 'Target SID is unavailable.' }
    if ($sid -eq $CurrentSid) { throw 'The current execution account cannot be disabled.' }
    if ($sid -match '-500$') { throw 'The built-in Administrator account is outside this tool scope.' }
    $members = @(Get-LocalGroupMember -SID 'S-1-5-32-544' -ErrorAction Stop)
    if (@($members | Where-Object { $_.SID.Value -eq $sid }).Count -gt 0) { throw 'Local Administrators members are outside this tool scope. Use a separately approved administrator-account procedure.' }
    if ($Account.Enabled -ne $true -and $Account.Enabled -ne $false) { throw 'Account enabled state is unavailable.' }
}

try {
    Write-Host 'DISABLE LOCAL ACCOUNT // MAKES CHANGES'
    Write-Host ''
    if ($env:OS -ne 'Windows_NT') { throw 'Windows is required.' }
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    try {
        $currentSid = $identity.User.Value
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run in an authorized elevated PowerShell host.' }
    } finally { $identity.Dispose() }
    Import-Module Microsoft.PowerShell.LocalAccounts -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($Name)) {
        if ($NoPause) { throw 'Specify -Name. NoPause does not authorize unattended changes.' }
        $Name = Read-Host 'Username'
    }
    $Name = $Name.Trim()
    if ([string]::IsNullOrWhiteSpace($Name) -or $Name -match '[\\/\*\?\[\]]') { throw 'Enter one exact local username, without domain prefixes or wildcard characters.' }
    $matches = @(Get-LocalUser -Name $Name -ErrorAction Stop | Where-Object { $_.Name -ieq $Name })
    if ($matches.Count -ne 1) { throw 'One exact local account must resolve.' }
    $account = $matches[0]
    $sid = $account.SID.Value
    Test-FkDisableEligibility -Account $account -CurrentSid $currentSid
    Write-Host ('{0}\{1}' -f $env:COMPUTERNAME,$account.Name)
    Write-Host 'Existing sessions stay open. Services or tasks using this account may be affected.'
    if (-not $account.Enabled) {
        $outcome = 'NO CHANGE // ALREADY DISABLED'
    } elseif ($PSCmdlet.ShouldProcess("$env:COMPUTERNAME\$($account.Name) [$sid]",'Disable local account')) {
        if ($NoPause) { throw 'Changes require an interactive typed confirmation. Omit NoPause to proceed.' }
        $expected = "DISABLE $env:COMPUTERNAME\$($account.Name)"
        $answer = Read-Host "Type $expected to continue [Enter = cancel]"
        if ($answer -cne $expected) { $outcome = 'CANCELLED // NO CHANGE' }
        else {
            $fresh = Get-LocalUser -SID $sid -ErrorAction Stop
            if ($fresh.SID.Value -ne $sid -or $fresh.Name -cne $account.Name -or $fresh.Enabled -ne $true) { throw 'Account identity or state changed after confirmation. Start again.' }
            Test-FkDisableEligibility -Account $fresh -CurrentSid $currentSid
            $attempted = $true
            Disable-LocalUser -SID $sid -Confirm:$false -ErrorAction Stop
            $verified = Get-LocalUser -SID $sid -ErrorAction Stop
            if ($verified.SID.Value -ne $sid -or $verified.Enabled -ne $false) { throw 'Disable was requested, but disabled state was not verified.' }
            $outcome = 'DISABLED // VERIFIED'
        }
    } else { $outcome = 'NO CHANGE // PREVIEW OR DECLINED' }
    switch ($outcome) {
        'DISABLED // VERIFIED' { Write-Host 'Account disabled. Confirmed.' }
        'NO CHANGE // ALREADY DISABLED' { Write-Host 'Account is already disabled.' }
        'CANCELLED // NO CHANGE' { Write-Host 'Cancelled. No changes made.' }
        default { Write-Host 'No changes made.' }
    }
} catch {
    $outcome = if ($attempted) { 'FAILED // CHANGE ATTEMPTED; RECHECK ACCOUNT STATE' } else { 'FAILED // NO CHANGE ATTEMPTED' }
    Write-Host ('FAILED: {0}' -f $_.Exception.Message) -ForegroundColor Red
    if ($attempted) { Write-Host 'A change was attempted. Check the account state before retrying.' }
    else { Write-Host 'No change attempted.' }
    if ($NoPause) { throw }
} finally {
    if (-not $NoPause) { [void](Read-Host 'Press Enter to finish.') }
}
