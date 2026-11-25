from pathlib import Path
import json,gzip,base64,hashlib
root=Path(__file__).resolve().parents[2];out=root/'qa/standalone-validator';qa=root/'qa/desktop-standard';lock=json.loads((qa/'LOCK.json').read_text());manifest=json.loads((root/'qa/release-manifest.json').read_text()); changed={r['path']:r['sha256'] for r in lock['files']};sources=[]
for row in manifest['source_files']:
 if row['status']!='enabled' or not row['path'].endswith('.ps1'):continue
 p=(qa/'candidate'/row['path']) if row['path'] in changed else (root/'dist'/row['path']);b=p.read_bytes();h=hashlib.sha256(b).hexdigest();assert h==changed.get(row['path'],row['sha256']);sources.append({'path':row['path'],'sha256':h,'changed':row['path'] in changed,'bytes':base64.b64encode(b).decode()})
payload=json.dumps({'baseline':'e9099d82f548c19bf4225fabe3e2e520a78d4ad2','sources':sources},separators=(',',':')).encode();encoded=base64.b64encode(gzip.compress(payload,mtime=0)).decode()
# Carry the already-executed isolated test harnesses forward, without source-tree dependencies.
s=(qa/'test-candidates.ps1').read_text();a=s.index('foreach($r in $m.source_files');b=s.index('$report=[pscustomobject]',a);s=s[a:b];start=s.index(' $p=Join-Path');end=s.index(' # Load ONLY',start)
s=s[:start]+''' $ast=$r.ast;$funcs=$r.functions
 Record $r.path 'PASS' 'Embedded SHA-256 and PowerShell parser'
 if(-not $r.changed){continue}
'''+s[end:];s=s.replace("foreach($r in $m.source_files|Where-Object {$_.status -eq 'enabled' -and $_.path.EndsWith('.ps1')})",'foreach($r in $sources)');s=s.replace("function Write-OK {param($m)}", "function Write-Host {param($Object,$ForegroundColor)};function Write-OK {param($m)}")
exports='function Test-EmbeddedExports {\nparam($sources,[string]$fixture)\n'+s+'\n}\n'
s=(qa/'test-inputs.ps1').read_text();a=s.index('$txt=Join-Path');b=s.index('$results|ConvertTo-Json',a);s=s[a:b];a=s.index(' $p="$root/qa');b=s.index(' $functions=@(',a);s=s[:a]+s[b:];s=s.replace('$results=[Collections.Generic.List[object]]::new()','$results=[Collections.Generic.List[object]]::new()');s=s.replace('foreach($row in $rows)','foreach($row in $sources)');s+='\nforeach($result in $results){Record ($result.path+" / "+$result.format) $result.result "Isolated input loader"}\n'
inputs='function Test-EmbeddedInputs {\nparam($sources,[string]$dir)\n'+s+'\n}\n'
s=(qa/'test-export-branches.ps1').read_text();a=s.index('$files=@(');b=s.index('$report|ConvertTo-Json',a);s=s[a:b];s=s.replace('$a=[Management.Automation.Language.Parser]::ParseFile("$candidate/$file",[ref]$t,[ref]$e)','$a=($sources|Where-Object path -eq $file).ast');s=s.replace('$a=[Management.Automation.Language.Parser]::ParseFile("$candidate/published-source/identity/INVOKE-DELETE-ACCOUNTS.ps1",[ref]$t,[ref]$e)',"$a=($sources|Where-Object path -eq 'published-source/identity/INVOKE-DELETE-ACCOUNTS.ps1').ast");s=s.replace('$a=[Management.Automation.Language.Parser]::ParseFile("$candidate/published-source/identity/RESOLVE-NAMES-TO-UPNS.ps1",[ref]$t,[ref]$e)',"$a=($sources|Where-Object path -eq 'published-source/identity/RESOLVE-NAMES-TO-UPNS.ps1').ast");s+='\nforeach($result in $report){Record $result.path $result.result ("Isolated export branch; "+$result.outputs+" output(s)")}\n'
branches='function Test-EmbeddedBranches {\nparam($sources,[string]$dir)\n$report=[Collections.Generic.List[object]]::new()\n'+s+'\n}\n'
main=(out/'main.ps1').read_text();main=main.replace('__PAYLOAD__',encoded).replace('__PAYLOAD_SHA__',hashlib.sha256(payload).hexdigest()).replace('__HARNESSES__',exports+'\n'+inputs+'\n'+branches)
dest=out/'VERIFY-FIELD-KIT.ps1';dest.write_bytes(b'\xef\xbb\xbf'+main.replace('\n','\r\n').encode());print(str(dest));print('Embedded sources:',len(sources),'File bytes:',dest.stat().st_size)
