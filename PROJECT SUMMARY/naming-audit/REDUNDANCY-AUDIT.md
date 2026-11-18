# Post-naming redundancy audit

November 18, 2026. Source-based screen of the frozen naming candidate, before release.

## Result

272 tools retained: 90 workflows and 182 Quick Commands. All embedded payloads decoded and fingerprinted. Zero byte-identical payload pairs; zero pairs identical after comment-line and whitespace normalization. These results rule out those narrow forms of duplication only. They do not prove all useful behavior is unique.

27 overlap families compared using decoded source. No retirement or deletion is justified by this review. Preserve standalone quick commands alongside broader workflows where input, backend, output, safeguards or workflow context differ. Consolidation may improve maintenance later, but is a separate product change.

## Evidence and limits

SOURCE-INVENTORY.json records every item, stable source ID, SHA-256, observed command tokens and declared metadata. OVERLAP-COMPARISON.md records the examined families. The homepage SHA-256 is recorded in RELEASE-BASELINE.md; this audit remains tied to those bytes. Both site catalogs are structurally identical after naming normalization. All 90 workflow payloads match a distributed source file.

Execution: 0 PowerShell tools run; 0 customer or host configurations contacted. PowerShell is unavailable in this environment. This is not the full isolated per-item execution audit described in the older attached Script redundancy audit.txt, which referred to a different repository and 326-item baseline. No behavior-equivalence or least-privilege certification is claimed.

## Corrections caught during self-review

1. Get-RecipientPermission is documented by Microsoft as a Send As reader. The earlier proposal to broaden its name was unnecessary. Keep the specific title and add -AccessRights SendAs. Reference: https://learn.microsoft.com/en-us/powershell/module/exchangepowershell/get-recipientpermission

2. Show Group Members uses direct LDAP (System.DirectoryServices.DirectorySearcher) as well as Graph and Exchange. A cmdlet-only screen missed that AD branch. AD coverage is preserved; the broad tool moves to Directory & Tenant Services rather than being labeled Entra-only.

3. The old Full Access reader returned multiple mailbox ACL rights and deny flags. Rename it Show Mailbox Permissions; preserve the broader output.

4. Exact current/legacy titles previously could be displaced by RSAT-first AD search guidance. Exact tool navigation now wins; general AD setup search behavior remains.

## Review dispositions

No source or card retired. No automatic recommendation to merge filtered sign-in, mail-audit or group views. Two challenge passes considered lost output and backend/authority differences; both reinforced retaining those families. Broader workflow availability alone was never used as a replacement criterion.

## Remaining work

If consolidation is desired later, start with sign-in views or mail audit views and design explicit filters/columns first. Require isolated PowerShell execution and preserved target/approval/error semantics before retirement. This release does not depend on those future changes.
