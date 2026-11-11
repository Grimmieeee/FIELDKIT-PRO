#Requires -Version 5.1
[CmdletBinding()]
param([string]$Mailbox)
Write-Host "Get Mailbox Usage Statistics"

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
Write-Host 'GET MAILBOX USAGE STATISTICS'
Write-Host ''
Write-Host 'TARGET'
Write-Host "Mailbox: $($target.PrimarySmtpAddress)"
Write-Host ''

if (-not $target.ExchangeGuid -or $target.ExchangeGuid -eq [guid]::Empty) { throw "Mailbox statistics identity unavailable." }
$stats = Get-MailboxStatistics -Identity $target.ExchangeGuid
if (-not $stats) { throw 'Mailbox statistics unavailable.' }
Write-Host 'USAGE'
Write-Host "Item count: $($stats.ItemCount)"
Write-Host "Total size: $($stats.TotalItemSize)"
$lastLogon = if ($stats.LastLogonTime) { $stats.LastLogonTime } else { 'Not reported' }
Write-Host "Last mailbox logon: $lastLogon"
Write-Host "Archive status: $($target.ArchiveStatus)"
