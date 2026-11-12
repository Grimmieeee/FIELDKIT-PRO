## Current production release

- v170 is the locked baseline. It matches card flag typography to action buttons, labels the Graph connector MgGraph, and restores output previews with verified example or script heading text. Sites source is `ab76d99272564c478497b6af64850c6fd1fada1a`. v169 is the immediate rollback.

- v169 was the run-guidance and sidebar baseline. It adds section-local format flags, lean preview output and run guidance, and pane-aligned sidebar branding. Sites source is `27a6808b54102da58ec71b1b1d2aa5116e9715f7`. v168 is the immediate rollback.

- v168 was the compact-card baseline. It aligns small UI labels, narrows desktop tool cards, and labels the PowerShell downloads on all 89 non-CLI cards. Sites source is `c3b6220e563267685bc5286ce9133f07415ac2bd`. v167 is the immediate rollback.

- v167 was the automatic pane-scaling baseline. The desktop dividers match and resizing the results or detail pane automatically scales its content. Sites source is `962c29a3ae5fa7933b0b686da776d0ddb582a779`. v166 is the immediate rollback.

- v166 was the copy-pruning release. It removes repeated preview copy and puts script input beside run instructions. Sites source is `f1516772ea07277055b9616e42613896b89bea8c`. v165 is the immediate rollback. Only catalog HTML changed.

- v165 adds independent preview zoom and arrow-key preview tracking. Sites source is `fd964d1c14dc812551fee5bc0bc6e399da002202`. Only the catalog HTML changed.

- v164 was the terminal-format release and is the immediate rollback for v165. Sites source is `81dc47e2aebc2e4ee50880cb23e521ff390f5bb3` and GitHub distribution source is `44f52d98d0dc8c79417c000b4ef6b88d2f4c0258`. v163 was its rollback baseline.
- Standardized the terminal header and existing close prompts for 90 additional downloadable scripts. The three BEC scripts already use the format. Client Connectivity Check retains its verified presentation. The three full-screen animations retain their display and exit behavior. The PowerShell diff is limited to host output and prompt text.
- Source QA passed for all 97 downloads, nine dual-service workflows, 181 CLI wrappers, the BEC ZIP, and 13 download-integrity cases. PowerShell 7.4.19 parsed 101 checked-in scripts and all wrappers. No new tenant or workstation execution was performed for these presentation changes.

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
