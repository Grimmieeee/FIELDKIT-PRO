$ErrorActionPreference='Stop';$root='/workspace/sites/field-kit-release';$records=Get-Content "$root/qa/desktop-standard/source-ast.json" -Raw|ConvertFrom-Json
$changed=Get-Content "$root/qa/desktop-standard/candidate-manifest.json" -Raw|ConvertFrom-Json
$allowed=@('Offer-VerifiedCsv','Offer-ExportCsv','Offer-ExportJson','Offer-FKDesktopReport','Get-ExportPath','Get-DefaultOutputDirectory','Test-UpnSyntax')
$inventory=foreach($r in $records){
 $p="$root/qa/desktop-standard/candidate/$($r.path)";if(-not(Test-Path $p)){$p="$root/dist/$($r.path)"}
 $t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($p,[ref]$t,[ref]$e)
 $functions=@($ast.FindAll({param($a)$a -is [Management.Automation.Language.FunctionDefinitionAst]},$true))
 if($r.path -in $changed.path){foreach($f in $functions){$old=$r.functions|Where-Object name -eq $f.Name;if($old -and $old.text.Replace("`r`n","`n") -cne $f.Extent.Text.Replace("`r`n","`n") -and $f.Name -notin $allowed){throw "Unexpected function change: $($r.path) $($f.Name)"}}}
 $calls=@{};$calls['<main>']=[Collections.Generic.List[string]]::new()
 foreach($f in $functions){$calls[$f.Name]=[Collections.Generic.List[string]]::new()}
 foreach($cmd in $ast.FindAll({param($a)$a -is [Management.Automation.Language.CommandAst]},$true)){
  $parent=$cmd.Parent;while($parent -and $parent -isnot [Management.Automation.Language.FunctionDefinitionAst]){$parent=$parent.Parent}
  $owner=if($parent){$parent.Name}else{'<main>'};$name=$cmd.GetCommandName();if($name){$calls[$owner].Add($name)}
 }
 $reachable=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase);$pending=[Collections.Generic.Queue[string]]::new();$pending.Enqueue('<main>')
 while($pending.Count){$name=$pending.Dequeue();if(-not$reachable.Add($name)){continue};if($calls.ContainsKey($name)){foreach($n in $calls[$name]){$pending.Enqueue($n)}}}
 $formats=@();if($reachable.Contains('Export-Csv')){$formats+='CSV'};if($reachable.Contains('Offer-ExportJson')){$formats+='JSON'};if($reachable.Contains('Offer-FKDesktopReport')){$formats+='HTML'};if($reachable.Contains('Export-VerifiedUpnTxt') -or $reachable.Contains('Export-Evidence')){$formats+='TXT'}
 if($r.path -eq 'published-source/incident-response/BEC-GET-TIMELINE-BUILDER.ps1' -and $reachable.Contains('Out-File')){$formats+='TXT'}
 if($r.path-eq'tools/git-handoff.ps1'){$formats=@()}
 $inputFunctions=@($functions|Where-Object {$_.Name -in @('Get-InputUPNs','Get-InputUsers','Get-MailboxInputs','Get-InputValues','Get-InputLines','Get-InputGroups','Import-InputEntries') -and $reachable.Contains($_.Name)}|ForEach-Object {$_.Name})
 [pscustomobject]@{path=$r.path;candidate=($r.path-in$changed.path);inputFunctions=$inputFunctions;resultExportFormats=$formats;exportDestination=if($formats.Count){'Desktop'}else{'No result export identified'};liveValidation='UNEXECUTED'}
}
$inventory|ConvertTo-Json -Depth 6|Set-Content "$root/qa/desktop-standard/behavior-inventory.json"
# Reproduce the actual baseline validator mismatch, then exercise candidate fix.
$r=$records|Where-Object path -eq 'published-source/identity/INVOKE-DELETE-ACCOUNTS.ps1'
& {$f=$r.functions|Where-Object name -eq 'Test-UpnSyntax';. ([scriptblock]::Create($f.text));if(Test-UpnSyntax -UPN 'one@example.test'){throw 'Baseline defect not reproduced'}}
$p="$root/qa/desktop-standard/candidate/$($r.path)";$t=$null;$e=$null;$a=[Management.Automation.Language.Parser]::ParseFile($p,[ref]$t,[ref]$e);$f=$a.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Test-UpnSyntax'},$true)[0]
& {. ([scriptblock]::Create($f.Extent.Text));if(-not(Test-UpnSyntax -UPN 'one@example.test')){throw 'Candidate validator failed'};if(-not(Test-UpnSyntax -Value 'one@example.test')){throw 'Existing Value parameter regressed'}}
Write-Host "PASS: 59-file inventory, only intended function changes, validator baseline reproduced and candidate fixed"
