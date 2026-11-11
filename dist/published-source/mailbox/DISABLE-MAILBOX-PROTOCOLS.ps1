#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Mailbox,
    [ValidateSet('POP','IMAP','SMTP AUTH')]
    [string[]]$Protocol
)
Write-Host 'DISABLE-MAILBOX-PROTOCOLS.ps1 // MAKES CHANGES'
Write-Host ''
Write-Host 'Objective: Disable selected mailbox-level POP, IMAP, or SMTP AUTH settings after approval.'
Write-Host ''

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
function Assert-MailboxContext {
    $current = @(Get-ConnectionInformation | Where-Object State -eq 'Connected')
    if ($current.Count -ne 1 -or [string]$current[0].ConnectionId -ne $connectionId) {
        throw 'Exchange Online connection changed. Start a new run.'
    }
}

Write-Host 'DISABLE MAILBOX PROTOCOLS'
Write-Host ''
Write-Host 'TARGET'
Write-Host "Mailbox: $($target.PrimarySmtpAddress)"
Write-Host ''

$cas = Get-CASMailbox -Identity $id
if (-not $cas -or $null -eq $cas.PopEnabled -or $null -eq $cas.ImapEnabled) { throw 'Mailbox protocol settings unavailable.' }
Write-Host 'CURRENT SETTINGS'
Write-Host "POP enabled: $($cas.PopEnabled)"
Write-Host "IMAP enabled: $($cas.ImapEnabled)"
$smtp = if ($null -eq $cas.SmtpClientAuthenticationDisabled) { 'Inherits organization setting' } elseif ($cas.SmtpClientAuthenticationDisabled) { 'Disabled' } else { 'Enabled' }
Write-Host "SMTP AUTH: $smtp"
if (-not $Protocol) {
    Write-Host ''
    $selection = Read-Host 'Protocols to disable (POP, IMAP, SMTP AUTH), comma-separated. Blank cancels'
    if (-not $selection.Trim()) { return }
    $Protocol = @($selection -split ',' | ForEach-Object { $_.Trim() })
    if (@($Protocol | Where-Object { $_ -notin 'POP','IMAP','SMTP AUTH' }).Count) { throw 'Unknown protocol. No changes made.' }
}
$change = @{}
if ($Protocol -contains 'POP' -and $cas.PopEnabled -ne $false) { $change.PopEnabled = $false }
if ($Protocol -contains 'IMAP' -and $cas.ImapEnabled -ne $false) { $change.ImapEnabled = $false }
if ($Protocol -contains 'SMTP AUTH' -and $cas.SmtpClientAuthenticationDisabled -ne $true) { $change.SmtpClientAuthenticationDisabled = $true }
if (-not $change.Count) { Write-Host 'Result: Selected protocols already disabled.'; return }
Write-Host ''
Write-Host 'PLANNED CHANGE'
Write-Host "Selected protocols: $($Protocol -join ', ')"
if ((Read-Host "Type DISABLE $Mailbox to apply") -cne "DISABLE $Mailbox") { Write-Host 'Result: Cancelled.'; return }
Assert-MailboxContext
$fresh = Get-CASMailbox -Identity $id
if (-not $fresh) { throw 'Unable to recheck protocol settings. No change made.' }
foreach ($property in $change.Keys) {
    if ($fresh.$property -ne $cas.$property) { throw 'Protocol settings changed after preview. Start a new run.' }
}
Set-CASMailbox -Identity $id @change
$after = Get-CASMailbox -Identity $id
if (-not $after) { throw 'Change submitted. Result could not be verified.' }
foreach ($property in $change.Keys) {
    if ($after.$property -ne $change[$property]) { throw 'Change submitted. Requested settings could not be verified.' }
}
Write-Host ''
Write-Host 'Result: Selected protocols disabled and verified.'
