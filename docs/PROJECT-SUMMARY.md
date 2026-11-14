# FIELD // KIT project status

## Production and source

Production is [fieldkit.pro](https://fieldkit.pro), Sites v180, from Sites source commit `cc19d8f455f790d1c8099cc374901e3f8796b578`. The homepage SHA-256 is `3c636caa08272d9018da5b1edc78385683d1480e7d5702efe2ba105083a6e796`. Roll back through Sites to v179 if needed. The entry site publishes separately.

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
