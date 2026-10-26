# Changelog

## 1.0.7 — 2026-10-26

- Documentation/help release only: preserve byte-identical split/merge, SHA-256, encryption, deletion and branding engine sources and all archive formats.
- Reorganize main help into usage, commands, globals, quick start, security and topic discovery; render the version from version.json even with NoLogo.
- Complete every command page, full parameter/default/alias coverage, safer deletion/encryption examples and accurate manifest selection/info/update behavior. Wrap interactive help at terminal width without changing redirected text or branding.
- Rewrite the English README with navigation and complete workflows; add a faithful Arabic guide with matching executable examples, command/parameter references, troubleshooting and a documentation coverage matrix.
- Add documentation consistency, parser/example/link/anchor, no-operation/password/ACL/deployment help isolation and narrow-terminal regressions. Ship both languages and reference/security/history documents; extend owned-file rollback/uninstall lists without changing installer validation or processing behavior.

## 1.0.6 — 2026-10-26

- Preserve legacy unencrypted schema/part bytes and verify authentic relocated fixtures generated with archived 1.0.2–1.0.5 releases, without original source files or password prompts.
- Restore merge output directly beside the selected manifest/parts by default; explicit Output and collision/Overwrite safeguards remain.
- Add split-only strict encrypt=true|false, default false. Use hidden confirmed passphrase entry, .NET AES-256-GCM records, PBKDF2-HMAC-SHA256 (600,000 iterations, fresh salt), domain-separated manifest HMAC, bounded buffers/physical part sizes and versioned authenticated schema 2. Merge/verify detect encryption automatically; authentication remains mandatory with verify=false.
- Move private write-ahead cleanup records to per-user Tqsim/Recovery. Remove records after full success or zero-deletion failures; retain actionable partial/interrupted state without touching unrelated records or completed output.
- Attempt normal deletion first; after access denial, try only current-SID per-file Delete permission when WRITE_DAC is authorized. No ownership takeover, broad ACL change, shell invocation or UAC bypass. Retain sources with actionable errors when denied, read-only, locked or changed.
- Add structured user-facing errors with diagnostics-only technical detail; preserve existing Int64 streaming, verification defaults, random logos/colors and separate progress/status rows. Package crypto source/specification without runtime downloads; add authentication, historical, real-ACL and recovery tests plus disposable multi-gigabyte measurements.

## 1.0.5 — 2026-10-26

- Add split/merge/merg -verify true|false, default true; retain -ds default false. Reject invalid Boolean strings without implicit truthiness. Omitted options use their established defaults.
- Replace repeated deletion-related payload scans with captured Windows identities, lengths, timestamps and restrictive locks. Keep each target locked until its own deletion boundary. Preserve reparse/hard-link/shared-manifest checks, safe publication and write-ahead cleanup journals.
- Split reads input once; merge validates parts and whole SHA-256 in its single writing pass without a separate preverification pass. Verify=true adds exactly one independent output read; verify=false skips it even when deletion is requested and displays the irreversible-deletion warning.
- Replace 4 KiB ComputeHash reads with bounded 4 MiB read-back hashing. Retain per-part durable flushes, Int64 arithmetic, existing buffer default and throttled two-line UI.
- Remove routine default-false retention messages; keep destructive-action results, failures and accurate verification-skipped status. Add actual stream-byte-count tests and developer-only profiling/benchmark tools excluded from release packages.

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
