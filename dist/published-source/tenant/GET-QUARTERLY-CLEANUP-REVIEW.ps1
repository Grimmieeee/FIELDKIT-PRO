# .VERSION 1.0.6
#Requires -Version 5.1

<#
QUARTERLY CLEANUP REVIEW

OBJECTIVE
Review accounts, mailbox access, and licenses for cleanup.

REVIEWS
- Enabled Entra member accounts with recorded sign-in activity older than the threshold
- Enabled Entra member accounts where sign-in activity is unavailable
- Active Entra admin role membership counts
- Cloud-manageable Entra groups without owners
- Exchange Online mailboxes with EXTERNAL forwarding enabled
- Microsoft 365 license capacity and assigned seats by SKU

DEFAULT STALE THRESHOLD
90 days

SAFETY
Read-only.
No changes are made.
Optional Desktop HTML report; default is No.
Query failures are reported as data gaps and are never treated as clean results.
#>

param(
    [ValidateRange(1,3650)]
    [int]$StaleDays = 90,

    [string]$TenantDomain
)
Write-Host "Review Account Cleanup"

$ErrorActionPreference = "Stop"

if ($PSVersionTable.PSVersion.Major -lt 7) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

# Embedded into standalone report scripts by tools/reporting/build.ps1.
$script:FKReportLines = New-Object 'Collections.Generic.List[string]'
$script:FKReportWarnings = @()
$script:FKReportStartedUtc = [DateTime]::UtcNow.ToString('o')

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

function Write-FKReportLine {
    [CmdletBinding()]
    param(
        [Parameter(Position=0,ValueFromRemainingArguments=$true)][object[]]$Object,
        [object]$Separator=' ',[switch]$NoNewline,
        [ConsoleColor]$ForegroundColor,[ConsoleColor]$BackgroundColor
    )
    $line=($Object | ForEach-Object {[string]$_}) -join [string]$Separator
    $script:FKReportLines.Add($line)
    Write-Host @PSBoundParameters
}

function ConvertTo-FKDesktopReport {
    param([string]$Title,[string[]]$Lines,[string]$StartedUtc,[string]$ScopeNote)
    $encode={param($Text) [Net.WebUtility]::HtmlEncode([string]$Text)}
    $blocks=New-Object 'Collections.Generic.List[string]'
    $section=New-Object 'Collections.Generic.List[string]'
    foreach($line in @($Lines)) {
        if($line -match '^\s*[A-Z][A-Z /+&:()-]{2,}\s*$' -and $line.Trim().Length -lt 90) {
            if($section.Count) {$blocks.Add('<pre>'+(& $encode ($section.ToArray() -join "`n"))+'</pre>');$section.Clear()}
            $blocks.Add('<h2>'+(& $encode $line.Trim())+'</h2>')
        } else {$section.Add([string]$line)}
    }
    if($section.Count){$blocks.Add('<pre>'+(& $encode ($section.ToArray() -join "`n"))+'</pre>')}
    $safeTitle=& $encode $Title
    return @"
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'"><title>$safeTitle</title>
<style>body{font:16px/1.55 system-ui,sans-serif;background:#f5f7f7;color:#172524;margin:0}main{max-width:1000px;margin:32px auto;padding:32px;background:white;border-top:4px solid #168779}header{border-bottom:1px solid #d1ddda;padding-bottom:20px}small{letter-spacing:.12em;color:#52716b}h1{font-size:28px;margin:12px 0}h2{font-size:15px;letter-spacing:.1em;color:#166b60;margin:28px 0 10px;border-bottom:1px solid #d1ddda;padding-bottom:8px}pre{font:14px/1.6 ui-monospace,Consolas,monospace;white-space:pre-wrap;overflow-wrap:anywhere;margin:0}aside{background:#eef5f2;padding:12px 16px;margin:20px 0}footer{font-size:12px;color:#52716b;margin-top:32px}@media print{body{background:white}main{margin:0;padding:0;max-width:none}h2{break-after:avoid}pre{font-size:11px}}</style></head>
<body><main><header><small>F I E L D // K I T</small><h1>$safeTitle</h1><p>Collection started (UTC): $(& $encode $StartedUtc)</p></header><aside>$(& $encode $ScopeNote) Findings, unavailable checks, and displayed limits below are preserved from this run. Absence of a finding does not establish complete coverage.</aside>$($blocks.ToArray() -join "`n")<footer>Read-only report. No remote content or executable scripts. Review findings in context before taking action.</footer></main></body></html>
"@
}

function Save-FKDesktopReport {
    param([string]$Folder,[string]$Title,[string]$Content)
    if([string]::IsNullOrWhiteSpace($Folder) -or -not [IO.Directory]::Exists($Folder)){throw 'Report folder does not exist.'}
    $stem=($Title -replace '[^a-zA-Z0-9._-]','-').Trim('-')
    if(-not $stem){$stem='field-kit-report'}
    $stem=$stem.Substring(0,[Math]::Min(80,$stem.Length))
    $name=$stem+'-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)+'.html'
    $path=Join-Path $Folder $name
    $bytes=(New-Object Text.UTF8Encoding($false)).GetBytes($Content)
    $stream=New-Object IO.FileStream($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try {$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
    $actual=[IO.File]::ReadAllBytes($path)
    $sha=[Security.Cryptography.SHA256]::Create()
    try {
        if([Convert]::ToBase64String($sha.ComputeHash($bytes)) -cne [Convert]::ToBase64String($sha.ComputeHash($actual))){throw 'Report readback did not match the collected content.'}
    }finally{$sha.Dispose()}
    return $path
}

function Offer-FKDesktopReport {
    param([string]$Title,[string]$ScopeNote='Scope matches the console output; only displayed rows are included.')
    if(-not $script:FKReportLines.Count){return}
    try {
        if((Read-Host 'Save report to Desktop? [Y/N]').Trim() -notmatch '^(?i)y$'){return}
        $folder=Get-FKDesktopDirectory
        $reportLines=@($script:FKReportLines.ToArray())
        if(@($script:FKReportWarnings).Count){$reportLines+=@('','SERVICE WARNINGS');$reportLines+=@($script:FKReportWarnings|ForEach-Object {[string]$_})}
        $content=ConvertTo-FKDesktopReport -Title $Title -Lines $reportLines -StartedUtc $script:FKReportStartedUtc -ScopeNote $ScopeNote
        $saved=Save-FKDesktopReport -Folder $folder -Title $Title -Content $content
        Write-Host ('[OK] Report saved and readback checked: '+$saved)
    }catch{Write-Host ('[WARN] Report export failed: '+$_.Exception.Message) -ForegroundColor Yellow}
}

function Write-FieldKitFooter {
    Write-FKReportLine ""
    Write-FKReportLine "F I E L D  //  K I T"
    Write-FKReportLine ""
}

function Write-OK   { param($m) Write-FKReportLine "[OK]   $m" -ForegroundColor Green }
function Write-Info { param($m) Write-FKReportLine "[INFO] $m" }
function Write-Warn { param($m) Write-FKReportLine "[WARN] $m" -ForegroundColor Yellow }
function Write-Fail { param($m) Write-FKReportLine "[FAIL] $m" -ForegroundColor Red }

function Write-Section {
    param([string]$Title)

    Write-FKReportLine $Title
}

function Pause-End {
    Write-FieldKitFooter
    Write-Host ''
    Write-Host 'SESSION COMPLETE'
    Write-FKReportLine ""
    Write-FKReportLine 'Press Enter to close session.' -NoNewline

    try {
        do {
            $key = $Host.UI.RawUI.ReadKey(
                "NoEcho,IncludeKeyDown"
            )
        }
        until ($key.VirtualKeyCode -eq 13)

        Write-FKReportLine ""
    }
    catch {
        Write-FKReportLine ""
        Read-Host 'Press Enter to close session.' | Out-Null
    }
}

function Get-ShortError {
    param($ErrorRecord)

    $message = $ErrorRecord.Exception.Message

    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = [string]$ErrorRecord
    }

    return (($message -replace "\s+", " ").Trim())
}

function Clean-Name {
    param([object]$Name)

    if ($null -eq $Name) {
        return ""
    }

    return (
        [string]$Name -replace
        '\s*\([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\)\s*$',
        ''
    ).Trim()
}

function Test-GuidString {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    return (
        $Value -match
        '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    )
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

function Invoke-GraphGet {
    param([string]$Uri)

    $command = Get-Command Invoke-MgGraphRequest -ErrorAction Stop
    $parameters = @{
        Method      = "GET"
        Uri         = $Uri
        ErrorAction = "Stop"
    }

    if ($command.Parameters.ContainsKey("OutputType")) {
        $parameters["OutputType"] = "PSObject"
    }

    return Invoke-MgGraphRequest @parameters
}

function Get-GraphPaged {
    param(
        [string]$Uri,
        [int]$MaxPages = 200
    )

    $items = @()
    $next = $Uri
    $pageCount = 0

    while ($next) {
        if ($pageCount -ge $MaxPages) {
            throw (
                "Graph pagination exceeded the safety limit of {0} pages. " +
                "Incomplete results were not accepted."
            ) -f $MaxPages
        }

        $page = Invoke-GraphGet -Uri $next

        if (
            $null -eq $page -or
            $page.PSObject.Properties.Name -notcontains "value"
        ) {
            throw "Graph returned an unexpected paged response. Incomplete results were not accepted."
        }

        $items += @(
            $page.value |
            Where-Object { $null -ne $_ }
        )

        $pageCount++
        $next = [string]$page.'@odata.nextLink'
    }

    return @($items)
}

function Get-GraphTenantInfo {
    $response = Invoke-GraphGet `
        -Uri "https://graph.microsoft.com/v1.0/organization?`$select=displayName,verifiedDomains"

    $organization = @($response.value) | Select-Object -First 1

    if (-not $organization) {
        throw "Graph did not return organization details."
    }

    $defaultDomain = @(
        $organization.verifiedDomains |
        Where-Object { $_.isDefault -eq $true } |
        Select-Object -First 1
    )

    return [PSCustomObject]@{
        DisplayName   = [string]$organization.displayName
        DefaultDomain = if ($defaultDomain) {
            [string]$defaultDomain.name
        }
        else {
            ""
        }
        Domains = @(
            $organization.verifiedDomains |
            ForEach-Object { [string]$_.name } |
            Where-Object { $_ }
        )
    }
}

function Test-GraphScopes {
    param(
        [object]$Context,
        [string[]]$RequiredScopes
    )

    if (-not $Context) {
        return $false
    }

    foreach ($scope in $RequiredScopes) {
        if (@($Context.Scopes) -notcontains $scope) {
            return $false
        }
    }

    return $true
}

function Connect-GraphAuto {
    param(
        [string[]]$Scopes,
        [string]$TargetDomain
    )

    Ensure-Module `
        -Name "Microsoft.Graph.Authentication" `
        -Command "Connect-MgGraph"

    $context = Get-MgContext -ErrorAction SilentlyContinue

    if (
        $context -and
        (Test-GraphScopes -Context $context -RequiredScopes $Scopes)
    ) {
        try {
            $tenant = Get-GraphTenantInfo

            if ($tenant.Domains -contains $TargetDomain) {
                Write-OK "Graph session reused"
                return $tenant
            }
        }
        catch {
        }
    }

    if ($context) {
        try {
            Disconnect-MgGraph `
                -ErrorAction SilentlyContinue |
                Out-Null
        }
        catch {
        }
    }

    Write-FKReportLine "Graph: Connecting..."

    $command = Get-Command `
        Connect-MgGraph `
        -ErrorAction Stop

    $parameters = @{
        Scopes      = $Scopes
        ErrorAction = "Stop"
    }

    if ($command.Parameters.ContainsKey("ContextScope")) {
        $parameters["ContextScope"] = "Process"
    }

    if ($command.Parameters.ContainsKey("NoWelcome")) {
        $parameters["NoWelcome"] = $true
    }

    Connect-MgGraph @parameters | Out-Null

    $context = Get-MgContext -ErrorAction Stop

    if (
        -not (
            Test-GraphScopes `
                -Context $context `
                -RequiredScopes $Scopes
        )
    ) {
        throw "Graph token is missing one or more required scopes."
    }

    $tenant = Get-GraphTenantInfo

    if ($tenant.Domains -notcontains $TargetDomain) {
        throw (
            "Graph connected to a different tenant. " +
            "Expected domain: $TargetDomain"
        )
    }

    Write-OK "Graph connected"
    return $tenant
}

function Get-ActiveExchangeConnection {
    if (-not (Get-Command Get-ConnectionInformation -ErrorAction SilentlyContinue)) {
        return $null
    }

    $connections = @(Get-ConnectionInformation -ErrorAction Stop | Where-Object {
        ($_.State -eq 'Connected' -or $_.ConnectionStatus -eq 'Connected') -and -not $_.ModulePrefix
    })
    if ($connections.Count -gt 1) { throw 'Multiple unprefixed Exchange sessions are open. Use one verified session for this review.' }
    return $connections | Select-Object -First 1
}

function Test-ExchangeRead {
    try {
        $null = Get-AcceptedDomain `
            -ResultSize 1 `
            -ErrorAction Stop

        return $true
    }
    catch {
        return $false
    }
}

function Test-ExchangeTenant {
    param([string]$TargetDomain)

    try {
        $domains = @(
            Get-AcceptedDomain `
                -ResultSize Unlimited `
                -ErrorAction Stop
        )

        return (
            @(
                $domains |
                Where-Object {
                    [string]$_.DomainName -eq $TargetDomain
                }
            ).Count -gt 0
        )
    }
    catch {
        return $false
    }
}

function Connect-ExchangeAuto {
    param([string]$TargetDomain)

    Ensure-Module `
        -Name "ExchangeOnlineManagement" `
        -Command "Connect-ExchangeOnline"

    if (
        (Get-ActiveExchangeConnection) -and
        (Test-ExchangeRead) -and
        (Test-ExchangeTenant -TargetDomain $TargetDomain)
    ) {
        Write-OK "Exchange session reused"
        return
    }

    Write-FKReportLine "Exchange Online: Connecting..."

    $command = Get-Command `
        Connect-ExchangeOnline `
        -ErrorAction Stop

    $parameters = @{
        ErrorAction = "Stop"
    }

    if ($command.Parameters.ContainsKey("ShowBanner")) {
        $parameters["ShowBanner"] = $false
    }

    if ($command.Parameters.ContainsKey("ShowProgress")) {
        $parameters["ShowProgress"] = $false
    }

    Connect-ExchangeOnline @parameters | Out-Null

    if (-not (Test-ExchangeRead)) {
        throw "Exchange connected, but read access could not be validated."
    }

    if (-not (Test-ExchangeTenant -TargetDomain $TargetDomain)) {
        throw (
            "Exchange connected to a different tenant. " +
            "Expected domain: $TargetDomain"
        )
    }

    Write-OK "Exchange connected"
}

function Get-LicenseSeatReview {
    # Microsoft Entra licensing reference: Product_Display_Name keyed by String_Id.
    $licenseNames = @{
        '10_ALR_ADDON' = '10-Year Audit Log Retention Add On'
        'AAD_BASIC' = 'Microsoft Entra ID Basic'
        'AAD_PREMIUM' = 'Microsoft Entra ID P1'
        'AAD_PREMIUM_FACULTY' = 'Microsoft Entra ID P1 for Faculty'
        'AAD_PREMIUM_P2' = 'Microsoft Entra ID P2'
        'ADALLOM_O365' = 'Office 365 Cloud App Security'
        'ADALLOM_STANDALONE' = 'Microsoft Cloud App Security'
        'ADV_COMMS' = 'Advanced Communications'
        'AGENT_365' = 'Agent 365'
        'ATA' = 'Microsoft Defender for Identity'
        'ATP_ENTERPRISE' = 'Microsoft Defender for Office 365 (Plan 1)'
        'ATP_ENTERPRISE_FACULTY' = 'Microsoft Defender for Office 365 (Plan 1) Faculty'
        'ATP_ENTERPRISE_GOV' = 'Microsoft Defender for Office 365 (Plan 1) GCC'
        'ATP_ENTERPRISE_STUDENT' = 'Microsoft Defender for Office 365 (Plan 1) Student'
        'ATP_ENTERPRISE_STUDENTS_USE_BENEFIT' = 'Microsoft Defender for Office 365 (Plan 1) Student use benefit'
        'AX7_USER_TRIAL' = 'Microsoft Dynamics AX7 User Trial'
        'BUSINESS_VOICE' = 'Microsoft 365 Business Voice (UK'
        'BUSINESS_VOICE_DIRECTROUTING' = 'Microsoft 365 Business Voice (without Calling Plan)'
        'BUSINESS_VOICE_DIRECTROUTING_MED' = 'Microsoft 365 Business Voice (without Calling Plan) for US'
        'BUSINESS_VOICE_MED2' = 'Microsoft 365 Business Voice'
        'BUSINESS_VOICE_MED2_TELCO' = 'Microsoft 365 Business Voice (US)'
        'CAREERCOACH_FACULTY' = 'Career Coach for faculty'
        'CAREERCOACH_STUDENTS' = 'Career Coach for students'
        'CCIBOTS_PRIVPREV_VIRAL' = 'Microsoft Copilot Studio Viral Trial'
        'CDSAICAPACITY' = 'AI Builder Capacity add-on'
        'CDS_DB_CAPACITY' = 'Common Data Service Database Capacity'
        'CDS_DB_CAPACITY_GOV' = 'Common Data Service Database Capacity for Government'
        'CDS_FILE_CAPACITY' = 'Common Data Service for Apps File Capacity'
        'CDS_LOG_CAPACITY' = 'Common Data Service Log Capacity'
        'CLIPCHAMP_PREMIUM' = 'Clipchamp Premium'
        'CLIPCHAMP_PREMIUM_ADD_ON' = 'Clipchamp Premium Add-on'
        'CLIPCHAMP_STANDARD' = 'Clipchamp Standard'
        'CMPA_ADDON' = 'Compliance Manager Premium Assessment Add-On'
        'CMPA_ADDON_GCC' = 'Compliance Manager Premium Assessment Add-On for GCC'
        'COMPLIANCE_PROGRAM_FOR_MICROSOFT_CLOUD' = 'Compliance Program for Microsoft Cloud'
        'CPC_B_1C_2RAM_64GB' = 'Windows 365 Business 1 vCPU 2 GB 64 GB'
        'CPC_B_2C_4RAM_128GB' = 'Windows 365 Business 2 vCPU 4 GB 128 GB'
        'CPC_B_2C_4RAM_256GB' = 'Windows 365 Business 2 vCPU 4 GB 256 GB'
        'CPC_B_2C_4RAM_64GB' = 'Windows 365 Business 2 vCPU 4 GB 64 GB'
        'CPC_B_2C_8RAM_128GB' = 'Windows 365 Business 2 vCPU 8 GB 128 GB'
        'CPC_B_2C_8RAM_256GB' = 'Windows 365 Business 2 vCPU 8 GB 256 GB'
        'CPC_B_4C_16RAM_128GB' = 'Windows 365 Business 4 vCPU 16 GB 128 GB'
        'CPC_B_4C_16RAM_128GB_WHB' = 'Windows 365 Business 4 vCPU 16 GB 128 GB (with Windows Hybrid Benefit)'
        'CPC_B_4C_16RAM_256GB' = 'Windows 365 Business 4 vCPU 16 GB 256 GB'
        'CPC_B_4C_16RAM_512GB' = 'Windows 365 Business 4 vCPU 16 GB 512 GB'
        'CPC_B_8C_32RAM_128GB' = 'Windows 365 Business 8 vCPU 32 GB 128 GB'
        'CPC_B_8C_32RAM_256GB' = 'Windows 365 Business 8 vCPU 32 GB 256 GB'
        'CPC_B_8C_32RAM_512GB' = 'Windows 365 Business 8 vCPU 32 GB 512 GB'
        'CPC_E_1C_2GB_64GB' = 'Windows 365 Enterprise 1 vCPU 2 GB 64 GB'
        'CPC_E_2C_4GB_128GB' = 'Windows 365 Enterprise 2 vCPU 4 GB 128 GB'
        'CPC_E_2C_4GB_256GB' = 'Windows 365 Enterprise 2 vCPU 4 GB 256 GB'
        'CPC_E_2C_4GB_64GB' = 'Windows 365 Enterprise 2 vCPU 4 GB 64 GB'
        'CPC_E_2C_8GB_128GB' = 'Windows 365 Enterprise 2 vCPU 8 GB 128 GB'
        'CPC_E_2C_8GB_256GB' = 'Windows 365 Enterprise 2 vCPU 8 GB 256 GB'
        'CPC_E_4C_16GB_128GB' = 'Windows 365 Enterprise 4 vCPU 16 GB 128 GB'
        'CPC_E_4C_16GB_256GB' = 'Windows 365 Enterprise 4 vCPU 16 GB 256 GB'
        'CPC_E_4C_16GB_512GB' = 'Windows 365 Enterprise 4 vCPU 16 GB 512 GB'
        'CPC_E_8C_32GB_128GB' = 'Windows 365 Enterprise 8 vCPU 32 GB 128 GB'
        'CPC_E_8C_32GB_256GB' = 'Windows 365 Enterprise 8 vCPU 32 GB 256 GB'
        'CPC_E_8C_32GB_512GB' = 'Windows 365 Enterprise 8 vCPU 32 GB 512 GB'
        'CPC_LVL_1' = 'Windows 365 Enterprise 2 vCPU 4 GB 128 GB (Preview)'
        'CPC_LVL_2' = 'Windows 365 Enterprise 2 vCPU 8 GB 128 GB (Preview)'
        'CPC_LVL_3' = 'Windows 365 Enterprise 4 vCPU 16 GB 256 GB (Preview)'
        'CRMINSTANCE' = 'Dynamics 365 - Additional Production Instance (Qualified Offer)'
        'CRMINSTANCE_GCC' = 'Dynamics 365 Enterprise Edition - Additional Production Instance for Government'
        'CRMPLAN2' = 'Microsoft Dynamics CRM Online Basic'
        'CRMPLAN2_GCC' = 'Microsoft Dynamics CRM Online Basic for Government'
        'CRMSTANDARD' = 'Microsoft Dynamics CRM Online'
        'CRMSTANDARD_GCC' = 'Microsoft Dynamics CRM Online for Government'
        'CRMSTORAGE' = 'Dynamics 365 - Additional Database Storage (Qualified Offer)'
        'CRMSTORAGE_GCC' = 'Dynamics 365 Enterprise Edition - Additional Database Storage for Government'
        'CRMTESTINSTANCE' = 'Dynamics 365 - Additional Non-Production Instance (Qualified Offer)'
        'CRMTESTINSTANCE_GCC' = 'Dynamics 365 Enterprise Edition - Additional Non-Production Instance for Government'
        'CRMTESTINSTANCE_NOPREREQ' = 'Dynamics 365 - Additional Non-Production Instance for Government'
        'CRM_AUTO_ROUTING_ADDON' = 'Dynamics 365 Field Service, Enterprise Edition - Resource Scheduling Optimization'
        'CRM_HYBRIDCONNECTOR' = 'Dynamics 365 Hybrid Connector'
        'CRM_ONLINE_PORTAL' = 'Dynamics 365 Enterprise Edition - Additional Portal (Qualified Offer)'
        'CRM_ONLINE_PORTAL_GCC' = 'Dynamics 365 Enterprise Edition - Additional Portal for Government'
        'CRM_ONLINE_PORTAL_NOPREREQ' = 'Dynamics 365 Enterprise Edition - Additional Portal for Government'
        'D365_CUSTOMER_SERVICE_ENT_ATTACH' = 'Dynamics 365 for Customer Service Enterprise Attach to Qualifying Dynamics 365 Base Offer A'
        'D365_CUSTOMER_SERVICE_PRO_ATTACH' = 'Dynamics 365 for Customer Service Professional Attach to Qualifying Dynamics 365 Base Offer'
        'D365_ENTERPRISE_CASE_MANAGEMENT_GOV' = 'Dynamics 365 for Case Management, Enterprise Edition for Government'
        'D365_ENTERPRISE_CUSTOMER_SERVICE_GOV' = 'Dynamics 365 for Customer Service Enterprise for Government'
        'D365_ENTERPRISE_FIELD_SERVICE_GOV' = 'Dynamics 365 for Field Service for Government'
        'D365_ENTERPRISE_PROJECT_SERVICE_AUTOMATION_GOV' = 'Dynamics 365 for Project Service Automation for Government'
        'D365_ENTERPRISE_SALES_GOV' = 'Dynamics 365 for Sales Enterprise for Government'
        'D365_FIELD_SERVICE_ATTACH' = 'Dynamics 365 for Field Service Attach to Qualifying Dynamics 365 Base Offer'
        'D365_FIELD_SERVICE_CONTRACTOR' = 'Dynamics 365 Field Service Contractor'
        'D365_FIELD_SERVICE_CONTRACTOR_GOV' = 'Dynamics 365 Field Service Contractor for Government'
        'D365_MARKETING_USER' = 'Dynamics 365 for Marketing USL'
        'D365_SALES_ENT_ATTACH' = 'Dynamics 365 Sales Enterprise Attach to Qualifying Dynamics 365 Base Offer'
        'D365_SALES_PRO' = 'Dynamics 365 For Sales Professional'
        'D365_SALES_PRO_ATTACH' = 'Dynamics 365 Sales Professional Attach to Qualifying Dynamics 365 Base Offer'
        'D365_SALES_PRO_GOV' = 'Dynamics 365 for Sales Professional for Government'
        'D365_SALES_PRO_IW' = 'Dynamics 365 For Sales Professional Trial'
        'DEFENDER_ENDPOINT_P1' = 'Microsoft Defender for Endpoint P1'
        'DEFENDER_ENDPOINT_P1_EDU' = 'Microsoft Defender for Endpoint P1 for EDU'
        'DEFENDER_THREAT_INTELLIGENCE' = 'Defender Threat Intelligence'
        'DESKLESSPACK' = 'Office 365 F3'
        'DESKLESSPACK_USGOV_GCCHIGH' = 'Office 365 F3_USGOV_GCCHIGH'
        'DEVELOPERPACK' = 'Office 365 E3 Developer'
        'DEVELOPERPACK_E5' = 'Microsoft 365 E5 Developer (without Windows and Audio Conferencing)'
        'DYN365_AI_SERVICE_INSIGHTS' = 'Dynamics 365 Customer Service Insights Trial'
        'DYN365_ASSETMANAGEMENT' = 'Dynamics 365 Asset Management Addl Assets'
        'DYN365_BUSCENTRAL_ADD_ENV_ADDON' = 'Dynamics 365 Business Central Additional Environment Addon'
        'DYN365_BUSCENTRAL_DB_CAPACITY' = 'Dynamics 365 Business Central Database Capacity'
        'DYN365_BUSCENTRAL_ESSENTIAL' = 'Dynamics 365 Business Central Essentials'
        'DYN365_BUSCENTRAL_PREMIUM' = 'Dynamics 365 Business Central Premium'
        'DYN365_BUSCENTRAL_TEAM_MEMBER' = 'Dynamics 365 Business Central Team Members'
        'DYN365_BUSINESS_MARKETING' = 'Dynamics 365 for Marketing Business Edition'
        'DYN365_CS_CHAT' = 'Dynamics 365 for Customer Service Chat'
        'DYN365_CS_CHAT_GOV' = 'Dynamics 365 for Customer Service Chat for Government'
        'DYN365_CS_MESSAGING_GOV' = 'Dynamics 365 for Customer Service Digital Messaging add-on for Government'
        'DYN365_CS_OC_MESSAGING_VOICE_GOV' = 'Dynamics 365 Customer Service Digital Messaging and Voice Add-in for Government'
        'DYN365_CS_OC_MESSAGING_VOICE_GOV_TEST' = 'Dynamics 365 Customer Service Digital Messaging and Voice Add-in for Government for Test'
        'DYN365_CS_VOICE' = 'Dynamics 365 Customer Service Voice Channel Add-in'
        'DYN365_CUSTOMER_INSIGHTS_ATTACH' = 'Dynamics 365 Customer Insights Attach'
        'DYN365_CUSTOMER_INSIGHTS_BASE' = 'Dynamics 365 Customer Insights Standalone'
        'DYN365_CUSTOMER_INSIGHTS_VIRAL' = 'Dynamics 365 Customer Insights vTrial'
        'DYN365_CUSTOMER_SERVICE_PRO' = 'Dynamics 365 Customer Service Professional'
        'DYN365_CUSTOMER_VOICE_ADDON' = 'Dynamics 365 Customer Voice Additional Responses'
        'DYN365_CUSTOMER_VOICE_BASE' = 'Dynamics 365 Customer Voice'
        'DYN365_ENTERPRISE_CASE_MANAGEMENT' = 'Dynamics 365 for Case Management Enterprise Edition'
        'DYN365_ENTERPRISE_CASE_MANAGEMENT_GOV' = 'Dynamics 365 for Case Management, Enterprise Edition for Government'
        'DYN365_ENTERPRISE_CUSTOMER_SERVICE' = 'Dynamics 365 for Customer Service Enterprise Edition'
        'DYN365_ENTERPRISE_CUSTOMER_SERVICE_GOV' = 'Dynamics 365 for Customer Service, Enterprise Edition for Government'
        'DYN365_ENTERPRISE_FIELD_SERVICE' = 'Dynamics 365 for Field Service Enterprise Edition'
        'DYN365_ENTERPRISE_FIELD_SERVICE_GOV' = 'Dynamics 365 for Field Service Enterprise Edition for Government'
        'DYN365_ENTERPRISE_P1_IW' = 'Dynamics 365 P1 Tria for Information Workers'
        'DYN365_ENTERPRISE_PLAN1' = 'Dynamics 365 Customer Engagement Plan'
        'DYN365_ENTERPRISE_PROJECT_SERVICE_AUTOMATION_GOV' = 'Dynamics 365 for Project Service Automation Enterprise Edition for Government'
        'DYN365_ENTERPRISE_SALES' = 'Dynamics 365 for Sales Enterprise Edition'
        'DYN365_ENTERPRISE_SALES_CUSTOMERSERVICE' = 'Dynamics 365 for Sales and Customer Service Enterprise Edition'
        'DYN365_ENTERPRISE_SALES_GOV' = 'Dynamics 365 for Sales, Enterprise Edition for Government'
        'DYN365_ENTERPRISE_TEAM_MEMBERS' = 'Dynamics 365 for Team Members Enterprise Edition'
        'DYN365_ENTERPRISE_TEAM_MEMBERS_GOV' = 'Dynamics 365 for Team Members Enterprise Edition for Government'
        'DYN365_FINANCE' = 'Dynamics 365 Finance'
        'DYN365_FINANCE_ATTACH' = 'Dynamics 365 for Finance Attach to Qualifying Dynamics 365 Base Offer'
        'DYN365_FINANCE_ATTACH_ISVEMB_PROJOPS' = 'Dynamics 365 Finance Attach to Qualifying Base Offer Embedded with Project Management & Accounting'
        'DYN365_FINANCIALS_ACCOUNTANT_SKU' = 'Dynamics 365 Business Central External Accountant'
        'DYN365_FINANCIALS_BUSINESS_SKU' = 'Dynamics 365 for Financials Business Edition'
        'DYN365_HUMAN_RESOURCES_ATTACH' = 'Dynamics 365 Human Resources Attach to Qualifying Dynamics 365 Base Offer'
        'DYN365_IOT_INTELLIGENCE_ADDL_MACHINES' = 'Sensor Data Intelligence Additional Machines Add-in for Dynamics 365 Supply Chain Management'
        'DYN365_IOT_INTELLIGENCE_SCENARIO' = 'Sensor Data Intelligence Scenario Add-in for Dynamics 365 Supply Chain Management'
        'DYN365_MARKETING_APP' = 'Dynamics 365 Marketing App'
        'DYN365_MARKETING_APPLICATION_ADDON' = 'Dynamics 365 for Marketing Additional Application'
        'DYN365_MARKETING_APP_ATTACH' = 'Dynamics 365 for Marketing Attach'
        'DYN365_MARKETING_CONTACT_ADDON' = 'Dynamics 365 for Marketing Addnl Contacts Tier 1'
        'DYN365_MARKETING_CONTACT_ADDON_T3' = 'Dynamics 365 for Marketing Addnl Contacts Tier 3'
        'DYN365_MARKETING_CONTACT_ADDON_T5' = 'Dynamics 365 for Marketing Addnl Contacts Tier 5'
        'DYN365_MARKETING_SANDBOX_APPLICATION_ADDON' = 'Dynamics 365 for Marketing Additional Non-Prod Application'
        'DYN365_OPERATIONS_ACTIVITY' = 'Dynamics 365 Operations – Activity'
        'DYN365_PROJECT_OPERATIONS' = 'Dynamics 365 Project Operations'
        'DYN365_PROJECT_OPERATIONS_ATTACH' = 'Dynamics 365 Project Operations Attach'
        'DYN365_REGULATORY_SERVICE' = 'Dynamics 365 Regulatory Service - Enterprise Edition Trial'
        'DYN365_RETAIL' = 'Dynamics 365 Commerce'
        'DYN365_RETAIL_TRIAL' = 'Dynamics 365 Commerce Trial'
        'DYN365_SALES_PREMIUM' = 'Dynamics 365 Sales Premium'
        'DYN365_SCM' = 'Dynamics 365 for Supply Chain Management'
        'DYN365_SCM_ATTACH' = 'Dynamics 365 for Supply Chain Management Attach to Qualifying Dynamics 365 Base Offer'
        'DYN365_TEAM_MEMBERS' = 'Dynamics 365 Team Members'
        'DYNAMICS_365_BUSINESS_CENTRAL_ESSENTIALS_ATTACH' = 'Dynamics 365 Business Central Essentials Attach'
        'DYNAMICS_365_CONTACT_CENTER' = 'Dynamics 365 Contact Center'
        'DYNAMICS_365_CONTACT_CENTER_ADD_ON_FOR_CUSTOMER_SERVICE_ENTERPRISE' = 'Dynamics 365 Contact Center Add-on for Customer Service Enterprise'
        'DYNAMICS_365_CONTACT_CENTER_DIGITAL' = 'Dynamics 365 Contact Center Digital'
        'DYNAMICS_365_CONTACT_CENTER_DIGITAL_ADD_ON_FOR_CUSTOMER_SERVICE_ENTERPRISE' = 'Dynamics 365 Contact Center Digital Add-on for Customer Service Enterprise'
        'DYNAMICS_365_CONTACT_CENTER_VOICE' = 'Dynamics 365 Contact Center Voice'
        'DYNAMICS_365_CONTACT_CENTER_VOICE_ADD_ON_FOR_CUSTOMER_SERVICE_ENTERPRISE' = 'Dynamics 365 Contact Center Voice Add-on for Customer Service Enterprise'
        'DYNAMICS_365_CUSTOMER_INSIGHTS_ATTACH_NEW' = 'Dynamics 365 Customer Insights Attach'
        'DYNAMICS_365_CUSTOMER_INSIGHTS_JOURNEYS_T3_INTERACTED_PEOPLE' = 'Dynamics 365 Customer Insights Journeys T3 Interacted People'
        'DYNAMICS_365_CUSTOMER_INSIGHTS_USER_LICENSE' = 'Dynamics 365 Customer Insights User License'
        'DYNAMICS_365_CUSTOMER_SERVICE_DIGITAL_MESSAGING_PARTNER_SANDBOX' = 'Dynamics 365 Customer Service Digital Messaging Partner Sandbox'
        'DYNAMICS_365_CUSTOMER_SERVICE_ENTERPRISE_ADMIN_TRIAL' = 'Dynamics 365 Customer Service Enterprise Admin'
        'DYNAMICS_365_CUSTOMER_SERVICE_ENTERPRISE_VIRAL_TRIAL' = 'Dynamics 365 Customer Service Enterprise Viral Trial'
        'DYNAMICS_365_FIELD_SERVICE_ENTERPRISE_VIRAL_TRIAL' = 'Dynamics 365 Field Service Viral Trial'
        'DYNAMICS_365_FOR_OPERATIONS' = 'Dynamics 365 UNF OPS Plan ENT Edition'
        'DYNAMICS_365_FOR_OPERATIONS_DEVICES' = 'Dynamics 365 Operations - Device'
        'DYNAMICS_365_FOR_OPERATIONS_SANDBOX_TIER2_SKU' = 'Dynamics 365 Operations - Sandbox Tier 2:Standard Acceptance Testing'
        'DYNAMICS_365_FOR_OPERATIONS_SANDBOX_TIER4_SKU' = 'Dynamics 365 Operations - Sandbox Tier 4:Standard Performance Testing'
        'DYNAMICS_365_GUIDES_VTRIAL' = 'Dynamics 365 Guides vTrial'
        'DYNAMICS_365_HIRING_SKU' = 'Dynamics 365 Talent: Attract'
        'DYNAMICS_365_MULTI_APP_' = 'Dynamics 365 Multi-app'
        'DYNAMICS_365_ONBOARDING_SKU' = 'Dynamics 365 Talent: Onboard'
        'DYNAMICS_365_SALES_FIELD_SERVICE_AND_CUSTOMER_SERVICE_PARTNER_SANDBOX' = 'Dynamics 365 Sales, Field Service and Customer Service Partner Sandbox'
        'DYNAMICS_365_SALES_PREMIUM_VIRAL_TRIAL' = 'Dynamics 365 Sales Premium Viral Trial'
        'DYNAMICS_365_SUPPLY_CHAIN_MANAGEMENT_PREMIUM' = 'Dynamics 365 Supply Chain Management Premium'
        'E3_VDA_ONLY' = 'Windows 10/11 Enterprise E3 VDA'
        'EMS' = 'Enterprise Mobility + Security E3'
        'EMSPREMIUM' = 'Enterprise Mobility + Security E5'
        'EMSPREMIUM_GOV' = 'Enterprise Mobility + Security G5 GCC'
        'EMSPREMIUM_USGOV_GCCHIGH' = 'Enterprise Mobility + Security E5_USGOV_GCCHIGH'
        'EMS_EDU_FACULTY' = 'Enterprise Mobility + Security A3 for Faculty'
        'EMS_GOV' = 'Enterprise Mobility + Security G3 GCC'
        'ENTERPRISEPACK' = 'Office 365 E3'
        'ENTERPRISEPACKPLUS_FACULTY' = 'Office 365 A3 for faculty'
        'ENTERPRISEPACKPLUS_STUDENT' = 'Office 365 A3 for students'
        'ENTERPRISEPACKWITHOUTPROPLUS_GOV' = 'Office 365 G3 without Microsoft 365 Apps GCC'
        'ENTERPRISEPACK_GOV' = 'Office 365 G3 GCC'
        'ENTERPRISEPACK_USGOV_DOD' = 'Office 365 E3_USGOV_DOD'
        'ENTERPRISEPACK_USGOV_GCCHIGH' = 'Office 365 E3_USGOV_GCCHIGH'
        'ENTERPRISEPREMIUM' = 'Office 365 E5'
        'ENTERPRISEPREMIUM_FACULTY' = 'Office 365 A5 for faculty'
        'ENTERPRISEPREMIUM_GOV' = 'Office 365 G5 GCC'
        'ENTERPRISEPREMIUM_NOPBIPBX_GOV' = 'Office 365 GCC G5 without Power BI and Phone System'
        'ENTERPRISEPREMIUM_NOPSTNCONF' = 'Office 365 E5 Without Audio Conferencing'
        'ENTERPRISEPREMIUM_NOPSTNCONF_NOPBI_GOV' = 'Office 365 GCC G5 without Audio Conferencing'
        'ENTERPRISEPREMIUM_STUDENT' = 'Office 365 A5 for students'
        'ENTERPRISEWITHSCAL' = 'Office 365 E4'
        'EOP_ENTERPRISE' = 'Exchange Online Protection'
        'EOP_ENTERPRISE_PREMIUM' = 'Exchange Enterprise CAL Services (EOP DLP)'
        'EQUIVIO_ANALYTICS' = 'Office 365 Advanced Compliance'
        'EQUIVIO_ANALYTICS_GOV' = 'Office 365 Advanced Compliance for GCC'
        'EXCHANGEARCHIVE' = 'Exchange Online Archiving for Exchange Server'
        'EXCHANGEARCHIVE_ADDON' = 'Exchange Online Archiving for Exchange Online'
        'EXCHANGEDESKLESS' = 'Exchange Online Kiosk'
        'EXCHANGEENTERPRISE' = 'Exchange Online (Plan 2)'
        'EXCHANGEENTERPRISE_FACULTY' = 'Exchange Online (Plan 2) for Faculty'
        'EXCHANGEENTERPRISE_GOV' = 'Exchange Online (Plan 2) for GCC'
        'EXCHANGEESSENTIALS' = 'Exchange Online Essentials (ExO P1 Based)'
        'EXCHANGESTANDARD' = 'Exchange Online (Plan 1)'
        'EXCHANGESTANDARD_ALUMNI' = 'Exchange Online (Plan 1) for Alumni with Yammer'
        'EXCHANGESTANDARD_GOV' = 'Exchange Online (Plan 1) for GCC'
        'EXCHANGESTANDARD_STUDENT' = 'Exchange Online (Plan 1) for Students'
        'EXCHANGETELCO' = 'Exchange Online POP'
        'EXCHANGE_S_ESSENTIALS' = 'Exchange Online Essentials'
        'EXPERTS_ON_DEMAND' = 'Microsoft Threat Experts - Experts on Demand'
        'FLOW_BUSINESS_PROCESS' = 'Power Automate per flow plan'
        'FLOW_BUSINESS_PROCESS_GCC' = 'Power Automate per flow plan for Government'
        'FLOW_FREE' = 'Microsoft Power Automate Free'
        'FLOW_P1_GOV' = 'Flow Plan 1 for Government'
        'FLOW_P2' = 'Microsoft Power Automate Plan 2'
        'FLOW_PER_USER' = 'Power Automate per user plan'
        'FLOW_PER_USER_DEPT' = 'Power Automate per user plan dept'
        'FLOW_PER_USER_GCC' = 'Power Automate per user plan for Government'
        'FORMS_PRO' = 'Dynamics 365 Customer Voice Trial'
        'FORMS_PRO_ADDON' = 'Dynamics 365 Customer Voice Additional Responses'
        'FORMS_PRO_USL' = 'Dynamics 365 Customer Voice USL'
        'GUIDES_USER' = 'Dynamics 365 Guides'
        'IDENTITY_THREAT_PROTECTION' = 'Microsoft 365 E5 Security'
        'IDENTITY_THREAT_PROTECTION_FOR_EMS_E5' = 'Microsoft 365 E5 Security for EMS E5'
        'INFORMATION_PROTECTION_COMPLIANCE' = 'Microsoft 365 E5 Compliance'
        'INTELLIGENT_CONTENT_SERVICES' = 'SharePoint Syntex'
        'INTUNE_A' = 'Intune'
        'INTUNE_A_D' = 'Microsoft Intune Device'
        'INTUNE_A_D_GOV' = 'Microsoft Intune Device for Government'
        'INTUNE_A_GOV' = 'Microsoft Intune Government'
        'INTUNE_A_VL' = 'Microsoft Intune Plan 1 A VL'
        'INTUNE_A_VL_USGOV_GCCHIGH' = 'Microsoft Intune Plan 1 A VL_USGOV_GCCHIGH'
        'INTUNE_EDU' = 'Intune for Education'
        'INTUNE_SMB' = 'Microsoft Intune SMB'
        'IT_ACADEMY_AD' = 'Microsoft Imagine Academy'
        'LITEPACK' = 'Office 365 Small Business'
        'LITEPACK_P2' = 'Office 365 Small Business Premium'
        'M365EDU_A1' = 'Microsoft 365 A1'
        'M365EDU_A3_FACULTY' = 'Microsoft 365 A3 for Faculty'
        'M365EDU_A3_STUDENT' = 'Microsoft 365 A3 for Students'
        'M365EDU_A3_STUUSEBNFT' = 'Microsoft 365 A3 for students use benefit'
        'M365EDU_A3_STUUSEBNFT_RPA1' = 'Microsoft 365 A3 - Unattended License for students use benefit'
        'M365EDU_A5_FACULTY' = 'Microsoft 365 A5 for faculty'
        'M365EDU_A5_NOPSTNCONF_STUUSEBNFT' = 'Microsoft 365 A5 without Audio Conferencing for students use benefit'
        'M365EDU_A5_STUDENT' = 'Microsoft 365 A5 for Students'
        'M365EDU_A5_STUUSEBNFT' = 'Microsoft 365 A5 for students use benefit'
        'M365_A5_SUITE_COMPONENTS_FACULTY' = 'Microsoft 365 A5 Suite features for faculty'
        'M365_COPILOT' = 'Microsoft Copilot for Microsoft 365'
        'M365_E5_SUITE_COMPONENTS' = 'Microsoft 365 E5 Suite features'
        'M365_F1' = 'Microsoft 365 F1'
        'M365_F1_COMM' = 'Microsoft 365 F1'
        'M365_F1_GOV' = 'Microsoft 365 F3 GCC'
        'M365_G3_GOV' = 'Microsoft 365 G3 GCC'
        'M365_G3_RPA1_GOV' = 'Microsoft 365 G3 - Unattended License for GCC'
        'M365_G5_GCC' = 'Microsoft 365 GCC G5'
        'M365_G5_GOV' = 'Microsoft 365 GCC G5 w/o WDATP/CAS Unified'
        'M365_SECURITY_COMPLIANCE_FOR_FLW' = 'Microsoft 365 Security and Compliance for Firstline Workers'
        'M365_TEAMS_PREMIUM' = 'Microsoft Teams Premium'
        'MCOACBYOT_AR_GCCHIGH_USGOV_GCCHIGH' = 'Microsoft 365 Audio Conferencing - GCCHigh Tenant (AR)_USGOV_GCCHIGH'
        'MCOCAP' = 'Microsoft Teams Shared Devices'
        'MCOCAP_GOV' = 'Microsoft Teams Shared Devices for GCC'
        'MCOEV' = 'Microsoft Teams Phone Standard'
        'MCOEVSMB_1' = 'Microsoft Teams Phone Standard for Small and Medium Business'
        'MCOEV_DOD' = 'Microsoft Teams Phone Standard for DOD'
        'MCOEV_FACULTY' = 'Microsoft Teams Phone Standard for Faculty'
        'MCOEV_GCCHIGH' = 'Microsoft Teams Phone Standard for GCCHIGH'
        'MCOEV_GOV' = 'Microsoft Teams Phone Standard for GCC'
        'MCOEV_STUDENT' = 'Microsoft Teams Phone Standard for Students'
        'MCOEV_TELSTRA' = 'Microsoft Teams Phone Standard for TELSTRA'
        'MCOEV_USGOV_DOD' = 'Microsoft Teams Phone Standard_USGOV_DOD'
        'MCOEV_USGOV_GCCHIGH' = 'Microsoft Teams Phone Standard_USGOV_GCCHIGH'
        'MCOIMP' = 'Skype for Business Online (Plan 1)'
        'MCOMEETACPEA' = 'Microsoft 365 Audio Conferencing Pay-Per-Minute - EA'
        'MCOMEETADV' = 'Microsoft 365 Audio Conferencing'
        'MCOMEETADV_FACULTY' = 'Microsoft 365 Audio Conferencing for faculty'
        'MCOMEETADV_GOV' = 'Microsoft 365 Audio Conferencing for GCC'
        'MCOMEETADV_USGOV_GCCHIGH' = 'Microsoft 365 Audio Conferencing_USGOV_GCCHIGH'
        'MCOPSTN1' = 'Skype for Business PSTN Domestic Calling'
        'MCOPSTN2' = 'Skype for Business PSTN Domestic and International Calling'
        'MCOPSTN5' = 'Skype for Business PSTN Calling Domestic Small'
        'MCOPSTN5_US' = 'Microsoft 365 Domestic Calling Plan (120 minutes) - US'
        'MCOPSTNC' = 'Communications Credits'
        'MCOPSTNEAU2' = 'TELSTRA Calling for O365'
        'MCOPSTNPP' = 'Skype for Business PSTN Usage Calling Plan'
        'MCOPSTN_1_GOV' = 'Microsoft Teams Domestic Calling Plan for GCC'
        'MCOPSTN_5' = 'Microsoft 365 Domestic Calling Plan (120 min)'
        'MCOPSTN_6' = 'Microsoft Teams Domestic Calling Plan (240 min)'
        'MCOSTANDARD' = 'Skype for Business Online (Plan 2)'
        'MCOTEAMS_ESSENTIALS' = 'Teams Phone with Calling Plan'
        'MDATP_SERVER' = 'Microsoft Defender for Endpoint Server'
        'MDATP_XPLAT' = 'Microsoft Defender for Endpoint P2_XPLAT'
        'MDE_SMB' = 'Microsoft Defender for Business'
        'MEETING_ROOM' = 'Microsoft Teams Rooms Standard'
        'MEETING_ROOM_GOV' = 'Microsoft Teams Rooms Standard for GCC'
        'MEETING_ROOM_GOV_NOAUDIOCONF' = 'Microsoft Teams Rooms Standard for GCC without Audio Conferencing'
        'MEETING_ROOM_NOAUDIOCONF' = 'Microsoft Teams Rooms Standard without Audio Conferencing'
        'MEE_FACULTY' = 'Minecraft Education Faculty'
        'MEE_STUDENT' = 'Minecraft Education Student'
        'MESSAGING_GCC_TEST' = 'Digital Messaging for GCC Test SKU'
        'MFA_STANDALONE' = 'Microsoft Azure Multi-Factor Authentication'
        'MICROSOFT365_LIGHTHOUSE' = 'Microsoft 365 Lighthouse'
        'MICROSOFT_365_BUSINESS_STANDARD_NO_TEAMS' = 'Microsoft 365 Business Standard (no Teams)'
        'MICROSOFT_365_COPILOT' = 'Microsoft Copilot for Microsoft 365'
        'MICROSOFT_365_COPILOT_EDU' = 'Microsoft 365 Copilot (Education Faculty)'
        'MICROSOFT_365_E3' = 'Microsoft 365 E3 (500 seats min)_HUB'
        'MICROSOFT_365_E3_EXTRA_FEATURES' = 'Microsoft 365 E3 Extra Features'
        'MICROSOFT_365_E5' = 'Microsoft 365 E5 (500 seats min)_HUB'
        'MICROSOFT_365_E5_WITHOUT_AUDIO_CONFERENCING' = 'Microsoft 365 E5 without Audio Conferencing (500 seats min)_HUB'
        'MICROSOFT_365_E7' = 'Microsoft 365 E7'
        'MICROSOFT_BUSINESS_CENTER' = 'Microsoft Business Center'
        'MICROSOFT_CLOUD_APP_SECURITY_APP_GOVERNANCE_ADD_ON' = 'App governance add-on to Microsoft Defender for Cloud Apps'
        'MICROSOFT_CLOUD_FOR_SUSTAINABILITY_USL' = 'Microsoft Sustainability Manager USL Essentials'
        'MICROSOFT_CLOUD_FOR_SUSTAINABILITY_VTRIAL' = 'Microsoft Cloud for Sustainability vTrial'
        'MICROSOFT_COPILOT_FOR_FINANCE_TRIAL' = 'Microsoft 365 Copilot for Finance (Preview)'
        'MICROSOFT_COPILOT_FOR_SALES' = 'Microsoft 365 Copilot for Sales'
        'MICROSOFT_DEFENDER_FOR_ENDPOINT_F2' = 'Microsoft Defender for Endpoint F2'
        'MICROSOFT_ENTRA_ID_GOVERNANCE' = 'Microsoft Entra ID Governance'
        'MICROSOFT_ENTRA_SUITE_STEP_UP_FOR_MICROSOFT_ENTRA_ID_P2' = 'Microsoft Entra Suite Add-on for Microsoft Entra ID P2'
        'MICROSOFT_INTUNE_ADVANCED_ANALYTICS' = 'Microsoft Intune Advanced Analytics'
        'MICROSOFT_INTUNE_SUITE' = 'Microsoft Intune Suite'
        'MICROSOFT_REMOTE_ASSIST' = 'Dynamics 365 Remote Assist'
        'MICROSOFT_REMOTE_ASSIST_HOLOLENS' = 'Dynamics 365 Remote Assist HoloLens'
        'MICROSOFT_SUSTAINABILITY_MANAGER_PREMIUM' = 'Microsoft Sustainability Manager Premium'
        'MICROSOFT_SUSTAINABILITY_MANAGER_PREMIUM_USL_ADDON' = 'Microsoft Sustainability Manager Premium USL Plus'
        'MICROSOFT_TEAMS_AUDIO_CONFERENCING_SELECT_DIAL_OUT' = 'Microsoft Teams Audio Conferencing with dial-out to USA/CAN'
        'MICROSOFT_TEAMS_EEA_NEW' = 'Microsoft Teams EEA'
        'MICROSOFT_TEAMS_ENTERPRISE_NEW' = 'Microsoft Teams Enterprise'
        'MICROSOFT_TEAMS_EXPLORATORY_DEPT' = 'Microsoft Teams Exploratory Dept'
        'MICROSOFT_TEAMS_PREMIUM' = 'Microsoft Teams Premium Introductory Pricing'
        'MICROSOFT_TEAMS_ROOMS_BASIC' = 'Microsoft Teams Rooms Basic'
        'MICROSOFT_TEAMS_ROOMS_BASIC_FAC' = 'Microsoft Teams Rooms Basic for EDU'
        'MICROSOFT_TEAMS_ROOMS_BASIC_WITHOUT_AUDIO_CONFERENCING' = 'Microsoft Teams Rooms Basic without Audio Conferencing'
        'MICROSOFT_TEAMS_ROOMS_PRO' = 'Microsoft Teams Rooms Pro'
        'MICROSOFT_TEAMS_ROOMS_PRO_FAC' = 'Microsoft Teams Rooms Pro for EDU'
        'MICROSOFT_TEAMS_ROOMS_PRO_GCC' = 'Microsoft Teams Rooms Pro for GCC'
        'MICROSOFT_TEAMS_ROOMS_PRO_WITHOUT_AUDIO_CONFERENCING' = 'Microsoft Teams Rooms Pro without Audio Conferencing'
        'MICROSOFT_VIVA_GOALS' = 'Microsoft Viva Goals'
        'MICROSOFT_VIVA_SALES' = 'Microsoft Sales Copilot'
        'MIDSIZEPACK' = 'Office 365 Midsize Business'
        'MS_TEAMS_IW' = 'Microsoft Teams Trial'
        'MTR_PREM' = 'Teams Rooms Premium'
        'NONPROFIT_PORTAL' = 'Nonprofit Portal'
        'O365_BUSINESS' = 'Microsoft 365 Apps for Business'
        'O365_BUSINESS_ESSENTIALS' = 'Microsoft 365 Business Basic'
        'O365_BUSINESS_PREMIUM' = 'Microsoft 365 Business Standard'
        'OFFICE365_MULTIGEO' = 'Office 365 Multi-Geo Capabilities'
        'OFFICEBASIC' = 'Basic Collaboration'
        'OFFICEMOBILE_SUBSCRIPTION_GOV_TEST' = 'Office Mobile Apps for Office 365 for GCC'
        'OFFICESUBSCRIPTION' = 'Microsoft 365 Apps for Enterprise'
        'OFFICESUBSCRIPTION_FACULTY' = 'Microsoft 365 Apps for Faculty'
        'OFFICESUBSCRIPTION_STUDENT' = 'Microsoft 365 Apps for Students'
        'OFFICE_PROPLUS_DEVICE1' = 'Microsoft 365 Apps for enterprise (device)'
        'OPERATOR_CONNECT_MOBILE' = 'Teams Phone Mobile'
        'PBI_PREMIUM_EM1_ADDON' = 'Power BI Premium EM1'
        'PBI_PREMIUM_EM2_ADDON' = 'Power BI Premium EM2'
        'PBI_PREMIUM_P1_ADDON' = 'Power BI Premium P1'
        'PBI_PREMIUM_P1_ADDON_GCC' = 'Power BI Premium P1 GCC'
        'PBI_PREMIUM_PER_USER' = 'Power BI Premium Per User'
        'PBI_PREMIUM_PER_USER_ADDON' = 'Power BI Premium Per User Add-On'
        'PBI_PREMIUM_PER_USER_ADDON_CE_GCC' = 'Power BI Premium Per User Add-On for GCC'
        'PBI_PREMIUM_PER_USER_ADDON_FACULTY' = 'Power BI Premium Per User Add-On for Faculty'
        'PBI_PREMIUM_PER_USER_ADDON_GCC' = 'Power BI Premium Per User Add-On for GCC'
        'PBI_PREMIUM_PER_USER_DEPT' = 'Power BI Premium Per User Dept'
        'PBI_PREMIUM_PER_USER_FACULTY' = 'Power BI Premium Per User for Faculty'
        'PBI_PREMIUM_PER_USER_GCC' = 'Power BI Premium Per User for Government'
        'PHONESYSTEM_VIRTUALUSER' = 'Microsoft Teams Phone Resource Account'
        'PHONESYSTEM_VIRTUALUSER_FACULTY' = 'Microsoft Teams Phone Resource Account for Faculty'
        'PHONESYSTEM_VIRTUALUSER_GOV' = 'Microsoft Teams Phone Resource Account for GCC'
        'POWERAPPS_DEV' = 'Microsoft Power Apps for Developer'
        'POWERAPPS_INDIVIDUAL_USER' = 'Power Apps and Logic Flows'
        'POWERAPPS_P1_GOV' = 'PowerApps Plan 1 for Government'
        'POWERAPPS_PER_APP' = 'Power Apps per app plan'
        'POWERAPPS_PER_APP_BD_ONLY_GCC' = 'Power Apps Per App BD Only for GCC'
        'POWERAPPS_PER_APP_GCC' = 'Power Apps per app plan for Government'
        'POWERAPPS_PER_APP_GCC_NEW' = 'Power Apps per app plan (1 app or website) for Government'
        'POWERAPPS_PER_APP_IW' = 'PowerApps per app baseline access'
        'POWERAPPS_PER_APP_NEW' = 'Power Apps per app plan (1 app or portal)'
        'POWERAPPS_PER_USER' = 'Power Apps Premium'
        'POWERAPPS_PER_USER_BD_ONLY' = 'Power Apps Per User BD Only'
        'POWERAPPS_PER_USER_GCC' = 'Power Apps Premium for Government'
        'POWERAPPS_PER_USER_ISVEMB' = 'Power Apps Premium embedded'
        'POWERAPPS_PORTALS_LOGIN_T2' = 'Power Apps Portals login capacity add-on Tier 2 (10 unit min)'
        'POWERAPPS_PORTALS_LOGIN_T2_GCC' = 'Power Apps Portals login capacity add-on Tier 2 (10 unit min) for Government'
        'POWERAPPS_PORTALS_LOGIN_T3' = 'Power Apps Portals login capacity add-on Tier 3 (50 unit min)'
        'POWERAPPS_PORTALS_PAGEVIEW' = 'Power Apps Portals page view capacity add-on'
        'POWERAPPS_PORTALS_PAGEVIEW_GCC' = 'Power Apps Portals page view capacity add-on for Government'
        'POWERAPPS_VIRAL' = 'Microsoft Power Apps Plan 2 Trial'
        'POWERAUTOMATE_ATTENDED_RPA' = 'Power Automate Premium'
        'POWERAUTOMATE_ATTENDED_RPA_GCC' = 'Power Automate Premium for Government'
        'POWERAUTOMATE_UNATTENDED_RPA' = 'Power Automate unattended RPA add-on'
        'POWERAUTOMATE_UNATTENDED_RPA_GCC' = 'Power Automate unattended RPA add-on for Government'
        'POWERBI_PRO_GOV' = 'Power BI Pro for GCC'
        'POWERFLOWGCC_TEST' = 'PowerApps & Flow GCC Test - O365 & Dyn365 Plans'
        'POWERFLOW_P2' = 'Microsoft Power Apps Plan 2 (Qualified Offer)'
        'POWER_AUTOMATE_PER_PROCESS' = 'Power Automate Process'
        'POWER_BI_ADDON' = 'Power BI for Office 365 Add-On'
        'POWER_BI_INDIVIDUAL_USER' = 'Power BI'
        'POWER_BI_PRO' = 'Power BI Pro'
        'POWER_BI_PRO_CE' = 'Power BI Pro CE'
        'POWER_BI_PRO_DEPT' = 'Power BI Pro Dept'
        'POWER_BI_PRO_FACULTY' = 'Power BI Pro for Faculty'
        'POWER_BI_STANDARD' = 'Microsoft Fabric (Free)'
        'POWER_BI_STANDARD_FACULTY' = 'Microsoft Fabric (Free) for faculty'
        'POWER_BI_STANDARD_STUDENT' = 'Microsoft Fabric (Free) for student'
        'POWER_PAGES_VTRIAL_FOR_MAKERS' = 'Power Pages vTrial for Makers'
        'POWER_VIRTUAL_AGENTS' = 'Microsoft Copilot Studio'
        'POWER_VIRTUAL_AGENTS_FOR_GCC_GCC' = 'Microsoft Copilot Studio for GCC'
        'POWER_VIRTUAL_AGENTS_USGOV_GCCHIGH' = 'Microsoft Copilot Studio_USGOV_GCCHIGH'
        'PRIVACY_MANAGEMENT_RISK' = 'Privacy Management – risk'
        'PRIVACY_MANAGEMENT_RISK_EDU' = 'Privacy Management - risk for EDU'
        'PRIVACY_MANAGEMENT_RISK_GCC' = 'Privacy Management - risk GCC'
        'PRIVACY_MANAGEMENT_RISK_USGOV_DOD' = 'Privacy Management - risk_USGOV_DOD'
        'PRIVACY_MANAGEMENT_RISK_USGOV_GCCHIGH' = 'Privacy Management - risk_USGOV_GCCHIGH'
        'PRIVACY_MANAGEMENT_SUB_RIGHTS_REQ_100_EDU_V2' = 'Privacy Management - subject rights request (100) for EDU'
        'PRIVACY_MANAGEMENT_SUB_RIGHTS_REQ_100_V2' = 'Privacy Management - subject rights request (100)'
        'PRIVACY_MANAGEMENT_SUB_RIGHTS_REQ_100_V2_GCC' = 'Privacy Management - subject rights request (100) GCC'
        'PRIVACY_MANAGEMENT_SUB_RIGHTS_REQ_100_V2_USGOV_DOD' = 'Privacy Management - subject rights request (100) USGOV_DOD'
        'PRIVACY_MANAGEMENT_SUB_RIGHTS_REQ_100_V2_USGOV_GCCHIGH' = 'Privacy Management - subject rights request (100) USGOV_GCCHIGH'
        'PRIVACY_MANAGEMENT_SUB_RIGHTS_REQ_10_EDU_V2' = 'Privacy Management - subject rights request (10) for EDU'
        'PRIVACY_MANAGEMENT_SUB_RIGHTS_REQ_10_V2' = 'Privacy Management - subject rights request (10)'
        'PRIVACY_MANAGEMENT_SUB_RIGHTS_REQ_10_V2_GCC' = 'Privacy Management - subject rights request (10) GCC'
        'PRIVACY_MANAGEMENT_SUB_RIGHTS_REQ_10_V2_USGOV_DOD' = 'Privacy Management - subject rights request (10) USGOV_DOD'
        'PRIVACY_MANAGEMENT_SUB_RIGHTS_REQ_10_V2_USGOV_GCCHIGH' = 'Privacy Management - subject rights request (10) USGOV_GCCHIGH'
        'PRIVACY_MANAGEMENT_SUB_RIGHTS_REQ_1_EDU_V2' = 'Privacy Management - subject rights request (1) for EDU'
        'PRIVACY_MANAGEMENT_SUB_RIGHTS_REQ_1_V2' = 'Privacy Management - subject rights request (1)'
        'PRIVACY_MANAGEMENT_SUB_RIGHTS_REQ_1_V2_GCC' = 'Privacy Management - subject rights request (1) GCC'
        'PRIVACY_MANAGEMENT_SUB_RIGHTS_REQ_1_V2_USGOV_DOD' = 'Privacy Management - subject rights request (1) USGOV_DOD'
        'PRIVACY_MANAGEMENT_SUB_RIGHTS_REQ_1_V2_USGOV_GCCHIGH' = 'Privacy Management - subject rights request (1) USGOV_GCCHIGH'
        'PRIVACY_MANAGEMENT_SUB_RIGHTS_REQ_50' = 'Privacy Management - subject rights request (50)'
        'PRIVACY_MANAGEMENT_SUB_RIGHTS_REQ_50_EDU_V2' = 'Privacy Management - subject rights request (50) for EDU'
        'PRIVACY_MANAGEMENT_SUB_RIGHTS_REQ_50_V2' = 'Privacy Management - subject rights request (50)'
        'PROJECTCLIENT' = 'Project for Office 365'
        'PROJECTESSENTIALS' = 'Project Online Essentials'
        'PROJECTESSENTIALS_FACULTY' = 'Project Online Essentials for Faculty'
        'PROJECTESSENTIALS_GOV' = 'Project Online Essentials for GCC'
        'PROJECTONLINE_PLAN_1' = 'Project Online Premium Without Project Client'
        'PROJECTONLINE_PLAN_1_FACULTY' = 'Project Plan 5 without Project Client for Faculty'
        'PROJECTONLINE_PLAN_2' = 'Project Online With Project for Office 365'
        'PROJECTPREMIUM' = 'Project Online Premium'
        'PROJECTPREMIUM_FACULTY' = 'Project Plan 5 for faculty'
        'PROJECTPREMIUM_GOV' = 'Project Plan 5 for GCC'
        'PROJECTPROFESSIONAL' = 'Planner and Project Plan 3'
        'PROJECTPROFESSIONAL_FACULTY' = 'Project Plan 3 for Faculty'
        'PROJECTPROFESSIONAL_GOV' = 'Project Plan 3 for GCC'
        'PROJECTPROFESSIONAL_USGOV_GCCHIGH' = 'Project Plan 3_USGOV_GCCHIGH'
        'PROJECT_MADEIRA_PREVIEW_IW_SKU' = 'Dynamics 365 Business Central for IWs'
        'PROJECT_P1' = 'Planner Plan 1'
        'PROJECT_PLAN1_DEPT' = 'Project Plan 1 (for Department)'
        'PROJECT_PLAN3_DEPT' = 'Project Plan 3 (for Department)'
        'PROJECT_PROFESSIONAL_TEST_GCC' = 'Project Plan 3 for GCC TEST'
        'RIGHTSMANAGEMENT' = 'Azure Information Protection Plan 1'
        'RIGHTSMANAGEMENT_ADHOC' = 'Rights Management Adhoc'
        'RIGHTSMANAGEMENT_CE' = 'Azure Information Protection Plan 1'
        'RIGHTSMANAGEMENT_CE_USGOV_GCCHIGH' = 'Azure Information Protection Premium P1_USGOV_GCCHIGH'
        'RMSBASIC' = 'Rights Management Service Basic Content Protection'
        'SHAREPOINTENTERPRISE' = 'SharePoint Online (Plan 2)'
        'SHAREPOINTSTANDARD' = 'SharePoint Online (Plan 1)'
        'SHAREPOINTSTORAGE' = 'Office 365 Extra File Storage'
        'SHAREPOINTSTORAGE_GOV' = 'Office 365 Extra File Storage for GCC'
        'SKU_DYNAMICS_365_FOR_HCM_TRIAL' = 'Dynamics 365 for Talent'
        'SMB_APPS' = 'Business Apps (free)'
        'SMB_BUSINESS' = 'Microsoft 365 Apps for Business'
        'SMB_BUSINESS_ESSENTIALS' = 'Microsoft 365 Business Basic'
        'SMB_BUSINESS_PREMIUM' = 'Microsoft 365 Business Standard - Prepaid Legacy'
        'SOCIAL_ENGAGEMENT_APP_USER' = 'Dynamics 365 AI for Market Insights (Preview)'
        'SPB' = 'Microsoft 365 Business Premium'
        'SPE_E3' = 'Microsoft 365 E3'
        'SPE_E3_RPA1' = 'Microsoft 365 E3 - Unattended License'
        'SPE_E3_USGOV_DOD' = 'Microsoft 365 E3_USGOV_DOD'
        'SPE_E3_USGOV_GCCHIGH' = 'Microsoft 365 E3_USGOV_GCCHIGH'
        'SPE_E5' = 'Microsoft 365 E5'
        'SPE_E5_CALLINGMINUTES' = 'Microsoft 365 E5 with Calling Minutes'
        'SPE_E5_NOPSTNCONF' = 'Microsoft 365 E5 without Audio Conferencing'
        'SPE_E5_USGOV_GCCHIGH' = 'Microsoft 365 E5_USGOV_GCCHIGH'
        'SPE_F1' = 'Microsoft 365 F3'
        'SPE_F5_COMP' = 'Microsoft 365 F5 Compliance Add-on'
        'SPE_F5_COMP_AR_D_USGOV_DOD' = 'Microsoft 365 F5 Compliance Add-on AR (DOD)_USGOV_DOD'
        'SPE_F5_COMP_AR_USGOV_GCCHIGH' = 'Microsoft 365 F5 Compliance Add-on AR_USGOV_GCCHIGH'
        'SPE_F5_COMP_GCC' = 'Microsoft 365 F5 Compliance Add-on GCC'
        'SPE_F5_SEC' = 'Microsoft 365 F5 Security Add-on'
        'SPE_F5_SECCOMP' = 'Microsoft 365 F5 Security + Compliance Add-on'
        'SPZA_IW' = 'App Connect IW'
        'STANDARDPACK' = 'Office 365 E1'
        'STANDARDPACK_GOV' = 'Office 365 G1 GCC'
        'STANDARDPACK_USGOV_GCCHIGH' = 'Office 365 E1_USGOV_GCCHIGH'
        'STANDARDWOFFPACK' = 'Office 365 E2'
        'STANDARDWOFFPACK_FACULTY' = 'Office 365 A1 for faculty'
        'STANDARDWOFFPACK_IW_FACULTY' = 'Office 365 A1 Plus for faculty'
        'STANDARDWOFFPACK_IW_STUDENT' = 'Office 365 A1 Plus for students'
        'STANDARDWOFFPACK_STUDENT' = 'Office 365 A1 for students'
        'STREAM' = 'Microsoft Stream'
        'STREAM_P2' = 'Microsoft Stream Plan 2'
        'STREAM_STORAGE' = 'Microsoft Stream Storage Add-On (500 GB)'
        'TEAMS_COMMERCIAL_TRIAL' = 'Microsoft Teams Commercial Cloud'
        'TEAMS_ESS' = 'Microsoft Teams Essentials'
        'TEAMS_ESSENTIALS_AAD' = 'Microsoft Teams Essentials (AAD Identity)'
        'TEAMS_EXPLORATORY' = 'Microsoft Teams Exploratory'
        'TEAMS_FREE' = 'Microsoft Teams (Free)'
        'TEAMS_PREMIUM_FOR_FACULTY' = 'Teams Premium for Faculty'
        'THREAT_INTELLIGENCE' = 'Microsoft Defender for Office 365 (Plan 2)'
        'THREAT_INTELLIGENCE_GOV' = 'Microsoft Defender for Office 365 (Plan 2) GCC'
        'TOPIC_EXPERIENCES' = 'Viva Topics'
        'TVM_PREMIUM_ADD_ON' = 'Microsoft Defender Vulnerability Management Add-on'
        'TVM_PREMIUM_STANDALONE' = 'Microsoft Defender Vulnerability Management'
        'UNIVERSAL_PRINT' = 'Universal Print'
        'VIDEO_INTEROP' = 'Skype Meeting Video Interop for Skype for Business'
        'VIRTUAL_AGENT_BASE' = 'Power Virtual Agent'
        'VIRTUAL_AGENT_BASE_GCC' = 'Power Virtual Agent for GCC'
        'VIRTUAL_AGENT_USL' = 'Microsoft Copilot Studio User License'
        'VIRTUAL_AGENT_USL_AR_USGOV_GCCHIGH' = 'Microsoft Copilot Studio User License for GCC High_USGOV_GCCHIGH'
        'VIRTUAL_AGENT_USL_GCC' = 'Microsoft Copilot Studio User License for GCC'
        'VISIOCLIENT' = 'Visio Plan 2'
        'VISIOCLIENT_FACULTY' = 'Visio Plan 2 for Faculty'
        'VISIOCLIENT_GOV' = 'Visio Plan 2 for GCC'
        'VISIOCLIENT_USGOV_GCCHIGH' = 'Visio Plan 2_USGOV_GCCHIGH'
        'VISIOONLINE_PLAN1' = 'Visio Plan 1'
        'VISIO_PLAN1_DEPT' = 'Visio Plan 1'
        'VISIO_PLAN2_DEPT' = 'Visio Plan 2'
        'VIVA' = 'Microsoft Viva Suite'
        'VIVA_GLINT_STANDALONE' = 'Microsoft Viva Glint'
        'VIVA_GOALS_USER_LED' = 'Viva Goals User-led'
        'VIVA_LEARNING' = 'Viva Learning'
        'WACONEDRIVEENTERPRISE' = 'OneDrive for Business (Plan 2)'
        'WACONEDRIVESTANDARD' = 'OneDrive for Business (Plan 1)'
        'WIN10_ENT_A3_FAC' = 'Windows 10/11 Enterprise A3 for faculty'
        'WIN10_ENT_A3_STU' = 'Windows 10/11 Enterprise A3 for students'
        'WIN10_ENT_A5_FAC' = 'Windows 10/11 Enterprise A5 for faculty'
        'WIN10_PRO_ENT_SUB' = 'Windows 10/11 Enterprise E3'
        'WIN10_VDA_E3' = 'Windows 10/11 Enterprise E3'
        'WIN10_VDA_E5' = 'Windows 10/11 Enterprise E5'
        'WINDOWS_365_S_2VCPU_4GB_128GB' = 'Windows 365 Shared Use 2 vCPU 4 GB 128 GB'
        'WINDOWS_365_S_2VCPU_4GB_256GB' = 'Windows 365 Shared Use 2 vCPU 4 GB 256 GB'
        'WINDOWS_365_S_2VCPU_4GB_64GB' = 'Windows 365 Shared Use 2 vCPU 4 GB 64 GB'
        'WINDOWS_365_S_2VCPU_8GB_128GB' = 'Windows 365 Shared Use 2 vCPU 8 GB 128 GB'
        'WINDOWS_365_S_2VCPU_8GB_256GB' = 'Windows 365 Shared Use 2 vCPU 8 GB 256 GB'
        'WINDOWS_365_S_4VCPU_16GB_128GB' = 'Windows 365 Shared Use 4 vCPU 16 GB 128 GB'
        'WINDOWS_365_S_4VCPU_16GB_256GB' = 'Windows 365 Shared Use 4 vCPU 16 GB 256 GB'
        'WINDOWS_365_S_4VCPU_16GB_512GB' = 'Windows 365 Shared Use 4 vCPU 16 GB 512 GB'
        'WINDOWS_365_S_8VCPU_32GB_128GB' = 'Windows 365 Shared Use 8 vCPU 32 GB 128 GB'
        'WINDOWS_365_S_8VCPU_32GB_256GB' = 'Windows 365 Shared Use 8 vCPU 32 GB 256 GB'
        'WINDOWS_365_S_8VCPU_32GB_512GB' = 'Windows 365 Shared Use 8 vCPU 32 GB 512 GB'
        'WINDOWS_STORE' = 'Windows Store for Business'
        'WINE5_GCC_COMPAT' = 'Windows 10/11 Enterprise E5 Commercial (GCC Compatible)'
        'WIN_DEF_ATP' = 'Microsoft Defender for Endpoint'
        'WIN_ENT_E5' = 'Windows 10/11 Enterprise E5 (Original)'
        'WORKLOAD_IDENTITIES_P2' = 'Microsoft Entra Workload ID'
        'WORKLOAD_IDENTITIES_PREMIUM_CN' = 'Workload Identities Premium'
        'WORKPLACE_ANALYTICS' = 'Microsoft Workplace Analytics'
        'WSFB_EDU_FACULTY' = 'Windows Store for Business EDU Faculty'
    }
    $uri = 'https://graph.microsoft.com/v1.0/subscribedSkus?$select=skuPartNumber,appliesTo,capabilityStatus,consumedUnits,prepaidUnits'
    $skus = @(Get-GraphPaged -Uri $uri)
    foreach ($sku in $skus) {
        if ([string]::IsNullOrWhiteSpace($sku.skuPartNumber) -or [string]::IsNullOrWhiteSpace($sku.appliesTo)) {
            throw 'License SKU identity or scope was missing.'
        }
        if ($sku.appliesTo -ne 'User') { continue }

        $enabled = 0L
        $assigned = 0L
        if (-not [long]::TryParse([string]$sku.prepaidUnits.enabled, [ref]$enabled) -or
            -not [long]::TryParse([string]$sku.consumedUnits, [ref]$assigned) -or
            $enabled -lt 0 -or $assigned -lt 0) {
            throw 'License seat counts were unavailable for one or more products.'
        }

        [pscustomobject]@{
            Product = if ($licenseNames.ContainsKey($sku.skuPartNumber)) { $licenseNames[$sku.skuPartNumber] } else { 'Product name unavailable' }
            Status = $sku.capabilityStatus
            Enabled = $enabled
            Assigned = $assigned
            Remaining = $enabled - $assigned
        }
    }
}

function Get-StaleLoginReview {
    param([int]$Days)

    # Graph pages containing signInActivity are limited to 500 users.
    $users = @(
        Get-GraphPaged `
            -Uri (
                "https://graph.microsoft.com/v1.0/users?" +
                "`$select=userPrincipalName,accountEnabled,userType,signInActivity" +
                "&`$top=500"
            )
    )

    $enabledMembers = @(
        $users |
        Where-Object {
            $_.accountEnabled -eq $true -and
            $_.userType -ne "Guest"
        }
    )

    $stale = @()
    $unavailable = @()
    $now = Get-Date

    foreach ($user in $enabledMembers) {
        $upn = [string]$user.userPrincipalName

        if (
            $user.signInActivity -and
            $user.signInActivity.lastSignInDateTime
        ) {
            try {
                $last = [datetime]$user.signInActivity.lastSignInDateTime
                $age = [int]($now - $last).TotalDays

                if ($age -ge $Days) {
                    $stale += [PSCustomObject]@{
                        UPN        = $upn
                        LastSignIn = $last.ToLocalTime()
                        Days       = $age
                    }
                }
            }
            catch {
                $unavailable += [PSCustomObject]@{
                    UPN    = $upn
                    Reason = "Sign-in timestamp could not be parsed"
                }
            }
        }
        else {
            $unavailable += [PSCustomObject]@{
                UPN    = $upn
                Reason = "No Entra sign-in activity returned"
            }
        }
    }

    return [PSCustomObject]@{
        Reviewed    = $enabledMembers.Count
        Stale       = @($stale)
        Unavailable = @($unavailable)
    }
}

function Get-AdminRoleReview {
    $rows = @()
    $gaps = @()

    $roles = @(
        Get-GraphPaged `
            -Uri "https://graph.microsoft.com/v1.0/directoryRoles?`$select=id,displayName"
    )

    foreach ($role in $roles) {
        try {
            $members = @(
                Get-GraphPaged `
                    -Uri (
                        "https://graph.microsoft.com/v1.0/directoryRoles/" +
                        "$($role.id)/members?`$select=displayName,userPrincipalName"
                    )
            )

            if ($members.Count -gt 0) {
                $rows += [PSCustomObject]@{
                    Role  = Clean-Name $role.displayName
                    Count = $members.Count
                }
            }
        }
        catch {
            $gaps += (
                "Admin role member lookup failed for " +
                "$(Clean-Name $role.displayName): $(Get-ShortError $_)"
            )
        }
    }

    return [PSCustomObject]@{
        Rows = @($rows)
        Gaps = @($gaps)
    }
}

function Test-GraphOwnerReviewSupported {
    param($Group)

    if ($Group.onPremisesSyncEnabled -eq $true) {
        return $false
    }

    $groupTypes = @($Group.groupTypes)

    if ($groupTypes -contains "Unified") {
        return $true
    }

    if (
        $Group.securityEnabled -eq $true -and
        $Group.mailEnabled -ne $true
    ) {
        return $true
    }

    return $false
}

function Get-OwnerlessGroupReview {
    $ownerless = @()
    $gaps = @()
    $skipped = 0

    $groups = @(
        Get-GraphPaged `
            -Uri (
                "https://graph.microsoft.com/v1.0/groups?" +
                "`$select=id,displayName,groupTypes,mailEnabled,securityEnabled,onPremisesSyncEnabled" +
                "&`$top=999"
            )
    )

    foreach ($group in $groups) {
        if (-not (Test-GraphOwnerReviewSupported -Group $group)) {
            $skipped++
            continue
        }

        try {
            $owners = Invoke-GraphGet `
                -Uri (
                    "https://graph.microsoft.com/v1.0/groups/" +
                    "$($group.id)/owners?`$select=id,displayName,userPrincipalName&`$top=1"
                )

            if ($null -eq $owners -or $null -eq $owners.value) {
                throw "Graph returned an incomplete owner response."
            }

            if (@($owners.value).Count -eq 0) {
                $ownerless += Clean-Name $group.displayName
            }
        }
        catch {
            $gaps += (
                "Group owner lookup failed for " +
                "$(Clean-Name $group.displayName): $(Get-ShortError $_)"
            )
        }
    }

    return [PSCustomObject]@{
        Ownerless = @($ownerless | Sort-Object -Unique)
        Skipped   = $skipped
        Gaps      = @($gaps)
    }
}

function Get-FriendlyForwardingDestination {
    param(
        $Mailbox,
        [System.Collections.Generic.List[string]]$Gaps
    )

    if ($Mailbox.ForwardingSmtpAddress) {
        return (
            ([string]$Mailbox.ForwardingSmtpAddress) -replace
            '^(?i)smtp:',
            ''
        ).Trim()
    }

    if ($Mailbox.ForwardingAddress) {
        try {
            $recipient = Get-Recipient `
                -Identity $Mailbox.ForwardingAddress `
                -ErrorAction Stop -WarningVariable +script:FKReportWarnings

            if ($recipient.PrimarySmtpAddress) {
                return [string]$recipient.PrimarySmtpAddress
            }

            if (
                $recipient.PSObject.Properties.Name -contains
                "ExternalEmailAddress" -and
                $recipient.ExternalEmailAddress
            ) {
                return (
                    ([string]$recipient.ExternalEmailAddress) -replace
                    '^(?i)smtp:',
                    ''
                ).Trim()
            }

            return [string]$recipient.DisplayName
        }
        catch {
            $Gaps.Add(
                "Forwarding destination could not be resolved for " +
                ([string]$Mailbox.UserPrincipalName)
            )

            return [string]$Mailbox.ForwardingAddress
        }
    }

    return ""
}

function Get-MailboxForwardingReview {
    $gaps = New-Object System.Collections.Generic.List[string]
    $rows = @()

    try {
        $acceptedDomains = @(
            Get-AcceptedDomain `
                -ResultSize Unlimited `
                -ErrorAction Stop
        )

        $internalDomains = @(
            $acceptedDomains |
            ForEach-Object {
                ([string]$_.DomainName).Trim().ToLowerInvariant()
            } |
            Where-Object { $_ } |
            Sort-Object -Unique
        )
    }
    catch {
        throw (
            "Accepted-domain enumeration failed: " +
            (Get-ShortError $_)
        )
    }

    try {
        $mailboxes = @(
            Get-Mailbox `
                -ResultSize Unlimited `
                -ErrorAction Stop -WarningVariable +script:FKReportWarnings
        )
    }
    catch {
        throw (
            "Mailbox enumeration failed: " +
            (Get-ShortError $_)
        )
    }

    foreach ($mailbox in $mailboxes) {
        if (
            -not $mailbox.ForwardingSmtpAddress -and
            -not $mailbox.ForwardingAddress
        ) {
            continue
        }

        $destination = Get-FriendlyForwardingDestination `
            -Mailbox $mailbox `
            -Gaps $gaps

        if ([string]::IsNullOrWhiteSpace($destination)) {
            $gaps.Add(
                "Forwarding destination was empty for " +
                ([string]$mailbox.UserPrincipalName)
            )
            continue
        }

        $external = $false
        $destinationDomain = ""

        if (
            $destination -match
            '(?i)([A-Z0-9._%+\-]+@([A-Z0-9.\-]+\.[A-Z]{2,}))'
        ) {
            $destination = $Matches[1]
            $destinationDomain = $Matches[2].ToLowerInvariant()

            if ($internalDomains -notcontains $destinationDomain) {
                $external = $true
            }
        }
        else {
            $gaps.Add(
                "Forwarding destination could not be classified as internal/external for " +
                ([string]$mailbox.UserPrincipalName) +
                ": " +
                $destination
            )
            continue
        }

        if (-not $external) {
            continue
        }

        $upn = [string]$mailbox.UserPrincipalName

        if ([string]::IsNullOrWhiteSpace($upn)) {
            $upn = [string]$mailbox.PrimarySmtpAddress
        }

        $rows += [PSCustomObject]@{
            UPN               = $upn
            Destination       = $destination
            DeliverAndForward = [bool]$mailbox.DeliverToMailboxAndForward
        }
    }

    return [PSCustomObject]@{
        Rows = @($rows)
        Gaps = @($gaps)
    }
}

try {
    Write-FKReportLine 'Review Account Cleanup'
    Write-FKReportLine 'Review accounts, mailbox access, and licenses for cleanup.'
    Write-FKReportLine "READ-ONLY. NO CHANGES MADE."
    Write-FKReportLine ""

    if (-not $TenantDomain -and (Get-Command Get-MgContext -ErrorAction SilentlyContinue)) {
        $activeGraph = Get-MgContext -ErrorAction SilentlyContinue
        if ($activeGraph -and $activeGraph.AuthType -eq 'Delegated' -and $activeGraph.Environment -eq 'Global' -and $activeGraph.Account) {
            try { $TenantDomain = (Get-GraphTenantInfo).DefaultDomain }
            catch { Write-Warn 'The active Graph session did not return a verified tenant domain.' }
        }
    }
    if (-not $TenantDomain -and -not $activeGraph -and (Get-Command Get-AcceptedDomain -ErrorAction SilentlyContinue)) {
        try {
            if (Get-ActiveExchangeConnection) {
                $defaultDomains = @(Get-AcceptedDomain -ResultSize Unlimited -ErrorAction Stop | Where-Object Default -eq $true)
                if ($defaultDomains.Count -eq 1) { $TenantDomain = [string]$defaultDomains[0].DomainName }
            }
        }
        catch { Write-Warn 'The active Exchange session did not provide one verified tenant domain.' }
    }
    if ([string]::IsNullOrWhiteSpace($TenantDomain)) {
        $TenantDomain = (Read-Host "Tenant domain").Trim()
    }

    if ([string]::IsNullOrWhiteSpace($TenantDomain)) {
        throw "Tenant domain is required."
    }

    $TenantDomain = $TenantDomain.ToLowerInvariant()

    $dataGaps = New-Object System.Collections.Generic.List[string]
    $graphAvailable = $false
    $exchangeAvailable = $false
    $tenant = $null

    try {
        $tenant = Connect-GraphAuto `
            -Scopes @(
                "User.Read.All",
                "Directory.Read.All",
                "AuditLog.Read.All",
                "Group.Read.All"
            ) `
            -TargetDomain $TenantDomain

        $graphAvailable = $true
    }
    catch {
        Write-Warn "Graph review unavailable"
        $dataGaps.Add(
            "Graph: $(Get-ShortError $_)"
        )
    }

    try {
        Connect-ExchangeAuto `
            -TargetDomain $TenantDomain

        $exchangeAvailable = $true
    }
    catch {
        Write-Warn "Exchange review unavailable"
        $dataGaps.Add(
            "Exchange: $(Get-ShortError $_)"
        )
    }

    Write-FKReportLine ""
    Write-Section "TENANT"

    if ($tenant) {
        Write-FKReportLine ("Name: {0}" -f $tenant.DisplayName)
    }
    else {
        Write-FKReportLine "Name: Not available"
    }

    Write-FKReportLine ("Domain: {0}" -f $TenantDomain)
    Write-FKReportLine ("Stale Threshold: {0} days" -f $StaleDays)

    $staleReview = $null
    $adminReview = $null
    $ownerReview = $null
    $forwardingReview = $null

    Write-FKReportLine ""
    Write-Section "STALE ENABLED USERS"

    if ($graphAvailable) {
        try {
            $staleReview = Get-StaleLoginReview `
                -Days $StaleDays

            if ($staleReview.Stale.Count -eq 0) {
                Write-FKReportLine "Status: No"
            }
            else {
                Write-FKReportLine (
                    "Status: Yes | {0} user(s)" -f
                    $staleReview.Stale.Count
                )

                foreach (
                    $row in
                    ($staleReview.Stale |
                        Sort-Object Days -Descending)
                ) {
                    Write-FKReportLine (
                        "{0} | Last Sign-In: {1} | Age: {2} days" -f
                        $row.UPN,
                        $row.LastSignIn.ToString("yyyy-MM-dd"),
                        $row.Days
                    )
                }
            }
        }
        catch {
            Write-FKReportLine "Status: Not available"
            $dataGaps.Add(
                "Stale users: $(Get-ShortError $_)"
            )
        }
    }
    else {
        Write-FKReportLine "Status: Not available"
    }

    Write-FKReportLine ""
    Write-Section "ACTIVITY NOT AVAILABLE"

    if ($staleReview) {
        if ($staleReview.Unavailable.Count -eq 0) {
            Write-FKReportLine "Status: No"
        }
        else {
            Write-FKReportLine (
                "Status: Yes | {0} user(s)" -f
                $staleReview.Unavailable.Count
            )

            foreach (
                $row in
                ($staleReview.Unavailable |
                    Sort-Object UPN)
            ) {
                Write-FKReportLine (
                    "{0} | {1}" -f
                    $row.UPN,
                    $row.Reason
                )
            }
        }
    }
    else {
        Write-FKReportLine "Status: Not available"
    }

    Write-FKReportLine ""
    Write-Section "ADMIN ROLES"

    if ($graphAvailable) {
        try {
            $adminReview = Get-AdminRoleReview

            if ($adminReview.Rows.Count -eq 0) {
                if ($adminReview.Gaps.Count -gt 0) { Write-FKReportLine "Status: Not available" }
                else { Write-FKReportLine "Status: No" }
            }
            else {
                Write-FKReportLine (
                    "Status: {0} active role(s)" -f
                    $adminReview.Rows.Count
                )

                foreach (
                    $row in
                    ($adminReview.Rows |
                        Sort-Object Role)
                ) {
                    Write-FKReportLine (
                        "Role: {0} | Members: {1}" -f
                        $row.Role,
                        $row.Count
                    )
                }
            }

            foreach ($gap in $adminReview.Gaps) {
                $dataGaps.Add($gap)
            }
        }
        catch {
            Write-FKReportLine "Status: Not available"
            $dataGaps.Add(
                "Admin roles: $(Get-ShortError $_)"
            )
        }
    }
    else {
        Write-FKReportLine "Status: Not available"
    }

    Write-FKReportLine ""
    Write-Section "OWNERLESS ENTRA GROUPS"

    if ($graphAvailable) {
        try {
            $ownerReview = Get-OwnerlessGroupReview

            if ($ownerReview.Ownerless.Count -eq 0) {
                Write-FKReportLine "Status: No"
            }
            else {
                Write-FKReportLine (
                    "Status: Yes | {0} group(s)" -f
                    $ownerReview.Ownerless.Count
                )

                foreach ($name in $ownerReview.Ownerless) {
                    Write-FKReportLine $name
                }
            }

            foreach ($gap in $ownerReview.Gaps) {
                $dataGaps.Add($gap)
            }
        }
        catch {
            Write-FKReportLine "Status: Not available"
            $dataGaps.Add(
                "Ownerless groups: $(Get-ShortError $_)"
            )
        }
    }
    else {
        Write-FKReportLine "Status: Not available"
    }

    Write-FKReportLine ""
    Write-Section "EXTERNAL MAILBOX FORWARDING"

    if ($exchangeAvailable) {
        try {
            $forwardingReview = Get-MailboxForwardingReview

            if ($forwardingReview.Rows.Count -eq 0) {
                Write-FKReportLine "Status: No"
            }
            else {
                Write-FKReportLine (
                    "Status: Yes | {0} mailbox(es)" -f
                    $forwardingReview.Rows.Count
                )

                foreach (
                    $row in
                    ($forwardingReview.Rows |
                        Sort-Object UPN)
                ) {
                    $copy = if ($row.DeliverAndForward) {
                        "Yes"
                    }
                    else {
                        "No"
                    }

                    Write-FKReportLine (
                        "{0} -> {1} | Deliver Copy: {2}" -f
                        $row.UPN,
                        $row.Destination,
                        $copy
                    )
                }
            }

            foreach ($gap in $forwardingReview.Gaps) {
                $dataGaps.Add($gap)
            }
        }
        catch {
            Write-FKReportLine "Status: Not available"
            $dataGaps.Add(
                "External forwarding: $(Get-ShortError $_)"
            )
        }
    }
    else {
        Write-FKReportLine "Status: Not available"
    }

    Write-FKReportLine ""
    Write-Section "LICENSE SEAT REVIEW"
    if ($graphAvailable) {
        try {
            $licenseRows = @(Get-LicenseSeatReview | Sort-Object Product)
            if ($licenseRows.Count -eq 0) {
                Write-FKReportLine "Status: No user license SKUs returned"
            }
            foreach ($row in $licenseRows) {
                Write-FKReportLine ("{0}: {1} enabled, {2} assigned, {3} remaining (enabled minus assigned). SKU status: {4}" -f $row.Product, $row.Enabled, $row.Assigned, $row.Remaining, $row.Status)
            }
        }
        catch {
            Write-FKReportLine "Status: Not available"
            $dataGaps.Add("License seat review: $(Get-ShortError $_)")
        }
    }
    else {
        Write-FKReportLine "Status: Not available"
    }

    Write-FKReportLine ""
    Write-Section "DATA GAPS"

    $uniqueDataGaps = @(
        $dataGaps |
        Select-Object -Unique
    )

    if ($uniqueDataGaps.Count -eq 0) {
        Write-FKReportLine "Status: No"
    }
    else {
        Write-FKReportLine "Status: Yes"

        foreach ($gap in $uniqueDataGaps) {
            Write-FKReportLine ("{0}" -f $gap)
        }
    }

    Write-FKReportLine ""
    Write-OK "Complete. No changes made."

}
catch {
    Write-FKReportLine ""
    Write-Fail (Get-ShortError $_)
}
finally {
    Offer-FKDesktopReport -Title 'GET-QUARTERLY-CLEANUP-REVIEW'

    Pause-End
}
