#Requires -Version 5.1
<#
.SYNOPSIS
Verify access to on-premises Active Directory and its synced Microsoft Entra tenant.
.DESCRIPTION
Reads one user from each directory and checks whether Entra reports an active
on-premises sync relationship with the same AD security identifier.
Requires ActiveDirectory, Microsoft.Graph.Authentication, Microsoft.Graph.Users,
and delegated User.Read.All consent for the Microsoft Graph sign-in.
Uses the user's cloud UPN suffix to target the Entra tenant. AD queries use the
current Windows credentials. Supply a domain controller when discovery cannot
locate the intended domain. Exit codes: 0 verified, 1 failed or inconclusive,
2 invalid input. This check does not verify write permissions or sync execution.
.EXAMPLE
.\Client-Connectivity-Check.ps1 -UserPrincipalName '<synced-user-upn>' -DomainController '<dc-fqdn>'
#>
[CmdletBinding()]
param(
    [string]$UserPrincipalName,
    [string]$DomainController
)

Write-Host 'CLIENT CONNECTIVITY CHECK // READ ONLY'

if ([string]::IsNullOrWhiteSpace($UserPrincipalName)) {
    $UserPrincipalName = Read-Host 'Enter a known synced user UPN'
}
$UserPrincipalName = ([string]$UserPrincipalName).Trim()
if ($UserPrincipalName -notmatch '^[^@\s]+@[^@\s]+$') {
    Write-Host 'INPUT: FAIL - Enter a valid cloud user UPN.'
    exit 2
}
if (-not $PSBoundParameters.ContainsKey('DomainController')) {
    $DomainController = Read-Host 'AD domain controller (Enter for automatic discovery)'
}
$adTarget = @{}
if (-not [string]::IsNullOrWhiteSpace($DomainController)) {
    $adTarget.Server = $DomainController.Trim()
}

$entraUser = $null
try {
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Import-Module Microsoft.Graph.Users -ErrorAction Stop
    $tenantDomain = ($UserPrincipalName -split '@', 2)[1]
    Connect-MgGraph -TenantId $tenantDomain -Scopes 'User.Read.All' -ContextScope Process -NoWelcome -ErrorAction Stop | Out-Null

    $properties = @('id', 'userPrincipalName', 'onPremisesSyncEnabled', 'onPremisesSecurityIdentifier', 'onPremisesLastSyncDateTime')
    $entraUser = Get-MgUser -UserId $UserPrincipalName -Property $properties -ErrorAction Stop
    if (-not $entraUser.Id) { throw 'The Entra query returned no user.' }
    Write-Host ('ENTRA: PASS - Read {0}.' -f $entraUser.UserPrincipalName)
} catch {
    $entraUser = $null
    Write-Host ('ENTRA: FAIL - {0}' -f $_.Exception.Message)
    Write-Host 'Check the Graph modules, sign-in, User.Read.All consent, and cloud UPN.'
}

$adUser = $null
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    if ($entraUser.OnPremisesSecurityIdentifier) {
        $adUser = Get-ADUser @adTarget -Identity $entraUser.OnPremisesSecurityIdentifier -ErrorAction Stop
    } else {
        $adMatches = @(Get-ADUser @adTarget -Filter { UserPrincipalName -eq $UserPrincipalName } -ResultSetSize 2 -ErrorAction Stop)
        if ($adMatches.Count -ne 1) { throw 'The AD query did not return exactly one user for that UPN.' }
        $adUser = $adMatches[0]
    }
    if (-not $adUser.SID) { throw 'The AD query returned no user SID.' }
    Write-Host ('AD: PASS - Read {0}.' -f $adUser.SamAccountName)
} catch {
    $adUser = $null
    Write-Host ('AD: FAIL - {0}' -f $_.Exception.Message)
    Write-Host 'Check the ActiveDirectory module, client network access, and target domain controller.'
}

if (-not $entraUser -or -not $adUser) {
    Write-Host 'SYNC LINK: SKIP - Both directory reads must succeed.'
    exit 1
}
if ($entraUser.OnPremisesSyncEnabled -ne $true) {
    Write-Host 'SYNC LINK: FAIL - Entra does not report this user as currently synced.'
    exit 1
}
if ([string]::IsNullOrWhiteSpace($entraUser.OnPremisesSecurityIdentifier)) {
    Write-Host 'SYNC LINK: INCONCLUSIVE - Entra returned no on-premises SID.'
    exit 1
}
if ($adUser.SID.Value -ne $entraUser.OnPremisesSecurityIdentifier) {
    Write-Host 'SYNC LINK: FAIL - The AD and Entra security identifiers differ.'
    exit 1
}
Write-Host 'SYNC LINK: PASS - Entra reports active on-premises sync and the AD SID matches.'
if ($entraUser.OnPremisesLastSyncDateTime) {
    Write-Host ('Last user sync reported by Entra: {0:u}' -f $entraUser.OnPremisesLastSyncDateTime)
}
exit 0
