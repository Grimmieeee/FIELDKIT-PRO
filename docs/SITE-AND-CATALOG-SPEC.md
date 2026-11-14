# Site, catalog and mobile reference

## Applicability

Production baseline is Sites v180, source cc19d8f455f790d1c8099cc374901e3f8796b578. See [Project Summary](PROJECT-SUMMARY.md) for the homepage hash and rollback. GitHub CI validates its own checkout. Historical QA records apply to their named revisions.

## Catalog

- Browse by task. Mail, Identity and Reports expose task sections. Reports group by what is inspected. Quick Commands remain directly accessible.
- Search accepts tool names and curated ticket phrases. Exact names and mapped intents precede ordinary matches. Broad matches prefer Read, Modify, Delete, then User, Users and Tenant when applicable. Curated follow-ups may appear directly under the lead result. BEC starts with User Risk Assessment and labels independent follow-ups as parallel checks.
- Scope and Objective narrow results alongside search. Task narrows supported categories. Scope precedes Impact on the card. Use User for one account, Users for multi-user work, Tenant for organization-wide tasks, Device for endpoint work and Self for operator session or workspace tools. Preserve specific boundaries where these labels would misrepresent the target.
- Use Delete for user-account deletion. Other irreversible actions can be Modify with a Destructive flag. Disclose local writes and sensitive output where they change operator decisions.
- Source-review inputs per scope and name real export formats. Reporting and baseline saves are distinct. Ordinary on-screen tools need no generic ticket footer.
- Card details include source-backed inputs, outputs, module names, API scopes, relevant previews and populated Related Items. Quick Commands expose their command through View Code.

## Desktop and mobile

- Dark first, with a light mode toggle. Muted green text marks active categories and scope and impact labels. Category selection uses text color.
- Desktop can show the list and detail pane side by side at 900 CSS pixels and above. Below that breakpoint, verify selection, detail scrolling and back navigation. At 600 CSS pixels and below, check touch targets, wrapped controls and text clipping.
- Check search, Scope/Objective/Task filters, clearing a query, card navigation, theme toggling, Favorites, Compare, View Code, Copy, and a download on desktop and iPhone Safari. Verify preserved focus and legible terminal previews. Record actual browser, viewport, revision and failures.
- Existing Safari acceptance predates the current release. Simulated ranking and rendering checks are available for v180. Exact-v180 browser acceptance is open.

## Release checks

Use the [Build Standard](tools/field-kit-build-standard.md) and [walkthrough](../qa/NEW-ENGINEER-WALKTHROUGH.md). Keep script bytes, embedded payloads, metadata and checksums aligned. Preserve deployment identity and audience. Record the published version and rollback.
