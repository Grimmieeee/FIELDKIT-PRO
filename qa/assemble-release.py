from pathlib import Path
import hashlib, json, re, subprocess

ROOT = Path(__file__).resolve().parents[1]
PAGE = ROOT / 'dist/index.html'
BASELINE = ROOT / 'release-baseline'
PIN = 'af51d3cf7e59975112d62480a4377d4c2a2c40f5'
maps = json.loads((ROOT / 'qa/catalog-revision-map.json').read_text())
old = maps['baselineMaps']
preview = maps['previewMaps']
catalog = json.loads((BASELINE / 'catalog-data.json').read_text())
integrity = old['FIELD_KIT_SOURCE_INTEGRITY']
held = {
    'INVOKE-ASSIGN-LICENSES.ps1', 'INVOKE-REMOVE-LICENSES.ps1',
    'GET-APP-REGISTRATION-AUDIT.ps1', 'GET-OAUTH-CONSENT-AUDIT.ps1',
    'GET-TENANT-LICENSING-AUDIT.ps1',
    'GET-GUEST-APP-CONSENT-AUDIT.ps1', 'GET-SERVICE-PRINCIPAL-OWNERS.ps1',
    'GET-ROOM-RESOURCE-ACCESS.ps1',
}
release = {}
rows = []
for path, expected in preview['FIELD_KIT_SOURCE_INTEGRITY'].items():
    name = Path(path).name
    op = old.get('FIELD_KIT_OPERATOR_CARDS', {}).get(name)
    eligible = path in integrity and name not in held and (path.endswith('.md') or op and op.get('sourceSha256') == integrity[path])
    reason = 'Established published source and source-bound guidance' if eligible else ('Updated candidate withheld pending Windows/tenant validation' if name in held else 'No established source and matching operator guidance at this path')
    row = {'path': path, 'preview_sha256': expected, 'status': 'enabled' if eligible else 'withheld', 'reason': reason}
    if eligible:
        payload = (BASELINE / 'payload' / path).read_bytes()
        assert hashlib.sha256(payload).hexdigest() == integrity[path], path
        target = ROOT / 'dist' / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(payload)
        row['sha256'] = integrity[path]
        baseline_item = next((x for x in catalog if x.get('publishedPath') == path), {})
        guidance = old.get('FIELD_KIT_CARD_GUIDANCE', {}).get(name, {})
        if guidance and guidance.get('sourceSha256') != integrity[path]:
            raise ValueError('Baseline guidance mismatch: ' + name)
        release[name] = {
            **baseline_item, **guidance,
            'publishedPath': path, 'file': name,
            'operatorCard': op,
            'version': (op or {}).get('releaseVersion', baseline_item.get('version', '')),
            'verification': baseline_item.get('verification'),
            'candidateNotice': '', 'releaseState': 'established',
        }
        if op and op.get('objective'):
            release[name]['objective'] = op['objective']
        for key in ['FIELD_KIT_CARD_GUIDANCE', 'FIELD_KIT_OPERATOR_CARDS']:
            if name in old.get(key, {}):
                preview.setdefault(key, {})[name] = old[key][name]
        if path in old.get('FIELD_KIT_CONNECTION_GUIDANCE', {}):
            preview.setdefault('FIELD_KIT_CONNECTION_GUIDANCE', {})[path] = old['FIELD_KIT_CONNECTION_GUIDANCE'][path]
    rows.append(row)

# Pin release bytes independently from the preview's historical source references.
allowed = {r['path']: r['sha256'] for r in rows if r['status'] == 'enabled'}
manifest = {'baseline_repository': 'Grimmieeee/pwsh-operations-catalog', 'baseline_commit': PIN,
            'source_files': rows, 'enabled': len(allowed), 'withheld': len(rows)-len(allowed),
            'windows_validation': 'UNEXECUTED', 'live_tenant_validation': 'UNEXECUTED'}
(ROOT / 'qa/release-manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
(ROOT / 'dist/SHA256SUMS.txt').write_text(''.join(f'{h}  {p}\n' for p,h in sorted(allowed.items())))

html = subprocess.check_output(['git', 'show', '0c8463b72d9c37207e7625113328377f942597c6:dist/index.html'], cwd=ROOT).decode('utf-8')
assert 'FIELD_KIT_RELEASE_ITEMS' not in html, 'Run against the frozen checkpoint only'
overlay = {'FIELD_KIT_SOURCE_INTEGRITY': {**preview['FIELD_KIT_SOURCE_INTEGRITY'], **allowed},
           'FIELD_KIT_RELEASE_SOURCES': allowed, 'FIELD_KIT_RELEASE_ITEMS': release,
           **{key: preview[key] for key in ['FIELD_KIT_CARD_GUIDANCE','FIELD_KIT_OPERATOR_CARDS','FIELD_KIT_CONNECTION_GUIDANCE']}}
script = '<script>\n' + '\n'.join('window.'+k+' = Object.freeze('+json.dumps(v,ensure_ascii=False)+');' for k,v in overlay.items()) + '\n</script>\n'
marker = '<script>\n(() => {\n  const TAXONOMY ='
if marker not in html:
    match = next((m for m in re.finditer(r'<script>[\s\S]*?</script>', html) if 'const TAXONOMY =' in m[0]), None)
    assert match, 'Catalog entry point not found'
    html = html[:match.start()] + script + html[match.start():]
else:
    html = html.replace(marker, script+marker, 1)
needle = '    const area = logicalArea(source);\n    return {'
assert needle in html
html = html.replace(needle, '''    // Release metadata comes from the same pinned source as the downloadable bytes.
    const established = window.FIELD_KIT_RELEASE_ITEMS?.[source.file];
    if (established) source = {...source, ...established};
    else if (source.publishedPath) source.releaseState = 'withheld';
''' + needle, 1)
needle = '    const expected = window.FIELD_KIT_SOURCE_INTEGRITY?.[value];'
assert needle in html
html = html.replace(needle, '''    if (!Object.hasOwn(window.FIELD_KIT_RELEASE_SOURCES || {}, value)) {
      throw new Error('This source is withheld from this release pending validation.');
    }
''' + needle, 1)
needle = '    const ext = /\\.md$/i.test(item.file || "") ? ".MD" : ".ps1";'
assert needle in html
html = html.replace(needle, '''    if (item.publishedPath && !Object.hasOwn(window.FIELD_KIT_RELEASE_SOURCES || {}, item.publishedPath)) {
      return '<span class="source-note">Download withheld pending validation.</span>';
    }
''' + needle, 1)
needle = '''      if (item.publishedPath){
        try { approvedSourceUrl(item.publishedPath); }
        catch { issues.push("Unapproved source: " + item.displayName); }
      }'''
assert needle in html
html = html.replace(needle, '''      if (item.publishedPath){
        if (item.releaseState === 'withheld') {
          if (Object.hasOwn(window.FIELD_KIT_RELEASE_SOURCES || {}, item.publishedPath) ||
              /id="(?:downloadSource|showSource)"/.test(sourceButton(item))) {
            issues.push("Withheld source is accessible: " + item.displayName);
          }
        } else {
          try { approvedSourceUrl(item.publishedPath); }
          catch { issues.push("Unapproved source: " + item.displayName); }
        }
      }''', 1)
lock = re.compile(r'// UI proof: real hosted catalog resolves and verifies source downloads separately\.\n\(\(\)=>\{const ids=\[.*?lock\(\);\}\)\(\);', re.S)
html, count = lock.subn('// Download eligibility is enforced by the pinned release manifest and source resolver.', html)
assert count == 1, 'Preview source lock not found'
html = html.replace('cache:"no-store", credentials:"omit", redirect:"error", signal:controller.signal',
                    'cache:"no-store", credentials:"same-origin", redirect:"error", signal:controller.signal')
html = html.replace("// Each downloaded proof opens in the approved light palette. The switch still offers dark.\nwindow.FIELD_KIT_APPEARANCE?.setTheme('light');",
                    '// The appearance bootstrap preserves the saved theme; first use defaults to light.')
# Display names change; canonical companion script names and payload bytes do not.
html = html.replace('Contain and Clean Up', 'Contain and Eradicate').replace('Contain and clean up', 'Contain and eradicate').replace('contain and clean up', 'contain and eradicate')
start = html.index('  function operatorInputInstruction(item){')
end = html.index('  function startMarkup(item){', start)
html = html[:start] + '''  function operatorInputInstruction(item){
    const input=String(item.operatorCard?.input || item.input || '').trim();
    const specific={
      'RESOLVE-NAMES-TO-UPNS.ps1':'<name or email> or <CSV/TXT path>',
      'INVOKE-CREATE-DYNAMIC-LICENSE-GROUP.ps1':'<tenant ID>, <group name>, <group alias>',
      'BEC-RISK-ASSESSMENT.ps1':'<user@domain.com>',
      'BEC-CONTAIN-ERADICATE.ps1':'<user@domain.com>',
      'BEC-RECOVER-VALIDATE.ps1':'<user@domain.com>',
      'BEC-INVOKE-EMAIL-RECOVERY.ps1':'<mailbox@domain.com>, <source folder>, <destination folder>',
      'BEC-GET-TENANT-EMAIL-SEARCH.ps1':'<sender, recipient or IP address>, <time range>',
      'BEC-GET-THREAT-INTEL-ACTIVITY.ps1':'<public IP or TXT path>, <provider API keys>',
      'BEC-GET-TIMELINE-BUILDER.ps1':'<evidence files>',
      'BEC-GET-TOKEN-DECODE.ps1':'<token>',
      'PREPARE-FIELD-KIT.ps1':'<Graph, Exchange or both>',
      'git-repo.ps1':'<repository path>, <Check, Pull or Push>',
      'git-handoff.ps1':'<repository path>',
      'Terminal-Tools.ps1':'<startup/setup or shutdown>',
      'Script-Tools.ps1':'<file or folder path>, <certificate when requested>',
      'GitHub-Tools.ps1':'<repository path>, <action>',
      'GitHub-Security-Check.ps1':'<GitHub account>, <security-log export path>'
    };
    let value=specific[item.file];
    if(!value){
      if(/Mailbox UPN/i.test(input))value='<mailbox@domain.com>';
      else if(/Group \\/ CSV/i.test(input))value='<Group Name>';
      else if(/UPN|User sign-in address/i.test(input))value='<user@domain.com>';
      else if(/IP address/i.test(input))value='<IP address>';
      else if(/Tenant ID/i.test(input))value='<tenant ID>';
      else if(/Tenant domain/i.test(input))value='<domain.com>';
      else if(/folder|files/i.test(input))value=/Toolkit/i.test(input)?'<toolkit folder path>':/^Folder$/i.test(input)?'<folder path>':'<file or folder path>';
      else value='<'+input+'>';
      if(/CSV \\/ TXT/.test(input))value+=' or <CSV/TXT path>';
      if(/time range/i.test(input))value+=', <time range>';
    }
    return 'Input: '+value;
  }
''' + html[end:]
marker = '  function minimalCardMarkup(item){'
flags = '''  function impactFlagsMarkup(item){
    const assessment=item.file==='BEC-RISK-ASSESSMENT.ps1';
    const contain=item.file==='BEC-CONTAIN-ERADICATE.ps1';
    if(assessment || contain){
      const chips=[[1,'Read only'],[2,'Modify'],[3,'Destruct']].map(([rank,label])=>{
        const later=assessment && rank>1;
        const title=later?'Later response steps only; assessment makes no changes.':rank===1?'Reviews evidence before any response action.':rank===2?'Changes require action selection and confirmation.':'Removal actions require selection and confirmation.';
        return '<span class="card-impact impact-'+rank+(later?' impact-later':'')+'" title="'+esc(title)+'">'+label+'</span>';
      }).join('');
      return '<span class="card-flags" role="group" aria-label="'+(assessment?'Assessment: read only. Modify and Destruct belong to later response steps.':'Reviews evidence; modification and removal actions require selection and confirmation.')+'">'+chips+'</span>';
    }
    const rank=actionRank(item),label=rank===3?'Destruct':rank===2?'Modify':rank===1?'Read only':'';
    return '<span class="card-flags"><span class="card-impact impact-'+rank+'">'+esc(label)+'</span>'+(catalogType(item)?'<span class="card-type">'+esc(catalogType(item))+'</span>':'')+'</span>';
  }
'''
html=html.replace(marker, flags+marker, 1)
old_flags='''<span class="card-flags"><span class="card-impact impact-${rank}">${esc(impact)}</span>${catalogType(item)?'<span class="card-type">'+esc(catalogType(item))+'</span>':''}</span>'''
assert old_flags in html
html=html.replace(old_flags,'${impactFlagsMarkup(item)}',1)
html=html.replace('</head>','<style>body.orbit-ui .card-topline .card-impact.impact-later{color:var(--muted);border-style:dashed;opacity:.48}</style>\n</head>',1)
# Keep permissions with the current script, before links to other tools.
start = html.index('  function minimalCardMarkup(item){')
end = html.index('  function openItem(item){', start)
card = html[start:end]
assert '${taskRelatedMarkup(item)}<div class="card-permissions">' in card
card = card.replace('${taskRelatedMarkup(item)}<div class="card-permissions">', '<div class="card-permissions">', 1)
assert '</svg></div>`;' in card
card = card.replace('</svg></div>`;', '</svg></div>${taskRelatedMarkup(item)}`;', 1)
html = html[:start] + card + html[end:]
PAGE.write_text(html)
print(json.dumps({'enabled_files':len(allowed),'withheld_files':manifest['withheld'],'baseline_commit':PIN}))
