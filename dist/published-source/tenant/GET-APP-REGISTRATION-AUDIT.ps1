# OBJECTIVE: Review app owners, credential expiry, and requested permissions.
#Requires -Version 5.1
<#
.VERSION 1.1.0
Audit Tenant Apps
Read-only candidate. Changed workflow is not operator verified.
Internal IDs are used only for matching and API calls; output and CSV use names.
#>
[CmdletBinding()]
param([int]$ExpiringDays=30, [string]$ExpectedTenantId, [switch]$IncludeMicrosoftApps, [switch]$NoPause)
Write-Host 'GET-APP-REGISTRATION-AUDIT.ps1 // READ ONLY'
Write-Host ''
Write-Host 'Objective: Review app owners, credential expiry, and requested permissions.'
Write-Host ''
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
function Resolve-FkTenantDomain {
    param([string]$Domain)
    $Domain = $Domain.Trim().ToLowerInvariant()
    if ($Domain -notmatch '^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z](?:[a-z0-9-]{0,61}[a-z0-9])?$') {
        throw 'Enter a valid tenant domain.'
    }
    try {
        $metadata = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$Domain/v2.0/.well-known/openid-configuration" -TimeoutSec 20 -ErrorAction Stop
        if ($metadata.issuer -notmatch '^https://login\.microsoftonline\.com/([0-9a-f-]{36})/v2\.0/?$') { throw 'Unexpected issuer.' }
        $tenant = [guid]::Parse($Matches[1])
        if ($tenant -eq [guid]::Empty) { throw 'Invalid tenant.' }
        return $tenant.ToString()
    }
    catch { throw "Could not resolve the Microsoft tenant for $Domain." }
}

function Get-FKSessionTenant {
    param([string]$ExpectedTenantId,[string[]]$RequiredScopes,[string[]]$TargetUPNs)
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    $ctx=Get-MgContext -ErrorAction SilentlyContinue
    if ($ctx -and $ExpectedTenantId -and $ctx.TenantId -ne $ExpectedTenantId) { throw 'The connected tenant differs from the expected tenant. Nothing was changed.' }
    if ($ctx -and ($ctx.AuthType -ne 'Delegated' -or $ctx.Environment -ne 'Global' -or -not $ctx.Account -or -not $ctx.TenantId)) { throw 'A delegated Microsoft Graph session is required.' }
    if (-not $ctx -and -not $ExpectedTenantId) {
        $domain = (Read-Host 'Tenant domain (for example, contoso.onmicrosoft.com; blank cancels)').Trim()
        if (-not $domain) { throw 'Tenant selection cancelled.' }
        $ExpectedTenantId = Resolve-FkTenantDomain -Domain $domain
    }
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

try {
    Clear-Host
    Write-Host "App Registration Details"
    Write-Host 'App Registration Details'
    Write-Host 'Review app owners, credential expiry, and requested permissions.'
    Write-Host 'Read only. Requested permissions are not proof of granted access.'
    if ($ExpiringDays -lt 1 -or $ExpiringDays -gt 3650) { throw 'ExpiringDays must be between 1 and 3650.' }
    if (-not (Ensure-Graph -Scopes @('Application.Read.All','Directory.Read.All') -TenantId $ExpectedTenantId)) { return }
    $context=Get-MgContext -ErrorAction Stop
    $script:FKTenant=[string]$context.TenantId;$script:FKAccount=[string]$context.Account
    $apps=@(Read-AuditCollection -Uri 'https://graph.microsoft.com/v1.0/applications?$select=id,appId,displayName,passwordCredentials,keyCredentials,requiredResourceAccess,createdDateTime,verifiedPublisher,publisherDomain&$top=999')
    $principals=@(Read-AuditCollection -Uri 'https://graph.microsoft.com/v1.0/servicePrincipals?$select=id,appId,displayName,servicePrincipalType,accountEnabled,appOwnerOrganizationId,verifiedPublisher,appRoles,oauth2PermissionScopes&$top=999')
    $byApp=@{};$matched=@{}
    foreach ($sp in $principals) {
        if (-not $sp.appId -or -not $sp.id) { $script:FKGaps.Add('An enterprise app has incomplete identity metadata.');continue }
        if (-not $byApp.ContainsKey([string]$sp.appId)) { $byApp[[string]$sp.appId]=@() }
        $byApp[[string]$sp.appId]+=$sp
        $script:FKResources[[string]$sp.appId]=$sp
    }
    $rows=New-Object System.Collections.ArrayList;$hidden=0
    $now=Get-Date;$soon=$now.AddDays($ExpiringDays)
    foreach ($app in $apps) {
        if (-not $app.id -or -not $app.appId) { $script:FKGaps.Add('An app registration has incomplete identity metadata.');continue }
        $linked=@($byApp[[string]$app.appId]|Where-Object { $null -ne $_ })
        # Multiple matches are kept separately. Do not choose an arbitrary owner set.
        $publisherSP=if($linked.Count -eq 1){$linked[0]}else{$null}
        $publisher=Get-PublisherInfo -Application $app -ServicePrincipal $publisherSP
        if (-not $IncludeMicrosoftApps -and $publisher.Microsoft) {
            $hidden++;foreach($sp in $linked){$matched[[string]$sp.id]=$true};continue
        }
        $name=Get-PublicText $app.displayName
        $owner=Get-OwnerSummary -Kind 'applications' -Id ([string]$app.id) -AppName $name
        [void]$rows.Add([pscustomobject]@{App=$name;Section='App registration';Publisher=$publisher.Name;Owners=$owner.Names;Item='Registration';Detail='Registered in this tenant';Finding=$owner.Finding})
        foreach ($kind in @('Secret','Certificate')) {
            $credentials=if($kind -eq 'Secret'){@($app.passwordCredentials)}else{@($app.keyCredentials)}
            foreach ($credential in $credentials) {
                if (-not $credential) { continue }
                $finding=Get-CredentialExpiryFinding -EndDate $credential.endDateTime -Now $now -Soon $soon -Kind $kind
                [void]$rows.Add([pscustomobject]@{App=$name;Section='Credentials';Publisher=$publisher.Name;Owners=$owner.Names;Item=$kind;Detail=((Get-PublicText $credential.displayName -Fallback 'Unnamed credential')+'; expires '+(Get-PublicText $credential.endDateTime -Fallback 'date unavailable'));Finding=$finding})
            }
        }
        foreach ($permission in @(Get-RequestedPermissionRows -Application $app)) {
            [void]$rows.Add([pscustomobject]@{App=$name;Section='Requested permissions';Publisher=$publisher.Name;Owners=$owner.Names;Item=$permission.Type;Detail=($permission.Resource+' · '+$permission.Permission);Finding='Requested only; grant not established'})
        }
        foreach ($sp in $linked) {
            $matched[[string]$sp.id]=$true
            $spName=Get-PublicText $sp.displayName
            $spOwner=Get-OwnerSummary -Kind 'servicePrincipals' -Id ([string]$sp.id) -AppName $spName
            [void]$rows.Add([pscustomobject]@{App=$spName;Section='Enterprise app';Publisher=$publisher.Name;Owners=$spOwner.Names;Item=(Get-PublicText $sp.servicePrincipalType -Fallback 'Type unavailable');Detail=('Sign-in enabled: '+(Get-PublicText $sp.accountEnabled -Fallback 'Unavailable'));Finding=$spOwner.Finding})
        }
        if (-not $linked.Count) {
            [void]$rows.Add([pscustomobject]@{App=$name;Section='Enterprise app';Publisher=$publisher.Name;Owners='Not applicable';Item='No matching enterprise app';Detail='Registration retained in report';Finding='Review'})
        }
    }
    foreach ($sp in $principals) {
        if (-not $sp.id -or $matched.ContainsKey([string]$sp.id)) { continue }
        $publisher=Get-PublisherInfo -ServicePrincipal $sp
        if (-not $IncludeMicrosoftApps -and $publisher.Microsoft) { $hidden++;continue }
        $name=Get-PublicText $sp.displayName
        $owner=Get-OwnerSummary -Kind 'servicePrincipals' -Id ([string]$sp.id) -AppName $name
        [void]$rows.Add([pscustomobject]@{App=$name;Section='Enterprise app';Publisher=$publisher.Name;Owners=$owner.Names;Item=(Get-PublicText $sp.servicePrincipalType -Fallback 'Type unavailable');Detail='No matching local app registration';Finding=$owner.Finding})
    }
    Section 'APP REVIEW'
    Write-PublicRows -Rows @($rows)
    INFO ("Review rows: {0}; Microsoft entries hidden: {1}" -f $rows.Count,$hidden)
    if (-not $rows.Count) { INFO 'No apps returned under this view. This is not a security verdict.' }
    Write-CollectionGaps
    Offer-ExportCsv -Rows @($rows) -DefaultName ("tenant-apps-review-{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    INFO 'Use -IncludeMicrosoftApps to include confirmed Microsoft apps.'
} catch {
    FAIL 'App review incomplete. Check the tenant, required access and connectivity before retrying.'
} finally {
    if ($script:FKTenant) { try { Disconnect-MgGraph -ErrorAction Stop | Out-Null } catch { WARN 'Graph disconnect could not be confirmed. Close this PowerShell window.' } }
    if (-not $NoPause) { Pause-End }
}
