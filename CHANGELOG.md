# Changelog

## 1.0.2 — 2026-10-26

- Fix the exact `The property '1' cannot be found` split failure: `[double].001` in the interactive progress calculation was parsed as property access under StrictMode. Use `[double]0.001` and expose the shared progress metrics for direct headless regression testing.
- Reproduce the original v1.0.1 failure on PowerShell 7.6.8 in an interactive terminal with disposable multi-gigabyte data. Small/quiet/redirected tests skipped progress and previously missed the defect. Regex match groups and size parsing were not the cause and remain unchanged.
- Add optional `-Diagnostics` output for exception type, source script, exact line, ScriptStackTrace and inner exceptions; preserve normal readable errors and exit codes. Preserve inner exceptions when manifest validation wraps a failure.
- Add 1 MiB/5 MiB CLI round trips, progress/zero-time/Int64 metrics checks, mid-write interruption cleanup, incomplete-part collision protection, and temporary-file preservation tests. Keep StrictMode, validation, Int64 streaming and manifest compatibility enabled.

## 1.0.1 — 2026-10-25

- Fix 2 GiB and larger parts failing because PowerShell selected `Math.Min(Int32, Int32)` for an Int32 buffer length and Int64 remaining byte count. Both operands are now explicitly Int64, and only the bounded FileStream read count is narrowed to Int32.
- Audit split, verify, merge, progress, and integration-file generation arithmetic; keep byte totals, part lengths, remaining bytes, and offsets in Int64 and retain overflow-safe BigInteger part-count calculation.
- Add regression coverage for 500MB, 1GB, 2GB, 4GB, Int32.MaxValue, Int32.MaxValue + 1, 200GB and 1TB, with binary round trips and v1.0.0 manifest compatibility. Manifest schema and CLI syntax are unchanged.
- Validate a real 4,294,967,313-byte random binary round trip with two 2 GiB parts plus a 17-byte final part and independent original/restored SHA-256 equality.

## 1.0.0 — 2026-10-25

Initial Tqsim release: binary streaming split, verified merge, strict manifests, CLI, per-user deployment and release tooling.
