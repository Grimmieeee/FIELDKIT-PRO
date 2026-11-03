#Requires -Version 5.1
<#
.VERSION 1.1.0-candidate.2
Audit Tenant App Consent
Read-only candidate. Changed workflow is not operator verified.
Internal IDs are used only for matching and API calls; output and CSV use names.
#>
[CmdletBinding()]
param([string]$ExpectedTenantId, [switch]$IncludeVerifiedPublishers, [switch]$GuestOnly, [switch]$NoPause)
$ErrorActionPreference = "Stop"

if ($PSVersionTable.PSVersion.Major -lt 7) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

function OK($m)   { Write-Host "[OK]   $m" -ForegroundColor Green }
function INFO($m) { Write-Host "[INFO] $m" }
function WARN($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function RISK($m) { Write-Host "[RISK] $m" -ForegroundColor Red }
function FAIL($m) { Write-Host "[FAIL] $m" -ForegroundColor Red }

function Pause-End {
    Write-Host ''
    Write-Host 'F I E L D  //  K I T'
    Write-Host ""
    Read-Host 'Press Enter to close.' | Out-Null
}

function Now {
    return (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}

function Section {
    param([string]$Title)

    Write-Host ""
    Write-Host (" {0} " -f $Title) `
        -ForegroundColor White `
        -BackgroundColor DarkGray
    Write-Host "Timestamp: $(Now)" -ForegroundColor DarkGray
}

function Confirm-Yes {
    param([string]$Prompt)

    $a = Read-Host "$Prompt [Y/N]"
    return ($a.Trim().ToUpper() -eq "Y")
}

function Encode-Value {
    param([string]$Value)
    return [System.Uri]::EscapeDataString($Value)
}

function Escape-OData {
    param([string]$Value)
    return ($Value -replace "'", "''")
}

function Clean-Name {
    param([object]$Value)

    if ($null -eq $Value) { return "" }

    $text = [string]$Value
    return ($text -replace '\s*\([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\)\s*$', '').Trim()
}

function Offer-ExportCsv {
    param(
        [array]$Rows,
        [string]$DefaultName
    )

    if (-not $Rows -or $Rows.Count -eq 0) { return }

    if (-not (Confirm-Yes "Export results to CSV")) { return }

    $path = Read-Host "CSV output path [blank for .\$DefaultName]"

    if (-not $path) {
        $path = Join-Path (Get-Location).Path $DefaultName
    }

    try {
        $Rows | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
        OK "Exported: $path"
    }
    catch {
        WARN "CSV export failed"
    }
}

function Offer-ExportJson {
    param(
        [object]$Object,
        [string]$DefaultName
    )

    if (-not $Object) { return }

    if (-not (Confirm-Yes "Export snapshot to JSON")) { return }

    $path = Read-Host "JSON output path [blank for .\$DefaultName]"

    if (-not $path) {
        $path = Join-Path (Get-Location).Path $DefaultName
    }

    try {
        $Object | ConvertTo-Json -Depth 20 | Out-File -FilePath $path -Encoding UTF8
        OK "Exported: $path"
    }
    catch {
        WARN "JSON export failed"
    }
}

function Get-CredentialExpiryFinding {
    param($EndDate, [datetime]$Now, [datetime]$Soon, [ValidateSet('Secret','Certificate')][string]$Kind)
    if (-not $EndDate) { return "$Kind expiry unavailable" }
    try { $end=[datetime]$EndDate } catch { return "$Kind expiry unavailable" }
    if ($end -lt $Now) { return "Expired $($Kind.ToLowerInvariant())" }
    if ($end -lt $Soon) { return "$Kind expiring soon" }
    return "$Kind OK"
}

function Graph-Get {
    param([string]$Uri)

    try { return Invoke-MgGraphRequest -Method GET -Uri $Uri -ErrorAction Stop }
    catch { throw 'Graph read failed; review incomplete. Check tenant, permissions and connectivity.' }
}

# Use the normal Graph sign-in/session; keep the resulting tenant identity internal.
function Get-FKSessionTenant {
    param([string]$ExpectedTenantId,[string[]]$RequiredScopes,[string[]]$TargetUPNs)
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    $ctx=Get-MgContext -ErrorAction SilentlyContinue
    if ($ctx -and $ExpectedTenantId -and $ctx.TenantId -ne $ExpectedTenantId) { throw 'The connected tenant differs from the expected tenant. Nothing was changed.' }
    $pinnedTenant=$(if ($ctx) { [string]$ctx.TenantId } else { $ExpectedTenantId })
    $missing=@($RequiredScopes | Where-Object { -not $ctx -or @($ctx.Scopes) -notcontains $_ })
    if ($ctx -and $missing.Count -gt 0) { Disconnect-MgGraph -ErrorAction Stop | Out-Null; $ctx=$null }
    if (-not $ctx) {
        $command=Get-Command Connect-MgGraph -ErrorAction Stop
        $parameters=@{Scopes=$RequiredScopes;ErrorAction='Stop'}
        if ($pinnedTenant) { $parameters.TenantId=$pinnedTenant }
        if ($command.Parameters.ContainsKey('ContextScope')) { $parameters.ContextScope='Process' }
        if ($command.Parameters.ContainsKey('NoWelcome')) { $parameters.NoWelcome=$true }
        Connect-MgGraph @parameters | Out-Null
        $ctx=Get-MgContext -ErrorAction Stop
    }
    if (-not $ctx.Account -or -not $ctx.TenantId) { throw 'The signed-in tenant could not be verified.' }
    if ($pinnedTenant -and $pinnedTenant -ne $ctx.TenantId) { throw 'The connected tenant differs from the expected tenant. Nothing was changed.' }
    $org=Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/organization?$select=id,displayName,verifiedDomains' -OutputType PSObject -ErrorAction Stop
    if (@($org.value).Count -ne 1 -or [string]$org.value[0].id -ne [string]$ctx.TenantId) { throw 'The signed-in organization could not be verified.' }
    $script:FKTenantLabel=[string]$org.value[0].displayName
    $domains=@($org.value[0].verifiedDomains | ForEach-Object { [string]$_.name })
    foreach ($target in @($TargetUPNs)) {
        if ($target -and ($domains -notcontains ([string]$target -split '@')[-1])) { throw 'A supplied user is outside the connected organization. Nothing was changed.' }
    }
    return [string]$ctx.TenantId
}

function Ensure-Graph {
    param([string[]]$Scopes, [string]$TenantId)

    $TenantId=Get-FKSessionTenant -ExpectedTenantId $TenantId -RequiredScopes $Scopes
    $expectedGuid=[guid]::Empty
    if (-not [guid]::TryParse($TenantId,[ref]$expectedGuid) -or $expectedGuid -eq [guid]::Empty) { throw "Tenant identity could not be verified. No audit was completed." }
    $TenantId=$expectedGuid.ToString()

    $module=Get-Module -ListAvailable -Name Microsoft.Graph.Authentication -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if (-not $module) {
        FAIL "Microsoft.Graph.Authentication module not available"
        Write-Host "Install with: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser"
        return $false
    }

    Import-Module $module.Path -Force -ErrorAction Stop | Out-Null

    $ctx=Get-MgContext -ErrorAction SilentlyContinue
    if ($ctx -and $ctx.TenantId -ne $TenantId) {
        throw 'Existing Graph session is for another tenant. No changes made. Open a new PowerShell window and sign in to the expected tenant.'
    }
    if ($ctx -and ($ctx.AuthType -ne 'Delegated' -or -not $ctx.Account)) {
        throw 'An interactive delegated Graph session is required. Open a new PowerShell window and sign in.'
    }
    $hasScopes=$true
    if (-not $ctx) { $hasScopes=$false }
    else {
        foreach ($scope in $Scopes) {
            if (@($ctx.Scopes) -notcontains $scope) { $hasScopes=$false; break }
        }
    }

    if ($ctx -and (-not $hasScopes -or $ctx.ContextScope -ne 'Process')) {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
        $ctx=$null
    }

    if ($ctx -and $ExpectedTenantId -and $ctx.TenantId -ne $ExpectedTenantId) { throw 'The connected tenant differs from the expected tenant. Nothing was changed.' }
    $pinnedTenant=$(if ($ctx) { [string]$ctx.TenantId } else { $ExpectedTenantId })
    $missing=@($RequiredScopes | Where-Object { -not $ctx -or @($ctx.Scopes) -notcontains $_ })
    if ($ctx -and $missing.Count -gt 0) { Disconnect-MgGraph -ErrorAction Stop | Out-Null; $ctx=$null }
    if (-not $ctx) {
        $command=Get-Command Connect-MgGraph -ErrorAction Stop
        if (-not $command.Parameters.ContainsKey('ContextScope')) { throw 'Update Microsoft.Graph.Authentication to a version supporting process-scoped sign-in.' }
        $parameters=@{ Scopes=$Scopes; TenantId=$TenantId; ContextScope='Process'; ErrorAction='Stop' }
        if ($command.Parameters.ContainsKey('NoWelcome')) { $parameters['NoWelcome']=$true }
        Connect-MgGraph @parameters | Out-Null
    }

    $ctx=Get-MgContext -ErrorAction Stop
    Assert-GraphContext -TenantId $TenantId
    foreach ($scope in $Scopes) {
        if (@($ctx.Scopes) -notcontains $scope) {
            FAIL "Graph token is missing required scope: $scope"
            return $false
        }
    }

    OK "Graph connected"
    INFO "Tenant: $script:FKTenantLabel | Account: $($ctx.Account)"
    return $true
}

function Assert-GraphContext {
    param([string]$TenantId, [string]$Account)
    $ctx=Get-MgContext -ErrorAction Stop
    if (-not $ctx -or $ctx.TenantId -ne $TenantId -or $ctx.AuthType -ne 'Delegated' -or
        -not $ctx.Account -or $ctx.ContextScope -ne 'Process' -or ($Account -and $ctx.Account -ne $Account)) {
        throw 'Graph tenant/account context changed or could not be validated. Stop and review the results; do not retry changes blindly.'
    }
}

function Get-GraphPages {
    param([string]$Uri)

    $items = New-Object System.Collections.ArrayList

    while ($Uri) {
        $page = Graph-Get $Uri

        if (-not $page -or $null -eq $page.value) { throw "Graph collection data is unavailable; review incomplete." }

        foreach ($item in @($page.value)) {
            [void]$items.Add($item)
        }

        $Uri = $page.'@odata.nextLink'
    }

    return @($items)
}


# IDs below are internal correlation keys. Public rows contain names only.
$script:FKGaps = New-Object System.Collections.Generic.List[string]
$script:FKServicePrincipals = @{}
$script:FKResources = @{}
$script:FKUsers = @{}
$script:FKTenant = ''
$script:FKAccount = ''

function Get-PublicText {
    param($Value, [string]$Fallback='Name unavailable')
    $text=([string]$Value -replace '[\p{Cc}\p{Cf}]',' ')
    $text=($text -replace '(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b','').Trim().Trim([char[]]'(){} ')
    if ([string]::IsNullOrWhiteSpace($text)) { return $Fallback }
    return $text
}

function Read-AuditCollection {
    param([string]$Uri)
    Assert-GraphContext -TenantId $script:FKTenant -Account $script:FKAccount
    return @(Get-GraphPages -Uri $Uri)
}

function Get-PublisherInfo {
    param($Application,$ServicePrincipal)
    # Documented Microsoft home tenants. Never trust a display name or domain string.
    $microsoft=@('f8cdef31-a31e-4b4a-93e4-5f571e91255a','72f988bf-86f1-41af-91ab-2d7cd011db47')
    if ($ServicePrincipal -and $microsoft -contains [string]$ServicePrincipal.appOwnerOrganizationId) {
        return [pscustomobject]@{Name='Microsoft';Verified=$true;Microsoft=$true}
    }
    foreach ($item in @($Application,$ServicePrincipal)) {
        if ($item -and $item.verifiedPublisher -and -not [string]::IsNullOrWhiteSpace([string]$item.verifiedPublisher.verifiedPublisherId)) {
            return [pscustomobject]@{Name=(Get-PublicText $item.verifiedPublisher.displayName -Fallback 'Verified publisher');Verified=$true;Microsoft=$false}
        }
    }
    return [pscustomobject]@{Name='Unknown publisher';Verified=$false;Microsoft=$false}
}

function Get-ResourceByAppId {
    param([string]$AppId)
    if (-not $AppId) { return $null }
    if ($script:FKResources.ContainsKey($AppId)) { return $script:FKResources[$AppId] }
    try {
        $filter=Encode-Value ("appId eq '{0}'" -f (Escape-OData $AppId))
        $matches=@(Read-AuditCollection -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=$filter&`$select=id,appId,displayName,appRoles,oauth2PermissionScopes")
        if ($matches.Count -ne 1) { throw 'Resource match unavailable or ambiguous.' }
        $script:FKResources[$AppId]=$matches[0]
    } catch {
        $script:FKGaps.Add('Resource or permission names could not be resolved.')
        $script:FKResources[$AppId]=$null
    }
    return $script:FKResources[$AppId]
}

function Get-OwnerSummary {
    param([string]$Kind,[string]$Id,[string]$AppName)
    try {
        $owners=@(Read-AuditCollection -Uri "https://graph.microsoft.com/v1.0/$Kind/$Id/owners?`$select=id,displayName,userPrincipalName,userType,accountEnabled")
        if (-not $owners.Count) { return [pscustomobject]@{Names='No owner';Finding='No owner'} }
        $names=@();$findings=@()
        foreach ($owner in $owners) {
            $name=Get-PublicText $owner.displayName
            if ($name -eq 'Name unavailable') { $script:FKGaps.Add("Owner name unavailable for $AppName.") }
            $names+=$name
            if ($owner.accountEnabled -eq $false) { $findings+='Disabled owner' }
            if ($owner.userType -eq 'Guest') { $findings+='Guest owner' }
            elseif ($owner.userType -eq 'Member') { $findings+='User owner' }
        }
        return [pscustomobject]@{Names=(@($names|Sort-Object -Unique)-join '; ');Finding=(@($findings|Sort-Object -Unique)-join '; ')}
    } catch {
        $script:FKGaps.Add("Owner lookup unavailable for $AppName.")
        return [pscustomobject]@{Names='Name unavailable';Finding='Owner lookup unavailable'}
    }
}

function Get-RequestedPermissionRows {
    param($Application)
    $rows=@()
    foreach ($requested in @($Application.requiredResourceAccess)) {
        if (-not $requested) { continue }
        $resource=Get-ResourceByAppId -AppId ([string]$requested.resourceAppId)
        foreach ($permission in @($requested.resourceAccess)) {
            $definitions=if ($permission.type -eq 'Role') { @($resource.appRoles) } else { @($resource.oauth2PermissionScopes) }
            $found=@($definitions|Where-Object { [string]$_.id -eq [string]$permission.id })
            $name='Permission name unavailable'
            if ($found.Count -eq 1) { $name=Get-PublicText $found[0].value -Fallback 'Permission name unavailable' }
            if ($name -eq 'Permission name unavailable') { $script:FKGaps.Add('A requested permission name could not be resolved.') }
            $rows += [pscustomobject]@{Resource=(Get-PublicText $resource.displayName);Permission=$name;Type=$(if($permission.type -eq 'Role'){'Application permission requested'}else{'Delegated permission requested'})}
        }
    }
    return $rows
}

function Write-PublicRows {
    param([object[]]$Rows)
    foreach ($row in $Rows) {
        Write-Host ''
        foreach ($property in $row.PSObject.Properties) {
            Write-Host ("{0}: {1}" -f $property.Name,(Get-PublicText $property.Value -Fallback 'Not returned'))
        }
    }
}

function Write-CollectionGaps {
    if ($script:FKGaps.Count) {
        WARN 'PARTIAL REVIEW: some names or ownership checks are unavailable.'
        foreach ($gap in @($script:FKGaps|Sort-Object -Unique)) { WARN $gap }
    }
}

function Get-ConsentServicePrincipal {
    param([string]$Id)
    if (-not $Id) { return $null }
    if ($script:FKServicePrincipals.ContainsKey($Id)) { return $script:FKServicePrincipals[$Id] }
    try {
        Assert-GraphContext -TenantId $script:FKTenant -Account $script:FKAccount
        $sp=Graph-Get -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$Id`?`$select=id,appId,displayName,appOwnerOrganizationId,verifiedPublisher"
        if (-not $sp -or [string]$sp.id -ne $Id) { throw 'App identity unavailable.' }
        $script:FKServicePrincipals[$Id]=$sp
    } catch {
        $script:FKServicePrincipals[$Id]=$null
        $script:FKGaps.Add('A client app or resource name/publisher could not be resolved.')
    }
    return $script:FKServicePrincipals[$Id]
}

function Get-ConsentUser {
    param([string]$Id)
    if ($script:FKUsers.ContainsKey($Id)) { return $script:FKUsers[$Id] }
    try {
        Assert-GraphContext -TenantId $script:FKTenant -Account $script:FKAccount
        $user=Graph-Get -Uri "https://graph.microsoft.com/v1.0/users/$Id`?`$select=id,displayName,userPrincipalName,userType,accountEnabled,externalUserState"
        if (-not $user -or [string]$user.id -ne $Id) { throw 'User identity unavailable.' }
        $script:FKUsers[$Id]=$user
    } catch {
        $script:FKUsers[$Id]=$null
        $script:FKGaps.Add('A grant principal could not be resolved; guest/member classification is unavailable.')
    }
    return $script:FKUsers[$Id]
}

function Get-RiskOAuth {
    param([string]$Scope)

    if (-not $Scope) { return $false }

    $patterns = @(
        "Mail.",
        "Mailbox",
        "Files.Read",
        "Files.ReadWrite",
        "Sites.",
        "Directory.",
        "Group.",
        "User.ReadWrite",
        "User.Read.All",
        "Calendars.ReadWrite",
        "Contacts.ReadWrite",
        "offline_access",
        "full_access_as_user"
    )

    foreach ($p in $patterns) {
        if ($Scope -like "*$p*") {
            return $true
        }
    }

    return $false
}

try {
    Clear-Host
    Write-Host 'Audit Tenant App Consent'
    Write-Host 'Review delegated app access, including guest consent.'
    Write-Host 'Read only. Unknown publishers are shown by default.'
    Write-Host 'Application-only grants are outside this delegated-consent review.'
    if (-not (Ensure-Graph -Scopes @('Application.Read.All','Directory.Read.All','User.Read.All') -TenantId $ExpectedTenantId)) { return }
    $context=Get-MgContext -ErrorAction Stop
    $script:FKTenant=[string]$context.TenantId;$script:FKAccount=[string]$context.Account
    $grants=@(Read-AuditCollection -Uri 'https://graph.microsoft.com/v1.0/oauth2PermissionGrants?$select=id,clientId,resourceId,principalId,consentType,scope&$top=999')
    $rows=New-Object System.Collections.ArrayList;$hidden=0
    foreach ($grant in $grants) {
        $client=Get-ConsentServicePrincipal -Id ([string]$grant.clientId)
        $publisher=Get-PublisherInfo -ServicePrincipal $client
        if (-not $IncludeVerifiedPublishers -and $publisher.Verified) { $hidden++;continue }
        $resource=Get-ConsentServicePrincipal -Id ([string]$grant.resourceId)
        $user=$null;$userType='Unknown';$principalName='Name unavailable';$enabled='Unavailable';$invitation='Not applicable';$grantScope='Unknown'
        if ($grant.consentType -eq 'AllPrincipals') {
            $principalName='All users (tenant-wide)';$userType='All users';$grantScope='Tenant-wide'
        } elseif ($grant.consentType -eq 'Principal' -and $grant.principalId) {
            $user=Get-ConsentUser -Id ([string]$grant.principalId)
            if ($user) {
                $principalName=Get-PublicText $user.displayName
                $userType=Get-PublicText $user.userType -Fallback 'Unknown'
                $enabled=Get-PublicText $user.accountEnabled -Fallback 'Unavailable'
                $invitation=Get-PublicText $user.externalUserState -Fallback 'Not returned'
            }
            $grantScope='Individual user'
        } else { $script:FKGaps.Add('A delegated grant has incomplete scope or principal metadata.') }
        # Unknown principals remain visible. Tenant-wide grants can also apply to guests.
        if ($GuestOnly -and $userType -eq 'Member') { continue }
        $permissions=Get-PublicText $grant.scope -Fallback 'Permission names unavailable'
        if ($permissions -eq 'Permission names unavailable') { $script:FKGaps.Add('A delegated grant returned no permission names.') }
        $risk=if((Get-RiskOAuth -Scope $permissions) -or $permissions -match '(?i)\b(?:Directory\.ReadWrite\.All|RoleManagement\.ReadWrite\.Directory|AppRoleAssignment\.ReadWrite\.All|Mail\.ReadWrite|Mail\.ReadWrite\.Shared|Mail\.Send|Files\.ReadWrite\.All|Sites\.ReadWrite\.All|User\.ReadWrite\.All)\b'){'High-risk scope; review'}else{'Review business need'}
        [void]$rows.Add([pscustomobject]@{
            ClientApp=(Get-PublicText $client.displayName);Publisher=$publisher.Name
            ResourceAPI=(Get-PublicText $resource.displayName);ConsentFor=$principalName
            UserType=$userType;AccountEnabled=$enabled;Invitation=$invitation
            GrantScope=$grantScope;Permissions=$permissions;Finding=$risk
        })
    }
    Section 'DELEGATED CONSENT'
    Write-PublicRows -Rows @($rows)
    INFO ("Grants shown: {0}; verified-publisher grants hidden: {1}" -f $rows.Count,$hidden)
    if (-not $rows.Count) { INFO 'No grants returned under this view. This is not proof that no app access exists.' }
    if ($GuestOnly) { INFO 'Guest view retains unknown principals and tenant-wide grants, which may also apply to guests.' }
    Write-CollectionGaps
    Offer-ExportCsv -Rows @($rows) -DefaultName ("tenant-app-consent-{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    INFO 'Use -IncludeVerifiedPublishers for all publishers, or -GuestOnly for the guest review.'
} catch {
    FAIL 'Consent review incomplete. Check the tenant, required access and connectivity before retrying.'
} finally {
    if ($script:FKTenant) { try { Disconnect-MgGraph -ErrorAction Stop | Out-Null } catch { WARN 'Graph disconnect could not be confirmed. Close this PowerShell window.' } }
    if (-not $NoPause) { Pause-End }
}
