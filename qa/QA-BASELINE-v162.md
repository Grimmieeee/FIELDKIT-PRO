# FIELDKIT-PRO QA baseline for v162

November 11, 2026 Pacific time

## Locked scope

- GitHub test source: `3129e41c8fbb962349c9b4bfb2ecd7b672010d14`, under `scripts/`.
- Sites source: `ef1399b41de677227019efaf937e29b36286f41e`, release 162.
- [Operator verification manifest](operator-verified-2026-11-11.json) pins Client Connectivity Check and the three BEC stages. All four GitHub copies matched the pinned Sites files byte-for-byte. The BEC companion handoffs resolve within `scripts/` under canonical filenames.

## Checks and exceptions

| Check | Result |
|---|---|
| GitHub snapshot release checks | 341 catalog entries, 102 release files, six cases passed |
| GitHub snapshot download checks | 13 synthetic cases passed |
| Sites v162 release checks | 270 catalog entries, 97 PowerShell sources, search and bundle checks passed |
| Sites v162 download checks | 13 synthetic cases passed |
| GitHub `dist/` versus Sites `dist/` PowerShell paths | One exact path-and-byte match, 78 shared paths with different bytes, 10 GitHub-only paths, 18 Sites-only paths |
| Fresh Windows PowerShell 5.1 or PowerShell 7 execution | Unexecuted in this audit |

The four locked files have no hardcoded legacy checkout path or runtime fetch from FIELDKIT-ARCHIVE. BEC containment help refers to the legacy host by name as an environment description. Its AD actions depend on Windows identity and AD connectivity. Client Connectivity Check needs the ActiveDirectory and Graph modules. BEC needs Graph and Exchange modules and delegated permissions.

The historical GitHub snapshot contains two utilities with defaults tied to `C:\Field-Kit`. `GET-TERMINAL-READINESS-CHECK.ps1` checks old folder and companion filenames, and `INVOKE-FILE-INVENTORY.ps1` defaults to scanning that tree. Neither is in v162. Keep them out of current launch and validation instructions.

Six other v162 scripts use both Graph and Exchange. Group Members and User Predelete Check use service-specific branches. Quarterly Cleanup Review, Disabled User Mailbox Access Cleanup, Shared Mailbox Sign-in Audit and Tenant Group Owners require path-specific review of tenant resolution and session reuse. Preserve their connection order until a change can be verified against the same tenant and target. No script was changed during this audit.

## Full-catalog lock

Open. Reconcile the v162 files with the canonical GitHub test source before taking release evidence on any additional script. From a clean Windows working directory, run the pinned read-only connectivity and risk checks with the legacy checkout absent, then exercise only authorized workflow stages. Record Windows PowerShell 5.1 and PowerShell 7 separately.
