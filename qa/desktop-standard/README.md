# Desktop export and capability alignment

Status: candidate preparation complete; Windows/tenant validation UNEXECUTED.

## Scope

- Inspected all 59 enabled PowerShell scripts, pinned by the release manifest.
- Prepared 38 separate candidate files. Established downloadable files are unchanged.
- 35 scripts expose a result export; 24 do not. No export was added to tools without one.
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
