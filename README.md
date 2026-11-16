# FIELDKIT-PRO

FIELD // KIT PRO PowerShell catalog, source and release evidence.
See [Project status](<PROJECT SUMMARY/README.md>) for the live release, source boundaries, and verification steps.
See [Site, catalog and mobile reference](<PROJECT SUMMARY/SITE-AND-CATALOG-SPEC.md>) for the production UI contract and acceptance checklist.

Start with the [Build Standard](<PROJECT SUMMARY/field-kit-build-standard.md>), then read the [Project Summary](<PROJECT SUMMARY/README.md>). Use a pinned FIELDKIT-PRO copy for GitHub tests; establish parity with the pinned Sites release before claiming production coverage. [Repository instructions](AGENTS.md)

Live site: https://fieldkit.pro/ — Sites **v237**. The separate [entry site](https://field-kit-entry.delbert-hifield.chatgpt.site/) is **v69**. Current Sites pins, download hashes, rollback targets and the operator-confirmed VPN smoke test are in the Project Summary. This documentation correction does not rebuild or republish either site.

- Security guidance: [SECURITY.md](SECURITY.md).
- Current release handoff: [qa/PROJECT-STATE.md](qa/PROJECT-STATE.md). Other versioned QA records retain their original historical scope.
- `release-baseline` is historical assembly material. Recover the pinned Sites source for the current production payload. Superseded review candidates are preserved in FIELDKIT-ARCHIVE.

The site is hosted with Sites, independently of GitHub Pages. This repository is public. Windows validator 1.0.1 was operator-reported at 161 PASS, 0 FAIL, 0 SKIP; verification remains source/version-specific.

Legacy repository removal is owner-approved. Current site download resolution uses hosted, same-origin files rather than the original repositories. See [current release review](qa/SITE-LOCK-REVIEW-2026-11-03.md), `qa/RELEASE-LOCK.json` and `qa/REPOSITORY-CLEANUP.json` for the historical baseline and deletion limits.
