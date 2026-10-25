# Tqsim 1.0.0 implementation report

Implemented in `D:\AntigravityIDE\codex\Tqsim` on 2026-10-25. Nothing has been uploaded to GitHub or installed into the real user's application directory. Deployment tests mock GitHub responses and user PATH writes.

## Delivered files and behavior

| Files | Purpose |
| --- | --- |
| tqsim.ps1, version.json | Direct CLI, case-insensitive commands, merge alias, banner switches and exit codes |
| src/Core/Tqsim.psm1 | Streaming binary split/merge/verify, banner and progress, strict JSON validation, size/path checks and temporary publication |
| install.ps1 | Self-contained HTTPS GitHub release installer, package checksum and extraction validation, per-user launcher/PATH management and rollback |
| update.ps1, uninstall.ps1 | Installed version comparison/update and selective application removal with data preservation |
| scripts/build-release.ps1 | Self-contained versioned ZIP and checksum |
| scripts/test-large-file.ps1 | Opt-in real binary integration test with configurable byte count |
| tests/*.Tests.ps1, tests/TestSupport.ps1 | Six Pester suites and shared fixtures |
| .github/workflows/release.yml | Tag-triggered validation, tests, build and GitHub Release publication |
| examples/help.txt | Shipped command reference |
| README.md, CHANGELOG.md, LICENSE, .gitignore | Usage, installation/trust/deployment documentation, release history, MIT license and data/build exclusions |
| dist/Tqsim-v1.0.0.zip, dist/Tqsim-v1.0.0.zip.sha256 | Locally built distribution and final-byte checksum |

The requested internal areas are consolidated into one importable core module to avoid load-order dependencies. Public entry points are preserved.

## Verification actually performed

- Windows PowerShell **7.6.5**, x64, with **Pester 4.10.1**: **51 tests passed, 0 failed, 0 skipped**.
- Real random **67,108,864-byte (64 MiB)** binary split → verify → merge; independent original/restored SHA-256 equality passed.
- Empty, tiny, single-part, divisible and short-final-part inputs; Unicode/space paths; alternate buffers; collisions and explicit overwrite; same-length corruption, truncation, missing parts, invalid original hash; malformed/duplicate/unsafe manifest data; and command exit codes tested.
- Local release ZIP built and checksum matched. Extracted installed package invoked through the actual Windows `.cmd` launcher, including Unicode path forwarding.
- Mocked clean/repeated installation, missing runtime, network failure, invalid metadata, missing assets, checksum rejection, broken ZIP, traversal rejection, PATH deduplication, update/current-version behavior, failed-update preservation, late-failure rollback/retry and uninstall data preservation passed.
- Simulated cancellation at output-stream creation cleans temporary state and preserves the source. This is not a physical Ctrl+C integration test.
- PowerShell application/test/build scripts parsed without syntax errors. The workflow was reviewed locally; GitHub Actions itself has not run.
- The system's Pester 3.4.0 was incompatible with PowerShell 7. The supported 4.10.1 module was downloaded from the official PowerShell Gallery into the ignored local test workspace, then used for all reported passing results.

## Installation and publication

See README.md for the complete Git initialization, authentication, public repository creation, topics, push, manual release and automatic tag-release commands. GitHub CLI is not available in this execution environment. No authentication or publication was attempted.

Installation URL format after publication and owner configuration:

```powershell
irm https://raw.githubusercontent.com/USERNAME/tqsim/main/install.ps1 | iex
```

Replace USERNAME both in published instructions and in install.ps1's repository default. Releases must contain `Tqsim-v1.0.0.zip` and `Tqsim-v1.0.0.zip.sha256`. For manual publication after building:

```powershell
gh release create v1.0.0 ./dist/Tqsim-v1.0.0.zip ./dist/Tqsim-v1.0.0.zip.sha256 --target main --title 'Tqsim v1.0.0' --notes-file CHANGELOG.md
```

Do not combine this with the tag-triggered automatic publication for the same release. Installer defaults to `%LOCALAPPDATA%\Programs\Tqsim`; restart a parent terminal after installation from a child process. Remote script execution and same-repository checksum trust are explained in README.md.

## Limits and remaining acceptance work

This is a working implementation, but it is **not certified to meet every production acceptance criterion**:

- File **data** uses a fixed buffer. Part metadata, rollback bookkeeping and parsed JSON use **O(number of parts)** memory. Therefore the strict requirement of constant total memory for arbitrarily many parts is not met. Streaming/on-disk manifest indexing would be needed to satisfy that stronger interpretation without imposing a part-count limit.
- No 200 GB, multi-terabyte, or actual >4 GB offset integration run was performed. Int64/overflow size handling is tested, not a substitute for those runs. To opt in, run `./scripts/test-large-file.ps1 -Bytes 214748364800` on a disposable volume with enough space for source, parts and restored output (roughly three times the input size). Files are retained for inspection.
- Live GitHub installation, real persistent user PATH updates, fresh-shell discovery, a separate standard Windows account, ARM64, PowerShell 7.0–7.5, FAT/exFAT, UNC storage, physical disk disconnection/full disk, real Ctrl+C and power-loss behavior have not been integration-tested.
- Installation/update/uninstallation should be run serially. No cross-process deployment lock is implemented. Previous immutable versions are retained rather than automatically pruned.
- Forced termination may leave temporary/unreferenced parts or a staged version. Normal managed failures clean owned temporary data. There is no resume facility.
- Windows file sharing restricts concurrent writers while input streams are open. Source length/time and output hashes are checked, but this is not a snapshot service.
- The installer validates known required files and version metadata after checking the package hash. A compromised publisher can still distribute malicious code. Same-repository checksums are integrity checks, not independent signatures.
- Network free-space reporting is skipped where unreliable. Atomic publication/replacement depends on destination filesystem support; failures remain nonzero and do not claim success.

The tests and release automation establish a useful baseline; perform the explicitly untested deployment/storage scenarios before describing the project as fully production-qualified.
