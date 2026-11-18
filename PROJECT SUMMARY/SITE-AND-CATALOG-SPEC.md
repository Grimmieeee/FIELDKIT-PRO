# Site, catalog and mobile reference

## Applicability

The [Project Summary](README.md) pins the current Sites production revision. See [Project Summary](README.md) for the homepage hash and rollback. GitHub CI validates its own checkout. Historical QA records apply to their named revisions.

## Naming baseline

Use [NAMING-STANDARD.md](NAMING-STANDARD.md), [NAMING-MAP.json](NAMING-MAP.json), and [CATALOG-BY-GROUP.md](CATALOG-BY-GROUP.md) for current names and exact category membership. All 272 tools retained. Old titles remain search aliases. Keep direct reads, audit records, guided review and mutations distinct. The current README source pins override historical revision references.

## Catalog

- Browse the eleven catalog sections, which default to A–Z, or search across All by relevance. Extras remain search-only. Search and category results use a flat list. Quick Commands remain directly accessible.
- Search accepts exact tool names, mapped commands, and ticket wording. Exact names and curated mappings take precedence over diagnostic wording rules. Unmatched category searches offer Search all categories. Generic account-compromise searches lead with assessment, followed by containment and recovery. Exact containment and recovery tool names lead with the named tool.
- The selected category filters results. Scope precedes Impact on the card. Use User for one account, User(s) for multi-user work, Tenant for organization-wide tasks, Workstation for computer tasks and Terminal for operator-session tools. Preserve AD, Cloud, Endpoint and other specific source-backed scopes where applicable. Preserve specific boundaries where these labels would misrepresent the target.
- Use Delete for user-account deletion. Other irreversible actions can be Modify with a Destructive flag. Disclose local writes and sensitive output where they change operator decisions.
- Source-review inputs per scope and name real export formats. Reporting and baseline saves are distinct. Ordinary on-screen tools need no generic ticket footer.
- Card details include source-backed inputs, outputs, **Prerequisites**, API scopes, Script Preview and populated Related Items. Quick Commands expose their command through View Code. List module names without version suffixes. When modules are listed, add a quiet setup link that opens Install PowerShell Modules. Keep source-required connection commands and conditional notes; omit empty sections and new elevation boilerplate. View Code and Download use the same embedded source bytes as the direct source endpoint.

## Desktop and mobile

- Dark first, with a light mode toggle. Muted green text marks active categories and scope and impact labels. Category selection uses text color.
- Desktop can show the list and detail pane side by side at 900 CSS pixels and above. Below that breakpoint, verify selection, detail scrolling and back navigation. At 600 CSS pixels and below, check touch targets, wrapped controls and text clipping.
- Check search, category filtering and recovery, clearing a query, card navigation, theme toggling, Favorites, Compare, View Code, Copy, and a download on desktop and iPhone Safari. Verify preserved focus and legible terminal previews. Record actual browser, viewport, revision and failures.
- At the historical v181/v44 checkpoint, Ryan accepted both the production catalog and the separate entry site on November 14, 2026. This records operator acceptance. Simulated ranking and rendering checks are separately recorded for v180.

## Release checks

Use the [Build Standard](field-kit-build-standard.md) and [walkthrough](NEW-ENGINEER-WALKTHROUGH.md). Keep script bytes, embedded payloads, metadata and checksums aligned. Preserve deployment identity and audience. Record the published version and rollback.

## Historical v237 / entry v69 acceptance scope

The [Project Summary](README.md) records the approved GET-AZ-VPN-STATUS.ps1 hash, current Sites commits, rollback versions and live byte parity. Its error path reports the failed stage/message before the close prompt, preserves the original failure through cleanup and unavailable input, and supports -NoPause. Ryan's post-release Windows/Azure smoke test is **operator-confirmed completed**; no per-step transcript or launch mechanism was supplied. Current desktop/mobile browser interaction QA and Windows launch-error injection remain unverified. Historical browser acceptance does not verify these revisions.
