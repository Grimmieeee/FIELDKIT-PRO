# Repository layout and relocation

[Project status](README.md) tracks current releases, rollback points and verification scope. The relocation baseline is [FIELDKIT-PRO at 9b313d3dc382e66517fe39fbf8078bb5b5f97759](https://github.com/Grimmieeee/FIELDKIT-PRO/tree/9b313d3dc382e66517fe39fbf8078bb5b5f97759). Candidate changes belong in branches and draft pull requests at their intended paths.

## Paths

Directory rows preserve every descendant path. Executable filenames are preserved.

| Original path | Destination |
| --- | --- |
| `PROJECT SUMMARY/` | `docs/` |
| Three `scripts/BEC-*.ps1` files | `scripts/incident-response/` |
| `scripts/Client-Connectivity-Check.ps1` | `scripts/connectivity/Client-Connectivity-Check.ps1` |
| `scripts/build-counter-worker.mjs`, `worker/router.mjs` | Same basenames in `build/` |
| `qa/scripts/` | `tests/release/` |
| `qa/connection-order-review.json`, `qa/operator-verified-2026-11-11.json` | Same basenames in `tests/` |
| `qa/assemble-release.py`, `qa/catalog-revision-map.json`, `qa/release-manifest.json`, `release-baseline/` | Same names under `archive/release-assembly/` |
| `qa/standalone-validator/` | `archive/standalone-validator/` |
| `qa/PROJECT-STATE.md`, `qa/QA-BASELINE-v162.md`, `qa/RELEASE-LOCK.json`, `qa/REPOSITORY-CLEANUP.json`, `qa/SITE-LOCK-REVIEW-2026-11-03.md`, `qa/V162-SHA256SUMS.txt` | Same basenames in `archive/qa/` |
| `dist/`, `.github/`, `.openai/`, `.gitignore`, `AGENTS.md`, `README.md`, `SECURITY.md` | Same paths |

The BEC files stay together for script-relative companion lookup. The active checks use the [relocation map](../tests/relocated-test-source-paths.json) to find the current copies. The original source paths, revisions and hashes stay in the evidence records.

## Downloads and GitHub links

Public site download paths and GitHub repository paths are separate. The public payload stays under `dist/`, with its existing route keys, `published-source/candidates/` URL segment, embedded sources and checksums. That segment is part of the download layout. Review status belongs in candidate PRs.

Branch-relative GitHub file and raw URLs for moved paths may break after merge. Commit-pinned URLs still resolve at their original path. GitHub URLs under `dist/` retain their paths. The checked-in workflows and docs are updated here, and the owner-scoped code search returned no matches for the old standalone GitHub branch URL patterns. External bookmarks, automation and unindexed consumers cannot be ruled out. Confirm any known consumers before merge and update them to the new path or pin the old URL to the appropriate commit. If a consumer requires an old branch-relative raw path, defer that move until the consumer can migrate.

## Historical consumers

The tracked reference and workflow search found no active CI caller for the assembler or standalone validator. The historical validator builder consumes the assembly release manifest and requires the absent `qa/desktop-standard/LOCK.json` plus other old harness files. The assembler reads its baseline and revision map and writes to the original release tree. Both are retained with their inputs and outputs for reference. Recover the original layout and exact inputs in a scratch checkout for historical reconstruction. The repository had no GitHub releases or release assets at review time. External consumers of the historical GitHub file URLs need the same compatibility check before merge.

Historical records retain original relative links and commands. Browse them in the [original QA tree](https://github.com/Grimmieeee/FIELDKIT-PRO/tree/9b313d3dc382e66517fe39fbf8078bb5b5f97759/qa) when following those references. Additional records are in [FIELDKIT-ARCHIVE](https://github.com/Grimmieeee/FIELDKIT-ARCHIVE).
