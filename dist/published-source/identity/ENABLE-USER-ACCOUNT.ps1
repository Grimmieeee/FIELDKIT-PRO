#Requires -Version 5.1
[CmdletBinding()]
param([string]$UserPrincipalName)
Write-Host "Re-Enable User Account"

$moduleNames = @('Microsoft.Graph.Authentication')
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
if (-not $UserPrincipalName) { $UserPrincipalName = Read-Host 'UPN' }
$UserPrincipalName = $UserPrincipalName.Trim()
if ($UserPrincipalName -notmatch '^[^\s@]+@[^\s@]+$') { throw 'Enter the exact user sign-in name.' }
$context = Get-MgContext
if (-not $context -or -not $context.TenantId -or -not $context.Account) { throw 'Connect to the target tenant with Microsoft Graph PowerShell and retry.' }
$graph = (Get-MgEnvironment -Name $context.Environment).GraphEndpoint.TrimEnd('/')
$userUri = "$graph/v1.0/users/$([uri]::EscapeDataString($UserPrincipalName))"
$user = Invoke-MgGraphRequest -Method GET -Uri "${userUri}?`$select=id,displayName,userPrincipalName,userType,accountEnabled,onPremisesSyncEnabled,onPremisesSecurityIdentifier"
if (-not $user.id -or $user.userPrincipalName -ine $UserPrincipalName) { throw 'Unable to bind the exact user.' }
$id = [string]$user.id

function Assert-GraphContext {
    $current = Get-MgContext
    if (-not $current -or $current.TenantId -ne $context.TenantId -or $current.Account -ne $context.Account -or $current.Environment -ne $context.Environment) {
        throw 'Microsoft Graph connection changed. Start a new run.'
    }
}


if ($user.userType -ne 'Member' -or $null -eq $user.accountEnabled) {
    throw 'The target is not an eligible member account or its status is unavailable.'
}
$hybrid = $user.onPremisesSyncEnabled -eq $true
if ($hybrid) {
    if (-not $user.onPremisesSecurityIdentifier) { throw 'The synced account has no readable AD SID. No change made.' }
    Import-Module ActiveDirectory
    $ad = Get-ADUser -Identity $user.onPremisesSecurityIdentifier -Properties Enabled
    if ([string]$ad.SID -ne $user.onPremisesSecurityIdentifier) { throw 'Unable to verify the authoritative AD account.' }
    $domainDn = [regex]::Match($ad.DistinguishedName, '(?:DC=[^,]+,)*DC=[^,]+$', 'IgnoreCase').Value
    if (-not $domainDn) { throw 'Unable to discover the AD domain.' }
    $domain = Get-ADDomain -Identity $domainDn
    $server = $domain.PDCEmulator
    if (-not $server) { throw 'Unable to discover a writable domain controller.' }
    $ad = Get-ADUser -Identity $ad.ObjectGUID -Server $server -Properties Enabled
    if ([string]$ad.SID -ne $user.onPremisesSecurityIdentifier) { throw 'Unable to verify the authoritative AD account.' }
}
elseif ($user.onPremisesSecurityIdentifier) {
    throw 'The account has an AD SID without active sync. Verify its authority before re-enabling.'
}
$authority = if ($hybrid) { 'Active Directory' } else { 'Entra ID' }
$enabled = if ($hybrid) { $ad.Enabled } else { $user.accountEnabled }
Write-Host 'RE-ENABLE USER ACCOUNT'
Write-Host ''
Write-Host 'TARGET'
Write-Host "User: $($user.displayName) <$UserPrincipalName>"
Write-Host "Authority: $authority"
Write-Host ''
if ($enabled) { Write-Host 'Result: Already enabled at the authoritative source.'; return }
if ((Read-Host "Type ENABLE $UserPrincipalName to apply") -cne "ENABLE $UserPrincipalName") { Write-Host 'Result: Cancelled.'; return }
Assert-GraphContext
$fresh = Invoke-MgGraphRequest -Method GET -Uri "${userUri}?`$select=id,userType,accountEnabled,onPremisesSyncEnabled,onPremisesSecurityIdentifier"
if ($fresh.id -ne $id -or $fresh.userType -ne 'Member' -or $fresh.accountEnabled -ne $user.accountEnabled -or $fresh.onPremisesSyncEnabled -ne $user.onPremisesSyncEnabled -or $fresh.onPremisesSecurityIdentifier -ne $user.onPremisesSecurityIdentifier) {
    throw 'Account or authority changed after preview. Start a new run.'
}
if ($hybrid) {
    $currentAd = Get-ADUser -Identity $ad.ObjectGUID -Server $server -Properties Enabled
    if ($currentAd.Enabled -ne $false -or [string]$currentAd.SID -ne $user.onPremisesSecurityIdentifier) {
        throw 'AD account changed after preview. Start a new run.'
    }
    Enable-ADAccount -Identity $ad.ObjectGUID -Server $server
    if ((Get-ADUser -Identity $ad.ObjectGUID -Server $server).Enabled -ne $true) { throw 'Enable submitted. AD status could not be verified.' }
    Write-Host 'Result: Enabled and verified in Active Directory. Verify Entra after sync.'
}
else {
    Invoke-MgGraphRequest -Method PATCH -Uri "$graph/v1.0/users/$id" -Body '{"accountEnabled":true}' -ContentType 'application/json' | Out-Null
    $after = Invoke-MgGraphRequest -Method GET -Uri "$graph/v1.0/users/${id}?`$select=accountEnabled"
    if ($after.accountEnabled -ne $true) { throw 'Enable submitted. Entra status could not be verified.' }
    Write-Host 'Result: Enabled and verified in Entra ID.'
}
