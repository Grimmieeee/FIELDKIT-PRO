from pathlib import Path
import json,re,hashlib
root=Path(__file__).resolve().parents[2]; base=root/'dist'; out=root/'qa/desktop-standard/candidate';rows=json.loads((root/'qa/desktop-standard/source-ast.json').read_text(encoding='utf-8-sig'))
helper='''function Get-FKDesktopDirectory {
    $desktop=[Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)
    if ([string]::IsNullOrWhiteSpace($desktop) -or -not [IO.Directory]::Exists($desktop)) {
        throw 'Desktop is unavailable. Export was not saved; no alternate folder was used.'
    }
    return $desktop
}

function Get-FKDesktopExportPath {
    param([Parameter(Mandatory)][string]$DefaultName)
    $name=[IO.Path]::GetFileName($DefaultName)
    if ([string]::IsNullOrWhiteSpace($name) -or $name -ne $DefaultName -or $name -match '[<>:"/\\\\|?*]') { throw 'Export filename must be a filename without a custom path.' }
    $stem=[IO.Path]::GetFileNameWithoutExtension($name)
    $extension=[IO.Path]::GetExtension($name)
    return (Join-Path (Get-FKDesktopDirectory) ($stem+'-'+[guid]::NewGuid().ToString('N')+$extension))
}

'''
manifest=[]
for row in rows:
 p=base/row['path']; raw=p.read_bytes(); bom=raw.startswith(b'\xef\xbb\xbf'); text=raw.decode('utf-8-sig'); eol='\r\n' if b'\r\n' in raw else '\n';s=text.replace('\r\n','\n');original=s
 # Remove custom path/default blocks from the common CSV/JSON offers and inline mailbox export.
 pattern=r'(?im)^([ \t]*)\$path\s*=\s*\(?Read-Host [^\n]*(?:CSV output path|JSON output path)[^\n]*\n\s*\n?\s*if\s*\([^\n]*\$path[^\n]*\)\s*\{[^{}]*\}'
 s,n=re.subn(pattern,lambda m:m[1]+'$path=Get-FKDesktopExportPath -DefaultName $DefaultName',s)
 # User group export has a Desktop/current-directory fallback and a separate defaultPath.
 if p.name=='GET-USER-GROUPS.ps1':
  s,n2=re.subn(r"    \$desktop=\[Environment\]::GetFolderPath\('Desktop'\).*?    \$path=Get-FKDesktopExportPath -DefaultName \$DefaultName", '    $path=Get-FKDesktopExportPath -DefaultName $DefaultName',s,flags=re.S);assert n2==1
 # Existing HTML report offers: no selectable folder parameter or fallback prompt.
 s=s.replace(",[string]$DesktopFolder=[Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)","")
 s=s.replace('$folder=$DesktopFolder','$folder=Get-FKDesktopDirectory')
 s,n3=re.subn(r"        try \{\$saved=Save-FKDesktopReport.*?\n        \}\n        Write-Host",'        $saved=Save-FKDesktopReport -Folder $folder -Title $Title -Content $content\n        Write-Host',s,flags=re.S)
 # Shared BEC export folder resolver.
 for f in row['functions']:
  if f['name']=='Get-ExportPath':
   old=f['text'].replace('\r\n','\n'); assert old in s
   s=s.replace(old,'function Get-ExportPath {\n    param([string]$DefaultName)\n    return (Get-FKDesktopExportPath -DefaultName $DefaultName)\n}')
 # Disable and hold offers use a different prompt and preserve projection/readback.
 if p.name in ['INVOKE-DISABLE-ACCOUNTS.ps1','INVOKE-LITIGATION-HOLD.ps1']:
  begin=s.index('    $DesktopPath = [Environment]' if p.name.startswith('INVOKE-DISABLE') else '    $desktop = [Environment]')
  end=s.index('    $ExportRows = @(',begin) if p.name.startswith('INVOKE-DISABLE') else s.index('    $parent = Split-Path',begin)
  name='("account-disable-{0}.csv" -f (Get-Date -Format "yyyyMMdd-HHmmss"))' if p.name.startswith('INVOKE-DISABLE') else '$DefaultName'
  s=s[:begin]+'    $path=Get-FKDesktopExportPath -DefaultName '+name+'\n\n'+s[end:]
 # Resolver: retain exact-match safety and separate full CSV / clean TXT choices.
 if p.name=='RESOLVE-NAMES-TO-UPNS.ps1':
  s=s.replace('    $outputDirectory = Get-DefaultOutputDirectory -InputPath $inputPath\n','')
  s=s.replace('Join-Path $outputDirectory', 'Join-Path (Get-FKDesktopDirectory)')
  for var,default in [('exportPath','defaultExport'),('cleanPath','defaultClean')]:
   pat=r'(?m)^([ \t]*)\$'+var+r' = Normalize-InputValue \(Read-Host [^\n]+\)\n\s*if \(-not \$'+var+r'\) \{ \$'+var+r' = \$'+default+r' \}'
   s,k=re.subn(pat,lambda m:m[1]+'$'+var+' = Get-FKDesktopExportPath -DefaultName ([IO.Path]::GetFileName($'+default+'))',s);assert k==1
 # Deletion evidence uses its existing multi-file subfolder beneath Desktop.
 if p.name=='INVOKE-DELETE-ACCOUNTS.ps1':
  s=s.replace('function Test-UpnSyntax {\n    param([string]$Value)',"function Test-UpnSyntax {\n    param([Alias('UPN')][string]$Value)")
  f=next(f for f in row['functions'] if f['name']=='Get-DefaultOutputDirectory');old=f['text'].replace('\r\n','\n')
  s=s.replace(old,'''function Get-DefaultOutputDirectory {
    return (Join-Path (Get-FKDesktopDirectory) ('Bulk-Identity-Deletion-'+[guid]::NewGuid().ToString('N')))
}''')
  a=s.index('            $requestedExportPath = $OutputDir');b=s.index('            $export = Export-Evidence',a)
  s=s[:a]+'            $destination = Get-DefaultOutputDirectory\n\n'+s[b:]
  s=s.replace('[string]$OutputDir',"[ValidateScript({throw 'Custom export paths are no longer supported. Results export to Desktop.'})][string]$OutputDir")
 if p.name=='INVOKE-FILE-INVENTORY.ps1':
  a=s.index('        $desktop = [Environment]');b=s.index('        $stamp = Get-Date',a)
  s=s[:a]+'        $outputFolder=Get-FKDesktopDirectory\n\n'+s[b:]
 if s!=original:
  # Insert functions before first function, after the script parameter block.
  first=next(f for f in row['functions'] if f['text'].replace('\r\n','\n') in s)
  ix=s.index(first['text'].replace('\r\n','\n'));s=s[:ix]+helper+s[ix:]
  # Distinguish candidate revision; historical operator verification does not transfer.
  s,k=re.subn(r'(?im)(\.VERSION[ \t]+)(\d+\.\d+\.)(\d+)',lambda m:m[1]+m[2]+str(int(m[3])+1),s,count=1)
  dest=out/row['path'];dest.parent.mkdir(parents=True,exist_ok=True);data=(b'\xef\xbb\xbf' if bom else b'')+s.replace('\n',eol).encode();dest.write_bytes(data)
  manifest.append({'path':row['path'],'baseline_sha256':hashlib.sha256(raw).hexdigest(),'candidate_sha256':hashlib.sha256(data).hexdigest(),'status':'CANDIDATE_UNVERIFIED','common_path_replacements':n,'html_fallbacks_removed':n3})
(root/'qa/desktop-standard/candidate-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print('Changed candidate files:',len(manifest))
