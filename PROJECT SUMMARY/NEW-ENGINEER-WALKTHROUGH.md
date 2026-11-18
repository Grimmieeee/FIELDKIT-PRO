# New engineer acceptance walkthrough

Use the published revision named in the test record. Browse and search only. Execute scripts separately in the approved environment.

1. Search `user locked out`, `hidden inbox rules`, and `tenant license report`. Confirm the first result fits the task and the relevant scope is visible.
2. Search `bec`. Confirm User Risk Assessment, Contain and Eradicate, and Restore and Validate appear in that order.
3. Select Identity & Access (Local) and search `message trace`. Choose Search all categories and verify the query stays put and BEC: Trace Email Delivery appears. Clear the query.
4. Search `bec` and verify the left sort menu offers Relevance, A–Z, and Z–A. Try Scope and Impact, then restore Relevance without clearing the query.
5. Open a script and a Quick Command. Verify inputs, outputs, source display, copy, and download availability.
6. Repeat key interactions on desktop and iPhone Safari. Use the [site specification](SITE-AND-CATALOG-SPEC.md) for acceptance and record the exact revision tested.

## Current handoff — v261 / entry v93

Use the [Project Summary](README.md) source pins. On both themes, verify Prerequisites shows module names without versions and the setup link opens Install PowerShell Modules. Check A–Z in each category, former/current title searches and the nine moves in NAMING-MAP.json. Verify source display and downloads against the pinned payload. Record desktop/iPhone Safari results separately; these browser checks were not executed during this release.

## Historical VPN acceptance notes

### Prior handoff — v237 / entry v69

Start with the [Project Summary](README.md) and [current QA state](../qa/PROJECT-STATE.md) for the source hashes and evidence boundaries. Ryan's published-VPN Windows/Azure smoke test is **operator-confirmed completed**. Do not re-open it as unexecuted or infer step outcomes without evidence.

Browser QA for these revisions remains **UNEXECUTED**. When that path is exercised, check the VPN card's Required Modules label, Az.Accounts/Az.Resources/Az.Network list, and plain-text Install PowerShell Modules note. Open View Code and save Download; compare the saved VPN hash with the published hash in the summary. Check Script Preview's tenant prompt, optional resource-group choice and example error output. Repeat applicable interactions on desktop and iPhone Safari and record the exact version, browser and outcomes. Existing source/render-function and HTTP-byte checks do not establish these browser interactions.

Native Windows Run with PowerShell error injection, unattended Azure operation, and the module installer's separate options remain unverified unless a specific later record covers them. No new runtime execution is required for this documentation correction.
