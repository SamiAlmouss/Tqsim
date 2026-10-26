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
