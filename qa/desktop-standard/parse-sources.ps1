$root='/workspace/sites/field-kit-release'
$m=Get-Content "$root/qa/release-manifest.json" -Raw|ConvertFrom-Json
$rows=foreach($r in $m.source_files|Where-Object {$_.status -eq 'enabled' -and $_.path.EndsWith('.ps1')}){
 $tokens=$null;$errors=$null;$ast=[System.Management.Automation.Language.Parser]::ParseFile("$root/dist/$($r.path)",[ref]$tokens,[ref]$errors)
 [pscustomobject]@{path=$r.path;errors=@($errors|ForEach-Object {$_.Message});functions=@($ast.FindAll({param($a)$a -is [System.Management.Automation.Language.FunctionDefinitionAst]},$true)|ForEach-Object {[pscustomobject]@{name=$_.Name;start=$_.Extent.StartOffset;end=$_.Extent.EndOffset;text=$_.Extent.Text}})}
}
$rows|ConvertTo-Json -Depth 8|Set-Content "$root/qa/desktop-standard/source-ast.json"
