#Requires -Version 5.1
[CmdletBinding()]
param([string]$Mailbox)
Write-Host "Get Mailbox Lit Hold Status"

$moduleNames = @('ExchangeOnlineManagement')
foreach ($moduleName in $moduleNames) {
    $minimum = if ($moduleName -eq 'ExchangeOnlineManagement') { [version]'3.2.0' }
    $module = Get-Module -ListAvailable -Name $moduleName |
        Where-Object { -not $minimum -or $_.Version -ge $minimum } |
        Sort-Object Version -Descending | Select-Object -First 1
    if (-not $module) {
        if (-not (Get-Command Install-Module -ErrorAction SilentlyContinue)) {
            throw "Cannot install $moduleName. Install-Module is unavailable in this PowerShell session."
        }
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        }
        Write-Host "Installing $moduleName for the current user..."
        $install = @{ Name = $moduleName; Scope = 'CurrentUser'; Repository = 'PSGallery'; Force = $true; ErrorAction = 'Stop' }
        if ($minimum) { $install.MinimumVersion = $minimum }
        Install-Module @install
        $module = Get-Module -ListAvailable -Name $moduleName |
            Where-Object { -not $minimum -or $_.Version -ge $minimum } |
            Sort-Object Version -Descending | Select-Object -First 1
        if (-not $module) { throw "Installed module $moduleName could not be found." }
    }
    Import-Module $module.Path -ErrorAction Stop
}

$ErrorActionPreference = 'Stop'
if (-not $Mailbox) { $Mailbox = Read-Host 'Primary mailbox email address' }
$Mailbox = $Mailbox.Trim()
if ($Mailbox -notmatch '^[^\s@]+@[^\s@]+$') { throw 'Enter the mailbox email address.' }
$connections = @(Get-ConnectionInformation | Where-Object State -eq 'Connected')
if ($connections.Count -ne 1) { throw 'Connect to exactly one Exchange Online organization and retry.' }
$connectionId = [string]$connections[0].ConnectionId
if (-not $connectionId) { throw 'Unable to identify the active Exchange Online connection.' }
$target = Get-Mailbox -Identity $Mailbox
if ([string]$target.PrimarySmtpAddress -ine $Mailbox -or -not $target.Guid -or $target.Guid -eq [guid]::Empty) {
    throw 'Mailbox could not be bound to the supplied primary address.'
}
$id = [string]$target.Guid
Write-Host 'GET MAILBOX LIT HOLD STATUS'
Write-Host ''
Write-Host 'TARGET'
Write-Host "Mailbox: $($target.PrimarySmtpAddress)"
Write-Host ''

Write-Host 'LITIGATION HOLD'
if ($null -eq $target.LitigationHoldEnabled) { throw 'Litigation hold status unavailable.' }
Write-Host "Enabled: $($target.LitigationHoldEnabled)"
if ($target.LitigationHoldEnabled) {
    Write-Host "Duration: $($target.LitigationHoldDuration)"
    if ($target.LitigationHoldDate) { Write-Host "Applied: $($target.LitigationHoldDate)" }
    if ($target.LitigationHoldOwner) { Write-Host "Applied by: $($target.LitigationHoldOwner)" }
}
Write-Host ''
Write-Host 'OTHER MAILBOX RETENTION SETTINGS'
$retentionHold = if ($null -ne $target.RetentionHoldEnabled) { $target.RetentionHoldEnabled } else { 'Not reported' }
$retentionPolicy = if ($target.RetentionPolicy) { $target.RetentionPolicy } else { 'None reported' }
Write-Host "Retention hold: $retentionHold"
Write-Host "Retention policy: $retentionPolicy"
foreach ($hold in $target.InPlaceHolds) {
    if ($hold) { Write-Host "In-place hold reference: $hold" }
}
