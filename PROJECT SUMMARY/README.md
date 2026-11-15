# FIELD // KIT project status

## Production and source

Production is [fieldkit.pro](https://fieldkit.pro), Sites v204, from Sites source commit `71d66bae8eabb4ddf3ee71011c87bcbd4f08fcdc`. The homepage SHA-256 is `6c1f5e02111779f611d80e359ec9d1e534795a0a775dc1b2aba3e2ca5f4a835d`. Roll back through Sites to v203 (`6f7aee0e7a789fd66a6dfa359ccf0de22e2706ee`) if needed. The entry site publishes separately.

The [catalog by group](CATALOG-BY-GROUP.md) lists all 270 entries across the eight navigation groups. Search and category results are flat, filenames use regular weight, and the tagline is **For everyday IT**. BEC workflow order, group membership, card toggling, and download checksums passed. Scope and impact labels retain Tenant and Delete where they apply.

GitHub and Sites have independent source histories. The GitHub baseline reviewed for this update is `f77f25f6cde0a2055f20a157d10674edb756a14e`. Treat its dist tree and operator test copies as revision-specific evidence. Establish byte parity with Sites before using a GitHub test to make a claim about production.

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

Ryan accepted both the production catalog and the separate entry site on November 14, 2026. The existing production checkpoints are catalog v181 and entry v44.

Start changes here. Update the affected reference in the same change as the implementation. Update this index when the deployed version, source hash, rollback point or acceptance evidence changes. Preserve historical evidence against its original revision. If a Sites runbook needs a current reference, link this bank and use the release-specific record for deployment evidence.

See [QA file disposition](QA-DISPOSITION.md) for retained and archived evidence. The Sites source runbook links back here.

## v181 verification

Ryan verified desktop and iPhone browser acceptance. Twelve ranking checks, eight simulated result-list scenarios, and 97 packaged checksums passed. All 102 public files matched the pinned release byte for byte over HTTPS. The three intake card updates changed catalog presentation and search; PowerShell payloads were unchanged.
