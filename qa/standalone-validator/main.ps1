<#
VERIFY-FIELD-KIT.ps1
.VERSION 1.0.1
One-file acceptance check for the locked FIELD // KIT candidate batch.
No operational script entrypoint is executed. Tenant checks are GET/read only.
Writes a synthetic CSV and a validation JSON report to Desktop. Temporary test files are removed.
Requires Windows PowerShell 5.1 or PowerShell 7; installed Graph Authentication / ExchangeOnlineManagement for live checks.
LocalOnly performs no connections. ParserOnly is an internal Windows PowerShell compatibility probe.
#>
[CmdletBinding()]
param([switch]$LocalOnly,[switch]$NoPause,[switch]$ParserOnly)
$ErrorActionPreference='Stop'
$script:Checks=[Collections.Generic.List[object]]::new()
$script:Group='Local';$script:GraphOwned=$false;$script:ExoOwned=$false
$script:GraphAttempted=$false;$script:ExoAttempted=$false
$script:StartedUtc=[datetime]::UtcNow.ToString('o')
$script:PayloadHash='__PAYLOAD_SHA__'
$script:PackedPayload='__PAYLOAD__'
function Hash-Bytes([byte[]]$Bytes){$sha=[Security.Cryptography.SHA256]::Create();try{return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}}
function Record($Name,$Status,$Detail){
 $script:Checks.Add([pscustomobject]@{Group=$script:Group;Check=$Name;Status=$Status;Detail=$Detail})
 if($Status-ne 'PASS' -or $script:Group-eq 'Live'){$color=if($Status-eq 'FAIL'){'Red'}elseif($Status-eq 'PASS'){'Green'}else{'Yellow'};Write-Host ("[{0}] {1} // {2}" -f $Status,$Name,$Detail) -ForegroundColor $color}
}
function Read-EmbeddedSources {
 $packed=[Convert]::FromBase64String($script:PackedPayload);$inputStream=[IO.MemoryStream]::new($packed);$gzip=[IO.Compression.GZipStream]::new($inputStream,[IO.Compression.CompressionMode]::Decompress);$output=[IO.MemoryStream]::new()
 try{$gzip.CopyTo($output);$bytes=$output.ToArray()}finally{$gzip.Dispose();$inputStream.Dispose();$output.Dispose()}
 if((Hash-Bytes $bytes)-cne$script:PayloadHash){throw 'Embedded payload hash mismatch.'}
 $payload=[Text.Encoding]::UTF8.GetString($bytes)|ConvertFrom-Json
 if(@($payload.sources).Count-ne59){throw 'Embedded source count mismatch.'}
 $sources=foreach($row in $payload.sources){
  $b=[Convert]::FromBase64String($row.bytes);if((Hash-Bytes $b)-cne$row.sha256){throw ('Embedded source hash mismatch: '+$row.path)}
  $text=[Text.Encoding]::UTF8.GetString($b).TrimStart([char]0xFEFF);$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseInput($text,[ref]$tokens,[ref]$errors)
  if($errors.Count){throw ('Parser failure: '+$row.path+' // '+($errors.Message-join'; '))}
  $functions=@($ast.FindAll({param($a)$a -is [Management.Automation.Language.FunctionDefinitionAst]},$true)|ForEach-Object {[pscustomobject]@{Name=$_.Name;Text=$_.Extent.Text;Extent=$_.Extent}})
  [pscustomobject]@{path=$row.path;sha256=$row.sha256;changed=$row.changed;ast=$ast;functions=$functions}
 }
 return $sources
}
__HARNESSES__
function Test-DesktopCsv($Sources){
 $desktop=[Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)
 if([string]::IsNullOrWhiteSpace($desktop)-or-not[IO.Directory]::Exists($desktop)){throw 'Windows Desktop could not be resolved. No alternate folder used.'}
 $source=$Sources|Where-Object path -eq 'published-source/identity/GET-ACCOUNT-STATUS.ps1'
 & {
  param($source,$desktop)
  foreach($f in $source.functions|Where-Object {$_.Name-in@('Get-FKDesktopDirectory','Get-FKDesktopExportPath','Offer-VerifiedCsv')}){. ([scriptblock]::Create($f.Text))}
  function Read-Host {param($Prompt)if($Prompt-notmatch'^Export results to CSV'){throw 'Unexpected export prompt'};return 'Y'}
  function Write-OK {param($Message)}
  $sample=@([pscustomobject][ordered]@{UPN='sample.one@example.test';Status='Complete';Detail='Comma, quote " and Unicode '+[char]0x00E9},[pscustomobject][ordered]@{UPN='sample.two@example.test';Status='Unavailable';Detail="Read failed`r`nSecond line"})
  $before=@((Get-ChildItem -LiteralPath $desktop -Filter 'FIELD-KIT-CSV-TEST-*.csv' -File).FullName)
  Offer-VerifiedCsv -Rows $sample -DefaultName 'FIELD-KIT-CSV-TEST.csv'
  $files=@(Get-ChildItem -LiteralPath $desktop -Filter 'FIELD-KIT-CSV-TEST-*.csv' -File|Where-Object {$_.FullName-notin$before})
  if($files.Count-ne1){throw 'Expected exactly one Desktop sample CSV.'}
  $rows=@(Import-Csv -LiteralPath $files[0].FullName -Encoding UTF8 -ErrorAction Stop)
  if($rows.Count-ne2){throw 'CSV row count changed.'}
  if((@($rows[0].PSObject.Properties.Name)-join'|')-cne'UPN|Status|Detail'){throw 'CSV columns changed.'}
  for($i=0;$i-lt2;$i++){foreach($name in @('UPN','Status','Detail')){if($rows[$i].$name-cne$sample[$i].$name){throw ('CSV roundtrip mismatch: '+$name)}}}
  return $files[0].FullName
 } $source $desktop
}
function Get-SafeError($ErrorRecord){return ($ErrorRecord.Exception.GetType().Name+': '+($ErrorRecord.Exception.Message -replace '[A-Za-z0-9_-]{30,}\.[A-Za-z0-9_-]{30,}\.[A-Za-z0-9_-]+','[token redacted]'))}
function Test-LiveConnections {
 $script:Group='Live'
 Write-Host '';Write-Host 'LIVE CHECKS // Read-only. No operational workflows or changes.' -ForegroundColor Cyan
 $choice=(Read-Host 'Check 1 Graph, 2 Exchange, 3 Both, 0 Skip [3]').Trim();if(-not$choice){$choice='3'}
 if($choice-notin@('0','1','2','3')){Record 'Connections' 'FAIL' 'Invalid selection; no connection attempted.';return}
 if($choice-eq '0'){Record 'Connections' 'SKIP' 'Operator skipped.';return}
 $tenant=(Read-Host 'Expected tenant ID or verified domain').Trim()
 $tenantGuid=[guid]::Empty;$isGuid=[guid]::TryParse($tenant,[ref]$tenantGuid)
 if(-not$tenant -or (-not$isGuid -and $tenant-notmatch'^[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?\.[A-Za-z]{2,}$')){Record 'Tenant selection' 'FAIL' 'Enter a tenant GUID or domain; no connection attempted.';return}
 $upn=(Read-Host 'Test user/mailbox UPN [Enter skips target reads]').Trim()
 if($upn -and $upn-notmatch'^[^@\s]+@[^@\s]+\.[^@\s]+$'){Record 'Target selection' 'FAIL' 'Invalid UPN; no connection attempted.';return}
 $graphTenant=''
 try {
  # Refuse to borrow or disconnect another session, including a persisted Graph context.
  if($choice-in@('1','3')){
   $module=Get-Module -ListAvailable Microsoft.Graph.Authentication|Sort-Object Version -Descending|Select-Object -First 1
   if(-not$module -or $module.Version-lt[version]'2.0.0'){throw 'Microsoft.Graph.Authentication 2.x or later is required. Install through your approved process, then rerun.'}
   Import-Module $module.Path -ErrorAction Stop
   if(Get-MgContext -ErrorAction Stop){throw 'An existing Graph context was found. Run this validator in a fresh session with no active Graph context.'}
   Record 'Graph module' 'PASS' ([string]$module.Version)
  }
  if($choice-in@('2','3')){
   $module=Get-Module -ListAvailable ExchangeOnlineManagement|Sort-Object Version -Descending|Select-Object -First 1
   if(-not$module -or $module.Version-lt[version]'3.2.0'){throw 'ExchangeOnlineManagement 3.2+ is required. Install/update through your approved process, then rerun.'}
   Import-Module $module.Path -ErrorAction Stop
   if(@(Get-ConnectionInformation -ErrorAction Stop).Count -or @(Get-PSSession|Where-Object {$_.ConfigurationName-eq 'Microsoft.Exchange'}).Count){throw 'An existing Exchange connection was found. Run this validator in a fresh PowerShell session.'}
   Record 'Exchange module' 'PASS' ([string]$module.Version)
  }
 }catch{Record 'Connection prerequisites' 'FAIL' (Get-SafeError $_);return}
 if($choice-in@('1','3')){
  try {
   $script:GraphAttempted=$true
   Connect-MgGraph -TenantId $tenant -Scopes @('Organization.Read.All','User.Read.All') -ContextScope Process -NoWelcome -ErrorAction Stop|Out-Null
   $script:GraphOwned=$true;$context=Get-MgContext -ErrorAction Stop
   if(-not$context -or $context.ContextScope-ne 'Process'){throw 'Graph process-scoped context was not established.'}
   $org=Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/organization?$select=id,verifiedDomains' -OutputType PSObject -ErrorAction Stop
   $organizations=@($org.value);if($organizations.Count-ne1){throw 'Expected exactly one organization.'};$graphTenant=[string]$organizations[0].id
   if($isGuid){if($graphTenant-ne$tenantGuid.ToString()){throw 'Graph tenant mismatch.'}}else{if($tenant-notin@($organizations[0].verifiedDomains|ForEach-Object {$_.name})){throw 'Expected domain is not verified in the Graph tenant.'}}
   Record 'Graph sign-in and tenant read' 'PASS' 'Expected tenant confirmed.'
   if($upn){$uri='https://graph.microsoft.com/v1.0/users/'+[uri]::EscapeDataString($upn)+'?$select=id,userPrincipalName';$user=Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject -ErrorAction Stop;if(-not$user.id -or $user.userPrincipalName-ne$upn){throw 'Graph target did not match.'};Record 'Graph test user read' 'PASS' 'Requested UPN matched; no user data exported.'}else{Record 'Graph test user read' 'SKIP' 'No target supplied.'}
  }catch{Record 'Graph connection/read' 'FAIL' (Get-SafeError $_)}
 }else{Record 'Graph connection' 'SKIP' 'Not selected.'}
 if($choice-in@('2','3')){
  try {
   $script:ExoAttempted=$true;Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop|Out-Null;$script:ExoOwned=$true
   $info=@(Get-ConnectionInformation -ErrorAction Stop|Where-Object State -eq 'Connected')
   if($info.Count-ne1){throw 'Expected exactly one connected Exchange session.'}
   $connectionTenant=[guid]::Empty
   if(-not[guid]::TryParse([string]$info[0].TenantID,[ref]$connectionTenant) -or $connectionTenant-eq[guid]::Empty){throw 'Exchange connection did not return a valid tenant ID.'}
   $exoTenant=$connectionTenant.ToString()
   if($isGuid){if($exoTenant-ne$tenantGuid.ToString()){throw 'Exchange tenant mismatch.'}}else{$domains=@(Get-AcceptedDomain -ErrorAction Stop|ForEach-Object {[string]$_.DomainName});if($tenant-notin$domains){throw 'Expected domain is not accepted in the Exchange tenant.'}}
   if($graphTenant -and $exoTenant-ne$graphTenant){throw 'Graph and Exchange tenants differ.'}
   Record 'Exchange sign-in and tenant read' 'PASS' 'Expected tenant confirmed.'
   if($upn){$mailboxes=@(Get-EXOMailbox -Identity $upn -ErrorAction Stop);if($mailboxes.Count-ne1){throw 'Expected one test mailbox.'};Record 'Exchange test mailbox read' 'PASS' 'Requested mailbox resolved; no mailbox data exported.'}else{Record 'Exchange test mailbox read' 'SKIP' 'No target supplied.'}
  }catch{Record 'Exchange connection/read' 'FAIL' (Get-SafeError $_)}
 }else{Record 'Exchange connection' 'SKIP' 'Not selected.'}
}
function Close-ValidatorConnections {
 $script:Group='Live'
 if($script:ExoAttempted){try{Disconnect-ExchangeOnline -Confirm:$false -ErrorAction Stop|Out-Null;$remaining=@(Get-ConnectionInformation -ErrorAction Stop|Where-Object State -eq 'Connected');if($remaining.Count){throw 'Exchange still reports a connected session.'};Record 'Exchange disconnect' 'PASS' 'No connected session remains.'}catch{Record 'Exchange disconnect' 'FAIL' (Get-SafeError $_)}}
 if($script:GraphAttempted){try{Disconnect-MgGraph -ErrorAction Stop|Out-Null;if(Get-MgContext -ErrorAction Stop){throw 'Graph context remains.'};Record 'Graph disconnect' 'PASS' 'Process context ended.'}catch{Record 'Graph disconnect' 'FAIL' (Get-SafeError $_)}}
}
function Save-ValidationReport($Sources,$SamplePath){
 $desktop=[Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)
 if(-not$desktop -or -not[IO.Directory]::Exists($desktop)){throw 'Desktop unavailable; no report saved elsewhere.'}
 $failed=@($script:Checks|Where-Object Status -eq 'FAIL').Count;$skipped=@($script:Checks|Where-Object Status -eq 'SKIP').Count
 $report=[ordered]@{ValidatorVersion='1.0.0';StartedUtc=$script:StartedUtc;CompletedUtc=[datetime]::UtcNow.ToString('o');PowerShell=[string]$PSVersionTable.PSVersion;Edition=[string]$PSVersionTable.PSEdition;PayloadSha256=$script:PayloadHash;SampleCsv=$SamplePath;Passed=@($script:Checks|Where-Object Status -eq 'PASS').Count;Failed=$failed;Skipped=$skipped;Scope='Embedded parsing, isolated input/export checks, real Desktop CSV roundtrip, selected read-only connections. No operational workflow entrypoints.';Unexecuted=@('Operational workflow end-to-end tests','AD/hybrid/sync connectivity','Every tool-specific permission/API','Browser download/package acceptance','Interactive cancellation across workflows','Clean close of every operational script');Sources=@($Sources|ForEach-Object {[ordered]@{Path=$_.path;Sha256=$_.sha256;Candidate=$_.changed}});Checks=@($script:Checks.ToArray())}
 $path=Join-Path $desktop ('FIELD-KIT-VALIDATION-'+[datetime]::Now.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)+'.json')
 $json=$report|ConvertTo-Json -Depth 10;[IO.File]::WriteAllText($path,$json,[Text.UTF8Encoding]::new($true));$read=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
 if($read.PayloadSha256-cne$script:PayloadHash -or @($read.Checks).Count-ne$script:Checks.Count){throw 'Report readback failed.'}
 return $path
}
$sources=@();$sample='';$fixture='';$reportPath=''
try {
 $sources=@(Read-EmbeddedSources)
 if($ParserOnly){if($PSVersionTable.PSVersion.Major-ne5 -or $PSVersionTable.PSVersion.Minor-ne1){throw 'ParserOnly requires Windows PowerShell 5.1.'};Write-Output 'FK_PARSER51_PASS:59';exit 0}
 Write-Host '';Write-Host 'FIELD // KIT // ACCEPTANCE CHECK' -ForegroundColor Cyan
 Write-Host 'One file. Dummy test data. No tenant changes. No module installs.'
 if([Environment]::OSVersion.Platform-eq[PlatformID]::Win32NT){Record 'Windows host' 'PASS' 'Windows detected.'}else{Record 'Windows host' 'FAIL' 'This run is not Windows acceptance.'}
 $script:Group='Local'
 $fixture=Join-Path ([IO.Path]::GetTempPath()) ('FIELD-KIT-VALIDATOR-'+[guid]::NewGuid().ToString('N'));$null=New-Item -ItemType Directory -Path $fixture -ErrorAction Stop
 Test-EmbeddedExports -sources $sources -fixture $fixture
 Test-EmbeddedInputs -sources $sources -dir $fixture
 Test-EmbeddedBranches -sources $sources -dir $fixture
 Record 'Embedded source tests' 'PASS' '59 sources parsed; 38 export/path suites, 43 input cases and 9 export branches completed.'
 if($PSVersionTable.PSVersion.Major-eq5 -and $PSVersionTable.PSVersion.Minor-eq1){Record 'Windows PowerShell 5.1' 'PASS' 'All embedded sources parsed and isolated checks ran in 5.1.'}
 elseif([Environment]::OSVersion.Platform-eq[PlatformID]::Win32NT){
  $legacy=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  if(Test-Path -LiteralPath $legacy){$child=@(& $legacy -NoLogo -NoProfile -NonInteractive -File $PSCommandPath -ParserOnly -NoPause 2>&1);if($LASTEXITCODE-ne0 -or 'FK_PARSER51_PASS:59'-notin$child){throw 'Windows PowerShell 5.1 child parser check failed.'};Record 'Windows PowerShell 5.1 parser' 'PASS' '59 embedded sources parsed in 5.1; function execution used current engine.'}else{Record 'Windows PowerShell 5.1 parser' 'FAIL' 'Windows PowerShell executable not found.'}
 }else{Record 'Windows PowerShell 5.1' 'SKIP' 'Unavailable on this host.'}
 $sample=Test-DesktopCsv $sources;Record 'Desktop CSV roundtrip' 'PASS' 'Actual candidate exporter: columns, quotes, commas, Unicode, multiline and unavailable status preserved.'
 Write-Host ('[PASS] Local checks complete. Sample CSV: '+$sample) -ForegroundColor Green
 if($LocalOnly){$script:Group='Live';Record 'Connections' 'SKIP' 'LocalOnly selected; no modules loaded or sign-in attempted.'}else{Test-LiveConnections}
}catch{if($ParserOnly){Write-Output ('FK_PARSER51_FAIL: '+(Get-SafeError $_));exit 1};Record 'Acceptance run' 'FAIL' (Get-SafeError $_)}
finally {
 if(-not$ParserOnly){
  Close-ValidatorConnections
  if($fixture -and (Test-Path -LiteralPath $fixture)){try{Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction Stop}catch{Record 'Temporary fixture cleanup' 'FAIL' 'Could not remove the validator temporary test directory.'}}
  try{$reportPath=Save-ValidationReport -Sources $sources -SamplePath $sample}catch{Record 'Save report' 'FAIL' (Get-SafeError $_)}
  Write-Host '';Write-Host 'SUMMARY' -ForegroundColor Cyan
  Write-Host ('PASS: '+@($script:Checks|Where-Object Status -eq 'PASS').Count+'   FAIL: '+@($script:Checks|Where-Object Status -eq 'FAIL').Count+'   SKIP: '+@($script:Checks|Where-Object Status -eq 'SKIP').Count)
  if($reportPath){Write-Host ('Report: '+$reportPath)}
  Write-Host 'This report does not mark operational workflows as verified or authorize release.'
  if(-not$NoPause){$null=Read-Host 'Press Enter to close'}
 }
}

if(@($script:Checks|Where-Object Status -eq 'FAIL').Count){exit 1}else{exit 0}
