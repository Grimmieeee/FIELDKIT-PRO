from pathlib import Path
import json,hashlib,re
root=Path(__file__).resolve().parents[2];qa=root/'qa/desktop-standard';manifest=json.loads((qa/'candidate-manifest.json').read_text());inventory=json.loads((qa/'behavior-inventory.json').read_text(encoding='utf-8-sig'));cards=json.loads((qa/'card-metadata.json').read_text());by_path={x['path']:x for x in cards};inputs=json.loads((qa/'input-test-results.json').read_text(encoding='utf-8-sig'))
for row in manifest:
 data=(qa/'candidate'/row['path']).read_bytes();assert hashlib.sha256(data).hexdigest()==row['candidate_sha256']
for row in inventory:
 card=by_path.get(row['path'],{});row['scope']=card.get('scope');row['inputLabel']=card.get('input');row['inputChecks']=[{'format':t['format'],'function':t['function']} for t in inputs if t['path']==row['path']];row['notes']=[]
 if row['path']=='published-source/identity/INVOKE-CREATE-DYNAMIC-LICENSE-GROUP.ps1':row['notes'].append('Export helper exists but is not called by the script. No export capability advertised.')
 if row['path'] in ['published-source/incident-response/BEC-GET-TOKEN-DECODE.ps1','published-source/incident-response/BEC-INVOKE-EMAIL-RECOVERY.ps1']:row['notes'].append('Export-path helper is dormant. No result export advertised.')
 if row['path']=='published-source/tenant/GET-TENANT-DRIFT-REVIEW.ps1':row['notes'].append('Saved baseline is persistent comparison state, not a result export; baseline path behavior retained.')
 if row['path']=='tools/git-handoff.ps1':row['notes'].append('Repository handoff snapshot also records the previous comparison boundary; repository state location retained.')
(qa/'behavior-inventory.json').write_text(json.dumps(inventory,indent=2)+'\n')
overrides=[]
for row in manifest:
 text=(qa/'candidate'/row['path']).read_text(encoding='utf-8-sig');v=re.search(r'\.VERSION\s+(\d+\.\d+\.\d+)',text,re.I);cap=next(x for x in inventory if x['path']==row['path'])
 overrides.append({'path':row['path'],'sha256':row['candidate_sha256'],'version':v[1] if v else None,'verification':None,'verificationHistory':None,'releaseState':'candidate-withheld','resultExportFormats':cap['resultExportFormats'],'resultExportDestination':'Desktop' if cap['resultExportFormats'] else None,'inputLabel':cap['inputLabel']})
(qa/'candidate-card-overrides.json').write_text(json.dumps(overrides,indent=2)+'\n')
count=sum(bool(x['resultExportFormats']) for x in inventory)
text=f'''# Desktop export and capability alignment

Status: candidate preparation complete; Windows/tenant validation UNEXECUTED.

## Scope

- Inspected all 59 enabled PowerShell scripts, pinned by the release manifest.
- Prepared 38 separate candidate files. Established downloadable files are unchanged.
- {count} scripts expose a result export; {59-count} do not. No export was added to tools without one.
- Three modified scripts contain dormant export helpers, not an active export option.
- Existing export formats and opt-in prompts remain. Exports use the OS-resolved Desktop; missing/unwritable Desktop fails rather than requesting a custom path or falling back.
- New CSV/JSON/TXT destinations get unique names. Existing HTML reports and deletion evidence retain their unique filenames/subfolders.
- Repository handoff snapshots, tenant baselines and profile/configuration writes retain their operational locations.
- Group tools retain group input. IP/token/file/local tools retain their own inputs. Scope alone does not imply UPN/CSV/TXT or export support.
- Fixed existing Delete User Accounts input defect: Test-UpnSyntax was called with -UPN while accepting only -Value. Candidate accepts both names.
- Updated candidate version headers and hashes. Operator verification does not transfer; candidate metadata explicitly clears it.

## Executed evidence

- 59/59 effective sources pass PowerShell 7.6 parser checks.
- 38 isolated export/path test bundles pass (97 records including parser checks).
- 43 input cases pass: explicit targets and TXT/CSV loaders, exercising original or candidate source functions.
- Nine additional isolated export branch tests pass, including BEC reports, inventory, deletion evidence and resolver CSV/TXT.
- Baseline validator defect reproduced; candidate fix passes both parameter names.
- Non-export functions compared against baseline; only the deliberate validator alias changed outside the export-function allowlist.
- No whole operational script, Graph, Exchange, AD or account mutation entrypoint executed.

## Files

- candidate/: candidate source files, never served by the current Site.
- candidate-manifest.json: baseline and candidate hashes.
- behavior-inventory.json: 59-file source-backed capability inventory and input test coverage.
- candidate-card-overrides.json: withheld metadata for a future validated release.
- test-results.json, input-test-results.json, branch-test-results.json: actual executed evidence.
- prepare.py / parse-sources.ps1 / audit.ps1 / test-*.ps1: repeatable preparation and checks. Scripts currently use this checkout's absolute path.

## Remaining acceptance

Windows PowerShell 5.1 parsing/execution, actual Windows Desktop resolution (including redirected/OneDrive Desktop), denied Desktop writes, browser Save As, actual module/auth behavior and live tenant results remain untested. Complete those on the approved endpoint before promotion, checksum/package rebinding, restored verification or public cutover.

The locked Quick Reference remains a design baseline. Its generic examples must not be treated as universal per-scope capabilities. Bind actual card checkmarks to behavior-inventory.json when promoting validated candidates.
'''
(qa/'README.md').write_text(text)
print({'scripts':59,'candidates':len(manifest),'active_result_exports':count})
