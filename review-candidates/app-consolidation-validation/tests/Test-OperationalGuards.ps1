#Requires -Version 7
# Extracted helpers and per-target blocks only. Run with run-contained.py for OS network denial.
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$script:Cases=[System.Collections.Generic.List[object]]::new()
function Check($Name,[scriptblock]$Body){ & $Body; $script:Cases.Add([pscustomobject]@{Check=$Name;Result='PASS'}) }
function Assert($Value,$Message){if(-not $Value){throw $Message}}
function Throws([scriptblock]$Body){$caught=$false;try{& $Body}catch{$caught=$true};Assert $caught 'Expected failure was accepted'}
function Load-Functions($Path,$Names){
 $t=$null;$e=$null;$ast=[System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$t,[ref]$e)
 Assert (-not $e.Count) 'Parse failed'
 foreach($f in $ast.EndBlock.Statements){if($f -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $f.Name -in $Names){. ([scriptblock]::Create($f.Extent.Text.Replace('function '+$f.Name,'function script:'+$f.Name)))}}
 return $ast
}
$app=Join-Path $root 'candidates/published-source/tenant/GET-APP-REGISTRATION-AUDIT.ps1'
$null=Load-Functions $app @('Assert-GraphContext','Get-GraphPages','Get-PublicText','Get-PublisherInfo','Get-CredentialExpiryFinding')
$script:ctx=[pscustomobject]@{TenantId='tenant';Account='tech@example.test';AuthType='Delegated';ContextScope='Process'}
function Get-MgContext{return $script:ctx}
Check 'Valid delegated process context accepted' {Assert-GraphContext -TenantId tenant -Account tech@example.test}
foreach($property in @('TenantId','Account','AuthType','ContextScope')){
 $saved=$script:ctx.$property;$script:ctx.$property='wrong'
 Check "Changed $property blocked" {Throws {Assert-GraphContext -TenantId tenant -Account tech@example.test}}
 $script:ctx.$property=$saved
}
Check 'Missing context blocked' {$saved=$script:ctx;$script:ctx=$null;Throws {Assert-GraphContext -TenantId tenant};$script:ctx=$saved}
$script:page=0
function Graph-Get {param($Uri);$script:page++;if($script:page -eq 1){return [pscustomobject]@{value=@('one');'@odata.nextLink'='page2'}};return [pscustomobject]@{value=@('two')}}
Check 'Paging retains all rows' {$rows=@(Get-GraphPages page1);Assert ($rows.Count -eq 2 -and $rows[0] -eq 'one' -and $rows[1] -eq 'two') 'Page lost'}
function Graph-Get {param($Uri);return [pscustomobject]@{value=@()}}
Check 'Empty collection accepted' {Assert (@(Get-GraphPages page1).Count -eq 0) 'Empty collection incorrect'}
function Graph-Get {param($Uri);return [pscustomobject]@{error='denied'}}
Check 'Malformed collection blocked' {Throws {Get-GraphPages page1}}
function Graph-Get {param($Uri);throw 'Fixture read denied'}
Check 'Read failure propagates' {Throws {Get-GraphPages page1}}
Check 'Publisher display name cannot impersonate Microsoft' {$p=Get-PublisherInfo -ServicePrincipal ([pscustomobject]@{displayName='Microsoft';appOwnerOrganizationId='other';verifiedPublisher=$null});Assert (-not $p.Microsoft -and -not $p.Verified -and $p.Name -eq 'Unknown publisher') 'Spoofed publisher trusted'}
Check 'Public text removes GUIDs' {Assert ((Get-PublicText 'Example 12345678-1234-1234-1234-123456789abc') -notmatch '12345678') 'GUID leaked'}
Check 'Invalid credential expiry stays unknown' {Assert ((Get-CredentialExpiryFinding -EndDate bad -Now (Get-Date) -Soon (Get-Date).AddDays(30) -Kind Secret) -eq 'Secret expiry unavailable') 'Unknown expiry treated as good'}

function Test-LicenseBlock($File,$Mode){
 $path=Join-Path $root ('candidates/published-source/identity/'+$File)
 $ast=Load-Functions $path @('Get-LicenseSnapshot','Read-LicenseUserById','Get-AssignedLicenseIds','Assert-GraphContext')
 $tries=@($ast.FindAll({param($n) $n -is [System.Management.Automation.Language.TryStatementAst] -and $n.Body.Extent.Text.Contains('$fresh=Read-LicenseUserById')},$true)|Sort-Object {$_.Extent.Text.Length})
 Assert ($tries.Count -gt 0) 'Target block not located'
 $ExpectedTenantId='tenant';$approvedAccount='tech@example.test';$script:writes=0;$script:Mode=$Mode
 $script:fresh=[pscustomobject]@{id='user';userPrincipalName='person@example.test';usageLocation='US';assignedLicenses=@([pscustomobject]@{skuId='sku';disabledPlans=@()});licenseAssignmentStates=@([pscustomobject]@{skuId='sku';assignedByGroup=$null})}
 $snap=Get-LicenseSnapshot -User $script:fresh
 $u=[pscustomobject]@{Id='user';UPN='person@example.test';Snapshot=$snap}
 $target=[pscustomobject]@{Id='user';UPN='person@example.test';Snapshot=$snap;UsageLocation='US'}
 $selected=[pscustomobject]@{skuId='sku'};$selectedName='Example License';$UsageLocation='US';$removeIds=@('sku');$removeNames='Example License';$body=@{}
 $results=[System.Collections.ArrayList]::new()
 function Graph-Get {param($Uri);return $script:fresh}
 function Get-GraphPages {param($Uri);$enabled=if($script:Mode -eq 'capacity'){1}else{5};return [pscustomobject]@{skuId='sku';prepaidUnits=[pscustomobject]@{enabled=$enabled};consumedUnits=1}}
 function Graph-Post {param($Uri,$Body);$script:writes++;if($script:Mode -eq 'write-error'){throw 'Synthetic write response unavailable'};if($File -eq 'INVOKE-REMOVE-LICENSES.ps1'){$script:fresh.assignedLicenses=@()}}
 function Invoke-MgGraphRequest {throw 'Unexpected direct request'}
 function Start-Sleep {}
 function WARN {}
 function OK {}
 if($Mode -eq 'identity'){$script:fresh.id='changed'}
 if($Mode -eq 'state'){$script:fresh.assignedLicenses[0].disabledPlans=@('changed')}
 if($Mode -eq 'inherited'){$script:fresh.licenseAssignmentStates[0].assignedByGroup='licensing-group'}
 if($Mode -eq 'missing-source'){$script:fresh.PSObject.Properties.Remove('licenseAssignmentStates')}
 & ([scriptblock]::Create($tries[0].Extent.Text))
 Assert ($results.Count -eq 1) 'Missing per-user outcome'
 if($Mode -in @('identity','state','capacity','inherited','missing-source')){Assert ($script:writes -eq 0 -and $results[0].Result -eq 'Failed') 'Guard allowed mutation or mislabeled result'}
 elseif($Mode -eq 'write-error'){Assert ($script:writes -eq 1 -and $results[0].Result -eq 'FailedValidation') 'Attempted mutation reported as clean failure/success'}
 else {Assert ($script:writes -eq 1 -and $results[0].Result -eq 'Verified') 'Synthetic success not verified'}
}
foreach($file in @('INVOKE-ASSIGN-LICENSES.ps1','INVOKE-REMOVE-LICENSES.ps1')){
 foreach($mode in @('identity','state','write-error','success')){Check "$file $mode" {Test-LicenseBlock $file $mode}}
}
Check 'Assignment blocks exhausted capacity' {Test-LicenseBlock 'INVOKE-ASSIGN-LICENSES.ps1' 'capacity'}
Check 'Removal blocks inherited assignments' {Test-LicenseBlock 'INVOKE-REMOVE-LICENSES.ps1' 'inherited'}
Check 'Removal blocks missing source evidence' {Test-LicenseBlock 'INVOKE-REMOVE-LICENSES.ps1' 'missing-source'}
$script:Cases|Format-Table -AutoSize
