# FIELD // KIT project status

## Production and source

Production is [fieldkit.pro](https://fieldkit.pro/), Sites v224, from Sites source commit `cce85c81c623b53ed8eae210d3ee8b6f1589e2fe`. The homepage SHA-256 is `5b74929fde4c46fc5c5479802a47fddac6e77dd22570a70a9364553428a51170`. The Sites catalog origin serves identical homepage bytes. Roll back through Sites to v223 (`da299fe565ca59a9c36a27f6d4077f4088cabb1b`) if needed. The [entry URL](https://field-kit-entry.delbert-hifield.chatgpt.site/) serves the same catalog homepage in its own Sites v58 deployment (`227b88cec14e974df3b0cfd421c61bf473cb182f`, rollback v57). The original entry v44 is the historical pre-cutover snapshot and its source is [archived](https://github.com/Grimmieeee/FIELDKIT-ARCHIVE/tree/7397f97f48804c72af2b530ebff5f14b70deb838/sites/field-kit-entry-v44).

The [catalog by group](CATALOG-BY-GROUP.md) lists all 270 entries across eight navigation groups and search-only Extras. Search and category results are flat, filenames use regular weight. The homepage has no tagline or About popup. The approved title and navigation margins are 32px and 20px. On v212, lockout searches surface Get AD User Details immediately after Unlock AD User. The search suite passed 12 ranking checks and eight simulated result-list scenarios, including the approved BEC order. Download checksums passed. Scope and impact labels retain Tenant and Delete where they apply.

GitHub and Sites have independent source histories. The GitHub baseline reviewed for this update is `f77f25f6cde0a2055f20a157d10674edb756a14e`. Treat its dist tree and operator test copies as revision-specific evidence. Establish byte parity with Sites before using a GitHub test to make a claim about production.

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

## Validation and release

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
