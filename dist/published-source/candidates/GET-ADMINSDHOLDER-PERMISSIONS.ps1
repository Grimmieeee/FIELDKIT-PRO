#Requires -Version 5.1
# .VERSION 0.1.1
# OBJECTIVE: Show the owner and access rules on the AdminSDHolder object in one AD domain.
<#
.SYNOPSIS
Show the owner and access rules on the AdminSDHolder object in one AD domain.
.DESCRIPTION
Reads one object's security descriptor through the pinned domain controller.
Shows raw access rules, owner SID and inheritance state. Does not expand groups,
resolve object-type GUIDs, evaluate effective access, inspect all child objects,
compare security baselines or modify permissions. AdminSDHolder rules alone do
not establish which accounts are currently protected. Does not request SACL data.
-Details shows rule GUIDs. -PassThru returns target metadata, SDDL and Rules;
CSV contains rule rows only. Empty/null DACL states are reported separately.
Requires ActiveDirectory and permission to read this security descriptor.
#>
[CmdletBinding()]
param([string]$Server,[string]$ExportPath,[switch]$Details,[switch]$NoPause,[switch]$PassThru)
Write-Host "AdminSDHolder Permissions"
$ErrorActionPreference='Stop'
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
    Write-Host 'ADMINSDHOLDER PERMISSIONS // READ ONLY'
    Write-Host ''
    if ($env:OS -ne 'Windows_NT') { throw 'Windows with the ActiveDirectory module is required.' }
    Import-Module ActiveDirectory -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($Server)) {
        $Server = [string](Get-ADDomainController -Discover -Writable -ErrorAction Stop).HostName
    }
    if ([string]::IsNullOrWhiteSpace($Server)) { throw 'No controller found. Specify -Server.' }
    $dc = Get-ADDomainController -Identity $Server -Server $Server -ErrorAction Stop
    $Server = [string]$dc.HostName
    if ([string]::IsNullOrWhiteSpace($Server)) { throw 'Controller identity is unavailable.' }
    $domain = Get-ADDomain -Server $Server -ErrorAction Stop
    Write-Host "Controller: $Server"
    $targetDn=('CN=AdminSDHolder,CN=System,' + $domain.DistinguishedName)
    $target=Get-ADObject -Identity $targetDn -Server $Server -Properties nTSecurityDescriptor -ErrorAction Stop
    if ($target.DistinguishedName -ine $targetDn -or -not $target.ObjectGuid) { throw 'Target identity is incomplete or does not match the selected object.' }
    $descriptor=$target.nTSecurityDescriptor
    if ($null -eq $descriptor -or -not $descriptor.PSObject.Methods['GetAccessRules']) { throw 'A readable security descriptor was not returned.' }
    $raw=[Security.AccessControl.RawSecurityDescriptor]::new($descriptor.GetSecurityDescriptorBinaryForm(),0)
    $owner=$descriptor.GetOwner([Security.Principal.SecurityIdentifier])
    $ownerSid=if ($null -ne $owner) { $owner.Value } else { 'Not returned' }
    $daclState=if ($null -eq $raw.DiscretionaryAcl) { 'NULL OR ABSENT' } elseif ($raw.DiscretionaryAcl.Count -eq 0) { 'EMPTY' } else { 'PRESENT' }
    $rules=@($descriptor.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier]))
    Write-Host "Object: $targetDn"
    Write-Host "Owner SID: $ownerSid"
    Write-Host ('Inheritance: {0}' -f $(if ($descriptor.AreAccessRulesProtected) { 'Blocked' } else { 'Enabled' }))
    $rows=@(
        foreach ($rule in $rules) {
            [pscustomobject][ordered]@{
                AccountSID=$rule.IdentityReference.Value
                Type=[string]$rule.AccessControlType; Rights=[string]$rule.ActiveDirectoryRights
                Inherited=$rule.IsInherited; Inheritance=[string]$rule.InheritanceType
                Limits=[string]$rule.ObjectFlags; ObjectType=[string]$rule.ObjectType
                InheritedObjectType=[string]$rule.InheritedObjectType
                Target=$targetDn; TargetGuid=[string]$target.ObjectGuid; OwnerSID=$ownerSid
                InheritanceBlocked=$descriptor.AreAccessRulesProtected; DomainController=$Server
            }
        }
    )
    if ($daclState -eq 'NULL OR ABSENT') { Write-Warning 'No DACL restriction. Other access controls can still apply.' }
    elseif ($daclState -eq 'EMPTY') { Write-Host 'Empty DACL: no access is granted by its rules.' }
    elseif ($rows.Count -eq 0) { throw 'DACL entries exist, but no access rules were decoded.' }
    else {
        $rows | Select-Object @{Name='SID';Expression={$_.AccountSID}},@{Name='TYPE';Expression={$_.Type}},@{Name='RIGHTS';Expression={$_.Rights}},@{Name='INHERITED';Expression={$_.Inherited}},@{Name='INHERITANCE';Expression={$_.Inheritance}},@{Name='LIMITS';Expression={$_.Limits}} | Format-FkTable | Out-Host
        if ($Details) { $rows | Select-Object AccountSID,Rights,ObjectType,InheritedObjectType | Format-FkTable | Out-Host }
    }
    Write-Host 'Raw rules only. GUID limits and group membership require further review.'
    if ($ExportPath) {
        if ($rows.Count -eq 0) { Write-Warning 'No rule rows to export.' }
        else {
            $rows | Export-Csv -LiteralPath $ExportPath -NoTypeInformation -Encoding UTF8 -NoClobber -ErrorAction Stop
            Write-Host "Export: $ExportPath"
        }
    }
    if ($PassThru) {
        [pscustomobject]@{Target=$targetDn;TargetGuid=[string]$target.ObjectGuid;OwnerSID=$ownerSid;DaclState=$daclState;InheritanceBlocked=$descriptor.AreAccessRulesProtected;SDDL=$descriptor.GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::Access);Rules=$rows}
    }
} catch {
    Write-Host ('FAILED: {0}' -f $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Check the AD module, controller, security-descriptor read access, and export path.'
    if ($NoPause) { throw }
} finally {
    if (-not $NoPause) { [void](Read-Host 'Press Enter to finish.') }
}
