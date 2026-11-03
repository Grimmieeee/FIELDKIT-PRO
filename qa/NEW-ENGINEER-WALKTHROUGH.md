# First-time engineer walkthrough

Reviewed source b4e72378d47dd44747929400da1cc69b01806aa1 using the local Chromium preview of the current deployed source. The newer locked capability-reference design and operational candidates are separate and not deployed. No tenant actions or operational script execution performed.

## Scenarios observed

- First use: Take a tour opens; optional workstation preparation exposes Setup package, readiness check and read-only account/mailbox checks. Instructions distinguish local READY from tenant access.
- Account status: opens from setup; Read only flag, target scope, concise run instructions and delegated Graph scopes visible. Bulk TXT/CSV formats are not discoverable from the short run instructions.
- Password reset: password search returns 12 results. Reset Cloud User Password is first; generic Reset Password is an AD quick command. Opening the latter explains AD, but the result title alone does not. Quick command still uses literal username rather than the approved angle-bracket placeholder convention.
- BEC: BEC search returns 11 tools with Assessment first. Assessment has active Read only and muted later-stage flags; accessible group label explains the distinction. Workflow instructions use the matching friendly launch filename and same-window guidance. Package inspection confirms three friendly filenames plus three internal companion aliases, guide and checksums. Aliases are intentional; duplicate-looking files remain a new-user friction point.
- Missing tool: Terminal Tools is visible and says Download withheld pending validation, with links to Prepare FIELD KIT and Check Toolkit Setup. Setup tour also links Terminal Tools, which is a distracting unavailable path for a new user.
- Mailbox question: who has access to a mailbox returns zero results; mailbox permissions finds the expected card. Empty-state guidance says to try another task name/search.
- Permissions: Get Mailbox Permissions lists Get-MailboxInputs alongside Exchange cmdlets, although it is a script-local function. Source cross-check finds this class of error on six cards; see new-engineer-permission-findings.json.
- Favorites: saving Mailbox Permissions updates state and saved count persists after reload. Reload from the tour hash also exposed a navigation defect, preventing a clean filtered-view persistence assessment in that sequence.
- Navigation failure: visit Take a tour, return to catalog via the card/home controls without clearing #start-here, reload. Main content is blank. Screenshot and AX observation confirmed. Clicking Take a tour restores content; Browse catalog changes hash to #catalog and restores normal navigation.

## Priorities

1. Fix #start-here reload so a direct or refreshed tour URL renders meaningful content. Also keep URL route consistent when returning to catalog.
2. Exclude script-local functions from generated Exchange permission lists on all six affected cards.
3. Distinguish AD and cloud reset result titles and normalize operator placeholders in the quick command.
4. Keep required inputs short, but expose accepted input formats through source-backed capability markers. Do not infer input/output capability from scope alone.
5. Remove the unavailable Terminal Tools shortcut from first-use setup until it can run; working setup/readiness alternatives already exist.
6. Explain intentional BEC companion aliases briefly in the package guide rather than add card text.
7. Improve no-result search guidance or stop-word handling for plain-language task questions. This is a usability improvement, not a broken keyword search.

No design changes or fixes applied during this review. Browser download acceptance, Windows execution, physical iPhone/Safari and live authentication remain outside this walkthrough. The flow is understandable for an engineer familiar with PowerShell; the routing and permission defects should be fixed before launch. No redesign recommended.
