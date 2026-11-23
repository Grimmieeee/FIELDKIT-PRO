# FIELD // KIT build standard

## Authority for on-screen output

The Build Standard, including its locked terminal presentation, is the single source of truth for all FIELD KIT script and Quick Command terminal output: headings, impact, objectives, prompts, connection status, confirmations, findings, action results, ticket notes, errors, incomplete work, timestamps, signature and closing behavior. Older previews, examples, checklist wording and chat drafts are superseded where they conflict. Apply the layout according to the task; do not add mutation confirmations or duplicate ticket summaries to ordinary read-only tools. Preserve useful data, supported inputs, workflow behavior and safeguards. Requested, verified, skipped, failed and unavailable outcomes remain distinct. Do not change operational behavior merely to fit a preview. Site display names govern headings; executable filenames remain stable. Web layout is governed by SITE-AND-CATALOG-SPEC.md; its terminal previews must match the approved script output. Future deviations require an explicit decision recorded in the Build Standard, not an inferred exception.

Documentation authority is locked; implementation and exact-source validation remain separate, pending work. This does not claim all existing scripts already conform.

Use the [current site, catalog and mobile reference](SITE-AND-CATALOG-SPEC.md) for UI and taxonomy requirements. Historical standards remain in Git history. Use the [naming standard](NAMING-STANDARD.md) and [rename map](NAMING-MAP.json) for current display names; executable filenames and native headers remain stable. Recover the pinned Sites source for production tests. GitHub's release suite validates its own older application tree.

## Approved interpretation — November 23, 2026

These explicit decisions supersede conflicting older checklist guidance. Preserve verified workflow behavior; this documentation update does not approve candidate scripts or change production.

- Preserve existing MFA enforcement in account creation. Do not remove it or replace it with a different policy model during alignment. Keep its API, permissions and runtime limitations explicit. BEC password reset and user password change remain separate steps; this does not add forced first-sign-in password change to BEC.
- Keep installation of required missing tools/modules when not detected. Check first; do not reinstall or upgrade present tooling merely for alignment. Report installation failures clearly. Preserve required platform/elevation boundaries and unattended behavior. This permission does not authorize execution-policy changes.
- Keep reusing compatible Graph sessions. Validate required scopes, expected tenant, connection context and target before use; reconnect only when needed. Reuse is not permission to trust an unrelated existing session.
- Replace employer branding such as CHR/CHR Support in active operator copy and templates with the exact signature `b u r n s i d //`. Remove client-specific `.itglue.com` references; use a neutral instruction when the link served a useful purpose. Do not substitute the signature into a URL or alter historical evidence or functional identifiers through blind replacement.
- Offboarding shows the target and reviewed plan, then accepts the single token `OFFBOARD`. Do not require appending the UPN. Documentation and previews must match.
- Account deletion must perform deletion in the authoritative directory, not only disable access, revoke sessions or remove licenses. Verify absence in that same source; failed reads are not proof of absence. Distinguish deletion from permanent purge. Do not silently expand deletion into a purge. Synced identities are deleted in AD; the resulting Entra removal is separately verified after sync.
- Align operator wording, impact labels, prompts and close behavior while preserving functionality. Use the established AD Groups output as the model: who was checked, what was found or changed, and what still needs action. Keep connection diagnostics outside ticket blocks. Ordinary on-screen tools need no generic ticket footer.
- Use the locked terminal layout below. Print the local completion timestamp at the end, not a start timestamp at the top. Use the same local time basis for event times; retain material action timestamps when a timeline matters.

## Preserve the working workflow

Start from the exact verified script version. Preserve prompts, approvals, connection behavior, results and executable filenames unless the authorized change touches them. Catalog names and search aliases may evolve separately. Show the target and plan before mutations; verify resulting state where reliable readback exists and distinguish completed, skipped, failed and unverified work. Recheck target and authority after approval for destructive identity work. Keep incomplete evidence visible.

## Connection order and verification

- Any workflow that needs both Exchange Online and Microsoft Graph establishes or validates Exchange first, then establishes or validates Graph. Apply this to standalone entry, same-session continuation, retries and fallbacks. Single-service workflows connect only to the service they need.
- Establishing a session is separate from using it. Before mailbox reads or writes, verify tenant agreement and match the mailbox to the expected directory identity. Preserve required permissions, approvals and authority checks.
- On every change, run `node qa/scripts/release-check.cjs`. The connection-order check detects unreviewed dual-service sources, changed reviewed bytes, and stale review entries. Review the reachable call paths for new or changed sources and update the evidence only after checking those paths.
- Before releasing connection-order changes, run `node qa/scripts/release-check.cjs --require-aligned`. The strict check blocks any unresolved path. Exercise standalone and same-session starts as applicable in the supported Windows hosts. Record connection order, tenant and target matching, and the exact revision tested. Earlier operator verification remains the baseline for the tested bytes.

## Locked terminal presentation — November 23, 2026

This layout supersedes older filename-first, impact-in-title, start-timestamp and close-prompt wording. It changes presentation, not operational behavior or script filenames.

```text
User Account Termination

Impact: Makes Changes

Objective: Disable the user account, reset the password,
revoke sessions, and review group memberships and licenses
for removal. Identify mailbox and OneDrive follow-up.

[Task-specific input and connection status]

CONFIRM:

[Target and planned changes]

Type OFFBOARD to proceed (q to quit): OFFBOARD

RESULTS:

[Actual outcomes, including requested, verified and failed actions]

TICKET NOTE:

[Concise results and actionable follow-up]

[XX] Incomplete:

[Only unresolved work; omit this section when none remains]

11.23.2026 : 14:35 PST

b u r n s i d //

Press Enter to close.
```

Use the tool's own site display name and actual impact. Timestamp format is `MM.dd.yyyy : HH:mm zzz-label`, where the final label is the actual local timezone abbreviation (PST in the example, PDT when applicable), not a hard-coded year-round PST. The timestamp is completion time, including incomplete or failed runs. Ordinary read-only tools do not duplicate results into an unnecessary ticket note or show mutation confirmation. Preserve required task-specific prompts and applicable BEC handoffs. Preview placeholders above describe placement and are not printed literally. No implementation or runtime verification is implied by locking this presentation.

## Interactive terminal output

- Start with the exact site display name, then a blank line, `Impact: Read-only`, `Impact: Makes Changes` or `Impact: Destructive`, then a blank line and a concise, specific `Objective:`. Executable filenames stay unchanged.
- Use plain labels such as `UPN:`, blank lines between sections, and concise prompts for the current stage. Retain input validation, target checks and required approvals. Keep unattended and composable entry points noninteractive.
- Reserve red for operational failures. Use warnings for incomplete data and review findings. Use the same local timezone for displayed run and event timestamps, including the offset when time matters.
- End interactive tools with `Press Enter to close.` or the applicable BEC handoff. Add a blank line before it when needed. Keep native CLI results, error behavior and required safeguards intact.
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
