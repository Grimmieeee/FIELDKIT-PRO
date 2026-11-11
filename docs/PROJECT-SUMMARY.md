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
