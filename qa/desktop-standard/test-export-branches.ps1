$ErrorActionPreference='Stop';$root='/workspace/sites/field-kit-release';$candidate="$root/qa/desktop-standard/candidate"
$dir=Join-Path ([IO.Path]::GetTempPath()) ('fk-branches-'+[guid]::NewGuid().ToString('N'));$null=New-Item -ItemType Directory $dir;$report=[Collections.Generic.List[object]]::new()
$files=@('published-source/incident-response/BEC-GET-DATA-EXFIL-ACTIVITY.ps1','published-source/incident-response/BEC-GET-IP-TRACE.ps1','published-source/incident-response/BEC-GET-TENANT-EMAIL-SEARCH.ps1','published-source/incident-response/BEC-GET-THREAT-INTEL-ACTIVITY.ps1','published-source/incident-response/BEC-GET-TIMELINE-BUILDER.ps1','published-source/tenant/GET-TENANT-MAILBOX-ACCESS-AUDIT.ps1','tools/INVOKE-FILE-INVENTORY.ps1')
foreach($file in $files){
 $t=$null;$e=$null;$a=[Management.Automation.Language.Parser]::ParseFile("$candidate/$file",[ref]$t,[ref]$e)
 & {
  param($a,$dir,$file,$report)
  foreach($f in $a.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -in @('Get-FKDesktopDirectory','Get-FKDesktopExportPath','Get-ExportPath')},$true)){. ([scriptblock]::Create($f.Extent.Text))}
  function Get-FKDesktopDirectory {return $dir};function Read-Host {throw 'Unexpected output path prompt'};function Confirm-Yes {return $true};function OK {param($m)};function Write-OK {param($m)}
  $data=@([pscustomobject]@{UPN='one@example.test';Result='Unavailable';Detail='Read failed';Scope='Local';File='fixture.ps1';RelativePath='fixture.ps1';Modified='fixture';Length=1})
  $results=$data;$rows=$data;$records=$data;$inventoryRows=$data;$signatureRows=$data;$duplicateRows=$data;$cleanupRows=$data;$export='Y';$ExportCsv=$false;$ExportTxt=$false
  $events=@([pscustomobject]@{Time=[datetime]'2026-01-01';TimeBasis='UTC';Phase='Assess';Action='Read';Detail='Unavailable fixture'})
  $blocks=@($a.FindAll({param($n)$n -is [Management.Automation.Language.IfStatementAst] -and $n.Clauses[0].Item1.Extent.Text -match 'ExportCsv|ExportTxt|\$export -match|Export results to CSV' -and $n.Extent.Text -match 'Export-Csv|Out-File'},$true))
  if($blocks.Count-ne1){throw "$file expected one isolated export branch, got $($blocks.Count)"}
  $before=@((Get-ChildItem $dir -File).FullName);. ([scriptblock]::Create($blocks[0].Extent.Text));$new=@(Get-ChildItem $dir -File|Where-Object {$_.FullName -notin $before})
  $expected=if($file-eq'tools/INVOKE-FILE-INVENTORY.ps1'){4}else{1};if($new.Count-ne$expected){throw "$file expected $expected outputs, got $($new.Count)"}
  foreach($f in $new){if($f.Extension-eq'.csv'){if(@(Import-Csv $f.FullName).Count-ne1){throw 'CSV row lost'}}else{if(-not(Get-Content $f.FullName -Raw).Contains('Unavailable fixture')){throw 'TXT evidence lost'}}}
  $report.Add([pscustomobject]@{path=$file;result='PASS';outputs=$new.Count})
 } $a $dir $file $report
}
# Deletion: exercise only the evidence writer, never account actions.
$t=$null;$e=$null;$a=[Management.Automation.Language.Parser]::ParseFile("$candidate/published-source/identity/INVOKE-DELETE-ACCOUNTS.ps1",[ref]$t,[ref]$e)
& {
 param($a,$dir,$report)
 foreach($f in $a.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -in @('Get-FKDesktopDirectory','Get-DefaultOutputDirectory','Export-Evidence')},$true)){. ([scriptblock]::Create($f.Extent.Text))}
 function Get-FKDesktopDirectory {return $dir};$dest=Get-DefaultOutputDirectory
 $rows=@([pscustomobject]@{UPN='one@example.test';Status='Failed';Authority='Entra';Reason='Unavailable';TechnicalError='Fixture'})
 $null=Export-Evidence -Results $rows -Destination $dest -TenantName 'fixture' -SyncResult ([pscustomobject]@{Attempted=$false;Success=$false;Server='';Detail='Not attempted';Status='Skipped'})
 if(@(Get-ChildItem $dest -File).Count-ne2){throw 'Evidence pair missing'}
 if(-not(Get-Content (Join-Path $dest 'identity-deletion-summary.txt') -Raw).Contains('Unavailable')){throw 'Failure reason lost'}
 $report.Add([pscustomobject]@{path='INVOKE-DELETE-ACCOUNTS.ps1';result='PASS';outputs=2})
} $a $dir $report
# Resolver's two export branches: exact-match TXT and full review CSV stay distinct.
$t=$null;$e=$null;$a=[Management.Automation.Language.Parser]::ParseFile("$candidate/published-source/identity/RESOLVE-NAMES-TO-UPNS.ps1",[ref]$t,[ref]$e)
& {
 param($a,$dir,$report)
 foreach($f in $a.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -in @('Get-FKDesktopDirectory','Get-FKDesktopExportPath','Export-VerifiedCsv','Export-VerifiedUpnTxt','Normalize-InputValue')},$true)){. ([scriptblock]::Create($f.Extent.Text))}
 function Get-FKDesktopDirectory {return $dir};function OK {param($m)};function WARN {param($m)};function INFO {param($m)};function Read-Host {throw 'Unexpected path prompt'}
 $export='Y';$exportClean='Y';$allRows=@([pscustomobject]@{UPN='one@example.test';Result='Exact'});$exactUpns=@('one@example.test')
 $blocks=@($a.FindAll({param($n)$n -is [Management.Automation.Language.IfStatementAst] -and $n.Clauses[0].Item1.Extent.Text -match '^\$export(?:Clean)? -match'},$true))
 if($blocks.Count-ne2){throw 'Resolver branch selection failed'}
 $before=@((Get-ChildItem $dir -File).FullName);foreach($b in $blocks){. ([scriptblock]::Create($b.Extent.Text))}
 $new=@(Get-ChildItem $dir -File|Where-Object {$_.FullName-notin$before});if($new.Count-ne2){throw 'Resolver export pair missing'}
 foreach($f in $new){if(-not(Get-Content $f.FullName -Raw).Contains('one@example.test')){throw 'Resolver target lost'}}
 $report.Add([pscustomobject]@{path='RESOLVE-NAMES-TO-UPNS.ps1';result='PASS';outputs=2})
} $a $dir $report
$report|ConvertTo-Json -Depth 6|Set-Content "$root/qa/desktop-standard/branch-test-results.json";Write-Host "PASS: $($report.Count) isolated export branches"
