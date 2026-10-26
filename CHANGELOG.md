# Changelog

## 1.0.4 — 2026-10-26

- Add strict split/merge/merg `-ds true|false`, default false. Explicit true independently verifies published data and source identities before deleting exact source files; merge removes its manifest last and refuses shared/ambiguous parts.
- Record durable write-ahead cleanup journals, preserve verified output on cleanup failure, and report confirmed deletions and remaining/unconfirmed entries with a nonzero exit. Journals never silently resume deletion.
- Independently randomize logo and information colors from eight bright accents once per invocation; retain all three literal logos and stable selections through progress and resize.
- Replace host-managed yellow progress with a bounded two-line display: progress bar on the first line, status/bytes/speed/elapsed/ETA on the second. Respect NoColor, NO_COLOR, Quiet and redirected output.
- Preserve Int64 streaming, bounded data buffers, manifest schema, CLI aliases, collision protection and opt-in diagnostics. Add deletion, interruption, cross-drive, identity and color regression coverage.

- Accept installation launched from Windows PowerShell 5.1 when PowerShell 7+ is installed. Discover and validate pwsh.exe, then hand off the self-contained loaded installer to a separate process without relying on script paths or a second download.
- Keep PowerShell 7+ installation in-process, preserve child exit codes in LASTEXITCODE, prevent relaunch loops, and never exit the caller's interactive window. Retain checksum, ZIP, rollback, PATH and update behavior.
- Add native 5.1/7 process tests for piped and downloaded-script invocation, success/failure parent survival, Unicode/quote-safe parameter forwarding and runtime discovery. Public URL verification is pending maintainer deployment; no release assets are overwritten.

## 1.0.3 — 2026-10-26

- Centralize case-insensitive command dispatch, practical dash/slash help aliases, version aliases, command-specific help and conservative typo suggestions. Handle help before file-operation validation; reject unsupported arguments with exit code 2 without evaluating command text.
- Store exactly three literal ASCII logos, select one cryptographically per invocation, and preserve it during progress and resize. Center the selected block and metadata; support dynamic heights, narrow-terminal fallback, true-color/ConsoleColor styling, NoColor/NO_COLOR and clean redirected output.
- Read the authoritative application version from version.json for the CLI, banner and new manifest application metadata. Preserve schema 1 and earlier manifests.
- Include CLI/branding helpers and all topic help files in release packages and owned-file deployment cleanup. Preserve the existing Windows launcher and Unicode/space forwarding.
- Retain the v1.0.2 StrictMode/progress correction, Int64 streaming, bounded binary buffers, SHA-256 integrity and interrupted-operation/collision protection. No processing-engine redesign or animation was added.

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
