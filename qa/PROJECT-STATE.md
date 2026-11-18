# Current QA handoff

Production is **v262 / entry v94**. Both deployments succeeded. The [Project Summary](<../PROJECT SUMMARY/README.md>) pins sources, hashes, deployment IDs and rollback. Related Items review: 106 lists, 477 to 236 links, 272 cards retained. Sixteen AD module declarations preserve prerequisite setup links. All executable bytes unchanged. Search and actual renderer/link checks passed on both source trees. No browser/PowerShell execution or new live HTTP parity evidence. See [review](<../PROJECT SUMMARY/RELATED-ITEMS-REVIEW.md>).

## Previous naming baseline evidence

# Current QA handoff

Current production: **v261 / entry v93**, deployed successfully November 18, 2026 Pacific. The [Project Summary](<../PROJECT SUMMARY/README.md>) pins sources, hashes, deployment IDs and rollback targets. 272 tools retained; 136 names and nine placements updated. Search/render checks, exact current/legacy title checks, category ordering, link targets, source preservation and bundled syntax checks passed on both Sites sources. No interactive browser or PowerShell execution for this revision. GitHub dist and its historical QA locks are not a copy of the current Sites deployment.

The post-naming source audit screened all payloads and compared 27 overlap families. No retirement justified. See [findings](<../PROJECT SUMMARY/naming-audit/REDUNDANCY-AUDIT.md>) and [comparisons](<../PROJECT SUMMARY/naming-audit/OVERLAP-COMPARISON.md>). Runtime equivalence remains unproven; no customer systems contacted.

## Historical evidence

## VPN release QA — v237 / entry v69

The [Project Summary](<../PROJECT SUMMARY/README.md>) is the current production and verification handoff. Documentation closeout: November 16, 2026 Pacific. No site build or publication accompanies this correction.

| Site | Saved version | Deployment (succeeded) |
|---|---|---|
| fieldkit.pro v237 | `appgprj_6ae3f267936c8191b969e7f49cc0f2ef~appgver_b16c92c0a5b481919579d0cc9381558d` | `appgdep_6afb8a3c4bec8191b1118a84ae4ec5a3` |
| Entry v69 | `appgprj_6ae3f5947cc88191b5a78a7d7ccf00ce~appgver_b9e5f27d03e4819191d35c7a8042f1a7` | `appgdep_6afb8a4698888191b380e771f28711dd` |

Main source: `32ca1aac9b85c2f49ef6cd447cf13c99f5796057`. Entry source: `a0455d5bc5b6351d1dd009f8c61c6fc5944bdb91`. Immediate rollback targets from Sites records: main v236 (`ccb16db37b224865be541a3ebdcc21e4d1e9bb98`) and entry v68 (`53c7841b6d4e9d3f7d5a4b58362d9871ef0319f2`). No rollback was executed.

Published VPN: `dist/published-source/candidates/GET-AZ-VPN-STATUS.ps1`, SHA-256 `77d5eb2c9e8d84f5991a0c2c916adec0a735a9103710d048c57e904fcc93d0cd`. Approved attachment baseline plus resilient error reporting/cleanup/pause and `-NoPause`. Cards use Required Modules and the plain-text Install PowerShell Modules note. View Code and downloads share the source bytes.

Fresh HTTPS checks matched each homepage and the VPN, resource-group and module-installer files against the respective release checkouts across both sites and the catalog origin. Exact source and archive checksums are in the Project Summary. Main and entry homepages have different hashes; the three named script downloads have matching hashes across sites.

**Operator-confirmed completed:** Ryan completed the post-release Windows/Azure smoke test with the published VPN script. Source association is the operator's statement, not a supplied local checksum/transcript. Exact PowerShell version, launch method and per-step results were not supplied. Record no specific module, tenant, connection-status or failure-branch outcome beyond that confirmation.

Release preparation separately passed Linux PowerShell 7.4.13 parser checks, five isolated tests of the actual AST-extracted error-handler blocks, actual page rendering-function checks, JavaScript syntax, manifest/source parity and built Worker endpoint checks. No operational body ran in the isolated tests. Current browser QA is UNEXECUTED. Native Windows failure-injection and other unspecified runtime paths remain UNVERIFIED. Do not transfer historical badges or test outcomes to changed bytes.

The GitHub documentation base was `0ae50d1b122a9a5bc38113a665ef1d35a7f1152d`. Its release suite passed 270 cards and 97 sources. Production has 271 cards. GitHub dist and historical QA locks are distinct snapshots; recover the pinned Sites source for new production tests. Existing v73/v162 and older evidence remains historical.

## Historical QA references

# Current QA references

- [Project status and release baseline](<../PROJECT SUMMARY/README.md>)
- [Site, catalog and mobile specification](<../PROJECT SUMMARY/SITE-AND-CATALOG-SPEC.md>)
- [New engineer acceptance walkthrough](<../PROJECT SUMMARY/NEW-ENGINEER-WALKTHROUGH.md>)
- [Archived QA state, design patches and previous build standard](https://github.com/Grimmieeee/FIELDKIT-ARCHIVE/commit/e177b3cf8301b4e5b27c827099c499b4313e3c9e)

Keep versioned QA evidence tied to the named release. Ryan accepted both sites on November 14, 2026.
