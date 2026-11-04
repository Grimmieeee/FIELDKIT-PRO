#Requires -Version 5.1
# .VERSION 0.1.1
# OBJECTIVE: List visible built-in Owner assignments within one Azure subscription.
<#
.SYNOPSIS
List visible built-in Owner assignments within one Azure subscription.
.DESCRIPTION
Queries active Azure RBAC assignments at or below the selected subscription,
then matches the built-in Owner role by ID. Retains principal IDs, assignment
scope and any returned conditions. Does not enumerate inherited management-group
assignments, eligible PIM roles, group members, custom equivalent roles, deny
assignments or effective access. Missing display names remain Object IDs.
Requires explicit tenant/subscription GUIDs. Azure public cloud only. Reuses a
matching Az context or signs in to the requested scope. Context changes and
context-autosave preference are process-scoped; the process may retain the login.
Does not install modules or modify Azure resources. Requires Az.Accounts and
Az.Resources with appropriate read permissions. CSV refuses existing files.
#>
[CmdletBinding()]
param([string]$TenantId,[string]$SubscriptionId,[string]$ExportPath,[switch]$NoPause,[switch]$PassThru)
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

try {
    Write-Host 'AZURE OWNER ASSIGNMENTS // READ ONLY'
    Write-Host ''
    Import-Module Az.Accounts -ErrorAction Stop
    Import-Module Az.Resources -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($TenantId)) {
        if ($NoPause) { throw 'Specify -TenantId.' }
        $TenantId = Read-Host 'Tenant ID'
    }
    if ([string]::IsNullOrWhiteSpace($SubscriptionId)) {
        if ($NoPause) { throw 'Specify -SubscriptionId.' }
        $SubscriptionId = Read-Host 'Subscription ID'
    }
    $tenantGuid = [guid]::Empty
    $subscriptionGuid = [guid]::Empty
    if (-not [guid]::TryParse($TenantId,[ref]$tenantGuid) -or $tenantGuid -eq [guid]::Empty) { throw 'Enter a valid tenant ID.' }
    if (-not [guid]::TryParse($SubscriptionId,[ref]$subscriptionGuid) -or $subscriptionGuid -eq [guid]::Empty) { throw 'Enter a valid subscription ID.' }
    $TenantId = $tenantGuid.ToString()
    $SubscriptionId = $subscriptionGuid.ToString()
    # Context changes stay in this PowerShell process; no saved context changes.
    Disable-AzContextAutosave -Scope Process -ErrorAction Stop | Out-Null
    $context = Get-AzContext -ErrorAction Stop
    if (-not $context -or $context.Tenant.Id -ne $TenantId -or $context.Subscription.Id -ne $SubscriptionId -or $context.Environment.Name -ne 'AzureCloud') {
        $login = Connect-AzAccount -Tenant $TenantId -Subscription $SubscriptionId -Environment AzureCloud -Scope Process -ErrorAction Stop
        $context = $login.Context
    }
    if (-not $context -or $context.Tenant.Id -ne $TenantId -or $context.Subscription.Id -ne $SubscriptionId -or $context.Environment.Name -ne 'AzureCloud') { throw 'Azure context does not match the requested tenant and subscription.' }
    Write-Host "Tenant: $TenantId"
    Write-Host ('Subscription: {0} [{1}]' -f $context.Subscription.Name,$SubscriptionId)
    $scope = '/subscriptions/' + $SubscriptionId
    $ownerRoleId = '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
    $assignments = @(Get-AzRoleAssignment -RoleDefinitionId $ownerRoleId -Scope $scope -DefaultProfile $context -ErrorAction Stop)
    $rows = @(
        foreach ($assignment in $assignments) {
            $roleId = ([string]$assignment.RoleDefinitionId).TrimEnd('/').Split('/')[-1]
            $assignmentScope = [string]$assignment.Scope
            $within = $assignmentScope -ieq $scope -or $assignmentScope.StartsWith($scope + '/', [StringComparison]::OrdinalIgnoreCase)
            if ($roleId -ieq $ownerRoleId -and $within) {
                $principal = if (-not [string]::IsNullOrWhiteSpace([string]$assignment.DisplayName)) { [string]$assignment.DisplayName } else { [string]$assignment.ObjectId }
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
        $rows | Select-Object @{Name='PRINCIPAL';Expression={$_.Principal}},@{Name='TYPE';Expression={$_.Type}},@{Name='SCOPE';Expression={$_.Scope}} | Format-FkTable | Out-Host
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
