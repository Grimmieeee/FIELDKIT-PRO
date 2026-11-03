# FIELD KIT release preparation, 2026-11-01

## Objective and authority

Ryan authorized release assembly, working downloads, browser QA, Windows validation and subsequent domain cutover. The approved layout stays locked. Established scripts may ship; updated app/licensing candidates remain withheld until validated. Public cutover follows Windows validation, not merely static checks.

## Baselines

- Approved Site: `appgprj_6ae3f267936c8191b969e7f49cc0f2ef`, owner-only, version 46.
- Frozen approved source: `0c8463b72d9c37207e7625113328377f942597c6`.
- Established script source: `Grimmieeee/pwsh-operations-catalog` at `af51d3cf7e59975112d62480a4377d4c2a2c40f5`.
- Original public catalog and entry Site have not been modified by this work.

## Completed

- Recovered all 94 established files and verified each against the pinned published checksum.
- Only 12 of the newer preview's 83 source hashes matched recovered bytes. No missing newer source was declared recovered or verified.
- Assembled a candidate using 72 established files with their matching source-bound cards, permissions and instructions. This deliberately selects established versions, rather than rebinding newer guidance to older scripts.
- Five updated app/licensing cards and four new tool menus retain no download/source controls. Two legacy app source paths are also withheld and not served. Total: 11 withheld source paths, nine visible cards.
- The four withheld menus are Terminal Tools, Script Tools, GitHub Tools and GitHub Security Check. Established component tools remain available where the catalog already includes them; no menu replacement or consolidation was invented.
- Download resolver enforces the release allowlist before loading bytes, validates SHA-256, rejects redirects, HTML, empty/invalid/oversized files, and preserves BOM and line endings.
- Same-origin credentials support owner-private static assets without allowing external source URLs.
- Setup and BEC ZIPs are assembled only after all member sources pass the existing package gates. BEC aliases preserve internal companion filenames.
- Fixed forced-light preview behavior so a saved theme survives reload. Styles and layout are unchanged.
- Private candidate deployed successfully as Site version 47, source commit `b6ac402caed9ac8cfd7205623f71e528237af4db`, saved version `appgprj_6ae3f267936c8191b969e7f49cc0f2ef~appgver_1931dfe93c7081918e1aad49f865e97b`, deployment `appgdep_6ae6e6ccb7e881919e3e6f633f05dfc3`.
- Private URL: https://field-kit-mobile-preview.delbert-hifield.chatgpt.site
- Enabled payload contains 59 PowerShell scripts and 13 Markdown references. There are still 311 catalog entries, including inline commands.

## Evidence actually obtained

- `release-check-results.json`: actual catalog resolver/ZIP builders with filesystem-backed synthetic fetch. 311 catalog entries pass; 72 files save byte-identically; withheld paths and actions fail closed; failed BEC member blocks the entire package.
- `download-integrity-tests.json`: 13 synthetic transport/content integrity cases pass.
- `package-check-results.json`: both generated ZIPs pass CRC and every SHA256SUMS member hash.
- Browser: search finds the expected account-status card; Favorite saves and filters correctly and survives reload; dark theme survives reload; withheld app card has no source action.
- Responsive browser iframe: long BEC card and expanded run instructions fit at 390, 414 and 768 CSS pixels with document scroll width equal to viewport width. This is Chromium responsive QA, not physical iPhone/Safari testing.
- Local HTTP browser source verification correctly refuses an insecure context. HTTPS acceptance is a separate subsequent check.
- All 59 served script version headers agree with their selected catalog versions. All four approved stylesheet blocks are byte-for-byte unchanged.
- Private deployment status is SUCCEEDED. The browser reached the expected private-site login gate and has no signed-in ChatGPT session. The authenticated HTTPS API check was stopped without a completed result. Do not count hosted source hashes or browser Save As as passed. Local byte and ZIP evidence remains valid.
- No custom domain is attached to the private candidate. No DNS or production domain changes were made.

## Required before public cutover

Subsequent presentation update: the two requested BEC cards preview all three flags; assessment keeps Modify/Destruct muted as later-stage capabilities. Contain and Clean Up is now Contain and Eradicate. All 50 input instruction sections use `Input: <…>`. Ryan accepted these changes and requested Permissions immediately before Related tools on every card. This order and the accepted presentation are now locked. Operational source bytes and withheld eligibility are unchanged. See `card-polish.json`.

Windows and live tenant execution are UNEXECUTED. No authorized Windows/jumpbox session is available in this Linux environment. Parser/synthetic/browser evidence is not operational approval.

On the approved Windows endpoint, validate the exact downloaded established files and package hashes, launch method, account/tenant sign-in, objective-specific inputs, results including not-found/failed/unavailable cases, cancel paths, exports when supported, disconnections and clean close. Validate the Setup package and the three BEC steps together. Do not test destructive changes against production identities merely to exercise the UI.

Retain the five app/licensing candidates and four unmatched menus as withheld. New operational candidates need separate source-specific approval; historical acceptance is not inherited.

After signed-in HTTPS download acceptance and Windows acceptance, confirm production download bytes, then perform the authorized domain cutover and HTTPS verification. Keep Site version 46 (`appgprj_6ae3f267936c8191b969e7f49cc0f2ef~appgver_77e91c99181481919c76bffa2e737916`) and the untouched public GitHub release as rollback checkpoints.

## Alignment polish, 2026-11-01

Authorized narrow presentation update: footer wordmark offset removed; header Favorite centers over the rightmost badge; mobile badges use a single row below the breadcrumb. Desktop Chromium BEC Contain card verified: star and Destruct badge centers differ by 0.008 CSS pixels. Mobile CSS updated; physical iPhone validation remains unexecuted. Operational files and release eligibility unchanged.

## Hosted download baseline LOCKED, 2026-11-01

Site version 51, source 9ad103d35d9aa34d44d1ef369201fbb92a9946bc: all 72 enabled hosted files returned HTTPS 200 without redirects and matched the release SHA-256 manifest. Evidence: https-download-check.json. Local catalog resolver/package checks (6) and integrity transport tests (13) passed again. This locks hosted source bytes and existing package-integrity baseline only. Browser Save As and Windows/tenant execution remain UNEXECUTED; public cutover remains blocked on those gates. No operational script bytes or audience changed.

## Input copy correction, 2026-11-01

Step 3 retains Input: followed by actual target placeholders. Removed optional CSV/TXT path alternatives from the generic instruction and name resolver instruction. Get Mailbox Permissions now shows Input: <mailbox@domain.com>. Required additional inputs remain where applicable. Script prompts still offer supported import methods; script bytes are unchanged. Render-function checks passed across all 50 instruction sections.

## DESIGN DONE / LOCKED, 2026-11-01

Ryan accepted the final design and requested all copy buttons use COPY. Both remaining Copy code templates now use COPY, matching connector and launch-command controls. COPIED success feedback remains. Verified no Copy code button labels remain. This is the final approved presentation baseline; changes from here are fixes or explicit new requests. Script bytes, download hashes, withheld eligibility and audience unchanged.

## About reference update, 2026-11-01

Ryan authorized an About reference for flags, scope icons, Verified and a collapsed Security guide with full-policy link. Removed repeated tour content, planned-tool counts and Built by. Tagline omitted pending selection. Uses existing flag colors and scope SVGs. Verified wording checked against isVerifiedRelease and verificationHistory. Chromium confirmed page rendering and Security guide expansion/collapse. Operational bytes unchanged.

## Compact quick reference, 2026-11-01

User requested labels without descriptions or section footnotes, Operator verified only, and CSV/TXT UPN file support. About now presents a compact quick-reference card using existing visual tokens; Security guide remains collapsed. File-input note says where supported to avoid implying every script accepts files or that the website uploads them. Chromium rendering checked. Tagline remains deferred. Script bytes unchanged.

## Scope/input/output concept preview, 2026-11-01

Preview only, not deployed: Operator verified above Flags; One target, Tenant-wide, Multiple targets, Local order; open Have ready/Get back sections with capability checkmarks; Security collapsed. Proposed layout patch: qa/about-capability-preview.patch. Generic rows illustrate a proposed standard, not universal existing capabilities. User requested Desktop-only exports with no custom paths. UNIMPLEMENTED: established GET-ACCOUNT-STATUS.ps1 currently prompts for a CSV output path and defaults to current directory (lines 273–276). Operational files unchanged; desktop export needs source-specific updates and validation before represented as existing behavior. Deployed quick reference remains unchanged pending preview review.

## Capability reference DESIGN LOCKED, 2026-11-01

Ryan approved the Have ready/Get back layout with Operator verified text left aligned and the checkmark immediately to its right. Chromium visually verified. Frozen design patch: qa/about-capability-locked.patch. This supersedes the earlier preview patch for presentation. Not deployed: capability/export claims still require source-specific reconciliation and Desktop-only export implementation/validation. Current deployed site and operational bytes remain unchanged.

## Behavior alignment candidate batch complete, 2026-11-01

User authorized checking behavior across all scripts and enforcing Desktop exports. All 59 enabled scripts inventoried; 38 separate candidates prepared under qa/desktop-standard/candidate. 35 scripts have active result exports; 24 do not. Existing formats and opt-in behavior retained; no new exports invented. Custom result-export prompts/fallbacks removed. Baselines, repository handoff comparison state and profile/configuration writes retained. Existing Delete User Accounts -UPN/-Value validator mismatch reproduced and fixed in candidate. Evidence: 59 parser checks, 38 isolated export/path bundles, 43 input cases, nine additional export-branch tests; all PASS. Candidate versions/hashes recorded and verification explicitly cleared. See qa/desktop-standard/README.md. Windows PowerShell 5.1, Windows Desktop resolution and live tenant runs remain UNEXECUTED. Served files and audience unchanged; candidates withheld from deployment. Locked reference remains pending source-specific promotion.

## Candidate baseline LOCKED, 2026-11-01

Ryan accepted the completed behavior-alignment batch. Frozen 38 candidate hashes and current test evidence in qa/desktop-standard/LOCK.json; all candidate hashes rechecked against the manifest. This accepts the prepared baseline, not Windows/live validation or release eligibility. Existing downloads, public domain and Site audience unchanged. Next: approved-endpoint acceptance, then source-specific promotion and package/checksum rebinding.

## Self-contained endpoint validator delivered, 2026-11-01

User requested one PS1 rather than source-file uploads. Prepared qa/standalone-validator/VERIFY-FIELD-KIT.ps1 (59 embedded hash-pinned sources; 38 locked candidates). Offline parser/input/export tests run without any operational entrypoints; actual Desktop synthetic CSV write/readback and JSON summary; optional read-only Graph/Exchange tenant and test target checks; process-scoped Graph; existing sessions rejected; disconnect attempted connections and pause on completion. No module installation or remote source downloads. Single-file smoke: 151 PASS under Linux with test Desktop, expected Windows FAIL and platform/live SKIPs. Missing Desktop fails closed. Seven mocked connection/control-flow cases PASS. Actual Windows/live checks UNEXECUTED, to be run by Ryan. Exact validator hash recorded in qa/standalone-validator/artifact.json. Operational downloads and Site audience unchanged.

## New-engineer walkthrough completed, 2026-11-02

Recorded observed browser scenarios and source/package cross-checks in qa/NEW-ENGINEER-WALKTHROUGH.md. Confirmed blank #start-here reload and six permission lists contaminated with script-local helper names. Other findings: AD/cloud result-name ambiguity, missing bulk-format discoverability, withheld setup-menu shortcut, intentional duplicate BEC aliases and plain-language search misses. Review only; no Site or operational source changes. Prioritize routing and permission metadata fixes before launch. Runtime/physical-device checks remain separate.

## Walkthrough fixes completed, 2026-11-02

Fixed direct/reloaded tour visibility and catalog URL routing. Removed local helpers from all six Exchange permission records in both embedded guidance layers. AD quick-command display title is Reset AD User Password; examples use <AD username>. Added source-bound input-format note while preserving step 3. Removed withheld Terminal Tools shortcut from setup. BEC package guide explains friendly/internal companion pairs. Added targeted mailbox-access question matching and actionable no-results hint. Chromium confirmed tour/home routing, natural-language search and corrected Mailbox Permissions input/permission content. Catalog/source/package checks and 13 integrity cases pass; all 72 established bytes unchanged. No operational candidates promoted; locked capability reference remains separate.

## Permission headings and mobile spacing, 2026-11-02

Shortened code-box headings to Microsoft Graph and Exchange / Purview; actual scope/cmdlet lists unchanged. Mobile top-line gap reduced from 12px to 4px, bottom margin from 18px to 8px, scope rail margin 12px to 8px. Phone-width Chromium at 390px confirmed width equals scrollWidth and compact styles applied. Permission-content assertions pass. Desktop styles and script payloads unchanged. Temporary iframe fixture removed before packaging.

## Presentation baseline LOCKED, 2026-11-02

Ryan accepted the simplified permission headers and tightened mobile spacing: "This is perfect. Lock it down!" Approved source 14a6ae11aee6403cf086b79de820f3a12d33a0ba. Private saved version appgprj_6ae3f267936c8191b969e7f49cc0f2ef~appgver_5fb3b7778ea08191b85a5bfb4f252c88 deployed successfully on retry. Frozen index hash recorded in qa/PRESENTATION-LOCK.json. Future presentation changes require a new request or defect fix. Operational candidates remain withheld pending endpoint validation; no audience/domain changes.

## Bespoke provenance and Visits, 2026-11-03

User authorized CUSTOM only on confirmed bespoke workflows; glossary omitted for insufficient operational value. CUSTOM appears beside scope for the three source-bound reviewed BEC workflows only, separate from impact flags. Added a quiet hits.sh Visits badge to footer on the hosted Site/public domain only; starts fresh, no extraCount or historical seed. Counts page hits, not unique people; third-party dependency; badge removes itself on load failure. Local QA excluded and service rendered using a separate test namespace. Browser confirmed BEC CUSTOM; deterministic rendering finds exactly three flagged cards. Release check passes: 311 catalog entries, 72 unchanged files, six package/audit checks. Operational candidates remain withheld; audience/domain unchanged.

## Mobile polish and Quick Commands discovery, 2026-11-03

Removed impact chips from Screensaver/Theme/GitHub families per user, retaining type chips and all operational metadata. CUSTOM sits immediately beside scope (8px mobile gap). Search placeholder names quick commands; category label Quick Commands replaces CMDS; singular/plural search terms supported. Browser checked 230 Quick Commands results, search phrase, mobile badge placement, and equal main-layout side margins (14px phone, 341.5px desktop); no horizontal overflow. Type-family rendering assertions and release audit pass. All 72 downloadable files unchanged; candidates withheld and audience unchanged.

## Search and flag-rail correction, 2026-11-03

Exact placeholder Search custom scripts or quick commands, lighter contrast and 13px mobile fit. Removed focus-within outline/shadow without removing search caret. CUSTOM moved to the left of a shared badge rail above scope; impact chips retain right alignment and favorite anchor. Explicit flex centering in every equal-width category cell. Browser checked 390px frame: category cells 113px each, 14px outer margins relative layout viewport; search focus outline none/shadow none; CUSTOM x28 above scope x28 with all impact chips on same line. Release audit passes, 72 payloads unchanged. No operational promotion or audience change.

## Remove repeated card notes, 2026-11-03

Exact search placeholder Search for a custom script or quick command, lighter placeholder colors. Removed supplemental decision/guard/preparation note rendering from minimal cards; kept availability/source-status notices and actual run instructions. Underlying metadata and operational scripts unchanged. Desktop shares full-width flag rail above scope: Chromium 1363px confirms CUSTOM/scope x688, impacts same y149, BEC supplemental notes zero. Release audit passes with all 72 files unchanged. User accepted mobile alignment; preserved it.

## Presentation baseline re-locked, 2026-11-03

Ryan approved the current presentation: "Yep this is the one. Lock it down!" Pinned source 30e8631e962a238f07171d7fc83ab53678bd2558 and deployed version in PRESENTATION-LOCK.json. Search wording/contrast, shared mobile/desktop flag rail, category alignment and removed supplemental notes are accepted. Future design changes require a new request or defect fix. Windows/live validation remains pending; no operational candidates promoted.

## Verification presentation LOCKED, 2026-11-03

User accepted Verified ✓ beneath card description with 22px spacing before actions. Implemented conditionally using existing exact-source isVerifiedRelease; no verification records changed. Main page unchanged: no title checks or legend. Earlier previews rejected. Accepted static preview field-kit-verified-below-description.jpg. Current qualifying count remains zero pending validation. Release audit passes; operational payloads unchanged.

## Validator tenant identity correction, 2026-11-02 (Pacific)

Ryan reported Windows acceptance: 159 PASS, 1 FAIL, 0 SKIP. Graph tenant/user reads and cleanup passed. Exchange connected and accepted expected domain, but cross-service comparison failed. Target mailbox read was not reached. Follow-up diagnostics confirmed populated connection TenantID and blank organization ExternalDirectoryOrganizationId. Validator 1.0.1 now validates exactly one connected Exchange record with non-empty GUID TenantID, retaining requested-domain/GUID and Graph/Exchange match checks. Old-source blank-ID false mismatch reproduced; 13 source-extracted mocked connector scenarios PASS, including missing/invalid/empty IDs, multiple connections, mismatches and cleanup. Embedded workflow payload unchanged. Corrected Windows/live rerun PENDING; no operational release or verification badges granted. Updated the existing one-file validator deliverable.

## Shared Windows acceptance PASS, 2026-11-02 (Pacific)

Ryan supplied complete validator 1.0.1 console output: 161 PASS, 0 FAIL, 0 SKIP. Graph and Exchange expected-tenant reads, test user/mailbox reads, and both disconnects reported PASS. Attached synthetic CSV independently parsed: exact 3 columns and 2 records; commas, quote, Unicode and multiline content preserved; UTF-8 BOM present. Evidence and CSV digest: qa/standalone-validator/windows-acceptance-2026-11-02.json. Generated validation JSON was not supplied, so console results remain operator-reported. This closes the observed validator tenant-ID failure and shared acceptance run; no blanket operational action verification, candidate promotion, domain/publication change or release authorization inferred.
