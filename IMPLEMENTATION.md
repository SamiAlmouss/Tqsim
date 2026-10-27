# Tqsim 1.0.8 maintenance release — 2026-10-27

Packages the completed installer/uninstaller lifecycle and Windows launcher fixes described below, with all v1.0.7 processing/CLI/help behavior preserved. version.json, changelog, current release references in both READMEs and version-matched CLI/installer fixtures move to 1.0.8. Previous 1.0.7 version-directory fixture names deliberately remain to test old leftover layouts. Build, rollback and uninstall known-file lists include docs/VALIDATION-v1.0.8.md. No application processing, authentication or archive format changes are introduced.

The installer regression suite can audit a disposable copy of a final release selected by the test-only TQSIM_RELEASE_TEST_ARCHIVE variable; production has no such option or bypass. Final artifact testing also runs this suite against the installer/uninstaller extracted from the ZIP, with only developer test/build files added to a separate disposable harness. Native PATH-resolved command tests redirect persistent-PATH accessors to fixture storage to protect the actual user registry; ownership/checksum/ZIP/rollback/cleanup/CLI code runs unchanged.

See docs/VALIDATION-v1.0.8.md for final full-suite evidence and the post-build package audit protocol. ZIP byte size, independently verified SHA-256 and actual artifact-test results are stored outside the ZIP to avoid a self-referential checksum. Historical implementation and test reports below retain their earlier scope. No global installation, commit, tag, push or publication is performed. Previous dist release files are preserved and SHA-256 checked.

---
# Installer lifecycle implementation before release preparation

Additional mandatory regressions now cover the exact default-root empty bin/versions layout, marker absence, nonempty unowned directories, five physical junction locations, corrupt/locked markers, native PATH-resolved tqsim lifecycle, exit codes 0/1/2/3 and parent-batch survival. Native execution uncovered a launcher self-deletion error; install.ps1 now emits a batch launcher that drops its own context before running pwsh, preserving exit codes without reopening the deleted file. Both final full suites pass 253 tests with zero failures/skips (7.6.5: 217.50 s; 7.6.9: 236.88 s). Actual symbolic-link creation was denied by Windows privilege checks; physical junction tests and the shared reparse-attribute guard pass, and that limit is explicitly reported. Native child tests redirect only persistent-PATH accessor bodies to fixture storage, leaving ownership/checksum/cleanup/CLI unchanged. See docs/INSTALLER-BOOTSTRAP.md for exact evidence and test isolation.

Root cause: uninstall removed the ownership marker and known files but deliberately left all directories. The next installation rejected that markerless root as unowned. Fixed install.ps1 and uninstall.ps1 together: prune only empty known directories; delete per-version version.json after other owned files; remove the root marker/root last on clean uninstall; preserve unrelated data and ownership when anything remains. Recognize only a file-free known legacy bin/versions layout or an empty target for reinstall, with hidden-entry and reparse checks. Reject invalid/unreadable metadata instead of discarding it. Apply fresh-install rollback to adopted empty roots too. The PowerShell 5.1 self-contained bootstrap serializes the new scaffold checker.

Added ten installer regression tests, without weakening prior assertions, and synchronized English/Arabic README, command help/guide, changelog and installer lifecycle notes. Full suite on PowerShell 7.6.5: 241 passed, zero failed/skipped (192.64 seconds). Installer/bootstrap/documentation suite on 7.6.9: 57 passed, zero failed/skipped (75.46 seconds). Evidence: .test-work/lifecycle-full.xml and lifecycle-store.xml. The earlier full run was interrupted to add metadata-last retry protection; only the final completed run is counted. See docs/INSTALLER-BOOTSTRAP.md for repair rules and limits.

At the initial lifecycle-fix stage, no engine changes, version bump, release ZIP replacement, publication, global installation or user-data cleanup was performed. The public installer changes only after authorized deployment; old packaged uninstallers need a future release to acquire the directory-pruning fix. The corrected local installer can already recover their recognized empty remnants safely.

---
# Tqsim 1.0.7 help and documentation release

The command/parameter inventory was audited against the current parser, processing function signatures, metadata reader, encryption/error handling and managed deployment scripts before writing documentation. No command, operation parameter, processing algorithm or archive format was added or changed. src/Core/Tqsim.psm1, Encryption.ps1, Crypto.cs, Deletion.ps1, Errors.ps1 and src/Console/Branding.ps1 remain byte-identical to the initial v1.0.6 checkout; validation compares their SHA-256.

## Changes

- src/Commands/CLI.ps1 changes only Get-TqsimHelp (resolve the version placeholder from authoritative metadata) and Show-TqsimHelp (word-wrap interactive text within terminal width, preserving redirected text, NoColor and styled headings). Argument parsing and dispatch are unchanged.
- examples/help.txt: compact title/version, usage, nine commands/aliases, all globals/aliases, quick start, defaults/security and help discovery. Every topic under examples/help is complete, including optional BufferSize/Overwrite/Manifest, all defaults, secure input, fast-mode assurance and safe cleanup/recovery.
- README.md: navigable English introduction, requirements/install, every command, defaults, encryption/deletion/verification guides, directory trees, historical measured performance, troubleshooting, managed update/uninstall, security, FAQ, contribution/license and manual publication instructions.
- README.ar.md: Arabic guide with matching functionality/defaults and the same unique executable tqsim examples. docs/COMMANDS.md mirrors the CLI pages; PARAMETERS.md inventories all 14 named options plus aliases/topic/defaults/accepted values/warnings; TROUBLESHOOTING.md covers symptoms/causes/remedies; HELP-COVERAGE.md records every command and audit corrections.
- Build/installer rollback/uninstaller known-file lists include Arabic/reference/history documents and changelog. Required-file checks, checksum/ZIP safety, PATH and deployment logic remain unchanged. Documentation metadata/test fixtures update to 1.0.7.
- tests/Documentation.Tests.ps1 adds 12 regression tests covering parser option inventory, command coverage/version/defaults, literal CLI-guide agreement, both-language example parsing/equality, local Markdown target/anchor resolution, current merge behavior, all topic/help-alias combinations without operation/secret/ACL/journal/deployment dispatch, narrow/one-column terminals, NoLogo/NoColor/Quiet and redirected output.

## Audit corrections and scope

Info is metadata-only: it displays maximum part size and schema, not per-part sizes or a dedicated encryption status, and does not authenticate encrypted metadata. Explicit Manifest overrides discovery; relative paths are relative to current working directory, with parts beside the selected manifest. Merge publishes after mandatory streaming integrity/authentication; optional independent read-back happens afterward, before deletion. Update has no check-only flag or confirmation; uninstall has no confirmation. Help bypasses operation requirements/value validation, not unknown/duplicate/malformed syntax. No unsupported Password/Source/Force/Check parameter is documented as a feature.

The existing 219 tests are retained; no assertions are weakened. Complete final counts, failures/skips, runtime versions, source preservation and extracted-package checks are recorded in docs/VALIDATION-v1.0.7.md. Historical engine/performance/security reports below retain their original release scope. No new multi-gigabyte performance or external crypto audit is claimed for this documentation release. No tag, push, publication, global installation or user ISO/backup access occurs. Release outputs: dist/Tqsim-v1.0.7.zip and its SHA-256 checksum. Manual publication and installed update steps appear in both READMEs.

---
# Tqsim 1.0.6 implementation and validation

Version 1.0.6 adds opt-in authenticated encryption, same-directory merge output, private recovery records and narrowly scoped deletion-permission handling. Legacy unencrypted schema 1 and part bytes retain their meaning. No user ISO/backup, global installation, Git commit, push or publication was used. Historical reports below describe their own releases only.

## Implementation map

- `src/Core/Encryption.ps1` and `Crypto.cs` implement schema 2, strict metadata validation, secure interactive secret entry, PBKDF2-SHA256 (600,000 iterations), separately derived AES-256-GCM and manifest-HMAC keys, unique prefix/counter nonces and bounded 4 MiB authenticated records. Physical parts include framing and never exceed Size. See `docs/ENCRYPTED-FORMAT-v1.md` for the complete interoperable wire format and security limitations.
- `src/Core/Tqsim.psm1` dispatches opt-in encrypted splitting and automatic encrypted merging/verification, while retaining legacy streaming. Default merge publishes the original filename directly beside the manifest; explicit Output is respected. Collision protection remains. Plaintext is authenticated before publication and temporary decrypted output is created atomically with an owner-only protected Windows DACL.
- `src/Core/Errors.ps1` provides readable structured errors, private file creation and minimal per-file ACL repair. Diagnostics retains exception type, source line, stack and inner exceptions. Password errors and corrupted archives share a safe authentication-failure message; missing parts identify the affected file.
- `src/Core/Deletion.ps1` preserves identity/length/time/read-lock checks and write-ahead cleanup. Only ds=true may grant the current SID the exact source file's Delete right, and only when existing WRITE_DAC permissions permit it. No ownership takeover, parent/drive ACL changes, FullControl grant or automatic elevation occurs. A failed retry restores the prior DACL. Read-only files and sharing violations receive specific guidance.
- Recovery records are privately created under `%LOCALAPPDATA%\Tqsim\Recovery`. Fully successful cleanup removes its own record. A failure before any deletion removes a pointless record; partial deletion or uncertain interrupted deletion keeps exact state for manual reconciliation. Unrelated recovery records are untouched. Completed output survives cleanup failure; users need not repeat processing.
- `src/Commands/CLI.ps1`, entry point, help, README and changelog add strict split-only encrypt=true|false, default false. Existing ds=false/verify=true, aliases, diagnostics, three logos, colors and two-row progress remain. Merge does not accept encrypt or a password argument.
- Installer, uninstaller and release builder include the three new core files and format specification. Installation rollback also accounts for the new documentation directory. Binary engine changes are confined to encrypted dispatch and the requested destination/error/cleanup behavior.
- New tests: Encryption.Tests.ps1, LegacyCompatibility.Tests.ps1, RecoveryPermissions.Tests.ps1 and authentic version-generated fixtures. Existing deletion/installer/CLI tests were updated for intentionally changed behavior. Developer-only scripts/test-crypto-integration.ps1 measures disposable data; tests/profilers are excluded from the release.

## Behavior, errors and limits

`split -File data.bin -Size 1GB -encrypt true` requests a hidden password twice (12 through 1,024 characters); merge/verify request it once after automatic detection. No password option exists. Losing the password makes recovery impossible. Normal errors explain wrong password/corruption, missing parts, existing destination, locked/read-only source or insufficient deletion permission; Diagnostics supplies technical details. Cancellation and authentication failure preserve sources and do not publish partial plaintext.

Authentication is mandatory even with verify=false. That switch skips only the independent read-back pass. Processing stays one input pass plus zero/one read-back, with fixed-size payload buffers. Metadata and held cleanup handles scale with part count. Private temporary plaintext is removed on failure; deletion is not secure erasure. Multi-file cleanup is not atomic, and crash records require manual reconciliation. No automatic UAC helper or recovery retry is supplied. Hardware power-loss guarantees, elevated administrator operation and external cryptographic review have not been established.

## Compatibility and measured validation

Authentic static fixtures were produced using the archived 1.0.2, 1.0.3, 1.0.4 and 1.0.5 releases before implementation. Each passes default and explicit-destination restoration without changing its original manifest bytes or requesting a secret. They represent genuine release-generated archives, not a test of unavailable historical cloud backups. Legacy unsigned hashes retain their original trust limitations.

The final test counts, runtime versions, independent Python cryptographic cross-check, NIST vector, actual 5 GiB + 17-byte runs, measured timings, package validation and limitations are recorded in `docs/VALIDATION-v1.0.6.md` in the source repository. All original tests remain. Earlier release ZIP/checksum hashes are checked unchanged. Live installation via the public URL is a post-publication check and remains unexecuted for unpublished 1.0.6.

Release assets: `dist/Tqsim-v1.0.6.zip` and `dist/Tqsim-v1.0.6.zip.sha256`. Publication and installed-command update instructions are in README.md; no publication or installed update was performed.

---
# Tqsim 1.0.5 implementation and validation

This release diagnoses and removes redundant data passes, adds strict optional verification, and retains the existing streaming architecture and terminal appearance. Version was promoted only after the pre-version full suites passed. No original ISO/.smm backup or other user data was used. Nothing was installed globally, committed, pushed or published.

## Files and functions changed

- src/Core/Tqsim.psm1: Split-Tqsim and Merge-Tqsim now accept verify=true by default and ds=false by default. Split hashes input once and optionally invokes one independent parts pass. Merge removes the pre-read pass, validates each part/whole SHA-256 while writing unpublished temporary output, checks final written length, publishes safely, and optionally reads the destination back once. Normal output omits default-false retention noise and distinguishes skipped verification. Progress remains throttled and two-line.
- src/Core/Deletion.ps1: Resolve-TqsimVerifyOption parses only true/false strings. Add-TqsimDeletionFile records identity/length/timestamps under restrictive locks without redundant payload hashing; ReadBack is explicit. Assert-TqsimReceipt revalidates identity and metadata, and Remove-TqsimVerifiedFile no longer rehashes payload. Invoke-TqsimVerifiedSourceDeletion requires completed streaming/publication, records whether independent verification occurred, warns for fast destructive mode, keeps other targets locked until their own deletion, and retains write-ahead partial-cleanup reporting. Get-TqsimStreamDigest uses bounded 4 MiB reads instead of ComputeHash(Stream)'s small reads.
- src/Commands/CLI.ps1: raw parser accepts verify only for split/merge/merg, validates case-insensitive true/false explicitly, preserves help ordering and all existing defaults/aliases.
- scripts/profile-performance.ps1 and scripts/ProfileStreams.cs (new): developer-only isolated-copy phase instrumentation, measured byte/call counters, uninstrumented elapsed benchmarking, all four parameter combinations and independent harness hashes. They are excluded from application ZIPs.
- tests/VerificationOptions.Tests.ps1 (new): ten tests cover strict defaults/parsing, exact real byte counts/no hidden passes in all four combinations, warning, default output, mandatory fast-mode integrity and direct/Windows-launcher forwarding. Existing tests remain. CLI/installer version fixtures move to 1.0.5.
- examples/help.txt, examples/help/split.txt, examples/help/merge.txt, README.md, CHANGELOG.md, version.json, IMPLEMENTATION.md and docs/PERFORMANCE-v1.0.5.md: exact defaults, measured results, safety tradeoffs and release instructions.

## Parameters and safety

Omitted -ds means false; omitted -verify means true. Required File and Size are never invented. Only true/false strings, case insensitive and quoted/unquoted, are accepted; missing/empty/yes/no/1/0/arbitrary values are usage errors. Explicit false is never implicitly cast to Boolean true. All existing optional parameters retain their documented defaults.

| ds | verify | Result |
| --- | --- | --- |
| false | true | Keep sources; one independent output pass |
| false | false | Keep sources; no independent output pass |
| true | true | Delete exact sources only after independent output verification |
| true | false | Explicit fast destructive mode after mandatory streaming integrity, successful flush/close and safe publication; no hidden output pass |

The fast destructive path visibly warns before cleanup, even with Quiet. It does not call streamed hashes independent verification. A successful write/flush cannot guarantee future durable storage. Every mode preserves exact byte counts, streaming part/whole hashes, manifest validation, no silent overwrite and safe publication. Deletion retains file IDs, timestamps, lengths, hard-link/reparse checks, shared-manifest refusal, protected-output locking, exact target lists and manifest-last cleanup. Pre-cleanup errors preserve sources. Multi-file cleanup is not atomic; journals retain confirmed and pending/unconfirmed states, output is preserved after partial failure, and no automatic retry is implemented. A small final close/revalidate/delete race remains; this is not a transaction against a privileged concurrent attacker. Ownership discovery is limited to manifests in the selected directory. Metadata and held handles scale with part count. Network/hardware power-loss behavior was not validated.

## Measured performance

Read the detailed [performance report](docs/PERFORMANCE-v1.0.5.md) in the source repository for raw evidence locations, all phase timings and limitations. Originally, deletion read seven full payload equivalents in each pipeline. The optimized design reads one input plus zero/one output pass: five redundant scans removed with verification, six in fast mode. Small manifest/journal I/O remains. Original default merge's separate preverification was removed. The FileStream API call count for a 512 MiB + 17 sample fell from over 655,000 to about 260 with verification, or 131 without, including metadata.

Actual uninstrumented local 512 MiB + 17 measurements (single runs; cache/storage state not controlled): deletion+verification split 13.158 s -> 3.595 s (38.9 -> 142.4 MiB/s); merge 9.835 s -> 2.865 s (52.1 -> 178.7 MiB/s). Fast deleting split/merge measured 2.264/2.357 s. These are observed runs, not guaranteed speedups. New default retained-source split performs an additional independent pass absent from the old default, so it was slower (2.409 -> 3.636 s) as expected from the requested semantics. No larger public data buffer or parallel I/O was introduced without evidence; per-part Flush(true) remains mandatory. Profiling code never runs in normal operation.

Real random 5 GiB + 17-byte integration passed all four ds/verify combinations using 1GB, 2GB and 4GB configurations, including an actual 4GB part in fast deleting mode. Every restored file was independently SHA-256 checked by the harness, regardless of application verification. Detailed elapsed/throughput values are in the performance report. No claim is made for physical 200GB/1TB tests.

## Automated and release validation

All 168 preceding tests are retained; ten new tests add strict verification/default and exact byte-pass checks. Full Pester 4.10.1 suites passed before version promotion; final version-matched suite results and package validation are documented with the release evidence. Regression coverage includes Int64 boundaries and old manifests, exact ASCII literals, stable colors/two-line progress, independent-verification failures, corrupt parts, cancellation, real process termination during cleanup, actual read-only partial deletion, path/identity/shared-manifest safety, native installer 5.1-to-7 handoff, checksum/ZIP validation, rollback, PATH, update/uninstall and real launcher behavior. Installer tests use local fixtures/mocked persistent PATH and network; they do not update the global app.

Release files: dist/Tqsim-v1.0.5.zip and .zip.sha256. Build refuses existing archives and earlier release files are preserved. Profiling tools/test data are not packaged. Manual publication/update steps remain in README.md for SamiAlmouss/Tqsim. Live public installation is pending authorized deployment. Older implementation reports below are historical and do not describe current verification semantics.

---

# Tqsim 1.0.4 implementation and validation

The v1.0.4 change adds strict, opt-in source deletion and stable random terminal colors, with the requested two-line progress display. Existing streaming loops, Int64 arithmetic, manifest schema 1, help aliases, collision protection, StrictMode and diagnostics are retained. Initial documentation edits and untracked v1.0.3 CLI/branding files already present in this working tree were preserved. No Git commit, push, publication, global application update or access to the user's original ISO/backup was performed.

## Modified and added files

| Files | v1.0.4 change |
| --- | --- |
| src/Core/Deletion.ps1 (new) | Strict true/false parsing, exact-path/ancestor checks, Windows file IDs, single-link checks, streaming verification, restrictive read locks, shared-manifest refusal and journalled deletion |
| src/Core/Tqsim.psm1 | Opt-in verification/cleanup boundaries around the existing split/merge pipelines; compact two-line progress status and accurate final completed-part count |
| src/Commands/CLI.ps1 | Accept ds only for split/merge, validate explicitly, route help safely and keep render state even with NoLogo |
| src/Console/Branding.ps1 | Eight-color palette, independent bounded color draws, stable invocation state, two-line renderer and ConsoleColor/NoColor fallbacks; three logo literals unchanged |
| examples/help.txt; examples/help/split.txt; examples/help/merge.txt | ds syntax, retention defaults, irreversible deletion and partial-cleanup warnings |
| install.ps1; uninstall.ps1; scripts/build-release.ps1 | Package, validate and remove only the additional owned Deletion.ps1 helper; preserve the previous installer bootstrap |
| version.json; tests/CLI.Tests.ps1; tests/Installer.Tests.ps1 | Authoritative version 1.0.4 and matching package/installer fixtures |
| tests/DeleteSource.Tests.ps1; tests/Colors.Tests.ps1 (new) | Real disposable deletion, safe retention, input errors, faults, interruption, cross-volume/link/ownership checks and deterministic rendering/color regressions |
| tests/fixtures/CleanupTerminationHarness.ps1 (new) | Disposable child paused after a real deletion, allowing the test to force termination before journal acknowledgement |
| scripts/test-delete-source.ps1 (new) | Reproducible random streaming data, retained/deleted-source multi-part round trips, independent final SHA-256 and JSON evidence |
| README.md; CHANGELOG.md; IMPLEMENTATION.md | Behavior, limitations, validation and manual release/update steps |

## Exact ds behavior

Only `-ds true` authorizes deletion; omitted or explicit false always retains source data. String matching is case insensitive and does not cast nonempty strings to Boolean. Missing/empty/yes/no/1/0/other values fail with usage code 2. Split and merge/merg accept it; other operations reject it. Help requests never execute processing/deletion. There is no extra confirmation after valid explicit true.

Split: independently reopen and validate the published manifest and all parts, verify individual lengths/hashes and ordered whole-file hash/count, reread the source, and revalidate its identity before deleting only that original. Merge: verify inputs before and during streaming, safely publish the output, independently reopen/hash/size-check it, then remove the exact listed parts and selected manifest last. The restored output is never a cleanup target. Defaults retain the original behavior and schema; completion text now states source retention.

Deletion checks Windows volume/file IDs, refuses hard links, checks file and ancestor reparse points, checks exact normalized paths and output collisions, and holds verified data open with restrictive sharing. Ownership checks examine other manifests in the selected directory; invalid neighbours or shared part names refuse deletion. Hashing streams files with bounded buffers; metadata and held handles grow with the number of parts. Failure to obtain verification or resources before cleanup retains sources.

## Cleanup safety and limitations

A unique `.tqsim-cleanup-<GUID>.json` is written next to the protected destination. Each update writes a unique temporary file, flushes it to disk and replaces the journal. It records authorized intent, exact identities/paths/hashes, protected output and per-target pending/deleting/deleted states. Intent is persisted before deletion and acknowledgement afterward. Success journals remain as an audit record. Journals never execute paths or silently resume cleanup.

Multi-file cleanup is not atomic. Failure returns operational code 1, reports confirmed deleted and remaining/unconfirmed counts, and preserves the verified output. The selected manifest remains until all its parts were removed. Forced termination between deletion and acknowledgement leaves a deleting entry that must be checked manually; the journal does not falsely call it deleted or pending. A failed journal write before the first deletion prevents cleanup. No automatic recovery is implemented.

All processing/read handles for deletion targets are disposed before deletion. Immediate identity/hash checks and a final path/ancestor check reduce substitution risks, but a small close-to-delete race remains. Use directories under your control; this is not a transaction against privileged concurrent filesystem attacks. Ownership cannot discover references from unknown directories. NTFS was used for testing; network filesystem semantics and hardware/power-loss durability are not guaranteed. SHA-256 detects differences and does not replace an independent backup or guarantee future durability.

## Rendering

The old yellow information line was the Status argument of native Write-Progress. Only routine progress was replaced; warning/error rendering remains unchanged. The first row contains the bar and percent, the second contains state, part counts, exact byte counts, speed, elapsed time and ETA. Lines are cropped to width minus one to avoid wrapping; narrow terminals can hide trailing details. Redraws reuse two console rows without clearing the screen or changing global terminal colors/cursor visibility.

Logo color uses one cryptographic draw from eight approved RGB accents. The information color uses an independent draw from the seven remaining accents, so colors are distinct without retry loops. Both and the logo remain fixed through verification, resize and completion. New invocations draw again and may repeat by chance. Exactly three unchanged literal logos remain registered. NoLogo suppresses logo selection while progress retains its own state. Quiet suppresses routine UI. NoColor/NO_COLOR suppress decorative colors; redirected output has no progress/ANSI. True-color terminals use RGB, other interactive consoles use bright ConsoleColor equivalents.

## Validation results

Final full Pester 4.10.1 runs on 2026-10-26:

| Runtime | Passed | Failed | Skipped |
| --- | ---: | ---: | ---: |
| PowerShell 7.6.5, bundled | 168 | 0 | 0 |
| PowerShell 7.6.9, installed Windows Store runtime | 168 | 0 | 0 |

All 136 existing tests remain; 32 new tests cover parsing, default/false retention, Unicode/spaces, zero bytes, exact/multiple parts, independent verification failures, write failures/cancellation, collisions, C-to-D/D-to-C processing, hard links/junctions, same-content file substitution, shared/invalid neighbouring manifests, unrelated files/sets, read-only deletion failure, journal write failure, partial cleanup and deterministic color/two-line rendering. The real Windows launcher and direct CLI are exercised. The final forced-termination test kills only its own disposable child after an actual first-part deletion but before acknowledgement: output SHA-256 stays correct, the manifest and remaining ten parts remain, and the journal records that first target as deleting/unconfirmed. Installer tests retain native Windows PowerShell 5.1.26100.9711-to-7 handoff, child failure/parent survival, safe ZIP/checksum, rollback, mocked persistent PATH/network, update and uninstall checks. No global installation was changed.

Real random, non-sparse integration file: **5,368,709,137 bytes (5 GiB + 17)**. Executed using scripts/test-delete-source.ps1 with part sizes 1GB, 2GB and 4GB. Each case split, independently verified, merged and independently checked the final hash/length:

| Part size | Exact part lengths in bytes | ds | Result | Elapsed |
| --- | --- | --- | --- | --- |
| 1GB | 1073741824 x 5; 17 | false | Original, parts and manifest retained at verification time; round trip passed | 00:02:13.9466306 |
| 2GB | 2147483648 x 2; 1073741841 | true | Verified original deleted after split; three parts/manifest deleted after verified merge | 00:05:11.5512944 |
| 4GB | 4294967296; 1073741841 | true | Verified input deleted after split; two parts/manifest deleted after verified merge | 00:06:04.3905455 |

All three final hashes matched the independently computed initial source SHA-256:

`192AF8BAD471CFCA221A4B2AE41E655A685AD9C643F573B83BC9DD418EA95320`

Evidence is retained in `.test-work/delete-integration/1f58fe24-d2e4-4375-a448-04fad64c77a6/results.json`, plus cleanup journals and disposable retained data. The 4GB stage intentionally uses and deletes the previous stage's reconstructed disposable file; its earlier reported hash was verified before that explicit deletion. Final Pester records are `.test-work/v104-final-765.xml` and `v104-final-store.xml`.

The actual two-row renderer was also exercised in an interactive 80-column Windows pseudo-console, progressing from 25% through 100%, with separate bar/status rows and no operation failure. Automated tests check stable colors during redraw/resize, literal logos, NoColor/NO_COLOR and clean redirection. Windows Terminal/VS Code visual inspection and network storage/power-loss testing were not performed. No 200GB or 1TB physical file test was performed; the retained Int64 arithmetic suite covers those numeric sizes.

Release outputs are `dist/Tqsim-v1.0.4.zip` and `.zip.sha256`; the checksum is external to avoid a self-referential package hash. The build refuses existing archives. Manual publishing and installed-command update steps are in README.md. Live installation from the public URL remains pending authorized deployment. Historical v1.0.3 findings follow for reference; they describe the preceding release, not the current colors/cleanup.

---

# Tqsim 1.0.3 implementation report

Installer follow-up: [Windows PowerShell 5.1 bootstrap fix, test results and pending live deployment check](docs/INSTALLER-BOOTSTRAP.md). The root install.ps1 now hands legacy callers to PowerShell 7 without relying on an original script path; the application engine and existing release archives remain unchanged. The report below describes the preceding v1.0.3 CLI/branding upgrade.

## Upgrade scope and modified files

Started from the clean v1.0.2 checkout on main at commit `fd87731` (`Release Tqsim v1.0.2 - Fix interactive progress`). This is an incremental CLI/help/branding upgrade. The binary streaming loops, safe part publication, merge verification and cleanup behavior were preserved. The real global installation and user ISO/backup data were not accessed or modified. No commit, push, or GitHub publication was performed.

| Files | Change |
| --- | --- |
| tqsim.ps1 | Raw argument entry point, shared normalization/dispatch, retained diagnostics and exit codes |
| src/Commands/CLI.ps1 | Argument validation, case-insensitive aliases, safe help routing, suggestions, version metadata reader and dispatch |
| src/Console/Branding.ps1 | Exactly three literal logos, cryptographic selection, per-invocation layout, styling and resize reflow |
| src/Core/Tqsim.psm1 | Load the helpers, consult invocation branding state during progress, read applicationVersion from metadata; processing engine unchanged |
| examples/help.txt; examples/help/*.txt | Full main help and split/merge/verify/info/update/uninstall/version/help topics |
| version.json | Authoritative version 1.0.3 |
| install.ps1; uninstall.ps1; scripts/build-release.ps1 | Include, validate and clean only owned new helper/help files |
| tests/CLICompatibility.Tests.ps1; tests/Logos.Tests.ps1; tests/fixtures/logos/*.txt | Alias/help-safety, literal/selection/layout/resize and suppression regressions |
| tests/CLI.Tests.ps1; tests/Installer.Tests.ps1 | Version expectations, real launcher aliases and existing Unicode argument forwarding |
| .gitattributes | Preserve logo fixture LF endings and intentional trailing spaces |
| README.md; CHANGELOG.md; IMPLEMENTATION.md | Supported syntax, terminal behavior, tests, limitations and release instructions |

## Actual CLI syntax

All names/aliases are case insensitive:

- Main help: no arguments, `help`, `-help`, `--help`, `-h`, `--h`, `-?`, `/?`, `/help` (including `-Help` and `--HELP`).
- Command help: `help split`, `split help`, `split -help`, `split --help`, `split -h`, `split /?`. Substitute merge/merg, verify, info, update, uninstall or version. `help help` describes help itself.
- Version: `version`, `-version`, `--version`, `-v`, `-V`. `-NoLogo` preserves the machine-friendly single version line.
- Existing operations: `split -File <path> -Size <size> [-Output <directory>]`; `merge|merg [-PartsPath <directory>] [-Manifest <path>] [-Output <directory>] [-Overwrite]`; `verify [-PartsPath <directory>] [-Manifest <path>]`; `info -Manifest <path>` or manifest discovery via PartsPath.
- Global controls: `-NoLogo`, `-Quiet`, `-Diagnostics`, `-NoColor`. Streaming commands retain `-BufferSize` (4096..67108864 bytes).

Help dispatch precedes mandatory file/size and buffer-value validation and cannot execute split/merge/verify/info/update/uninstall. Recognized options with unsupported values can still be explained by help; unsupported or duplicate argument names remain usage errors. Unknown commands suggest only reasonably clear corrections, such as splitt → split, merger → merge and verfiy → verify. No argument text is evaluated or passed to Invoke-Expression.

The version command, banner and generated manifest applicationVersion all read version.json. Manifest schema remains version 1. Exit codes remain 0 success, 1 operational error, 2 usage/unknown arguments, and 3 invalid manifest/integrity. Developer diagnostics retain exception type, exact source line, ScriptStackTrace and inner exceptions; normal failures remain readable.

## PowerShell and launcher compatibility

The root script deliberately has no advanced-script param binder, allowing the app to see reserved-looking help tokens before any file parameter validation. The raw tokens are normalized centrally. Existing full named options, quoted paths with spaces/Unicode, colon-attached option values and explicit Boolean switch values such as `-Quiet:$false` are supported. Named options use a single dash and their full names. Prefix abbreviations, GNU `--file`, and arbitrary PowerShell common parameters are intentionally rejected with code 2.

The global `.cmd` launcher and its dispatcher remain unchanged. Every listed global help/version alias, including `-?` and `/?`, was actually exercised through that launcher in temporary managed installations. Put app options after `pwsh -NoProfile -File ./tqsim.ps1`; a `pwsh -?` option before the script asks the runtime for its own help. Do not dot-source the CLI entry point; use the script or installed command normally.

## Three-logo engine

Exactly three predefined logos are registered: original five-line design, wide eight-line design, and seven-line block design ending with the colon. Each source literal was checked against fixtures extracted directly from the user's brief. Leading/trailing spaces, slashes, punctuation and line alignment match exactly. The compact TQSIM label is a responsive fallback, not a fourth randomized logo.

One `RandomNumberGenerator.GetInt32(0,3)` selection occurs when an invocation first enables branding. The render state is a local object owned by that dispatch call, not a mutable global/module selection. Repeated invocations can randomly choose the same design. Progress and resize reuse the same LogoIndex; suppressed branding does not request a random choice.

Horizontal padding is `max(0, floor((terminalWidth - widestLogoLine) / 2))`; each individual literal line retains its internal whitespace. Tagline, version and the secure-operation label are centered separately. Vertical spacing accounts for the actual logo height and the help/body/dashboard allocation. No terminal background is changed and no screen clearing is used.

An interactive window narrower than the selected design uses TQSIM. Active-operation dimension changes reflow that same selection and restore the full design when it fits. Reflow prints a fresh block on dimension changes rather than clearing/repositioning the screen. Completed static help output has no background resize listener. Terminal-dimension calls fall back safely to 80 by 25 if unavailable.

The themes use green/cyan/red, with RGB 63EDC6/53DCEB/EF5965 on recognized true-color virtual terminals and ConsoleColor fallbacks elsewhere. `-NoColor` and NO_COLOR suppress Tqsim text styling; native PowerShell progress may still use its host's colors. `-NoLogo` removes all branding and selection. Quiet also suppresses routine progress but explicit help/version/info output remains useful. Redirected output has plain logo/text lines without ANSI, artificial centering, animation or redraw codes. No animation exists, so no NoAnimation option is advertised.

## Tests actually executed

Pester 4.10.1 full suites:

| Runtime | Passed | Failed | Skipped |
| --- | ---: | ---: | ---: |
| PowerShell 7.6.8 (Windows Store runtime) | 121 | 0 | 0 |
| PowerShell 7.6.5 (bundled runtime) | 121 | 0 | 0 |

The original 88 processing/diagnostics tests were retained. New tests cover all global help/version forms, command-topic normalization and real screen output, side-effect-free help dispatch, typo suggestions, unsupported arguments, Unicode/space values and switch binding. Installer tests actually invoke the Windows `.cmd` launcher with all global aliases and all operational help topics, plus the existing Unicode split path test. Deployment downloads and persistent user PATH changes are mocked.

Logo tests check all literal designs/heights against source-brief fixtures, real cryptographic RNG index ranges, selection of each design, 12,000 seeded/mock draws with reproducible approximately uniform counts, per-invocation selection, no global state, horizontal/vertical layout, narrow fallback, resize restoration without reselection, NoLogo/Quiet suppression, and clean redirected output. The seeded distribution check deliberately avoids probabilistic test failures; the real GetInt32 API is separately range-tested.

A real zero-argument external CLI invocation also displayed one banner plus full main help. All source, deployment and test scripts passed PowerShell syntax parsing. Git whitespace checking respects the required intentional trailing spaces via .gitattributes.

### Interactive binary regression

A real terminal run on PowerShell 7.6.8 with branding/progress enabled generated **134,217,745 disposable random bytes (128 MiB + 17)** under a new workspace test directory, used a Unicode/space filename, split into **129 parts** with a 1MB chunk, verified, and merged using the merg alias. Source and restored SHA-256 matched; the source hash stayed unchanged:

```text
1E0CEFA8A3EB4B04FA1E1221DF8D7A4E15C1DEE7A6B8620E5A1CD6A534527AA8
```

Interactive help/branding also completed successfully. Results are retained at `.test-work/v103-interactive-results.json`; suite summaries are `.test-work/v103-results-7.6.8.json` and `.test-work/v103-results-7.6.5.json`. Resize geometry is tested with controlled terminal dimensions, not a claim of physical drag-resize testing in every terminal application.

No new 200GB/terabyte or multi-gigabyte integration run is claimed for this upgrade. Existing 1GB/2GB/4GB size parsing/read arithmetic and binary fixtures still pass, along with v1.0.2's corrected `[double]0.001`, StrictMode, Int64 streaming, SHA-256, old manifest compatibility, collisions and simulated mid-write interruption cleanup. Historical v1.0.2 multi-gigabyte evidence is separate from these new results.

## Release package

Build after reviewing the source:

```powershell
./scripts/build-release.ps1
```

Artifacts: `dist/Tqsim-v1.0.3.zip` and `dist/Tqsim-v1.0.3.zip.sha256`. The package has 20 application/help/document files, including both new helpers and all eight help-topic texts. Tests, fixtures, Git metadata and disposable data are excluded. The builder refuses to overwrite an existing ZIP. Final archive contents, checksum, extracted CLI/help and a packaged disposable binary round trip are validated after building. All six v1.0.0/v1.0.1/v1.0.2 ZIP/checksum assets are compared with their pre-upgrade hashes and preserved.

## Exact publication and update instructions

Nothing was published or installed into the real user environment. From the repository root, after review:

```powershell
git add .gitattributes tqsim.ps1 version.json src/Core/Tqsim.psm1 src/Commands/CLI.ps1 src/Console/Branding.ps1 examples/help.txt examples/help install.ps1 uninstall.ps1 scripts/build-release.ps1 tests/CLI.Tests.ps1 tests/Installer.Tests.ps1 tests/CLICompatibility.Tests.ps1 tests/Logos.Tests.ps1 tests/fixtures/logos README.md CHANGELOG.md IMPLEMENTATION.md
git commit -m 'Release Tqsim 1.0.3: CLI help compatibility and literal random logos'
git push origin main
gh release create v1.0.3 ./dist/Tqsim-v1.0.3.zip ./dist/Tqsim-v1.0.3.zip.sha256 --repo SamiAlmouss/Tqsim --target (git rev-parse HEAD) --title 'Tqsim v1.0.3' --notes-file CHANGELOG.md
gh release view v1.0.3 --repo SamiAlmouss/Tqsim
```

Authenticate GitHub CLI if needed and upload both assets. Do not overwrite prior tags/assets or combine manual publication with another publisher for the same tag.

Once v1.0.3 is the latest stable published release:

```powershell
tqsim update
tqsim --version -NoLogo
```

Expected output: `1.0.3`. Existing older installers can download/extract the new complete ZIP; the staged 1.0.3 installer/uninstaller know the new owned files. Alternatively download and inspect the current installer before running it with `-Repository SamiAlmouss/Tqsim`, as described in README.md. The user installation and personal file data are preserved by this upgrade workflow.

## Practical limits

No physical Windows Terminal/VS Code/standard-console matrix or physical drag-resize sweep is claimed; layout and terminal fallbacks have deterministic tests plus a real Windows interactive-console run. PowerShell owns native progress rendering and may repaint/color its overlay. App-managed resize reflow appends a fresh stable-identity block rather than rewriting terminal history. No animation, background resize listener or command abbreviation system was added.

Binary data buffers remain bounded, while existing manifest/rollback metadata still grows with part count. The upgrade does not add resume support, independent release signatures or cross-process deployment locking. These existing limitations do not change the tested file integrity behavior.
