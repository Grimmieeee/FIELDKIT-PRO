# .VERSION 1.0.0
<#
.SYNOPSIS
Check forwarding, delegated access, and inbox rules, including hidden rules.
.DESCRIPTION
Read-only. Supply one or more mailboxes or a TXT/CSV path, or explicitly select tenant scope.
Use RulesOnly for an inbox-rule scan without forwarding or permission queries.
#>
param(
    [string[]]$UPN,
    [switch]$Tenant,
    [switch]$IncludeShared,
    [switch]$RulesOnly,
    [switch]$SuspiciousOnly
)
Write-Host 'GET-MAILBOX-RULES.ps1 // READ ONLY'
Write-Host ''
Write-Host 'Objective: Check forwarding, delegated access, and inbox rules, including hidden rules, for one mailbox, a list, or the full tenant.'
Write-Host ''

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

$script:FKDeferredLines = $null

function Write-FKReportLine {
    [CmdletBinding()]
    param(
        [Parameter(Position=0,ValueFromRemainingArguments=$true)][object[]]$Object,
        [object]$Separator=' ',[switch]$NoNewline,
        [ConsoleColor]$ForegroundColor,[ConsoleColor]$BackgroundColor
    )
    $line=($Object | ForEach-Object {[string]$_}) -join [string]$Separator
    if ($null -ne $script:FKDeferredLines) {
        $script:FKDeferredLines.Add(@{} + $PSBoundParameters)
        return
    }
    $script:FKReportLines.Add($line)
    Write-Host @PSBoundParameters
}

function Show-FKDeferredLines {
    $lines = $script:FKDeferredLines
    $script:FKDeferredLines = $null
    foreach ($line in $lines) { Write-FKReportLine @line }
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

function Write-OK   { param($m) Write-FKReportLine "[OK]   $m" -ForegroundColor Green }
function Write-Info { param($m) Write-FKReportLine "[INFO] $m" }
function Write-Warn { param($m) Write-FKReportLine "[WARN] $m" -ForegroundColor Yellow }
function Write-Fail { param($m) Write-FKReportLine "[FAIL] $m" -ForegroundColor Red }

function Write-Section {
    param([string]$Title)

    Write-FKReportLine ""
    try {
        Write-FKReportLine $Title `
            -ForegroundColor White `
            -BackgroundColor DarkGray
    }
    catch {
        Write-FKReportLine $Title
    }
}

function Pause-End {
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
        Read-Host 'Press ENTER to close.' | Out-Null
    }
}

function Get-ShortError {
    param($ErrorRecord)

    $Message = $ErrorRecord.Exception.Message

    if ([string]::IsNullOrWhiteSpace($Message)) {
        $Message = [string]$ErrorRecord
    }

    return (($Message -replace "\s+", " ").Trim())
}

function Ensure-Module {
    param([string]$Name)

    $module=Get-Module -ListAvailable -Name $Name -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if (-not $module) {
        throw "$Name is required but is not installed. Install with: Install-Module $Name -Scope CurrentUser"
    }

    Import-Module $module.Path -Force -ErrorAction Stop
}

function Test-AnyMailbox {
    param([string[]]$Mailboxes)

    foreach ($Mailbox in $Mailboxes) {
        try {
            Get-Mailbox `
                -Identity $Mailbox `
                -ErrorAction Stop -WarningVariable +script:FKReportWarnings |
                Out-Null

            return $true
        }
        catch {
        }
    }

    return $false
}

function Connect-ExchangeAuto {
    param([string[]]$ValidationMailboxes)

    Ensure-Module -Name "ExchangeOnlineManagement"

    $Connected = $false

    if (Get-Command Get-ConnectionInformation -ErrorAction SilentlyContinue) {
        $Connection = Get-ConnectionInformation -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if (
            $Connection -and
            (Test-AnyMailbox -Mailboxes $ValidationMailboxes)
        ) {
            $Connected = $true
        }
    }

    if ($Connected) {
        Write-OK "Exchange session reused"
        return
    }

    Write-FKReportLine "Exchange Online: Connecting..."

    $Command = Get-Command Connect-ExchangeOnline -ErrorAction Stop
    $Parameters = @{
        ErrorAction = "Stop"
    }

    if ($Command.Parameters.ContainsKey("ShowBanner")) {
        $Parameters["ShowBanner"] = $false
    }

    Connect-ExchangeOnline @Parameters | Out-Null

    if (-not (Test-AnyMailbox -Mailboxes $ValidationMailboxes)) {
        throw "Exchange connected, but none of the supplied mailboxes resolved in the connected tenant."
    }

    Write-OK "Exchange connected"
}

function Get-MailboxInputs {
    param([string[]]$Values)

    $items=New-Object System.Collections.ArrayList
    $rawValues=@($Values | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })

    if ($rawValues.Count -eq 0) {
        $entered=(Read-Host "Mailbox UPN(s) or TXT/CSV path").Trim().Trim('"')
        if ($entered) { $rawValues=@($entered) }
    }

    foreach ($value in $rawValues) {
        $clean=([string]$value).Trim().Trim('"')
        if (-not $clean) { continue }

        if (Test-Path -LiteralPath $clean -PathType Leaf) {
            if ([System.IO.Path]::GetExtension($clean) -ieq '.csv') {
                foreach ($row in @(Import-Csv -LiteralPath $clean -ErrorAction Stop)) {
                    $candidate=$null
                    foreach ($name in @('UPN','UserPrincipalName','Email','Address','Mailbox','Name','Input')) {
                        if ($row.PSObject.Properties.Name -contains $name -and $row.$name) {
                            $candidate=[string]$row.$name
                            break
                        }
                    }
                    if (-not $candidate) {
                        $first=$row.PSObject.Properties | Select-Object -First 1
                        if ($first) { $candidate=[string]$first.Value }
                    }
                    if ($candidate -and $candidate.Trim()) { [void]$items.Add($candidate.Trim().Trim('"')) }
                }
            }
            else {
                foreach ($line in @(Get-Content -LiteralPath $clean -Encoding UTF8 -ErrorAction Stop)) {
                    $candidate=([string]$line).Trim().Trim('"')
                    if ($candidate -and $candidate -notmatch '^#') { [void]$items.Add($candidate) }
                }
            }
            continue
        }

        foreach ($candidate in @($clean -split '\s*,\s*')) {
            if ($candidate) { [void]$items.Add($candidate.Trim()) }
        }
    }

    return @($items | Where-Object { $_ } | Select-Object -Unique)
}

function Clean-Name {
    param($Name)

    if ($null -eq $Name) {
        return ""
    }

    return (
        [string]$Name -replace
        '\s*\([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\)\s*$',
        ''
    ).Trim()
}

function Rule-Detail {
    param($Rule)

    $Parts = @()

    foreach ($Property in @(
        "ForwardTo",
        "RedirectTo",
        "ForwardAsAttachmentTo",
        "DeleteMessage",
        "MoveToFolder",
        "CopyToFolder",
        "StopProcessingRules"
    )) {
        $Value = $Rule.$Property

        if ($null -ne $Value -and "$Value" -ne "") {
            if ($Value -is [array]) {
                $Parts += "$Property=$($Value -join ', ')"
            }
            else {
                $Parts += "$Property=$Value"
            }
        }
    }

    if ($Parts.Count -eq 0) {
        return "No high-risk action displayed"
    }

    return ($Parts -join "; ")
}

function Write-QueryFailure {
    param(
        [string]$Label,
        [string]$Message
    )

    $script:FKUnavailableChecks.Add($Label)
    Write-FKReportLine "Status : Not available"
    Write-Warn "$Label query failed: $Message"
}

function Is-SystemRule {
    param([string]$RuleName)

    if (-not $RuleName) { return $true }
    if ($RuleName -eq "Junk E-mail Rule") { return $true }
    if ($RuleName -like "Microsoft.Exchange.*") { return $true }
    if ($RuleName -like "Microsoft Outlook*") { return $true }
    if ($RuleName -like "Outlook Rules Organizer*") { return $true }
    return $false
}

function Get-RuleRisk {
    param($Rule)

    $flags = @()
    if ($Rule.ForwardTo) { $flags += "ForwardTo" }
    if ($Rule.RedirectTo) { $flags += "RedirectTo" }
    if ($Rule.ForwardAsAttachmentTo) { $flags += "ForwardAsAttachmentTo" }
    if ($Rule.DeleteMessage) { $flags += "DeleteMessage" }
    if ($Rule.PermanentDelete) { $flags += "PermanentDelete" }
    if ($Rule.MoveToFolder -match "Deleted|Junk|Trash") { $flags += "MoveToFolder" }
    if ($Rule.IsHidden) { $flags += "Hidden" }

    if ($flags.Count -eq 0) { return "Review" }
    return ($flags -join ", ")
}
function Resolve-ForwardingAddress {
    param($ForwardingAddress)

    if (-not $ForwardingAddress) { return '' }

    try {
        $recipient=Get-Recipient -Identity $ForwardingAddress -ErrorAction Stop
        if ($recipient.PrimarySmtpAddress) { return [string]$recipient.PrimarySmtpAddress }
        if ($recipient.DisplayName) { return [string]$recipient.DisplayName }
    }
    catch {}

    return [string]$ForwardingAddress
}

function Convert-RuleTargets {
    param($Targets)

    return (
        @($Targets) |
        ForEach-Object { [string]$_ } |
        Where-Object { $_ } |
        Sort-Object -Unique
    ) -join '; '
}


function Export-MailboxRulesCsv {
    param([object[]]$Rows,[string]$Name)
    if (-not $Rows.Count -or (Read-Host "Export $Name CSV? [y/N]") -notmatch '^(?:y|yes)$') { return }
    $path=Get-FKDesktopExportPath -DefaultName ("{0}-{1}.csv" -f $Name,(Get-Date -Format 'yyyyMMdd-HHmmssfff'))
    $Rows | Export-Csv -LiteralPath $path -NoTypeInformation -Encoding UTF8 -NoClobber -ErrorAction Stop
    $actual=@(Import-Csv -LiteralPath $path -ErrorAction Stop)
    if ($actual.Count -ne $Rows.Count) { throw 'CSV row count did not match.' }
    for ($i=0;$i -lt $Rows.Count;$i++) {
        foreach ($property in $Rows[$i].PSObject.Properties) {
            if ([string]$actual[$i].($property.Name) -cne [string]$property.Value) {
                throw "CSV readback did not match row $($i+1), column $($property.Name)."
            }
        }
    }
    Write-OK "Exported and verified: $path"
}

try {
    Write-FKReportLine 'Get Mailbox Rules'
    Write-FKReportLine 'Check forwarding, delegated access, and inbox rules, including hidden rules.'
    Write-FKReportLine "READ-ONLY. NO CHANGES MADE."
    Write-FKReportLine ""

    if ($Tenant -and $UPN) { throw 'Choose tenant scope or mailbox inputs.' }
    if ($IncludeShared -and -not $Tenant) { throw 'IncludeShared applies only to tenant scope.' }
    if ($Tenant) {
        Ensure-Module -Name 'ExchangeOnlineManagement'
        $connections=@(Get-ConnectionInformation -ErrorAction Stop | Where-Object State -eq 'Connected')
        if (-not $connections.Count) {
            Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop | Out-Null
            $connections=@(Get-ConnectionInformation -ErrorAction Stop | Where-Object State -eq 'Connected')
        }
        if ($connections.Count -ne 1) { throw 'Tenant scope requires exactly one active Exchange Online connection.' }
        $client=[string]$connections[0].TenantID
        if (-not $client) { $client=[string]$connections[0].Organization }
        if (-not $client) { throw 'The connected Exchange tenant could not be identified.' }
        Write-FKReportLine "Exchange tenant: $client | Account: $($connections[0].UserPrincipalName)"
        if ((Read-Host 'Scan this tenant? [y/N]') -notmatch '^(?:y|yes)$') { return }
        $types=@('UserMailbox')
        if ($IncludeShared) { $types+='SharedMailbox' }
        $UPN=@(Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails $types -ErrorAction Stop |
            ForEach-Object { [string]$_.PrimarySmtpAddress } | Where-Object { $_ } | Sort-Object -Unique)
    }
    else {
        $UPN=@(Get-MailboxInputs -Values $UPN)
        if (-not $UPN.Count) { throw 'At least one mailbox address is required.' }
        Connect-ExchangeAuto -ValidationMailboxes $UPN
    }

    $ruleRows=New-Object 'Collections.Generic.List[object]'
    $forwardRows=New-Object 'Collections.Generic.List[object]'
    Write-Section 'TARGET'
    Write-FKReportLine ("Mailboxes requested: {0}" -f $UPN.Count)
    if ($RulesOnly) { Write-FKReportLine "Mode: Inbox rules only" }
    $script:FKUnavailableChecks = New-Object 'Collections.Generic.List[string]'
    $script:FKDeferredLines = New-Object 'Collections.Generic.List[hashtable]'
    $mailboxResults = New-Object 'Collections.Generic.List[string]'

    foreach ($MailboxUPN in $UPN) {
        $script:FKUnavailableChecks.Clear()
        $findings = @()
        $forwardStart=$forwardRows.Count
        $ruleStart=$ruleRows.Count
        Write-FKReportLine ""
        Write-FKReportLine ("MAILBOX: {0}" -f $MailboxUPN)

        try {
            $Mailbox = Get-Mailbox `
                -Identity $MailboxUPN `
                -ErrorAction Stop -WarningVariable +script:FKReportWarnings
        }
        catch {
            $mailboxResults.Add("${MailboxUPN}: Failed (mailbox lookup)")
            $forwardRows.Add([pscustomobject]@{Mailbox=$MailboxUPN;Type='Mailbox';Name='';Target='';Enabled='';Status='Failed: '+(Get-ShortError $_);DeliverToMailboxAndForward=''})
            $ruleRows.Add([pscustomobject]@{Mailbox=$MailboxUPN;RuleName='';Enabled='';Priority='';Risk='';ForwardTo='';RedirectTo='';ForwardAsAttachmentTo='';MoveToFolder='';Hidden='';Status='Mailbox lookup failed';Coverage='Unavailable'})
            Write-Warn "Mailbox lookup failed: $(Get-ShortError $_)"
            continue
        }

        if (-not $RulesOnly) {
            Write-Section "FORWARDING"

            $Forwarding = @()
            foreach ($property in 'ForwardingAddress','ForwardingSmtpAddress') {
                if ($Mailbox.$property) {
                    $forwardRows.Add([pscustomobject]@{Mailbox=$MailboxUPN;Type='MailboxForwarding';Name=$property;Target=if($property -eq 'ForwardingAddress'){Resolve-ForwardingAddress $Mailbox.$property}else{[string]$Mailbox.$property};Enabled=$true;Status='Found';DeliverToMailboxAndForward=$Mailbox.DeliverToMailboxAndForward})
                }
            }

            if ($Mailbox.ForwardingSmtpAddress) {
                $Forwarding += "SMTP: $($Mailbox.ForwardingSmtpAddress)"
            }

            if ($Mailbox.ForwardingAddress) {
                $Forwarding += "Recipient: $($Mailbox.ForwardingAddress)"
            }

            if ($Mailbox.DeliverToMailboxAndForward) {
                $Forwarding += "DeliverToMailboxAndForward: True"
            }

            if ($Forwarding.Count -gt 0) { $findings += 'Forwarding' }
            if ($Forwarding.Count -eq 0) {
                Write-FKReportLine "None found"
            }
            else {
                $Forwarding | ForEach-Object {
                    Write-FKReportLine "$_"
                }
            }

            Write-Section "FULL ACCESS"

            try {
                $FullAccess = @(
                    Get-MailboxPermission `
                        -Identity $Mailbox.Identity `
                        -ErrorAction Stop -WarningVariable +script:FKReportWarnings |
                    Where-Object {
                        $_.User -ne "NT AUTHORITY\SELF" -and
                        $_.IsInherited -eq $false -and
                        $_.AccessRights -contains "FullAccess"
                    }
                )

                if ($FullAccess.Count -gt 0) { $findings += 'Full Access' }
                if ($FullAccess.Count -eq 0) {
                    Write-FKReportLine "None found"
                }
                else {
                    $FullAccess | ForEach-Object {
                        Write-FKReportLine ("{0}" -f $_.User)
                    }
                }
            }
            catch {
                Write-QueryFailure `
                    -Label "Full Access" `
                    -Message (Get-ShortError $_)
            }

            Write-Section "SEND AS"

            try {
                $SendAs = @(
                    Get-RecipientPermission `
                        -Identity $Mailbox.Identity `
                        -ErrorAction Stop -WarningVariable +script:FKReportWarnings |
                    Where-Object {
                        $_.Trustee -ne "NT AUTHORITY\SELF" -and
                        $_.AccessRights -contains "SendAs"
                    }
                )

                if ($SendAs.Count -gt 0) { $findings += 'Send As' }
                if ($SendAs.Count -eq 0) {
                    Write-FKReportLine "None found"
                }
                else {
                    $SendAs | ForEach-Object {
                        Write-FKReportLine ("{0}" -f $_.Trustee)
                    }
                }
            }
            catch {
                Write-QueryFailure `
                    -Label "Send As" `
                    -Message (Get-ShortError $_)
            }

            Write-Section "SEND ON BEHALF"

            try {
                $SendOnBehalf = @($Mailbox.GrantSendOnBehalfTo)

                if ($SendOnBehalf.Count -gt 0) { $findings += 'Send on Behalf' }
                if ($SendOnBehalf.Count -eq 0) {
                    Write-FKReportLine "None found"
                }
                else {
                    foreach ($Delegate in $SendOnBehalf) {
                        try {
                            $Recipient = Get-Recipient `
                                -Identity $Delegate `
                                -ErrorAction Stop -WarningVariable +script:FKReportWarnings

                            if ($Recipient.PrimarySmtpAddress) {
                                Write-FKReportLine (
                                    "  - {0} <{1}>" -f
                                    $Recipient.DisplayName,
                                    $Recipient.PrimarySmtpAddress
                                )
                            }
                            else {
                                Write-FKReportLine ("{0}" -f $Recipient.DisplayName)
                            }
                        }
                        catch {
                            Write-Warn "A Send On Behalf delegate was returned but its friendly name could not be resolved."
                        }
                    }
                }
            }
            catch {
                Write-QueryFailure `
                    -Label "Send On Behalf" `
                    -Message (Get-ShortError $_)
            }

        }

        Write-Section "INBOX RULES"

        $RulesAvailable = $true
        $Rules = @()
        $RuleError = ""

        try {
            $Rules = @(
                Get-InboxRule `
                    -Mailbox $Mailbox.Identity `
                    -IncludeHidden `
                    -ErrorAction Stop -WarningVariable +script:FKReportWarnings
            )
        }
        catch {
            try {
                $Rules = @(
                    Get-InboxRule `
                        -Mailbox $Mailbox.Identity `
                        -ErrorAction Stop -WarningVariable +script:FKReportWarnings
                )

                $script:FKUnavailableChecks.Add('Hidden inbox rules')
                Write-Warn "Hidden-rule visibility is not available in this session."
            }
            catch {
                $RulesAvailable = $false
                $RuleError = Get-ShortError $_
            }
        }

        if (-not $RulesAvailable) {
            Write-QueryFailure `
                -Label "Inbox rules" `
                -Message $RuleError
        }
        elseif ($Rules.Count -eq 0) {
            Write-FKReportLine "None found"
        }
        else {
            foreach ($Rule in $Rules) {
                $name=Clean-Name $Rule.Name
                $risk=Get-RuleRisk $Rule
                $targets=@()
                foreach ($kind in 'ForwardTo','RedirectTo','ForwardAsAttachmentTo') {
                    if ($Rule.$kind) { $targets += "${kind}: $(Convert-RuleTargets $Rule.$kind)" }
                }
                if ($targets.Count) {
                    $forwardRows.Add([pscustomobject]@{Mailbox=$MailboxUPN;Type='InboxRule';Name=$name;Target=$targets -join ' | ';Enabled=$Rule.Enabled;Status='Found';DeliverToMailboxAndForward=''})
                }
                if ($Tenant -and (Is-SystemRule $name)) { continue }
                if ($SuspiciousOnly -and $risk -eq 'Review') { continue }
                $ruleRows.Add([pscustomobject]@{
                    Mailbox=$MailboxUPN;RuleName=$name;Enabled=$Rule.Enabled;Priority=$Rule.Priority;Risk=$risk
                    ForwardTo=$Rule.ForwardTo -join '; ';RedirectTo=$Rule.RedirectTo -join '; '
                    ForwardAsAttachmentTo=$Rule.ForwardAsAttachmentTo -join '; ';MoveToFolder=[string]$Rule.MoveToFolder
                    Hidden=[bool]$Rule.IsHidden;Status='Found';Coverage=if($script:FKUnavailableChecks.Contains('Hidden inbox rules')){'Visible only'}else{'Visible and hidden'}
                })
                $Hidden = ""

                if ($Rule.IsHidden) {
                    $Hidden = " [HIDDEN]"
                }

                Write-FKReportLine ("Rule: {0}{1}" -f (Clean-Name $Rule.Name), $Hidden)
                Write-FKReportLine ("Action: {0}" -f (Rule-Detail $Rule))
            }
        }
        if ($RulesAvailable -and $Rules.Count -gt 0) { $findings += 'Inbox rules' }
        $status = 'Complete'
        if ($script:FKUnavailableChecks.Count) { $status = 'Partial' }
        $findingText = if ($findings.Count) { $findings -join ', ' } else { 'None found in completed checks' }
        $coverage = if ($script:FKUnavailableChecks.Count) { '; not checked: ' + ($script:FKUnavailableChecks -join ', ') } else { '' }
        $mailboxResults.Add("${MailboxUPN}: $status; $findingText$coverage")
        if ($ruleRows.Count -eq $ruleStart) {
            $ruleRows.Add([pscustomobject]@{
                Mailbox=$MailboxUPN;RuleName='';Enabled='';Priority='';Risk='';ForwardTo='';RedirectTo=''
                ForwardAsAttachmentTo='';MoveToFolder='';Hidden=''
                Status=if(-not $RulesAvailable){'Not checked'}elseif($Rules.Count){'No rules matched filter'}else{'None found'}
                Coverage=if(-not $RulesAvailable){'Unavailable'}elseif($script:FKUnavailableChecks.Contains('Hidden inbox rules')){'Visible only'}else{'Visible and hidden'}
            })
        }
        if ($forwardRows.Count -eq $forwardStart -or $script:FKUnavailableChecks.Contains('Hidden inbox rules') -or -not $RulesAvailable) {
            $forwardRows.Add([pscustomobject]@{
                Mailbox=$MailboxUPN;Type='Summary';Name='';Target='';Enabled=''
                Status=if(-not $RulesAvailable){'Inbox rules not checked'}elseif($script:FKUnavailableChecks.Contains('Hidden inbox rules')){'Hidden inbox rules not checked'}elseif($RulesOnly){'No rule forwarding found; mailbox settings not checked'}else{'No forwarding found'}
                DeliverToMailboxAndForward=''
            })
        }
    }

    $details = $script:FKDeferredLines
    $script:FKDeferredLines = $null
    Write-Section 'RESULT'
    foreach ($result in $mailboxResults) { Write-FKReportLine $result }
    $script:FKDeferredLines = $details
    Show-FKDeferredLines
    try { Export-MailboxRulesCsv -Rows @($ruleRows.ToArray()) -Name 'mailbox-inbox-rules' }
    catch { Write-Warn ("Inbox-rule export failed: "+(Get-ShortError $_)) }
    try { Export-MailboxRulesCsv -Rows @($forwardRows.ToArray()) -Name 'mailbox-forwarding' }
    catch { Write-Warn ("Forwarding export failed: "+(Get-ShortError $_)) }
    Write-Section 'COMPLETED' 
    Write-FKReportLine ((Get-Date).ToString('yyyy-MM-dd HH:mm'))

}
catch {
    $message = Get-ShortError $_
    $details = $script:FKDeferredLines
    $script:FKDeferredLines = $null
    Write-Section 'RESULT'
    Write-FKReportLine 'Status: Failed'
    Write-Fail $message
    $script:FKDeferredLines = $details
    Show-FKDeferredLines
}
finally {
    Offer-FKDesktopReport -Title 'GET-MAILBOX-RULES'

    Pause-End
}