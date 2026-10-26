# Tqsim v1.0.7 — release validation

Date: 2026-10-26. Scope: documentation/help only. No binary engine, archive format, hash/authentication algorithm or processing defaults changed. No tag, push, publication or global installation was performed. No user ISO or .smm backup was opened or modified.

## Full regression suites

| Runtime | Passed | Failed | Skipped | Pending / inconclusive | Elapsed |
| --- | ---: | ---: | ---: | --- | ---: |
| PowerShell 7.6.5 (bundled) | 231 | 0 | 0 | 0 / 0 | 196.63 s |
| PowerShell 7.6.9 (installed Store runtime) | 231 | 0 | 0 | 0 / 0 | 199.25 s |

Pester 4.10.1. Evidence: `.test-work/v107-final-765.xml` and `.test-work/v107-final-store.xml`. All 219 preceding tests remain; 12 new documentation tests were added. No tests were deleted or weakened. The initial 12-test documentation run also passed before promoting version metadata. A sandbox-restricted first attempt stalled and was interrupted; the completed runs used normal temporary-file access and returned the results above. No completed run reported a failed or skipped test.

The complete suite covers real binary split/merge/SHA-256, encryption/password/authentication/tampering, authentic archived-release fixtures, Int64 boundaries, source deletion and actual NTFS deny/allow/sharing/read-only states, crash/partial cleanup, terminal logos/colors/progress, installer checksum/ZIP validation/rollback/PATH/update/uninstall, native Windows PowerShell 5.1.26100.9711 handoff and installed launcher forwarding. Installer work uses isolated fixtures and mocked external network/persistent PATH, not the user's managed installation.

## Documentation consistency and help safety

- Nine commands/spellings: split, merg, merge, verify, info, update, uninstall, version, help. Complete CLI pages and both-language command references/defaults/examples.
- All 14 actual named parser options are covered: File, Size, Output, PartsPath, Manifest, BufferSize, ds, verify, encrypt, Overwrite, NoLogo, NoColor, Quiet, Diagnostics. Unified reference also covers every help/version alias, optional topic, accepted values, mandatory/default status and warnings.
- Main help resolves its displayed version from version.json, including with NoLogo. Main structure: title/version, usage, commands, globals, quick start, security, get help.
- Thirty-three unique executable tqsim examples match between English and Arabic. PowerShell AST tokenization and the real argument parser accept each example. Syntax lines with angle-bracket placeholders are treated as reference syntax, not executable examples. Examples are parsed, never blindly executed against their illustrative D:/E: paths.
- Every topic/help-flag combination is dispatched with operation, manifest, password, ACL, journal and deployment functions mocked to fail if called; all call counts remain zero. Help bypasses mandatory operation arguments/value validation without weakening the actual parser.
- NoLogo/NoColor/Quiet, redirected output without decorative ANSI, 20-column interactive help and a one-column terminal pass. Wrapping retains all non-whitespace text. Existing literal logo/color/centering regressions remain intact. Narrow-terminal coverage uses a mocked terminal size, not a claim to have tested every terminal emulator.
- Local Markdown targets and heading anchors resolve in both READMEs and current reference/guide files. docs/COMMANDS.md matches the built-in pages exactly. Current instructions agree on same-directory merging, split-only encryption, authentication versus read-back and original-schema password-free recovery.
- No unsupported commands were added. Audit corrections: info has no explicit encryption-status/per-part listing and does not authenticate HMAC; explicit Manifest overrides discovery; independent merge read-back follows publication; update has no check-only/confirmation; uninstall has no confirmation. See [coverage matrix](HELP-COVERAGE.md).

## Engine and deployment preservation

SHA-256 comparison against the initial v1.0.6 checkout confirms six unchanged files: src/Core/Tqsim.psm1, Encryption.ps1, Crypto.cs, Deletion.ps1, Errors.ps1 and src/Console/Branding.ps1. Comparing parser AST function text against the archived v1.0.6 ZIP confirms Resolve-TqsimInvocation, Invoke-TqsimCommand, Invoke-TqsimDeployment, Get-TqsimVersion and Get-TqsimSuggestion are unchanged. Only the two help reader/renderer functions changed in CLI.ps1.

Build, installer rollback and uninstaller ownership lists gained documentation filenames only. Existing required-file validation, checksum/ZIP protection, rollback behavior, PATH and managed update logic remain. Documentation sources, version.json and version-matched CLI/installer fixtures moved to 1.0.7. Previous release archives/checksums are checked against `.test-work/v107-prior-release-hashes.json` (14 release assets plus the existing .gitkeep entry).

## Release package audit

Assets: `dist/Tqsim-v1.0.7.zip` and `dist/Tqsim-v1.0.7.zip.sha256`. Package contract: 37 entries, including both READMEs, changelog, implementation, all command pages, reference/coverage/troubleshooting/validation/history/format documents and existing application/deployment files. Tests, profiling scripts and disposable data are excluded. The build refuses an existing ZIP.

The separate post-build audit `.test-work/validate-v107-release.ps1` records the actual ZIP byte size, SHA-256, entry count and disposable extracted location in `.test-work/v107-release-validation.json`. It checks every archive entry against validated source bytes, checksum, safe/unique paths and unchanged prior assets. It exercises extracted version and every help topic (including both merge spellings), exact source/help text agreement, NoLogo/NoColor/redirected output and local packaged documentation links.

Its extracted-package disposable binary checks cover all four plain ds/verify combinations; standalone verify; default same-directory plain restore; encrypted split/auto-merge with ds=true and verify=true/false; independent SHA-256 equality; and an actual read-only partial-cleanup failure returning code 1 while preserving completed output/manifest. The encrypted harness replaces only its secret reader with a public nonsecret fixture passphrase; production has no password option. The post-build JSON is deliberately outside the ZIP to avoid making a checksum report recursively depend on its own archive checksum.

## Limits and deployment

No new multi-gigabyte benchmark was run for this documentation release; [v1.0.6 large-file measurements](VALIDATION-v1.0.6.md) and [v1.0.5 optimization measurements](PERFORMANCE-v1.0.5.md) are explicitly historical. No external crypto audit, Linux/macOS certification, physical 200GB/1TB, elevated/UAC-helper or hardware/network crash guarantee is claimed. Existing security limitations remain in the [format specification](ENCRYPTED-FORMAT-v1.md).

The published one-line install command has not been run for unpublished v1.0.7. After authorized publication, test it in disposable Windows PowerShell 5.1 and PowerShell 7 sessions and verify 1.0.7. Both language READMEs provide exact release asset commands and managed update steps. Nothing is automatically tagged, pushed, published or installed.