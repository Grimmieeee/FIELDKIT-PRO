param([string]$ValidatorPath="$PSScriptRoot/VERIFY-FIELD-KIT.ps1",[string[]]$Scenarios=@('success','success-domain','missing-org','missing-org-domain','mismatch','mismatch-domain','existing','partial','readfailure','missing-tenant','invalid-tenant','empty-tenant','multiple-connections'))
$ErrorActionPreference='Stop';$root=$PSScriptRoot;$t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($ValidatorPath,[ref]$t,[ref]$e);if($e){throw ($e.Message-join'; ')}
$functions=$ast.FindAll({param($a)$a -is [Management.Automation.Language.FunctionDefinitionAst] -and $a.Name-in@('Record','Get-SafeError','Test-LiveConnections','Close-ValidatorConnections')},$true)
$results=[Collections.Generic.List[object]]::new()
foreach($scenario in $Scenarios){
 & {
  param($functions,$scenario,$results)
  foreach($f in $functions){. ([scriptblock]::Create($f.Extent.Text))}
  $script:Checks=[Collections.Generic.List[object]]::new();$script:GraphAttempted=$false;$script:ExoAttempted=$false;$script:GraphOwned=$false;$script:ExoOwned=$false
  $script:GraphConnected=($scenario-eq 'existing');$script:ExoConnected=$false;$script:Calls=[Collections.Generic.List[string]]::new()
  $script:Answers=[Collections.Generic.Queue[string]]::new();foreach($a in @('3',$(if($scenario-like '*domain'){'example.test'}else{'11111111-1111-1111-1111-111111111111'}),'fixture@example.test')){$script:Answers.Enqueue($a)}
  function Read-Host {param($Prompt)return $script:Answers.Dequeue()};function Write-Host {param($Object,$ForegroundColor)}
  function Get-Module {param([switch]$ListAvailable,$Name)return [pscustomobject]@{Path='fixture';Version=[version]'3.9.0'}}
  function Import-Module {param($Name,$ErrorAction)}
  function Get-PSSession {return @()}
  function Get-MgContext {param($ErrorAction)if($script:GraphConnected){return [pscustomobject]@{ContextScope='Process'}}}
  function Connect-MgGraph {param($TenantId,$Scopes,$ContextScope,[switch]$NoWelcome,$ErrorAction)
   if($ContextScope-ne'Process'-or$Scopes.Count-ne2){throw 'Unexpected Graph request'};$script:Calls.Add('GraphConnect');$script:GraphConnected=$true;if($scenario-eq 'partial'){throw 'Fixture interrupted sign-in'}
  }
  function Invoke-MgGraphRequest {param($Method,$Uri,$OutputType,$ErrorAction)
   if($Method-ne'GET'){throw 'Mutation attempted'};$script:Calls.Add($Uri)
   if($Uri-like'*organization?*'){return [pscustomobject]@{value=@([pscustomobject]@{id='11111111-1111-1111-1111-111111111111';verifiedDomains=@([pscustomobject]@{name='example.test'})})}}
   if($Uri-like'*users/fixture*'){if($scenario-eq 'readfailure'){throw 'Fixture denied read'};return [pscustomobject]@{id='fixture';userPrincipalName='fixture@example.test'}}
   throw 'Unexpected endpoint'
  }
  function Connect-ExchangeOnline {param($ShowBanner,$ErrorAction)$script:ExoConnected=$true;$script:Calls.Add('ExoConnect')}
  function Get-ConnectionInformation {param($ErrorAction)
   if($script:ExoConnected){
    $id=if($scenario-eq'mismatch'){'22222222-2222-2222-2222-222222222222'}elseif($scenario-eq'missing-tenant'){''}elseif($scenario-eq'invalid-tenant'){'not-a-guid'}elseif($scenario-eq'empty-tenant'){[guid]::Empty.ToString()}else{'11111111-1111-1111-1111-111111111111'}
    [pscustomobject]@{State='Connected';TenantID=$id}
    if($scenario-eq'multiple-connections'){[pscustomobject]@{State='Connected';TenantID=$id}}
   }
  }
  function Get-OrganizationConfig {param($ErrorAction)$id=if($scenario-in@('missing-org','missing-org-domain')){''}elseif($scenario-in@('mismatch','mismatch-domain')){'22222222-2222-2222-2222-222222222222'}else{'11111111-1111-1111-1111-111111111111'};return [pscustomobject]@{ExternalDirectoryOrganizationId=$id}}
  function Get-AcceptedDomain {param($ErrorAction)return [pscustomobject]@{DomainName=$(if($scenario-eq 'mismatch-domain'){'wrong.test'}else{'example.test'})}}
  function Get-EXOMailbox {param($Identity,$ErrorAction)$script:Calls.Add('MailboxRead');return [pscustomobject]@{Identity=$Identity}}
  function Disconnect-MgGraph {param($ErrorAction)$script:Calls.Add('GraphDisconnect');$script:GraphConnected=$false}
  function Disconnect-ExchangeOnline {param($Confirm,$ErrorAction)$script:Calls.Add('ExoDisconnect');$script:ExoConnected=$false}
  Test-LiveConnections;Close-ValidatorConnections
  if($scenario-eq 'existing'){
   if($script:Calls.Count-ne0 -or-not$script:GraphConnected){throw 'Existing context was touched'}
   if(-not@($script:Checks|Where-Object Status -eq 'FAIL').Count){throw 'Existing context not rejected'}
  }elseif($scenario-in@('success','success-domain','missing-org','missing-org-domain')){
   if(@($script:Checks|Where-Object Status -eq 'FAIL').Count){throw (($script:Checks|ConvertTo-Json)-join'')}
   foreach($call in @('MailboxRead','GraphDisconnect','ExoDisconnect')){if($call-notin$script:Calls){throw ('Missing '+$call)}}
  }else{
   if(-not@($script:Checks|Where-Object Status -eq 'FAIL').Count){throw 'Failure was presented as success'}
   if($script:GraphConnected-or$script:ExoConnected){throw 'Connection leaked'}
   if($scenario-in@('mismatch','mismatch-domain','missing-tenant','invalid-tenant','empty-tenant','multiple-connections')-and'MailboxRead'-in$script:Calls){throw 'Read continued after tenant mismatch'}
  }
  $results.Add([pscustomobject]@{scenario=$scenario;result='PASS';scope='Mocked connector commands; no real modules/authentication'})
 } $functions $scenario $results
}
$results|ConvertTo-Json -Depth 6|Set-Content "$root/connection-test-results.json";Write-Host ('PASS: '+$results.Count+' connector control-flow scenarios')
