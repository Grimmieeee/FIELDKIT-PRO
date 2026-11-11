#Requires -Version 5.1
[CmdletBinding()]
param([string]$UserPrincipalName)
Write-Host 'REMOVE-USER-APP-CONSENT.ps1 // MAKES CHANGES'
Write-Host ''
Write-Host 'Objective: Remove one selected user-specific delegated app grant after approval.'
Write-Host ''

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


function Get-UserGrants {
    $uri = "$graph/v1.0/users/$id/oauth2PermissionGrants"
    do {
        $page = Invoke-MgGraphRequest -Method GET -Uri $uri
        $page.value | Where-Object { $_.consentType -eq 'Principal' -and $_.principalId -eq $id -and $_.id }
        $uri = $page.'@odata.nextLink'
    } while ($uri)
}

Write-Host 'REMOVE USER APP CONSENT'
Write-Host ''
Write-Host 'TARGET'
Write-Host "User: $($user.displayName) <$UserPrincipalName>"
Write-Host ''
$grants = @(Get-UserGrants)
if (-not $grants.Count) { Write-Host 'Result: No user-specific delegated grants found.'; return }
Write-Host 'USER-SPECIFIC GRANTS'
$choices = for ($i = 0; $i -lt $grants.Count; $i++) {
    $grant = $grants[$i]
    $app = Invoke-MgGraphRequest -Method GET -Uri "$graph/v1.0/servicePrincipals/$($grant.clientId)?`$select=displayName"
    $resource = Invoke-MgGraphRequest -Method GET -Uri "$graph/v1.0/servicePrincipals/$($grant.resourceId)?`$select=displayName"
    if (-not $app.displayName -or -not $resource.displayName) { throw 'Unable to identify an app or resource by name. No grants changed.' }
    Write-Host "[$($i + 1)] $($app.displayName) | $($resource.displayName) | $($grant.scope)"
    [pscustomobject]@{ Grant=$grant; App=$app.displayName; Resource=$resource.displayName }
}
[int]$choice = 0
if (-not [int]::TryParse((Read-Host 'Select one grant number. Blank cancels'), [ref]$choice) -or $choice -lt 1 -or $choice -gt $grants.Count) { return }
$selected = @($choices)[$choice - 1]
$grant = $selected.Grant
Write-Host ''
Write-Host "Remove: $($selected.App) | $($selected.Resource) | $($grant.scope)"
if ((Read-Host "Type REMOVE $UserPrincipalName to apply") -cne "REMOVE $UserPrincipalName") { Write-Host 'Result: Cancelled.'; return }
Assert-GraphContext
$freshUser = Invoke-MgGraphRequest -Method GET -Uri "${userUri}?`$select=id"
if ($freshUser.id -ne $id) { throw 'User changed after preview. Start a new run.' }
$fresh = @(Get-UserGrants | Where-Object id -eq $grant.id)
if ($fresh.Count -ne 1 -or $fresh[0].clientId -ne $grant.clientId -or $fresh[0].resourceId -ne $grant.resourceId -or $fresh[0].scope -cne $grant.scope) {
    throw 'Grant changed after preview. Start a new run.'
}
Invoke-MgGraphRequest -Method DELETE -Uri "$graph/v1.0/oauth2PermissionGrants/$($grant.id)" | Out-Null
if (@(Get-UserGrants | Where-Object id -eq $grant.id).Count) { throw 'Removal submitted. The grant is still visible.' }
Write-Host ''
Write-Host 'Result: User-specific grant removed and verified.'
