# FIELDKIT-PRO

FIELD // KIT PRO PowerShell catalog, source and release evidence.

Start with the [Build Standard](docs/tools/field-kit-build-standard.md), then read the [Project Summary](docs/PROJECT-SUMMARY.md). Use the checked-in FIELDKIT-PRO copies for new tests. [Repository instructions](AGENTS.md)

Live site: https://fieldkit.pro/

- Current verified test copies: `scripts/`. See the [v162 QA baseline](qa/QA-BASELINE-v162.md).
- Current v162 catalog and hosted sources: `dist/`. The [v162 QA baseline](qa/QA-BASELINE-v162.md) records the source revision and parity checks.
- Security guidance: [SECURITY.md](SECURITY.md).
- Release and verification evidence: `qa/`.
- Proposed or historical sources under `review-candidates`, `release-baseline` and candidate directories are not automatically active downloads.

The site is hosted with Sites, independently of GitHub Pages. This repository is public. Windows validator 1.0.1 was operator-reported at 161 PASS, 0 FAIL, 0 SKIP; verification remains source/version-specific.

Legacy repository removal is owner-approved. Current site download resolution uses hosted, same-origin files rather than the original repositories. See [current release review](qa/SITE-LOCK-REVIEW-2026-11-03.md), `qa/RELEASE-LOCK.json` and `qa/REPOSITORY-CLEANUP.json` for the historical baseline and deletion limits.
