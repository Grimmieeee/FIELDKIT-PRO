# One-file FIELD KIT validator

Deliverable: VERIFY-FIELD-KIT.ps1. Everything required for the offline checks is embedded; no companion source files, repo checkout, download or module installation is performed.

Run on the approved Windows jumpbox using Run with PowerShell (Windows PowerShell 5.1), or launch from a new PowerShell window. Defaults to interactive local checks then a Graph / Exchange / Both / Skip choice. Enter the expected tenant and optional test UPN. An existing Graph context or Exchange session is rejected before new connections are attempted. Only connections attempted by this validator are disconnected.

The live probes request Organization.Read.All and User.Read.All for Graph, and make read-only Exchange organization/domain/mailbox queries. The selected tenant is checked before target reads. Module availability and import compatibility are checked; required modules must already be installed through the approved process. Optional targets are not marked passed when skipped.

Desktop outputs: one synthetic FIELD-KIT-CSV-TEST CSV and one FIELD-KIT-VALIDATION JSON report. Dummy targets use example.test; tenant user/mailbox records are not exported. The JSON may contain tenant/domain/UPN details in error messages; review before sharing. Temporary isolated-test fixtures are removed. No alternate output folder is offered. Source hashes in the report bind results to the locked mixture of 38 candidates and 21 unchanged scripts.

Optional CLI switches: -LocalOnly (no connections), -NoPause. ParserOnly is an internal Windows PowerShell 5.1 child check. Any FAIL gives a nonzero exit code; skipped checks remain explicit. No operational entrypoint is run, no tenant mutations occur, and no verification badges are granted.

Executed here: single-file Linux PowerShell 7.6 smoke test with a test-configured Desktop path; 151 passing checks, expected Windows-host failure, expected Windows PowerShell 5.1 and connection skips. CSV and JSON report readback passed. Missing Desktop failed without fallback. Seven mocked live-connection scenarios passed: GUID/domain success, GUID/domain mismatch, existing context preservation, partial sign-in cleanup and failed read handling. These mock checks do not prove live authentication. Windows PowerShell 5.1 execution, actual Windows Desktop resolution and real sign-ins remain UNEXECUTED.

Build source: build.py assembles main.ps1 plus the already-executed isolated export/input/branch harnesses and locked source bytes. Do not edit the generated payload by hand. artifact.json pins the exact delivered validator hash.

## Validator 1.0.1 tenant identity correction

Uses the unique connected Exchange record TenantID, validated as a non-empty GUID, instead of the potentially blank Get-OrganizationConfig.ExternalDirectoryOrganizationId. Expected-domain/GUID and cross-service checks remain in place. Rejects missing/invalid/empty tenant IDs and multiple connected sessions before mailbox reads. Exact embedded source payload is unchanged. Baseline false mismatch reproduced with domain input and blank organization property; 13 isolated connector cases PASS. Ryan reported 159 PASS/1 FAIL on Windows with validator 1.0.0; diagnostic confirmed a populated connection TenantID and blank organization ID. Corrected Windows/live rerun remains PENDING.
