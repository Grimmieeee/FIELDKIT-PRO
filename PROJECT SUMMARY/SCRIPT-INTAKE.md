# Script intake review

The [Build Standard](field-kit-build-standard.md), including its November 23 approved interpretation, controls workflow preservation, missing-tool installation, MFA enforcement, Graph reuse, branding, approvals and deletion semantics.

Use this checklist for each submitted script before proposing a catalog entry. A source review can support card copy. Runtime verification is a separate result.

| Field | Record |
|---|---|
| Source | Repository or submission, pinned revision or SHA-256, and evidence type |
| Operator task | What decision or action does this help an engineer make? |
| Catalog home | One primary catalog category, card title, and format |
| Scope and impact | Target and greatest effect available during normal use. Call out conditional writes and irreversible actions. |
| Inputs | Required and optional inputs, defaults, cancellation, and batch formats actually supported |
| Prerequisites | Platform, PowerShell version, modules, connection order, permissions and approvals where applicable |
| Outputs | Actual terminal results, export formats and gates, limitations, and sensitive fields |
| Discovery | Exact tool or command name, ticket phrases, and expected lead and follow-up results |
| Overlap | Closest entries and the material difference. Recommend add, update, link, or hold. |
| Decision | Supported card copy, claims to fix, and checks needed for any proposed change |

Review the reachable paths for each claim. Use source evidence to distinguish missing data from negative findings. Before release, tie the approved card and download to the same bytes and use the existing release checks. Record runtime or operator evidence only when it exists.

## Historical dry run — Find What’s Using Disk Space

- **Source:** Sites v180 source commit `cc19d8f455f790d1c8099cc374901e3f8796b578`, `dist/published-source/candidates/GET-DISK-SPACE-USAGE.ps1`, SHA-256 `1cf92aa361aa41e59f21f895089d0beabbaeaf091310092f15e6b5cc7a8c5992`.
- **Proposed card:** Endpoint → Disk Space. Downloadable workflow. **Device · Read**. Show free space on ready fixed drives and rank the largest readable locations on one selected drive.
- **Inputs:** Drive letter. If omitted, the prompt lists drives first and a blank answer cancels the scan. Optional Top defaults to 10 and accepts 1–50.
- **Prerequisites:** PowerShell 5.1 or later on Windows with a ready fixed drive. Results depend on read access. The reviewed source uses local filesystem APIs and cmdlets.
- **Output:** On Screen. Shows free and total capacity, ranked readable file lengths, read-error directory count and skipped reparse-point count. Readable file lengths may differ from allocated disk usage. The source has no export path.
- **Discovery:** `disk filling up` should lead to this workflow. `show local drive free space` describes the narrower capacity-only task.
- **Overlap:** Show Local Drive Free Space answers how much is left. This workflow adds where readable usage is concentrated. Keep both.
- **Decision:** Source supports the proposed card. This was a static dry run. No script was executed and no catalog entry changed.

Return to [Project Summary](README.md).
