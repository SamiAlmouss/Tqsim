# Tqsim 1.0.3 implementation report

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
