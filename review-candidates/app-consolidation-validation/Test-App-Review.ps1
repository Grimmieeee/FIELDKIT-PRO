#Requires -Version 7
# Runs extracted read-only workflow logic with fixed fixtures, no source loading or sign-in.
[CmdletBinding()]
param([string]$Root=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$cases=New-Object System.Collections.Generic.List[object]
function Assert-True($Value,$Message){if(-not $Value){throw $Message}}
function Test-Workflow([string]$File,[bool]$IncludeAll=$false,[bool]$GuestView=$false){
    $path=Join-Path $Root ('candidates/published-source/tenant/'+$File)
    $tokens=$null;$errors=$null
    $ast=[System.Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
    Assert-True (-not $errors.Count) ($errors|Out-String)
    # Never dot-source a workflow, import modules, or evaluate its connection code.
    $excluded=@('Ensure-Graph','Assert-GraphContext','Graph-Get','Get-GraphPages','Offer-ExportCsv','Write-PublicRows','Pause-End','Section','INFO','WARN','FAIL','OK')
    $functions=@($ast.EndBlock.Statements | Where-Object {$_ -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -notin $excluded})
    $script:FKGaps=New-Object System.Collections.Generic.List[string]
    $script:FKServicePrincipals=@{};$script:FKResources=@{};$script:FKUsers=@{}
    $script:FKTenant='fixture-tenant';$script:FKAccount='technician@example.test'
    foreach($function in $functions){. ([scriptblock]::Create($function.Extent.Text))}
    function Ensure-Graph {return $true}
    function Assert-GraphContext {}
    function Get-MgContext {return [pscustomobject]@{TenantId='fixture-tenant';Account='technician@example.test'}}
    function Disconnect-MgGraph {}
    function Clear-Host {}
    function Offer-ExportCsv {param($Rows,$DefaultName);$script:ExportRows=@($Rows)}
    function Write-PublicRows {param($Rows);$script:PublicRows=@($Rows)}
    function Section {}
    function INFO {}
    function WARN {}
    function FAIL {param($Message);throw $Message}
    function OK {}
    $script:Microsoft=[pscustomobject]@{id='microsoft-object';appId='microsoft-app';displayName='First-party fixture';appOwnerOrganizationId='f8cdef31-a31e-4b4a-93e4-5f571e91255a';verifiedPublisher=$null}
    $script:Unknown=[pscustomobject]@{id='unknown-object';appId='unknown-app';displayName='Unverified Example';appOwnerOrganizationId='external';verifiedPublisher=$null;servicePrincipalType='Application';accountEnabled=$true;appRoles=@();oauth2PermissionScopes=@()}
    $script:Verified=[pscustomobject]@{id='verified-object';appId='verified-app';displayName='Verified Example';appOwnerOrganizationId='external';verifiedPublisher=[pscustomobject]@{verifiedPublisherId='partner';displayName='Example Publisher'}}
    $script:Resource=[pscustomobject]@{id='resource-object';appId='resource-app';displayName='Example API';appRoles=@([pscustomobject]@{id='permission-role';value='Files.Read.All'});oauth2PermissionScopes=@()}
    function Graph-Get {param($Uri)
        if($Uri -match '/servicePrincipals/unknown-object\?'){return $script:Unknown}
        if($Uri -match '/servicePrincipals/verified-object\?'){return $script:Verified}
        if($Uri -match '/servicePrincipals/microsoft-object\?'){return $script:Microsoft}
        if($Uri -match '/servicePrincipals/resource-object\?'){return $script:Resource}
        if($Uri -match '/users/guest-user\?'){return [pscustomobject]@{id='guest-user';displayName='Guest Person';userType='Guest';accountEnabled=$true;externalUserState='Accepted'}}
        if($Uri -match '/users/member-user\?'){return [pscustomobject]@{id='member-user';displayName='Member Person';userType='Member';accountEnabled=$true}}
        throw 'Fixture lookup unavailable'
    }
    function Get-GraphPages {param($Uri)
        if($Uri -match '/oauth2PermissionGrants\?'){
            foreach($entry in @(@('unknown-object','guest-user','Principal'),@('unknown-object','member-user','Principal'),@('unknown-object','','AllPrincipals'),@('verified-object','guest-user','Principal'),@('missing-object','missing-user','Principal'),@('microsoft-object','guest-user','Principal'))){
                [pscustomobject]@{clientId=$entry[0];principalId=$entry[1];consentType=$entry[2];resourceId='resource-object';scope='Mail.Read'}
            };return
        }
        if($Uri -match '/applications\?'){
            return [pscustomobject]@{id='registration-object';appId='unknown-app';displayName='Local Example';verifiedPublisher=$null;passwordCredentials=@([pscustomobject]@{displayName='Secret';endDateTime='2000-01-01'});keyCredentials=@();requiredResourceAccess=@([pscustomobject]@{resourceAppId='resource-app';resourceAccess=@([pscustomobject]@{id='permission-role';type='Role'})})}
        }
        if($Uri -match '/owners\?'){
            if($Uri -match '/applications/'){return @()}
            if($Uri -match '/unknown-object/'){return [pscustomobject]@{displayName='Guest Owner';userType='Guest';accountEnabled=$false}}
            throw 'Owner collection unavailable'
        }
        if($Uri -match '/servicePrincipals\?'){return @($script:Unknown,$script:Microsoft,$script:Verified,$script:Resource)}
        throw 'Unexpected collection route'
    }
    $ExpectedTenantId='fixture-tenant';$IncludeMicrosoftApps=$IncludeAll;$IncludeVerifiedPublishers=$IncludeAll;$GuestOnly=$GuestView;$NoPause=$true;$ExpiringDays=30
    $script:ExportRows=@();$script:PublicRows=@()
    $main=@($ast.EndBlock.Statements | Where-Object {$_ -is [System.Management.Automation.Language.TryStatementAst]})[-1]
    & ([scriptblock]::Create($main.Extent.Text))
    Assert-True ($script:PublicRows.Count -gt 0) 'Expected fixture rows'
    $csv=$script:ExportRows|ConvertTo-Csv -NoTypeInformation|Out-String
    Assert-True ($csv -notmatch '(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b') 'GUID leaked into public CSV'
    Assert-True ($csv -notmatch 'unknown-object|permission-role|registration-object|resource-app') 'Internal fixture keys leaked'
    Assert-True (@($script:ExportRows[0].PSObject.Properties.Name | Where-Object {$_ -match '(?i)(?:^id$|Id$)'}).Count -eq 0) 'ID column leaked'
    if($File -eq 'GET-OAUTH-CONSENT-AUDIT.ps1'){
        Assert-True ($csv -match 'Unknown publisher') 'Unknown publisher missing'
        Assert-True ($csv -match 'Guest Person') 'Guest consent missing'
        Assert-True ($csv -match 'All users \(tenant-wide\)') 'Tenant-wide consent lost'
        Assert-True ($csv -match 'Example API') 'Resource name missing'
        Assert-True ($script:FKGaps.Count -gt 0) 'Failed principal/app read must remain visible as gap'
        if(-not $IncludeAll){Assert-True ($csv -notmatch '"Verified Example"|"First-party fixture"' ) 'Verified publisher filter failed'}
        else {Assert-True ($csv -match '"Verified Example"' ) 'All-publisher override failed'}
        if($GuestView){Assert-True ($csv -notmatch 'Member Person') 'Guest filter retained known member'}
    }else{
        Assert-True ($csv -match 'Guest Owner' -and $csv -match 'Disabled owner') 'Enterprise ownership lost'
        Assert-True ($csv -match 'No owner') 'Registration ownership lost'
        Assert-True ($csv -match 'Expired secret') 'Expiry finding lost'
        Assert-True ($csv -match 'Files.Read.All' -and $csv -match 'Requested only; grant not established') 'Requested permission label lost'
        Assert-True ($csv -match 'No matching local app registration') 'Unmatched enterprise app lost'
        if(-not $IncludeAll){Assert-True ($csv -notmatch 'First-party fixture') 'Microsoft exclusion failed'}
    }
    $cases.Add([pscustomobject]@{File=$File;AllPublishers=$IncludeAll;GuestView=$GuestView;Result='PASS'})
}
Test-Workflow 'GET-APP-REGISTRATION-AUDIT.ps1'
Test-Workflow 'GET-APP-REGISTRATION-AUDIT.ps1' $true
Test-Workflow 'GET-OAUTH-CONSENT-AUDIT.ps1'
Test-Workflow 'GET-OAUTH-CONSENT-AUDIT.ps1' $true
Test-Workflow 'GET-OAUTH-CONSENT-AUDIT.ps1' $false $true
$cases|Format-Table -AutoSize
