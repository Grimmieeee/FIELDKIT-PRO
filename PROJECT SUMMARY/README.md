# FIELD // KIT project status

## Production and source

Production is [fieldkit.pro](https://fieldkit.pro/), Sites v232, from Sites source commit `04c6b26ca44ef4df9689b677d099178c967cb809`. The homepage SHA-256 is `471f3f2ef2ef854890cee366b2c681c962542fb24a04079f2e6dcfe31d8e3eec`. The Sites catalog origin serves identical homepage bytes. Roll back through Sites to v231 (`60722c438dc79dbf187338c9429591d4bbdab8b0`) if needed. The [entry URL](https://field-kit-entry.delbert-hifield.chatgpt.site/) serves the same catalog homepage in its own Sites v66 deployment (`d2aaffbdf1f3cefab834d8f4da8194c554b7859b`, rollback v65). The original entry v44 is the historical pre-cutover snapshot and its source is [archived](https://github.com/Grimmieeee/FIELDKIT-ARCHIVE/tree/7397f97f48804c72af2b530ebff5f14b70deb838/sites/field-kit-entry-v44).

The [catalog by group](CATALOG-BY-GROUP.md) lists all 270 entries across eight navigation groups and search-only Extras. Search and category results are flat, filenames use regular weight. The homepage has no tagline or About popup. The approved title and navigation margins are 32px and 20px. On v212, lockout searches surface Get AD User Details immediately after Unlock AD User. The search suite passed 12 ranking checks and eight simulated result-list scenarios, including the approved BEC order. Download checksums passed. Scope and impact labels retain Tenant and Delete where they apply.

GitHub and Sites have independent source histories. The GitHub baseline reviewed for this update is `f77f25f6cde0a2055f20a157d10674edb756a14e`. Treat its dist tree and operator test copies as revision-specific evidence. Establish byte parity with Sites before using a GitHub test to make a claim about production.

## Active Directory module setup

Sites v232 adds Install Active Directory Module (RSAT) under Session and Setup, with links from cards that declare the module. The quick command selects the Windows client or server feature and checks Get-ADUser. Search QA passed and all three live homepages matched. Windows installation was not executed.

## Sort header typography

Sites v231 shares the section-tab font size across Script, Scope, and Impact. Search tests passed and all three live homepages matched. Browser visual alignment was not reverified.

## Search intent closeout

Sites v230 avoids misleading results for broad DNS cache, TCP/IP stack, and Windows services searches and adds read-only mappings for common diagnostic phrases. Thirteen focused checks and the full search suite passed. Ryan verified Script sorting on iPhone. Both pinned Sites commits rebuilt from clean source exports and their complete generated dist trees matched their release builds. All three live homepages matched the release with fresh requests. Use the clean rebuild instructions below with the current pins above.

## Feedback close control

Sites v229 replaces Back to tools on Submit an idea with an upper-right close control that returns to the catalog. Live feedback HTML matched across all three URLs.

## Script sort touch menu

Sites v228 uses visible sort buttons under Script. Simulated tests passed. Both Sites origins and a fresh custom-domain request matched the build. iPhone touch verification is pending.

## Script sort header

Sites v227 keeps Script visible as a sort menu in browse and search. Scope and Impact also use green labels. Search tests and download checksums passed. All three live homepages matched. iPhone Safari verification is pending for this revision.

## Category wording

Sites v226 displays Directory & Tenant, Encryption & Certs, and Devices. Category identifiers and membership are preserved. Search and packaged download checks passed, and all three live homepages matched.

## Search sort menu

Sites v225 puts Relevance, A–Z, and Z–A in the left search results header and removes the standalone reset row. Scope and Impact remain one-tap sorts. Browse mode retains Script sorting. Simulated sort and menu-state checks passed. All three live homepages matched.

## Search result sorting

Sites v224 defaults searches to relevance, including curated follow-up and BEC order. An explicit column sort orders the full matching set. Sort by relevance restores the default. Both directions for all three columns and relevance restoration passed simulated checks. All three live homepages matched.

## Sort column alignment

Sites v223 centers Scope and Impact labels over their column values by balancing the chevron footprint. Sort controls retain their borderless appearance. Search and packaged download checks passed, and all three live homepages matched.

## Approved FAQ refresh

Sites v222 publishes the approved Draft 2 FAQ, option 04 title gradient, two-tone intro, card-sized close link back to the catalog, and bottom-right signature. FAQ SHA-256: `2dc72f16ae73375eb799eb3f73030dc9863d969bf447c5b275ee945a0da46491`. The FAQ and catalog HTML matched the release across all three URLs. Search and packaged download checks passed.

## FAQ and feedback

The toolbar starts with the icon-only FAQ and Submit an idea links. The FAQ is published at `/faq.html` and covers the jump-box workflow and troubleshooting. The toolbar and FAQ link to `/feedback.html`, which submits to Formspree. Live page bytes were verified across all three URLs. Ryan confirmed the Formspree test reached Gmail and verified the search recovery, result ordering, and FAQ/feedback walkthrough items against v219. Homepage and FAQ bytes matched across all three live URLs.

## Sign-in and command search

Sites v216 adds sign-in symptom and error-code mappings and the Get-InboxRule and gpresult shortcuts. Four new simulated searches and download checksums passed. All three live homepages matched the release.

## Extras

Sites v221 moves nine terminal and GitHub tools into search-only Extras. Browse and broad searches omit them. Targeted partial searches and saved Favorites still reach them. The search suite, Extras checks, download checksums, and three live homepage byte comparisons passed.

## Five-batch search verification

Sites v220 adds 12 ticket mappings after testing 25 fresh queries across identity, mail, endpoint, tenant, and incident response. The full simulated suite and packaged checksums passed. All three live homepages matched the release. Running-service inventory and forwarding change attribution remain catalog gaps.

## Search intent and scope

Sites v219 recognizes common diagnostic wording variations and scope terms. Existing aliases and exact tool names take precedence. Fifteen new simulated cases and the existing suite passed. The baseline verification reran search and packaged download checksums. Homepage, FAQ, feedback page, and checksum manifest matched the pinned payload across all three live URLs. Current browser acceptance remains separate.

## Ticket search audit batch

Sites v218 updates 39 mappings across identity, mail, endpoints, tenant, and incident response. The simulated suite passed all 39 mappings and two mailbox protocol intent checks, plus the existing suite. Download checksums passed and all three live homepages matched.

## Search follow-up

Sites v215 adds ticket mappings for DNS, certificate expiration, Group Policy, disk free space, AD and Entra group members, and failed logins. Eight additional simulated ticket cases and download checksums passed. All three live homepage responses matched the release bytes.

## Search audit update

Generic account-compromise queries start with assessment. Exact BEC containment and recovery names lead with the requested tool. Mailbox access and forwarding distinguish individual and tenant-wide work. Ticket aliases cover message trace, tenant MFA, lockout, failed login, password expiry, available licenses, disk space, and uptime. Empty category searches offer Search all categories. The simulated suite passed 12 ranking checks, eight existing scenarios, 17 targeted mappings, and category recovery rendering. All three live homepage responses matched the release bytes.

## Catalog and operator workflow

The catalog supports ticket-language search, eight category filters, and ranked follow-up checks. Empty category searches can expand to All without clearing the query. User and Users distinguish individual and batch work. Tenant represents organization-wide coverage. Check each card against its source for supported input and export formats.

In the core BEC workflow, start with User Risk Assessment, continue with approved containment, then Restore and Validate. The final step offers a consolidated TXT summary and marks unavailable stages explicitly. A partial report does not establish incident closure. Keep evidence and follow-up in the incident ticket.

## v226 release acceptance

Ryan confirmed the final iPhone Safari check for the search sort dropdown and updated category labels. Main v226 and entry v60 are the accepted live baseline.

## Clean rebuild and script intake\n\nRecover the deployed release from the pinned Sites source revision for each deployment. From a clean checkout, run `node scripts/build-counter-worker.mjs`. The worker is built from the tracked `dist/` payload and uses the existing Sites hosting manifest. This is a rebuild of the pinned source, not a reconstruction from GitHub alone. Run `node qa/search-relevance.cjs` from the main Sites checkout and `sha256sum -c --quiet SHA256SUMS.txt` from each checkout's `dist/`.\n\nClean exports of main v226 and entry v60 both rebuilt successfully. The generated worker, hosting manifest, and homepage, FAQ, and feedback HTML matched their respective release builds byte for byte. Search and packaged download checks passed.\n\nUse the [script intake checklist](SCRIPT-INTAKE.md) for incoming tools. The original dry run is historical source-review evidence.\n\n## Validation and release

1. Pin the source commit and record the affected file paths and hashes.
2. Run the GitHub site checks for the GitHub tree. In the Sites checkout, run node qa/search-relevance.cjs and verify dist/SHA256SUMS.txt from inside dist.
3. Compare the packaged homepage and downloads with the intended release. Exercise changed browser flows on desktop and mobile.
4. Save and deploy the exact Sites source revision with the existing site identity and audience. Verify the deployment and record the previous version for rollback.

The v180 release checks passed the nine ranking checks, eight simulated results scenarios, and the 97 manifest checksums. PowerShell operational vetting was accepted by the operator. These checks are recorded separately from browser acceptance for the exact production revision.

## Maintenance

Keep the deployment payload, build scripts, GitHub workflows, and the test inputs needed by those workflows together. Archive obsolete snapshots only after checking references and confirming the destination contains the original bytes.

## Reference bank

- [Build standard](field-kit-build-standard.md)
- [Site, catalog and mobile specification](SITE-AND-CATALOG-SPEC.md)
- [New engineer walkthrough](NEW-ENGINEER-WALKTHROUGH.md)

Ryan accepted both the production catalog and the separate entry site on November 14, 2026. The acceptance checkpoints were catalog v181 and entry v44.

Start changes here. Earlier Sites release notes preserve their historical checkpoints. Update the affected reference in the same change as the implementation. Update this index when the deployed version, source hash, rollback point or acceptance evidence changes. Preserve historical evidence against its original revision. If a Sites runbook needs a current reference, link this bank and use the release-specific record for deployment evidence.

See [QA file disposition](QA-DISPOSITION.md) for retained and archived evidence. The Sites source runbook links back here.

## v181 verification

Ryan verified desktop and iPhone browser acceptance. Twelve ranking checks, eight simulated result-list scenarios, and 97 packaged checksums passed. All 102 public files matched the pinned release byte for byte over HTTPS. The three intake card updates changed catalog presentation and search; PowerShell payloads were unchanged.
