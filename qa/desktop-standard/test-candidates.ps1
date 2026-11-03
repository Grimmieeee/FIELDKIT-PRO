$ErrorActionPreference='Stop'
$root='/workspace/sites/field-kit-release';$candidate="$root/qa/desktop-standard/candidate";$results=[Collections.Generic.List[object]]::new()
function Record($name,$status,$detail){$results.Add([pscustomobject]@{name=$name;result=$status;detail=$detail})}
$m=Get-Content "$root/qa/release-manifest.json" -Raw|ConvertFrom-Json
$manifest=Get-Content "$root/qa/desktop-standard/candidate-manifest.json" -Raw|ConvertFrom-Json
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('fk-export-test-'+[guid]::NewGuid().ToString('N'));$null=New-Item -ItemType Directory $fixture
foreach($r in $m.source_files|Where-Object {$_.status -eq 'enabled' -and $_.path.EndsWith('.ps1')}) {
 $p=Join-Path $candidate $r.path;if(-not(Test-Path $p)){$p="$root/dist/$($r.path)"}
 $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($p,[ref]$tokens,[ref]$errors)
 if($errors.Count){throw "$p parser errors: $($errors.Message -join '; ')"};Record $r.path 'PASS' 'PowerShell parser'
 if(-not ($manifest.path -contains $r.path)){continue}
 $funcs=@($ast.FindAll({param($a)$a -is [Management.Automation.Language.FunctionDefinitionAst]},$true))
 # Load ONLY source-reviewed export functions into this isolated scope. Never load script entrypoints.
 & {
  param($funcs,$fixture,$path)
  $allowed=@('Get-FKDesktopDirectory','Get-FKDesktopExportPath','Offer-VerifiedCsv','Offer-ExportCsv','Offer-ExportJson','ConvertTo-FKDesktopReport','Save-FKDesktopReport','Offer-FKDesktopReport','Get-ExportPath','Get-DefaultOutputDirectory','Export-VerifiedCsv','Export-VerifiedUpnTxt')
  foreach($f in $funcs|Where-Object {$_.Name -in $allowed}){. ([scriptblock]::Create($f.Extent.Text))}
  function Assert($ok,$message){if(-not $ok){throw "$path : $message"}}
  # Actual Desktop resolver must fail closed on Linux with no Desktop; no current-directory fallback.
  if([string]::IsNullOrWhiteSpace([Environment]::GetFolderPath('DesktopDirectory'))){$failed=$false;try{$null=Get-FKDesktopDirectory}catch{$failed=$true};Assert $failed 'missing Desktop must fail'}
  function Get-FKDesktopDirectory {return $fixture}
  $p1=Get-FKDesktopExportPath 'roundtrip.csv';$p2=Get-FKDesktopExportPath 'roundtrip.csv'
  Assert ((Split-Path $p1 -Parent)-eq $fixture) 'destination';Assert ($p1-ne$p2) 'unique filenames'
  foreach($bad in @('../escape.csv','C:\elsewhere\test.csv','sub/report.csv','')){$failed=$false;try{$null=Get-FKDesktopExportPath $bad}catch{$failed=$true};Assert $failed "reject custom filename/path $bad"}
  $script:Answer='N';$script:PromptCount=0
  function Read-Host {param($Prompt)$script:PromptCount++;if($Prompt -match '(?i)(output path|export path|output folder|report folder|enter csv path)'){throw 'Unexpected custom export prompt'};return $script:Answer}
  function Confirm-Yes {param($Prompt)return ($script:Answer-eq'Y')}
  function Write-OK {param($m)};function OK {param($m)};function WARN {param($m)throw $m}
  $data=@([pscustomobject]@{UPN='one@example.test';Result='Complete';Detail='comma, quote " and Unicode é'},[pscustomobject]@{UPN='two@example.test';Result='Unavailable';Detail='Read failed'})
  foreach($name in @('Offer-VerifiedCsv','Offer-ExportCsv','Offer-ExportJson')){
   if($funcs.Name -notcontains $name){continue}
   $before=@(Get-ChildItem $fixture -File).Count;$script:Answer='N';$script:PromptCount=0
   if($name-eq'Offer-ExportJson'){& $name -Object @{Rows=$data} -DefaultName 'snapshot.json'}else{ $cmd=Get-Command $name;if($cmd.Parameters.ContainsKey('DefaultName')){& $name -Rows $data -DefaultName 'rows.csv'}else{& $name -Rows $data}}
   Assert (@(Get-ChildItem $fixture -File).Count-eq$before) 'decline causes zero writes'
   $script:Answer='Y';$beforeNames=@((Get-ChildItem $fixture -File).FullName)
   if($name-eq'Offer-ExportJson'){& $name -Object @{Rows=$data} -DefaultName 'snapshot.json'}else{$cmd=Get-Command $name;if($cmd.Parameters.ContainsKey('DefaultName')){& $name -Rows $data -DefaultName 'rows.csv'}else{& $name -Rows $data}}
   $written=@(Get-ChildItem $fixture -File|Where-Object {$_.FullName -notin $beforeNames});Assert ($written.Count-eq1) 'one output'
   if($name-eq'Offer-ExportJson'){$roundtrip=Get-Content $written[0].FullName -Raw|ConvertFrom-Json;Assert ($roundtrip.Rows.Count-eq2) 'JSON roundtrip'}else{$roundtrip=@(Import-Csv $written[0].FullName);Assert ($roundtrip.Count-eq2) 'CSV row count';Assert ($roundtrip[1].Result-eq'Unavailable') 'failure status preserved'}
   function Get-FKDesktopDirectory {throw 'Desktop unavailable fixture'}
   $before=@(Get-ChildItem $fixture -File).Count;try{if($name-eq'Offer-ExportJson'){& $name -Object @{Rows=$data} -DefaultName 'x.json'}elseif((Get-Command $name).Parameters.ContainsKey('DefaultName')){& $name -Rows $data -DefaultName 'x.csv'}else{& $name -Rows $data}}catch{}
   Assert (@(Get-ChildItem $fixture -File).Count-eq$before) 'missing Desktop writes nothing'
   function Get-FKDesktopDirectory {return $fixture}
  }
  if($funcs.Name -contains 'Offer-FKDesktopReport'){
   $script:FKReportLines=[Collections.Generic.List[string]]::new();$script:FKReportLines.Add('STATUS: Unavailable <tag>');$script:FKReportWarnings=@('Read failed');$script:FKReportStartedUtc='fixture'
   $script:Answer='Y';$beforeNames=@((Get-ChildItem $fixture -File).FullName);Offer-FKDesktopReport -Title 'Fixture'
   $written=@(Get-ChildItem $fixture -File|Where-Object {$_.FullName -notin $beforeNames});Assert ($written.Count-eq1) 'HTML report saved';$html=Get-Content $written[0].FullName -Raw;Assert ($html.Contains('Unavailable') -and $html.Contains('&lt;tag&gt;')) 'HTML output preserved and escaped'
  }
  if($funcs.Name -contains 'Get-ExportPath'){$p=Get-ExportPath 'evidence.csv';Assert ((Split-Path $p -Parent)-eq$fixture) 'BEC Desktop path'}
 } $funcs $fixture $r.path
 Record $r.path 'PASS' 'Isolated export/path checks; entrypoint not executed'
}
$report=[pscustomobject]@{scope='PowerShell parser and isolated extracted export functions; no Graph, EXO, AD or full script entrypoints executed';results=$results}
$report|ConvertTo-Json -Depth 8|Set-Content "$root/qa/desktop-standard/test-results.json"
Write-Host "PASS: $($results.Count) checks"
