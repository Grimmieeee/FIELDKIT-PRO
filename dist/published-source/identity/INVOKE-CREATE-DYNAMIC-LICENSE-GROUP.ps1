<#
INVOKE-CREATE-DYNAMIC-LICENSE-GROUP.ps1
.VERSION 1.0.7

Create dynamic Entra group for licensed users.

Purpose:
- Creates a dynamic security group for enabled users with at least one active license/service plan
- Prompts for display name and mail nickname
- Does not assign licenses by itself

Change-making.
Requires Graph write permissions.
#>
# OBJECTIVE: Create a dynamic security group for enabled users with at least one enabled license service plan.


param(
    [string]$DisplayName = "Dynamic-Group-AnyLicense",
    [string]$MailNickname = "DG_AnyLicense",
    [string]$ExpectedTenantId
)
Write-Host 'INVOKE-CREATE-DYNAMIC-LICENSE-GROUP.ps1 // MAKES CHANGES'
Write-Host ''
Write-Host 'Objective: Create a dynamic security group for enabled users with at least one enabled license service plan.'
Write-Host ''

$ErrorActionPreference = "Stop"

if ($PSVersionTable.PSVersion.Major -lt 7) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

function Get-FKDesktopDirectory {
    $desktop=[Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)
    if ([string]::IsNullOrWhiteSpace($desktop) -or -not [IO.Directory]::Exists($desktop)) {
        throw 'Desktop is unavailable. Export was not saved; no alternate folder was used.'
    }
    return $desktop
}

function Get-FKDesktopExportPath {
    param([Parameter(Mandatory)][string]$DefaultName)
    $name=[IO.Path]::GetFileName($DefaultName)
    if ([string]::IsNullOrWhiteSpace($name) -or $name -ne $DefaultName -or $name -match '[<>:"/\\|?*]') { throw 'Export filename must be a filename without a custom path.' }
    $stem=[IO.Path]::GetFileNameWithoutExtension($name)
    $extension=[IO.Path]::GetExtension($name)
    return (Join-Path (Get-FKDesktopDirectory) ($stem+'-'+[guid]::NewGuid().ToString('N')+$extension))
}

function OK($m)   { Write-Host "[OK]   $m" -ForegroundColor Green }
function INFO($m) { Write-Host "[INFO] $m" }
function WARN($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function RISK($m) { Write-Host "[RISK] $m" -ForegroundColor Red }
function FAIL($m) { Write-Host "[FAIL] $m" -ForegroundColor Red }

function Pause-End {
    Write-Host ''
    Write-Host 'SESSION COMPLETE'
    Write-Host ""
    Read-Host 'Press ENTER to close.' | Out-Null
}

function Now {
    return (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}

function Section {
    param([string]$Title)

    Write-Host ""
    Write-Host "--------------------------------------" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "Timestamp: $(Now)" -ForegroundColor Cyan
    Write-Host "--------------------------------------" -ForegroundColor Cyan
}

function Confirm-Yes {
    param([string]$Prompt)

    $a = Read-Host "$Prompt [Y/N]"
    return ($a.Trim().ToUpper() -eq "Y")
}

function Confirm-Type {
    param(
        [string]$Prompt,
        [string]$Required
    )

    Write-Host ""
    WARN $Prompt
    $a = Read-Host "Type $Required to continue"

    return ($a.Trim().ToUpper() -eq $Required.ToUpper())
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

function Get-InputLines {
    param([string]$Path)

    if (-not $Path) {
        $Path = (Read-Host "Input TXT/CSV path").Trim().Trim('"')
    }

    if (-not $Path -or -not (Test-Path $Path)) {
        FAIL "Input file not found"
        return @()
    }

    $items = New-Object System.Collections.ArrayList

    try {
        if ($Path.ToLower().EndsWith(".csv")) {
            $rows = Import-Csv -Path $Path -ErrorAction Stop

            foreach ($row in $rows) {
                $value = $null

                foreach ($name in @("UPN","UserPrincipalName","Email","Address","Group","GroupName","DisplayName","Name","Input")) {
                    if ($row.PSObject.Properties.Name -contains $name -and $row.$name) {
                        $value = "$($row.$name)"
                        break
                    }
                }

                if (-not $value) {
                    $first = $row.PSObject.Properties | Select-Object -First 1
                    if ($first) { $value = "$($first.Value)" }
                }

                if ($value -and $value.Trim()) {
                    [void]$items.Add($value.Trim().Trim('"'))
                }
            }
        }
        else {
            $lines = Get-Content -Path $Path -Encoding UTF8 -ErrorAction Stop

            foreach ($line in $lines) {
                $clean = $line.Trim().Trim('"')

                if ($clean -and $clean -notmatch '^#') {
                    [void]$items.Add($clean)
                }
            }
        }
    }
    catch {
        FAIL "Could not read input file"
        return @()
    }

    return @($items | Select-Object -Unique)
}

function Offer-ExportCsv {
    param(
        [array]$Rows,
        [string]$DefaultName
    )

    if (-not $Rows -or $Rows.Count -eq 0) { return }

    if (-not (Confirm-Yes "Export results to CSV")) { return }

    $path=Get-FKDesktopExportPath -DefaultName $DefaultName

    try {
        $Rows | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
        OK "Exported: $path"
    }
    catch {
        WARN "CSV export failed"
    }
}

function Graph-Get {
    param([string]$Uri)

    try { return Invoke-MgGraphRequest -Method GET -Uri $Uri -ErrorAction Stop }
    catch { throw "Graph read failed; review incomplete. $($_.Exception.Message)" }
}

function Graph-Post {
    param(
        [string]$Uri,
        [object]$Body
    )

    try {
        return Invoke-MgGraphRequest -Method POST -Uri $Uri -Body ($Body | ConvertTo-Json -Depth 20) -ContentType "application/json" -ErrorAction Stop
    } catch {
        return $null
    }
}

function Graph-Patch {
    param(
        [string]$Uri,
        [object]$Body
    )

    try {
        Invoke-MgGraphRequest -Method PATCH -Uri $Uri -Body ($Body | ConvertTo-Json -Depth 20) -ContentType "application/json" -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Graph-Delete {
    param([string]$Uri)

    try {
        Invoke-MgGraphRequest -Method DELETE -Uri $Uri -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Ensure-Graph {
    param([string[]]$Scopes, [string]$TenantId)

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
    return $true
}

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

function Get-GraphUserByUPN {
    param([string]$UPN)

    $encoded = Encode-Value $UPN
    $uri = "https://graph.microsoft.com/v1.0/users/${encoded}?`$select=id,displayName,userPrincipalName,mail,accountEnabled,userType,onPremisesSyncEnabled,assignedLicenses,usageLocation,signInActivity,lastPasswordChangeDateTime"
    $user = Graph-Get $uri

    if ($user -and $user.id) { return $user }

    $escaped = Escape-OData $UPN
    $filter = Encode-Value "userPrincipalName eq '$escaped' or mail eq '$escaped'"
    $uri = "https://graph.microsoft.com/v1.0/users?`$filter=$filter&`$select=id,displayName,userPrincipalName,mail,accountEnabled,userType,onPremisesSyncEnabled,assignedLicenses,usageLocation,signInActivity,lastPasswordChangeDateTime"
    $fallback = Graph-Get $uri

    if ($fallback -and $fallback.value -and @($fallback.value).Count -gt 0) {
        return @($fallback.value)[0]
    }

    return $null
}

function Get-GraphGroupByInput {
    param([string]$InputValue)

    $escaped = Escape-OData $InputValue
    $filter = Encode-Value "displayName eq '$escaped' or mail eq '$escaped'"
    $uri = "https://graph.microsoft.com/v1.0/groups?`$filter=$filter&`$select=id,displayName,mail,securityEnabled,mailEnabled,groupTypes,onPremisesSyncEnabled,membershipRule,membershipRuleProcessingState"
    $result = Graph-Get $uri

    if (-not $result -or $null -eq $result.value) { throw 'Group lookup is unavailable. No creation approved.' }
    if (@($result.value).Count -gt 1) { throw 'Group lookup is ambiguous. Resolve duplicate names before creating a group.' }
    if (@($result.value).Count -eq 1) {
        return @($result.value)[0]
    }

    return $null
}

try {
    try { $host.UI.RawUI.WindowTitle = "Create Dynamic Licensed Users Group" } catch {}

    Clear-Host
    Write-Host "Create Dynamic Group"
    Write-Host 'Create Dynamic Group'
    Write-Host 'Create a dynamic security group for enabled users with at least one enabled license service plan.'
    Write-Host "Change-making"
    Write-Host ""

    $inputName = Read-Host "Display name [default: $DisplayName]"
    if ($inputName) { $DisplayName = $inputName.Trim() }

    $inputNick = Read-Host "Mail nickname [default: $MailNickname]"
    if ($inputNick) { $MailNickname = $inputNick.Trim() }

    if (-not $ExpectedTenantId -and (Get-Command Get-MgContext -ErrorAction SilentlyContinue)) {
        $activeContext = Get-MgContext -ErrorAction SilentlyContinue
        if ($activeContext -and $activeContext.AuthType -eq 'Delegated' -and $activeContext.Account -and $activeContext.Environment -eq 'Global' -and $activeContext.TenantId) { $ExpectedTenantId = $activeContext.TenantId }
    }
    if (-not $ExpectedTenantId) {
        $domain = (Read-Host 'Tenant domain (for example, contoso.onmicrosoft.com; blank cancels)').Trim()
        if (-not $domain) { throw 'Tenant selection cancelled. No changes made.' }
        $ExpectedTenantId = Resolve-FkTenantDomain -Domain $domain
    }
    $tenantGuid=[guid]::Empty
    if (-not [guid]::TryParse($ExpectedTenantId,[ref]$tenantGuid) -or $tenantGuid -eq [guid]::Empty) { throw 'A valid expected tenant ID is required. No changes made.' }
    $ExpectedTenantId=$tenantGuid.ToString()
    if (-not (Ensure-Graph -Scopes @("Group.ReadWrite.All","Directory.Read.All") -TenantId $ExpectedTenantId)) {
        Pause-End
        return
    }
    $approvedAccount=(Get-MgContext -ErrorAction Stop).Account

    $rule = '(user.accountEnabled -eq true) -and (user.assignedPlans -any (assignedPlan.servicePlanId -ne null -and assignedPlan.capabilityStatus -eq "Enabled"))'

    Section "PREVIEW"
    if ($domain) { Write-Host "Tenant domain: $domain" }
    Write-Host "Account      : $approvedAccount"
    Write-Host "Display name : $DisplayName"
    Write-Host "Mail nickname: $MailNickname"
    Write-Host "Rule         : $rule"
    Write-Host ""

    $existing = Get-GraphGroupByInput -InputValue $DisplayName

    if ($existing) {
        WARN "Group already exists: $($existing.displayName)"
        Pause-End
        return
    }

    if (-not (Confirm-Type "This will create a dynamic Entra security group." "CREATE")) {
        WARN "Cancelled"
        Pause-End
        return
    }

    $body = @{
        displayName = $DisplayName
        mailEnabled = $false
        mailNickname = $MailNickname
        securityEnabled = $true
        groupTypes = @("DynamicMembership")
        membershipRule = $rule
        membershipRuleProcessingState = "On"
    }

    Section "CREATE"
    Assert-GraphContext -TenantId $ExpectedTenantId -Account $approvedAccount

    $created = Graph-Post "https://graph.microsoft.com/v1.0/groups" $body

    if ($created -and $created.id) {
        Start-Sleep -Milliseconds 300
        $verified=Get-GraphGroupByInput -InputValue $DisplayName

        if (
            $verified -and
            [string]$verified.id -eq [string]$created.id -and
            @($verified.groupTypes) -contains "DynamicMembership" -and
            [string]$verified.membershipRule -eq [string]$rule -and
            [string]$verified.membershipRuleProcessingState -eq "On"
        ) {
            OK "Group created and verified: $DisplayName"
        }
        else {
            throw "Group creation returned success, but the dynamic membership configuration could not be verified."
        }
    } else {
        throw "Group creation is unverified. Review current tenant groups before retrying; the request outcome may be unknown."
    }

    Section "RESULTS"
    Write-Host "Display name : $DisplayName"
    Write-Host "Mail nickname: $MailNickname"
    Write-Host "Rule         : $rule"
    Write-Host "Operator     : $env:USERDOMAIN\$env:USERNAME"
    Write-Host "Time         : $(Now)"

    Pause-End
}
catch {
    Write-Host ""
    FAIL "Unhandled script error"
    Write-Host $_.Exception.Message
    Pause-End
}

