$bad=0
Get-ChildItem (Join-Path (Split-Path $PSScriptRoot -Parent) 'candidates') -Recurse -Filter '*.ps1' | ForEach-Object {
$t=$null;$e=$null
[void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$t,[ref]$e)
if($e.Count){$bad++;$e|ForEach-Object {Write-Output $_.ToString()}}else{Write-Output ('PASS: '+$_.Name)}
}
exit $bad
