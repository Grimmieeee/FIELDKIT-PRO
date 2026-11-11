## Current production release

- v163 deployed November 11, 2026 from Sites commit `9c89b0424bbbe5fa787bdc7db51854c97021eff1`. GitHub distribution source is `fea77363b436facdb8c26b7ee7f4c92ae148148d`. v162 is the rollback baseline.
- Ryan cleared the Windows Exchange/Graph sign-in and BEC password-reset checks for release. The release verification here consisted of strict source-order, bundle, parser and download integrity checks. The prior v162 QA record below is historical.
- The release includes Exchange-first updates, the BEC package, and interactive CLI wrappers. Terminal-format updates for the other downloadable scripts remain open.

# FIELDKIT-PRO project summary

Read the [Build Standard](tools/field-kit-build-standard.md) before planning work.

## Current baseline

- Canonical test source is [FIELDKIT-PRO](https://github.com/Grimmieeee/FIELDKIT-PRO). Check out and record a specific commit before testing. Use [FIELDKIT-ARCHIVE](https://github.com/Grimmieeee/FIELDKIT-ARCHIVE) for historical comparison.
- [fieldkit.pro](https://fieldkit.pro/) release v162 was built from Sites source commit `ef1399b41de677227019efaf937e29b36286f41e`. Sites and GitHub have separate commit histories. Compare hashes when establishing release parity.
- The operator-verified BEC trio and Client Connectivity Check are in `scripts/`. Their [hash manifest](../qa/operator-verified-2026-11-11.json) identifies the exact files deployed in v162. Keep the BEC scripts together under their canonical filenames.

## Evidence and open work

- [v162 QA baseline](../qa/QA-BASELINE-v162.md) pins the four matching test copies. The GitHub `dist/` tree now mirrors the complete v162 distribution. Use `dist/` for new catalog tests and the pinned `scripts/` copies for the four operator-verified workflows.

- The operator verified the BEC containment and recovery workflow, including off-domain sign-in. Client Connectivity Check and the BEC trio carry exact-source operator verification. PowerShell 7 runtime coverage remains open.
- The 97 published scripts received a static screening. The connection-order gate covers nine dual-service workflows and their 12 checked-in copies. Five live Graph-first paths remain open pending promotion of the fixes. Record live, synthetic and static evidence separately.
- Begin new tests with the FIELDKIT-PRO copies and [active v162 checksums](../qa/V162-SHA256SUMS.txt). Where release parity has not been established, reconcile the applicable copy and its checksum before testing for release acceptance.

## Terminal output and Exchange-first release QA

- Review commit `b695074590088eb78accafb0923ac109f25edb22` passed catalog, bundle, 181 CLI wrapper construction checks and 13 download-integrity cases.
- All five Exchange-first candidates passed source call-order review and the strict hash gate when substituted into an isolated distribution. The review branch keeps the files under `review-candidates/`, so its downloadable catalog still serves the prior scripts. No site was redeployed.
- Release acceptance still requires an integrated distribution with the updated hashes, Windows authentication and tenant/target checks on the changed revisions, and a targeted BEC reset check. The wider downloadable-script terminal-format rollout is also open. v162 remains the live rollback baseline.

### Integrated candidate QA

- The release candidate integrates the Exchange-first fixes into the downloadable sources and pins the BEC ZIP to those exact members. The strict connection-order gate and all 13 download-integrity cases pass.
- A PowerShell 7 parser check found 29 CLI wrappers broken by smart apostrophes. The candidate normalizes apostrophes before escaping literals. The CI parser now checks the 97 downloadable scripts, four repository copies and all 181 generated wrappers.
- Parser and static results do not establish Windows authentication, tenant alignment at runtime, or the changed BEC password-reset behavior. Those checks and the remaining downloadable-script terminal formatting are open. v162 remains the deployed baseline.
