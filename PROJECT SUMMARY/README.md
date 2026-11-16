# FIELD // KIT project status

## Production and source

Production is [fieldkit.pro](https://fieldkit.pro/), Sites v213, from Sites source commit `ba086dfacc9d1e4a9c61bc335d8d6a7b4819a59c`. The homepage SHA-256 is `c77b0dbee6dfcec18f3f7b7ed217ce57b334c63877d8e974d24def66adf44fad`. The Sites catalog origin serves identical homepage bytes. Roll back through Sites to v212 (`eeb34a2bc33ffb336a7cedaf06931d6ea1b3aefe`) if needed. The [entry URL](https://field-kit-entry.delbert-hifield.chatgpt.site/) serves the same catalog homepage in its own Sites v47 deployment (`14fb88ddde1e9ba2933b565481ab443d1d6386e1`, rollback v46). The original entry v44 is the rollback point and its source is [archived](https://github.com/Grimmieeee/FIELDKIT-ARCHIVE/tree/7397f97f48804c72af2b530ebff5f14b70deb838/sites/field-kit-entry-v44).

The [catalog by group](CATALOG-BY-GROUP.md) lists all 270 entries across the eight navigation groups. Search and category results are flat, filenames use regular weight. The homepage has no tagline or About popup. The approved title and navigation margins are 32px and 20px. On v212, lockout searches surface Get AD User Details immediately after Unlock AD User. The search suite passed 12 ranking checks and eight simulated result-list scenarios, including the approved BEC order. Download checksums passed. Scope and impact labels retain Tenant and Delete where they apply.

GitHub and Sites have independent source histories. The GitHub baseline reviewed for this update is `f77f25f6cde0a2055f20a157d10674edb756a14e`. Treat its dist tree and operator test copies as revision-specific evidence. Establish byte parity with Sites before using a GitHub test to make a claim about production.

## Search audit update

Generic account-compromise queries start with assessment. Exact BEC containment and recovery names lead with the requested tool. Mailbox access and forwarding distinguish individual and tenant-wide work. Ticket aliases cover message trace, tenant MFA, lockout, failed login, password expiry, available licenses, disk space, and uptime. Empty category searches offer Search all categories. The simulated suite passed 12 ranking checks, eight existing scenarios, 17 targeted mappings, and category recovery rendering. All three live homepage responses matched the release bytes.

## Catalog and operator workflow

The catalog supports ticket-language search, task sections, Reports, Scope and Objective filters, and ranked follow-up checks. User and Users distinguish individual and batch work. Tenant represents organization-wide coverage. Check each card against its source for supported input and export formats.

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

Start changes here. Update the affected reference in the same change as the implementation. Update this index when the deployed version, source hash, rollback point or acceptance evidence changes. Preserve historical evidence against its original revision. If a Sites runbook needs a current reference, link this bank and use the release-specific record for deployment evidence.

See [QA file disposition](QA-DISPOSITION.md) for retained and archived evidence. The Sites source runbook links back here.

## v181 verification

Ryan verified desktop and iPhone browser acceptance. Twelve ranking checks, eight simulated result-list scenarios, and 97 packaged checksums passed. All 102 public files matched the pinned release byte for byte over HTTPS. The three intake card updates changed catalog presentation and search; PowerShell payloads were unchanged.
