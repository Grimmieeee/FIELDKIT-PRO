<#
.VERSION 1.0.5
#>
# OBJECTIVE: Review policies for gaps in device-code sign-in protection.

<#
tenant-device-code-exposure-audit-clean.ps1

Read-only device code exposure audit.

Purpose:
- Checks Conditional Access policies for device code flow blocking indicators
- Reviews recent sign-ins for device code activity where available
- Helps assess exposure to device code phishing
#>

param(
    [int]$LookbackHours = 72,
    [string]$ExpectedTenantId
)
Write-Host 'GET-DEVICE-CODE-EXPOSURE.ps1 // READ ONLY'
Write-Host ''
Write-Host 'Objective: Review Conditional Access coverage for device code authentication.'
Write-Host ''
Write-Host "Device Code Exposure"

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

function Write-FieldKitFooter {
    Write-Host ""
    Write-Host "F I E L D  //  K I T"
    Write-Host ""
}

function OK($m)   { Write-Host "[OK]   $m" -ForegroundColor Green }
function INFO($m) { Write-Host "[INFO] $m" }
function WARN($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function RISK($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function FAIL($m) { Write-Host "[FAIL] $m" -ForegroundColor Red }

function Pause-End {
    Write-FieldKitFooter
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
    Write-Host $Title
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

    $path=Get-FKDesktopExportPath -DefaultName $DefaultName

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

    $path=Get-FKDesktopExportPath -DefaultName $DefaultName

    try {
        $Object | ConvertTo-Json -Depth 20 | Out-File -FilePath $path -Encoding UTF8
        OK "Exported: $path"
    }
    catch {
        WARN "JSON export failed"
    }
}

function Graph-Get {
    param([string]$Uri)

    try { return Invoke-MgGraphRequest -Method GET -Uri $Uri -ErrorAction Stop }
    catch { throw "Graph read failed; review incomplete. $($_.Exception.Message)" }
}

function Ensure-Module {
    param(
        [string]$Name,
        [string]$Command
    )

    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        return
    }

    $module = Get-Module -ListAvailable -Name $Name |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if (-not $module) {
        throw "$Name is required but is not installed. Install it first with: Install-Module $Name -Scope CurrentUser"
    }

    Import-Module $module.Path -Force -ErrorAction Stop

    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        throw "$Name loaded, but $Command is unavailable."
    }
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
    if (-not $TenantId -and ($ctx -and $ctx.AuthType -eq 'Delegated' -and $ctx.Account -and $ctx.Environment -eq 'Global' -and $ctx.TenantId)) { $TenantId = $ctx.TenantId }
    if (-not $TenantId) {
        $domain = (Read-Host 'Tenant domain (for example, contoso.onmicrosoft.com; blank cancels)').Trim()
        if (-not $domain) { throw 'Tenant selection cancelled.' }
        $TenantId = Resolve-FkTenantDomain -Domain $domain
    }
    $expectedGuid=[guid]::Empty
    if (-not [guid]::TryParse($TenantId,[ref]$expectedGuid) -or $expectedGuid -eq [guid]::Empty) { throw "A valid expected tenant ID is required. No audit was completed." }
    $TenantId=$expectedGuid.ToString()
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
    INFO "Account: $($ctx.Account)"
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

function Get-GraphUserByUPN {
    param([string]$UPN)

    $encoded = Encode-Value $UPN
    $uri = "https://graph.microsoft.com/v1.0/users/${encoded}?`$select=id,displayName,userPrincipalName,mail,accountEnabled,userType,onPremisesSyncEnabled,assignedLicenses,signInActivity,lastPasswordChangeDateTime"
    $user = Graph-Get $uri

    if ($user -and $user.id) { return $user }

    $escaped = Escape-OData $UPN
    $filter = Encode-Value "userPrincipalName eq '$escaped' or mail eq '$escaped'"
    $uri = "https://graph.microsoft.com/v1.0/users?`$filter=$filter&`$select=id,displayName,userPrincipalName,mail,accountEnabled,userType,onPremisesSyncEnabled,assignedLicenses,signInActivity,lastPasswordChangeDateTime"
    $fallback = Graph-Get $uri

    if ($fallback -and $fallback.value -and @($fallback.value).Count -gt 0) {
        return @($fallback.value)[0]
    }

    return $null
}

function Is-RiskyScope {
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
        "full_access_as_user",
        "Application.ReadWrite",
        "RoleManagement.ReadWrite"
    )

    foreach ($p in $patterns) {
        if ($Scope -like "*$p*") { return $true }
    }

    return $false
}

try {
    try { $host.UI.RawUI.WindowTitle = "Tenant Device Code Exposure Audit" } catch {}
Write-Host 'Review Device Code Exposure'
Write-Host 'Review policies for gaps in device-code sign-in protection.'
    Write-Host "Read-only"
    Write-Host ""

    $inputHours = Read-Host "Lookback hours [default $LookbackHours]"
    if ($inputHours) { try { $LookbackHours = [int]$inputHours } catch {} }

    if (-not (Ensure-Graph -Scopes @("Policy.Read.ConditionalAccess","AuditLog.Read.All","Directory.Read.All") -TenantId $ExpectedTenantId)) {
        Pause-End
        exit 1
    }

    Section "CONDITIONAL ACCESS"

    $policies = @(Get-GraphPages -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies")
    $capRows = New-Object System.Collections.ArrayList

    foreach ($p in $policies) {
        $clientTypes = ""
        $conditionsText = ($p | ConvertTo-Json -Depth 20)

        try { $clientTypes = @($p.conditions.clientAppTypes) -join "; " } catch {}

        $finding = "Review"
        if ($conditionsText -match "deviceCode") { $finding = "Device code condition/reference present" }
        elseif ($p.state -eq "disabled") { $finding = "Disabled policy" }
        elseif ($p.state -eq "enabledForReportingButNotEnforced") { $finding = "Report-only policy" }

        [void]$capRows.Add([pscustomobject]@{
            PolicyName=(Clean-Name $p.displayName)
            State=$p.state
            ClientAppTypes=$clientTypes
            Finding=$finding
        })
    }

    $devicePolicies = @($capRows | Where-Object { $_.Finding -eq "Device code condition/reference present" })

    if ($devicePolicies.Count -gt 0) {
        OK "Device code policy reference found"
    } else {
        WARN "No obvious device code policy reference found"
    }

    Section "SIGN-IN REVIEW"

    $since = (Get-Date).AddHours(-1 * $LookbackHours).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $filter = Encode-Value "createdDateTime ge $since"
    $uri = "https://graph.microsoft.com/v1.0/auditLogs/signIns?`$top=100&`$filter=$filter"
    $logs = @(Get-GraphPages -Uri $uri)

    $deviceRows = New-Object System.Collections.ArrayList

    foreach ($log in $logs) {
        $text = ($log | ConvertTo-Json -Depth 10)

        if ($text -match "deviceCode|Device Code|device code") {
            [void]$deviceRows.Add([pscustomobject]@{
                Time=$log.createdDateTime
                UPN=$log.userPrincipalName
                App=$log.appDisplayName
                ClientApp=$log.clientAppUsed
                IP=$log.ipAddress
                Country=$log.location.countryOrRegion
                Result=$(if ($log.status.errorCode -eq 0) { "Success" } else { "Failed" })
            })
        }
    }

    Write-Host "Policies reviewed      : $($capRows.Count)"
    Write-Host "Device policy refs     : $($devicePolicies.Count)"
    Write-Host "Sign-ins reviewed      : $($logs.Count)"
    Write-Host "Device code sign-ins   : $($deviceRows.Count)"
    Write-Host ""

    foreach ($r in ($deviceRows | Select-Object -First 50)) {
        if ($r.Result -eq "Success") {
            RISK "$($r.Time) | $($r.UPN) | $($r.Result) | $($r.IP) | $($r.App)"
        } else {
            WARN "$($r.Time) | $($r.UPN) | $($r.Result) | $($r.IP) | $($r.App)"
        }
    }

    Offer-ExportCsv -Rows @($deviceRows) -DefaultName "tenant-device-code-exposure-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"

    OK "Complete. No changes made."
    Pause-End
}
catch {
    Write-Host ""
    FAIL ("Unhandled script error: {0}" -f $_.Exception.Message)
    Pause-End
}
