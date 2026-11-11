#Requires -Version 5.1
[CmdletBinding()]
param([string]$Mailbox)
Write-Host 'REMOVE-MAILBOX-DELEGATE.ps1 // MAKES CHANGES'
Write-Host ''
Write-Host 'Objective: Remove one direct Full Access, Send As, or Send on Behalf grant after approval.'
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


function Get-DirectDelegates {
    $mailboxState = Get-Mailbox -Identity $id
    if (-not $mailboxState) { throw 'Mailbox could not be read.' }
    foreach ($entry in Get-MailboxPermission -Identity $id) {
        if (-not $entry.IsInherited -and -not $entry.Deny -and $entry.AccessRights -contains 'FullAccess' -and [string]$entry.User -ne 'NT AUTHORITY\SELF') {
            [pscustomobject]@{ Right = 'Full Access'; Trustee = [string]$entry.User }
        }
    }
    foreach ($entry in Get-RecipientPermission -Identity $id) {
        if (-not $entry.IsInherited -and $entry.AccessControlType -ne 'Deny' -and $entry.AccessRights -contains 'SendAs' -and [string]$entry.Trustee -ne 'NT AUTHORITY\SELF') {
            [pscustomobject]@{ Right = 'Send As'; Trustee = [string]$entry.Trustee }
        }
    }
    foreach ($entry in $mailboxState.GrantSendOnBehalfTo) {
        if ($entry) {
            $trustee = if ($entry.DistinguishedName) { $entry.DistinguishedName } else { [string]$entry }
            [pscustomobject]@{ Right = 'Send on Behalf'; Trustee = $trustee }
        }
    }
}

Write-Host 'REMOVE MAILBOX DELEGATE'
Write-Host ''
Write-Host 'TARGET'
Write-Host "Mailbox: $($target.PrimarySmtpAddress)"
Write-Host ''

$grants = @(Get-DirectDelegates | Where-Object Trustee | Sort-Object Right, Trustee -Unique)
if (-not $grants.Count) { Write-Host 'Result: No direct delegate grants found.'; return }
Write-Host 'DIRECT DELEGATE GRANTS'
for ($i = 0; $i -lt $grants.Count; $i++) {
    $grant = $grants[$i]
    $recipient = Get-Recipient -Identity $grant.Trustee -ErrorAction SilentlyContinue
    $grant | Add-Member -NotePropertyName Label -NotePropertyValue $(if ($recipient.PrimarySmtpAddress) { [string]$recipient.PrimarySmtpAddress } else { 'Unresolved trustee' })
    Write-Host "[$($i + 1)] $($grant.Label) | $($grant.Right)"
}
[int]$choice = 0
if (-not [int]::TryParse((Read-Host 'Select one grant number. Blank cancels'), [ref]$choice) -or $choice -lt 1 -or $choice -gt $grants.Count) { return }
$selected = $grants[$choice - 1]
if ($selected.Label -eq 'Unresolved trustee') { throw 'Unable to verify the trustee by email address. No change made.' }
Write-Host ''
Write-Host "Remove: $($selected.Right) for $($selected.Label)"
if ((Read-Host "Type REMOVE $Mailbox to apply") -cne "REMOVE $Mailbox") { Write-Host 'Result: Cancelled.'; return }
Assert-MailboxContext
function Find-SelectedGrant {
    Get-DirectDelegates | Where-Object { $_.Right -eq $selected.Right -and $_.Trustee -eq $selected.Trustee }
}
if (@(Find-SelectedGrant).Count -ne 1) { throw 'Grant changed after preview. Start a new run.' }
switch ($selected.Right) {
    'Full Access' { Remove-MailboxPermission -Identity $id -User $selected.Trustee -AccessRights FullAccess -Confirm:$false | Out-Null }
    'Send As' { Remove-RecipientPermission -Identity $id -Trustee $selected.Trustee -AccessRights SendAs -Confirm:$false | Out-Null }
    'Send on Behalf' { Set-Mailbox -Identity $id -GrantSendOnBehalfTo @{Remove=$selected.Trustee} }
}
if (@(Find-SelectedGrant).Count) { throw 'Removal submitted. The grant is still visible.' }
Write-Host ''
Write-Host 'Result: Selected grant removed and verified.'
