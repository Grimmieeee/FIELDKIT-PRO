$ErrorActionPreference='Stop';$root='/workspace/sites/field-kit-release';$rows=Get-Content "$root/qa/desktop-standard/source-ast.json" -Raw|ConvertFrom-Json
$dir=Join-Path ([IO.Path]::GetTempPath()) ('fk-inputs-'+[guid]::NewGuid().ToString('N'));$null=New-Item -ItemType Directory $dir
$txt=Join-Path $dir 'targets.txt';$csv=Join-Path $dir 'targets.csv'
@('one@example.test','two@example.test')|Set-Content $txt
"UPN`none@example.test`ntwo@example.test"|Set-Content $csv
$results=[Collections.Generic.List[object]]::new()
foreach($row in $rows){
 $p="$root/qa/desktop-standard/candidate/$($row.path)"
 if(Test-Path $p){$t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($p,[ref]$t,[ref]$e);$row.functions=@($ast.FindAll({param($a)$a -is [Management.Automation.Language.FunctionDefinitionAst]},$true)|ForEach-Object {[pscustomobject]@{name=$_.Name;text=$_.Extent.Text}})}
 $functions=@($row.functions|Where-Object {$_.name -in @('Get-InputUPNs','Get-InputUsers','Get-MailboxInputs','Get-InputValues','Get-InputLines','Get-InputGroups','Import-InputEntries')})
 foreach($f in $functions){
  & {
   param($row,$f,$txt,$csv,$results)
   foreach($helper in $row.functions|Where-Object {$_.name -in @('Normalize-InputValue','Get-CsvInputColumn','Test-UpnSyntax')}){. ([scriptblock]::Create($helper.text))}
   . ([scriptblock]::Create($f.text));function FAIL {param($m)throw $m};function WARN {param($m)};function Write-Warn {param($m)};function Write-OK {param($m)};function Write-Info {param($m)};function INFO {param($m)};function OK {param($m)};function Read-Host {throw 'Unexpected prompt in explicit-input fixture'}
   $cmd=Get-Command $f.name
   foreach($path in @($txt,$csv)){
    if($cmd.Parameters.ContainsKey('Path')){$actual=& $f.name -Path $path}else{$actual=& $f.name -Values @($path)}
    $json=ConvertTo-Json -InputObject $actual -Depth 10
    if(-not($json.Contains('one@example.test')-and$json.Contains('two@example.test'))){throw "$($row.path) $($f.name) lost target: $json"}
    $results.Add([pscustomobject]@{path=$row.path;function=$f.name;format=[IO.Path]::GetExtension($path);result='PASS'})
   }
   if($cmd.Parameters.ContainsKey('Values')){
    $actual=& $f.name -Values @('one@example.test','two@example.test');$json=ConvertTo-Json -InputObject $actual -Depth 10
    if(-not($json.Contains('one@example.test')-and$json.Contains('two@example.test'))){throw 'Direct targets lost'}
    $results.Add([pscustomobject]@{path=$row.path;function=$f.name;format='direct';result='PASS'})
   }
  } $row $f $txt $csv $results
 }
}
$results|ConvertTo-Json -Depth 6|Set-Content "$root/qa/desktop-standard/input-test-results.json";Write-Host "PASS: $($results.Count) input checks"
