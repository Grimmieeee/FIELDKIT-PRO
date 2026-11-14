# FIELD // KIT build standard

Use the [current site, catalog and mobile reference](SITE-AND-CATALOG-SPEC.md) for UI and taxonomy requirements. Historical standards remain in Git history.

## Connection order and verification

- Any workflow that needs both Exchange Online and Microsoft Graph establishes or validates Exchange first, then establishes or validates Graph. Apply this to standalone entry, same-session continuation, retries and fallbacks. Single-service workflows connect only to the service they need.
- Establishing a session is separate from using it. Before mailbox reads or writes, verify tenant agreement and match the mailbox to the expected directory identity. Preserve required permissions, approvals and authority checks.
- On every change, run `node qa/scripts/release-check.cjs`. The connection-order check detects unreviewed dual-service sources, changed reviewed bytes, and stale review entries. Review the reachable call paths for new or changed sources and update the evidence only after checking those paths.
- Before releasing connection-order changes, run `node qa/scripts/release-check.cjs --require-aligned`. The strict check blocks any unresolved path. Exercise standalone and same-session starts as applicable in the supported Windows hosts. Record connection order, tenant and target matching, and the exact revision tested. Earlier operator verification remains the baseline for the tested bytes.

## Interactive terminal output

- Start with the canonical filename or CLI entry title, followed by ` // ` and the actual impact flag. Use a blank line, one short `Objective:` sentence, and a blank line before the first prompt or result.
- Use plain labels such as `UPN:`, blank lines between sections, and concise prompts for the current stage. Retain input validation, target checks and required approvals. Keep unattended and composable entry points noninteractive.
- Reserve red for operational failures. Use warnings for incomplete data and review findings. Use the same local timezone for displayed run and event timestamps, including the offset when time matters.
- End interactive tools with `Press ENTER to close.` or the applicable BEC handoff. Add a blank line before it when needed. Keep native CLI results, error behavior and required safeguards intact.
- BEC password reset and user password change are separate operator steps. Do not add a forced first-sign-in password change to this workflow. Keep the operator checklist brief and preserve the canonical three companion filenames.
- Keep client-specific data, obsolete paths, and unrelated workflow prompts out of examples and CLI output. Rebind exact-source verification only after the changed behavior has evidence.

## Hybrid Windows execution baseline

- Start with [Project Summary](README.md) and test the exact checked-in FIELDKIT-PRO revision. Use FIELDKIT-ARCHIVE for historical comparison only.
- Validate from a domain-connected Windows host running PowerShell 5.1. Record PowerShell 7 runtime results separately.
- For BEC User Risk Assessment, establish Exchange Online before Graph. Validate both tenants and match the mailbox external directory object ID to the Graph user ID before mailbox work. Reuse only a compatible, validated connection. Keep Graph-only and Exchange-only workflows independent.
- Keep the three BEC stages in the same PowerShell session with canonical companion filenames. Preserve stage-specific authentication and target checks when a stage is launched independently. Keep containment and recovery behind explicit operator confirmation.
- For synced identities, verify the authoritative AD write by readback. A delta request is an accepted request. Verify the resulting Entra account state and operator sign-in separately. The Entra Connect host and domain controller are separate roles. Keep environment-specific host input out of generic workflow prompts unless that workflow explicitly needs a host.
- For interactive launches, show startup or connection failures and retain the result until the operator exits. Preserve unattended behavior. Keep prompts short, use blank lines between sections, and distinguish missing data from negative findings.
- Bind operator verification to exact source bytes and tested scope. Update the download allowlist, catalog checksums and card metadata together. A source review or a release check carries its own evidence.

## Source and release integrity

- Check the exact revision and source bytes before claiming verification. Document static review, simulated browser results, operator validation and production delivery separately.
- Keep source downloads and embedded copies aligned. Preserve the checksum manifest. Run the release and download integrity checks, and parse changed PowerShell without executing customer operations.
- Add previews using fictional data. Disclose missing checks and evidence gaps. Preserve existing workflow approvals and change boundaries.
- BEC Restore and Validate offers one consolidated TXT summary, including available stages when final assessment returns no result or throws. Treat an incomplete summary as incomplete evidence.
