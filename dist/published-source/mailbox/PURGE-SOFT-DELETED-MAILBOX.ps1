#Requires -Version 5.1
<#
.SYNOPSIS
Preview or permanently delete one eligible soft-deleted Exchange Online mailbox.
.DESCRIPTION
Preview is the default. Purge requires -Purge and exact typed approval. Inactive
mailboxes and mailboxes with hold evidence or incomplete hold data are blocked.
This tool never changes holds or deletes an Entra user. Test-tenant candidate.
#>
[CmdletBinding()]
param([string]$MailboxAddress,[switch]$Purge)
Write-Host "Purge Soft-Deleted Mailbox"

$ErrorActionPreference = 'Stop'
$attempted = $false
$prefix = 'FKMailboxPurge'

function Get-ConnectedSession {
    @(Get-ConnectionInformation | Where-Object { $_.State -eq 'Connected' -and $_.ModulePrefix -eq $prefix })
}

function Assert-Session {
    $current = @(Get-ConnectedSession)
    if ($current.Count -ne 1 -or $current[0].ConnectionId -ne $connection.ConnectionId -or
        $current[0].TenantID -ne $connection.TenantID -or $current[0].UserPrincipalName -ne $connection.UserPrincipalName) {
        throw 'Exchange Online session changed.'
    }
}

function Get-SoftDeletedMailbox {
    param([string]$Filter)
    Assert-Session
    Get-FKMailboxPurgeMailbox -SoftDeletedMailbox -Filter $Filter -ResultSize Unlimited
}

function Assert-Eligible {
    param($Target)
    if ($Target.RecipientTypeDetails -notin @('UserMailbox','SharedMailbox') -or -not $Target.WhenSoftDeleted) {
        throw 'Mailbox type or soft-deleted state could not be verified.'
    }
    foreach ($name in 'IsInactiveMailbox','LitigationHoldEnabled','DelayHoldApplied','DelayReleaseHoldApplied','ComplianceTagHoldApplied') {
        $flag = $Target.PSObject.Properties[$name]
        if (-not $flag -or $flag.Value -isnot [bool] -or $flag.Value) {
            throw "Hold or inactive-mailbox check blocked purge: $name."
        }
    }
    if (-not $Target.PSObject.Properties['InPlaceHolds'] -or @($Target.InPlaceHolds | Where-Object { $_ }).Count) {
        throw 'Mailbox hold data is missing or a hold is present.'
    }
    $org = @(Get-FKMailboxPurgeOrganizationConfig)
    if ($org.Count -ne 1 -or -not $org[0].PSObject.Properties['InPlaceHolds'] -or
        @($org[0].InPlaceHolds | Where-Object { $_ }).Count) {
        throw 'Organization hold data is missing or an organization-wide hold needs review.'
    }
    $active = @(Get-FKMailboxPurgeMailbox -Filter $guidFilter -ResultSize Unlimited)
    if ($active.Count) { throw 'An active mailbox matches the Exchange GUID.' }
}

try {
    Write-Host 'PURGE SOFT-DELETED MAILBOX'
    Write-Host ''
    if (-not $MailboxAddress) { $MailboxAddress = Read-Host 'Exact primary mailbox email address' }
    $MailboxAddress = $MailboxAddress.Trim()
    if ($MailboxAddress -notmatch '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(?:\.[A-Za-z0-9\-]+)+$') {
        throw 'Enter one valid mailbox email address.'
    }

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
    $sessions = @(Get-ConnectedSession)
    if (-not $sessions.Count) {
        Connect-ExchangeOnline -Prefix $prefix -ShowBanner:$false | Out-Null
        $sessions = @(Get-ConnectedSession)
    }
    if ($sessions.Count -ne 1 -or -not $sessions[0].ConnectionId -or
        -not $sessions[0].TenantID -or -not $sessions[0].UserPrincipalName) {
        throw 'A single identifiable Exchange Online session is required.'
    }
    $connection = $sessions[0]

    $found = @(Get-SoftDeletedMailbox "PrimarySmtpAddress -eq '$MailboxAddress'")
    if ($found.Count -ne 1 -or [string]$found[0].PrimarySmtpAddress -ine $MailboxAddress) {
        throw 'Exactly one matching soft-deleted mailbox is required.'
    }
    $target = $found[0]
    $guid = [guid]::Empty
    if (-not [guid]::TryParse([string]$target.ExchangeGuid,[ref]$guid) -or $guid -eq [guid]::Empty) {
        throw 'Exchange mailbox identity is unavailable.'
    }
    $guidFilter = "ExchangeGuid -eq '$guid'"

    Write-Host 'TARGET'
    Write-Host "Signed in as: $($connection.UserPrincipalName)"
    Write-Host "Name: $($target.DisplayName)"
    Write-Host "Mailbox: $MailboxAddress"
    Write-Host "Soft-deleted: $($target.WhenSoftDeleted)"
    Write-Host ''
    Assert-Eligible $target
    if (-not $Purge) {
        Write-Host 'Status: Preview complete. No mailbox was purged.'
        return
    }
    Write-Host 'Permanent deletion prevents mailbox recovery.'
    $approval = "PURGE $MailboxAddress"
    if ((Read-Host "Type $approval to proceed") -cne $approval) {
        Write-Host 'Status: Cancelled. No mailbox was purged.'
        return
    }

    $fresh = @(Get-SoftDeletedMailbox $guidFilter)
    if ($fresh.Count -ne 1 -or [string]$fresh[0].ExchangeGuid -ne [string]$guid -or
        [string]$fresh[0].PrimarySmtpAddress -ine $MailboxAddress -or
        $fresh[0].WhenSoftDeleted -ne $target.WhenSoftDeleted -or
        $fresh[0].RecipientTypeDetails -ne $target.RecipientTypeDetails) {
        throw 'Mailbox changed after approval.'
    }
    Assert-Eligible $fresh[0]
    Assert-Session
    $attempted = $true
    $fresh[0] | Remove-FKMailboxPurgeMailbox -PermanentlyDelete -Confirm:$false -ErrorAction Stop
    Write-Host 'PURGE RESULTS'
    Write-Host 'Exchange accepted the purge command.'
    for ($i=0; $i -lt 6; $i++) {
        if (@(Get-SoftDeletedMailbox $guidFilter).Count -eq 0) {
            Write-Host 'Verification: Mailbox is absent from the soft-deleted inventory.'
            return
        }
        Start-Sleep -Seconds 5
    }
    throw 'Mailbox is still visible. Verify in Exchange before retrying.'
}
catch {
    Write-Host ''
    if ($attempted) { Write-Host 'Status: Purge attempted. Verify the mailbox state before retrying.' }
    else { Write-Host 'Status: Stopped before purge.' }
    Write-Host "Reason: $($_.Exception.Message -replace '\s+', ' ')"
    throw 'Soft-deleted mailbox purge did not complete.'
}
finally {
    Write-Host ''
    Write-Host "Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
}
