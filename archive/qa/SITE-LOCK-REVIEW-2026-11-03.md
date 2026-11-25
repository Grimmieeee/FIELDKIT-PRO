# FIELDKIT-PRO release review, 2026-11-03

Current release: Sites version 71, source `4a03abead463b13943f98fa5d26d3ebd161c6890`.
Canonical repository: `Grimmieeee/FIELDKIT-PRO`, default branch `main`.
Public site: https://fieldkit.pro/
Index SHA-256: `ee0d61d140fdfe996497efd89bd72653e301e8665b8d69f1c880e6872b0ce9b8`.

## Result

The approved design is locked by source hash. All 19 style blocks and all 59 PowerShell payloads are unchanged. The owner explicitly accepted the live visit counter as-is. Its namespace, appearance and behavior are preserved.

Corrected the operating standards' old primary-repository name and old Pages URL; rebound its checksum in the catalog, manifest and sums. Removed “Preview” from browser title. Synced the already-deployed hits.sh image permission into GitHub. Fixed two QA output paths so checks work in any checkout. No identity, mailbox, permissions, access, operational script, or verification-badge changes.

## Checks actually completed

- Native Sites: version 71 deployed successfully. Domain and SSL active; public visitor audience, owner only editor. Hosting does not use old GitHub Pages.
- Current resolver/ZIP builders: 311 catalog entries, 72 files, 6 package/release cases PASS.
- Synthetic transport/content failure cases: 13 PASS, including mismatch, redirect, invalid UTF-8, HTML, traversal and external URL rejection.
- Generated Setup and BEC ZIPs: CRC and all checksum members PASS (2 and 6 source members).
- All 72 public source paths are same-origin; no external source URL is accepted. Legacy repo links are absent from runtime index and operational scripts.
- Three source-bound BEC verified records remain unchanged. No other workflow was marked verified.
- Live Chromium: tour routing and reload, return to catalog, BEC search, no-results guidance, 230 Quick Commands category, mailbox-permissions search/card, favorites persistence and cleanup, About/reference, Security guide and PRO policy link, BEC scope/flags/permissions, close control, code preview, and dark-theme persistence.
- Live BEC PS1 download reported “Download verified.” New title visible after deployment.
- Existing phone-layout evidence was retained because CSS is unchanged. No new physical iPhone/Safari or phone viewport run is claimed.
- No new Windows or live-tenant action execution was performed.

## Repository deletion assessment

Keep FIELDKIT-PRO/main. The current site and release packages are independent of FieldKit, field-kit, Jumpbox, pwsh-operations-catalog and FIELDKIT-ARCHIVE. Deleting those repos should not interrupt the current site runtime or its downloads.

This is not a promise that deletion breaks nothing outside the site:

- Existing clones/remotes, bookmarked old URLs, GitHub Pages URLs and external scheduled jobs referencing deleted repos stop working. Endpoint jobs/clones were not available to inspect.
- The old catalog contains publish-site.yml, site-check.yml and scheduled codeql.yml. They belong to the old repo, are not the current Sites deployment path, and are not migrated into PRO. Deletion removes those checks.
- Other four repositories' default trees contain no workflow files or submodules. Original nondefault branch/history coverage was not re-audited; archive snapshots do not preserve all refs/history.
- Historical PROJECT-HANDOFF.md remains historical evidence and mentions its original repository. It is not used for live source resolution.

No repository deleted. Broad deletion clearance remains conditional on accepting old URL/history/CI loss and checking any endpoint jobs/remotes still in use.

## Baseline and rollback

Previous live baseline: Sites version 70, source b7591fc73c5be3388b05d07a84cccb27f02f8899.
GitHub review base: 3be5a1d94c5351a812a74c7aa04c3d30698f3539.
Current authoritative state: qa/RELEASE-LOCK.json and qa/PRESENTATION-LOCK.json.
“Locked” means the approved source/presentation baseline, not newly enabled branch protection.
