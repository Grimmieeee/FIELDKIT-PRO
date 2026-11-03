# Security

FIELDKIT-PRO is public. Treat committed content as public, including files not linked from the catalog.

Do not commit passwords, tokens, private keys, PFX files, client credentials or private client/incident evidence. Use clearly synthetic examples.

The catalog is a static website hosted with Sites. Downloadable scripts run on the operator's computer, not on the website. Review code and permissions, use an authorized account and approved endpoint, and confirm the tenant and target before approving changes. Keep secrets and collected evidence out of shared logs.

## Download integrity

The page checks release-bound SHA-256 hashes before showing, copying or downloading hosted script sources. Only approved same-origin paths are allowed; redirects, HTML responses, oversized files and checksum mismatches are rejected. Download bytes preserve original encoding markers and line endings.

These checks detect mismatched or corrupted responses. They do not prove script safety or protect against someone able to replace both the page and its checksums. Protect repository and hosting access and review source changes.

## Verification

Verification is tied to exact source/version evidence. Source review, synthetic tests, operator acceptance and live-service tests are different evidence. A successful download or connection test does not prove every operational action.

## Exposure response

If a credential is exposed, revoke or rotate it first. Remove exposed content, address Git history where needed, verify hosted copies are clear, and review relevant access. Deleting a repository alone does not revoke a credential or remove other copies.

Do not submit credentials or private incident evidence through public GitHub issues. Use public issues only for sanitized questions or reproducible defects.

## Release checks

From the repository root:

```text
node qa/scripts/release-check.cjs
node qa/scripts/download-integrity-check.cjs
```

Keep release source, manifests and deployment artifacts aligned. Confirm the intended host serves the current release and test relevant browser actions. Parser/static checks, successful deployment and Windows/tenant validation remain separate results. These checks are not a comprehensive vulnerability scanner.
