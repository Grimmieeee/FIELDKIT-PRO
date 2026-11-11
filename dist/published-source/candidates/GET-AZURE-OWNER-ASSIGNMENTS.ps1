#Requires -Version 5.1
# .VERSION 0.1.3
# OBJECTIVE: List visible built-in Owner assignments within one Azure subscription.
<#
.SYNOPSIS
List visible built-in Owner assignments within one Azure subscription.
.DESCRIPTION
Queries active Azure RBAC assignments at or below the selected subscription,
then matches the built-in Owner role by ID. Retains principal IDs, assignment
scope and any returned conditions. Does not enumerate inherited management-group
assignments, eligible PIM roles, group members, custom equivalent roles, deny
assignments or effective access. Missing display names are marked unavailable.
Uses the active Azure context or prompts for a tenant domain and subscription name. Azure public cloud only. Reuses a
matching Az context or signs in to the requested scope. Context changes and
context-autosave preference are process-scoped; the process may retain the login.
Does not install modules or modify Azure resources. Requires Az.Accounts and
Az.Resources with appropriate read permissions. CSV refuses existing files.
#>
[CmdletBinding()]
param([string]$TenantId,[string]$SubscriptionId,[string]$ExportPath,[switch]$NoPause,[switch]$PassThru,[string]$TenantDomain,[string]$SubscriptionName)
Write-Host "Azure Owner Assignments"
$ErrorActionPreference = 'Stop'
# Display-only formatter: keeps all selected columns and wraps complete values.
function Format-FkTable {
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline=$true)][object]$InputObject,[int]$Width=0)
    begin {
        $items=New-Object 'System.Collections.Generic.List[object]'
        function Convert-FkCell {
            param($Value)
            if ($null -eq $Value) { return '' }
            if ($Value -is [datetime]) { return $Value.ToString('yyyy-MM-dd HH:mm',[Globalization.CultureInfo]::InvariantCulture) }
            if ($Value -is [datetimeoffset]) { return $Value.ToString('yyyy-MM-dd HH:mm zzz',[Globalization.CultureInfo]::InvariantCulture) }
            $text=([string]$Value).Replace("`r`n","`n").Replace("`r","`n").Replace("`t",'    ')
            $text=$text -replace '\x1b\[[0-?]*[ -/]*[@-~]',''
            return ($text -replace '[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]','')
        }
        function Get-FkElementWidth {
            param([string]$Element)
            $cp=[char]::ConvertToUtf32($Element,0)
            $category=[Globalization.CharUnicodeInfo]::GetUnicodeCategory($Element,0)
            if ($category -in @([Globalization.UnicodeCategory]::NonSpacingMark,[Globalization.UnicodeCategory]::EnclosingMark,[Globalization.UnicodeCategory]::Format)) { return 0 }
            if ($cp -ge 0x1100 -and ($cp -le 0x115f -or $cp -eq 0x2329 -or $cp -eq 0x232a -or ($cp -ge 0x2e80 -and $cp -le 0xa4cf -and $cp -ne 0x303f) -or ($cp -ge 0xac00 -and $cp -le 0xd7a3) -or ($cp -ge 0xf900 -and $cp -le 0xfaff) -or ($cp -ge 0xfe10 -and $cp -le 0xfe19) -or ($cp -ge 0xfe30 -and $cp -le 0xfe6f) -or ($cp -ge 0xff00 -and $cp -le 0xff60) -or ($cp -ge 0xffe0 -and $cp -le 0xffe6) -or ($cp -ge 0x1f300 -and $cp -le 0x1faff) -or ($cp -ge 0x20000 -and $cp -le 0x3fffd))) { return 2 }
            return 1
        }
        function Get-FkCellWidth {
            param([string]$Text)
            $length=0
            $iterator=[Globalization.StringInfo]::GetTextElementEnumerator($Text)
            while ($iterator.MoveNext()) { $length+=Get-FkElementWidth $iterator.GetTextElement() }
            return $length
        }
        function Split-FkCell {
            param([string]$Text,[int]$Limit)
            foreach ($paragraph in $Text.Split([char]10)) {
                $buffer=[Text.StringBuilder]::new();$used=0
                $iterator=[Globalization.StringInfo]::GetTextElementEnumerator($paragraph)
                while ($iterator.MoveNext()) {
                    $element=$iterator.GetTextElement();$size=Get-FkElementWidth $element
                    if ($used+$size -gt $Limit -and $buffer.Length -gt 0) { $buffer.ToString();[void]$buffer.Clear();$used=0 }
                    [void]$buffer.Append($element);$used+=$size
                }
                $buffer.ToString()
            }
        }
    }
    process { if ($null -ne $InputObject) { $items.Add($InputObject) } }
    end {
        if ($items.Count -eq 0) { return }
        if ($Width -eq 0) {
            try { $Width=$Host.UI.RawUI.WindowSize.Width } catch { $Width=80 }
            if ($Width -lt 20) { $Width=80 }
        }
        if ($Width -lt 20 -or $Width -gt 500) { throw 'Display width must be 20 through 500.' }
        $headers=@($items[0].PSObject.Properties | ForEach-Object {$_.Name})
        if ($headers.Count -eq 0) { return }
        $values=New-Object 'System.Collections.Generic.List[object]'
        $sizes=New-Object 'System.Collections.Generic.List[int]'
        $desired=New-Object 'System.Collections.Generic.List[int]'
        foreach ($header in $headers) { $size=[math]::Max(3,(Get-FkCellWidth $header));$sizes.Add($size);$desired.Add($size) }
        foreach ($item in $items) {
            $cells=@(foreach ($header in $headers) { Convert-FkCell $item.PSObject.Properties[$header].Value })
            $values.Add($cells)
            for ($i=0;$i -lt $headers.Count;$i++) {
                foreach ($part in $cells[$i].Split([char]10)) { $desired[$i]=[math]::Max($desired[$i],(Get-FkCellWidth $part)) }
            }
        }
        $minimum=2*($headers.Count-1)
        foreach ($size in $sizes) { $minimum+=$size }
        $lines=New-Object 'System.Collections.Generic.List[string]'
        if ($minimum -gt $Width) {
            # Very narrow hosts use aligned labels rather than dropping columns.
            $labelWidth=0
            foreach ($header in $headers) { $labelWidth=[math]::Max($labelWidth,(Get-FkCellWidth $header)) }
            $labelWidth=[math]::Min($labelWidth,[math]::Max(3,[int]($Width/3)))
            foreach ($cells in $values) {
                for ($i=0;$i -lt $headers.Count;$i++) {
                    foreach ($label in @(Split-FkCell $headers[$i] $Width)) { $lines.Add($label) }
                    foreach ($part in @(Split-FkCell $cells[$i] ($Width-2))) { $lines.Add('  '+$part) }
                }
                $lines.Add('')
            }
            return $lines.ToArray()
        }
        $remaining=$Width-$minimum
        while ($remaining -gt 0) {
            $grew=$false
            for ($i=0;$i -lt $sizes.Count -and $remaining -gt 0;$i++) {
                if ($sizes[$i] -lt $desired[$i]) { $sizes[$i]++;$remaining--;$grew=$true }
            }
            if (-not $grew) { break }
        }
        $parts=@(for ($i=0;$i -lt $headers.Count;$i++) { $headers[$i]+(' '*($sizes[$i]-(Get-FkCellWidth $headers[$i]))) })
        $lines.Add(([string]::Join('  ',[string[]]$parts)).TrimEnd())
        $parts=@(foreach ($size in $sizes) { '-'*$size })
        $lines.Add([string]::Join('  ',[string[]]$parts))
        foreach ($cells in $values) {
            $chunks=New-Object 'System.Collections.Generic.List[object]';$height=1
            for ($i=0;$i -lt $headers.Count;$i++) {
                $column=@(Split-FkCell $cells[$i] $sizes[$i]);$chunks.Add($column);$height=[math]::Max($height,$column.Count)
            }
            for ($row=0;$row -lt $height;$row++) {
                $parts=@(for ($i=0;$i -lt $headers.Count;$i++) {
                    $part=if ($row -lt $chunks[$i].Count) { [string]$chunks[$i][$row] } else { '' }
                    $part+(' '*($sizes[$i]-(Get-FkCellWidth $part)))
                })
                $lines.Add(([string]::Join('  ',[string[]]$parts)).TrimEnd())
            }
            if ($height -gt 1) { $lines.Add('') }
        }
        return $lines.ToArray()
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

try {
    Write-Host 'AZURE OWNER ASSIGNMENTS // READ ONLY'
    Write-Host ''
    Import-Module Az.Accounts -ErrorAction Stop
    Import-Module Az.Resources -ErrorAction Stop
    Disable-AzContextAutosave -Scope Process -ErrorAction Stop | Out-Null
    $context = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $TenantId -and -not $TenantDomain -and $context.Environment.Name -eq 'AzureCloud' -and $context.Account.Id) {
        $TenantId = $context.Tenant.Id
    }
    if (-not $TenantId) {
        if (-not $TenantDomain) {
            if ($NoPause) { throw 'Specify -TenantDomain.' }
            $TenantDomain = Read-Host 'Azure tenant domain (for example, contoso.onmicrosoft.com)'
        }
        $TenantId = Resolve-FkTenantDomain -Domain $TenantDomain
    }
    if (-not $SubscriptionId -and -not $SubscriptionName -and $context.Tenant.Id -eq $TenantId -and $context.Environment.Name -eq 'AzureCloud' -and $context.Account.Id) {
        $SubscriptionId = $context.Subscription.Id
    }
    if (-not $SubscriptionId -and -not $SubscriptionName) {
        if ($NoPause) { throw 'Specify -SubscriptionName.' }
        $SubscriptionName = (Read-Host 'Azure subscription name').Trim()
        if (-not $SubscriptionName) { throw 'Subscription selection cancelled.' }
    }

    $tenantGuid = [guid]::Empty
    if (-not [guid]::TryParse($TenantId,[ref]$tenantGuid) -or $tenantGuid -eq [guid]::Empty) { throw 'Tenant validation failed.' }
    $TenantId = $tenantGuid.ToString()
    if (-not $context -or $context.Tenant.Id -ne $TenantId -or $context.Environment.Name -ne 'AzureCloud') {
        $login = Connect-AzAccount -Tenant $TenantId -SkipContextPopulation -Environment AzureCloud -Scope Process -ErrorAction Stop
        $context = $login.Context
    }
    if (-not $context -or $context.Tenant.Id -ne $TenantId -or $context.Environment.Name -ne 'AzureCloud') { throw 'Azure sign-in did not match the requested tenant.' }
    $subscriptions = @(Get-AzSubscription -TenantId $TenantId -DefaultProfile $context -ErrorAction Stop | Where-Object {
        if ($SubscriptionId) { $_.Id -eq $SubscriptionId }
        else { $_.Name -eq $SubscriptionName }
    })
    if ($subscriptions.Count -ne 1) { throw 'The subscription selection was missing or ambiguous in this tenant. No resources were queried.' }
    $SubscriptionId = [string]$subscriptions[0].Id
    $context = Set-AzContext -Tenant $TenantId -Subscription $SubscriptionId -Scope Process -DefaultProfile $context -ErrorAction Stop
    if (-not $context -or $context.Tenant.Id -ne $TenantId -or $context.Subscription.Id -ne $SubscriptionId -or $context.Environment.Name -ne 'AzureCloud') { throw 'Azure context does not match the requested tenant and subscription.' }
    if ($TenantDomain) { Write-Host "Tenant: $TenantDomain" }
    Write-Host ("Subscription: {0}" -f $context.Subscription.Name)
    $scope = '/subscriptions/' + $SubscriptionId
    $ownerRoleId = '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
    $assignments = @(Get-AzRoleAssignment -RoleDefinitionId $ownerRoleId -Scope $scope -DefaultProfile $context -ErrorAction Stop)
    $rows = @(
        foreach ($assignment in $assignments) {
            $roleId = ([string]$assignment.RoleDefinitionId).TrimEnd('/').Split('/')[-1]
            $assignmentScope = [string]$assignment.Scope
            $within = $assignmentScope -ieq $scope -or $assignmentScope.StartsWith($scope + '/', [StringComparison]::OrdinalIgnoreCase)
            if ($roleId -ieq $ownerRoleId -and $within) {
                $principal = if (-not [string]::IsNullOrWhiteSpace([string]$assignment.DisplayName)) { [string]$assignment.DisplayName } else { 'Name unavailable' }
                [pscustomobject][ordered]@{
                    Principal=$principal; ObjectId=[string]$assignment.ObjectId
                    Type=[string]$assignment.ObjectType; Scope=$assignmentScope
                    RoleDefinitionId=$roleId; AssignmentId=[string]$assignment.RoleAssignmentId
                    Condition=$assignment.Condition; ConditionVersion=$assignment.ConditionVersion
                    TenantId=$TenantId; SubscriptionId=$SubscriptionId
                }
            }
        }
    )
    $rows = @($rows | Sort-Object Scope,Principal,AssignmentId)
    if ($rows.Count -eq 0) { Write-Host 'No visible built-in Owner assignments returned within this subscription.' }
    else {
        $rows | Select-Object @{Name='PRINCIPAL';Expression={$_.Principal}},@{Name='TYPE';Expression={$_.Type}},@{Name='SCOPE';Expression={ if ($_.Scope -eq $scope) { $context.Subscription.Name } else { $_.Scope.Substring($scope.Length).TrimStart('/') } }} | Format-FkTable | Out-Host
        Write-Host ('{0} assignments.' -f $rows.Count)
    }
    Write-Host 'Excludes inherited management-group roles, PIM eligibility and group-member expansion.'
    if ($ExportPath) {
        if ($rows.Count -eq 0) { Write-Warning 'No rows to export.' }
        else {
            $rows | Export-Csv -LiteralPath $ExportPath -NoTypeInformation -Encoding UTF8 -NoClobber -ErrorAction Stop
            Write-Host "Export: $ExportPath"
        }
    }
    if ($PassThru) { $rows }
} catch {
    Write-Host ('FAILED: {0}' -f $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Check the Az modules, requested tenant/subscription, read permissions, and export path.'
    if ($NoPause) { throw }
} finally {
    $context = $null
    $login = $null
    if (-not $NoPause) { [void](Read-Host 'Press Enter to finish.') }
}
