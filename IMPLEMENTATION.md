# Tqsim 1.0.2 — split runtime fix and validation report

## Exact reproduced defect

The original v1.0.1 release was extracted into a disposable workspace directory. Running its split operation under the user's installed **PowerShell 7.6.8**, with a real terminal and a freshly generated **5,368,709,137-byte (5 GiB + 17)** random file, reproduced the exact reported exception:

```text
System.Management.Automation.PropertyNotFoundException
The property '1' cannot be found on this object. Verify that the property exists.
at Show-TqsimProgress, src/Core/Tqsim.psm1: line 86
at Split-Tqsim, src/Core/Tqsim.psm1: line 109
```

The original failing source line was:

```powershell
$seconds=[math]::Max([double].001,[double]$Clock.Elapsed.TotalSeconds); $rate=$Done/$seconds
```

`[double].001` is parsed as member/property access on the Double type, not a cast of the decimal constant. Under StrictMode it requests a nonexistent numeric property `1`. The correct expression is **`[double]0.001`**. This malformed expression was introduced in the v1.0.1 progress arithmetic change.

This was **not** a regex-group, array-index, manifest dictionary, or Int64 streaming failure. The size parser remains unchanged. Small files can finish before the first progress update. Quiet/redirected runs skip Show-TqsimProgress entirely, so previous binary/large-file tests did not exercise the failing path. The baseline reproduction used interactive output specifically to expose it.

The reproduced original module SHA-256 is `DD9CDF1681C1ADE39ACEF5D23BAE0828EFED4DB2C7139A962520BD703BD9784E`. The saved exception record is `.test-work/runtime768-60153957-242e-4e8b-91cb-eb15b0451281/baseline-failure.json`.

## Focused correction

- Use `[double]0.001` in progress arithmetic. The calculation is shared through Get-TqsimProgressMetrics, which is tested directly even on headless CI. Interactive rendering uses those same metrics.
- Preserve StrictMode, validation, 4 MiB binary buffers, Int64 file/part/remaining-byte counters and the v1.0.1 Int64 Min operands. Only bounded FileStream read counts are Int32. No entire chunk/file is loaded into RAM.
- Add optional CLI **-Diagnostics**. Errors still start with a readable FAILED message; diagnostics add exception type, source script, exact line number, source text, ScriptStackTrace and inner exceptions to stderr. Existing exit codes remain unchanged.
- Preserve the inner exception when manifest validation wraps a failure, so diagnostic output retains the original cause.
- Keep collision checks and unique staging names. Existing incomplete part names cause a safe failure; unrelated old temporary files are preserved.
- Set CLI version, banner, application manifest metadata and version.json to **1.0.2**. Manifest schema remains version 1 and old manifests remain compatible.

## Complete automated test results

| Runtime | Tests passed | Failed | Skipped |
| --- | ---: | ---: | ---: |
| PowerShell 7.6.8 (user's Windows Store runtime) | 88 | 0 | 0 |
| PowerShell 7.6.5 (bundled execution runtime) | 88 | 0 | 0 |

Pester 4.10.1 was used. The 7.6.8 run also put that runtime first on its process PATH so child CLI and Windows launcher tests ran on 7.6.8. Real user PATH changes and GitHub downloads are mocked in installer tests.

Coverage includes real **1 MiB and 5 MiB CLI sources with 1GB parts**, multiple output parts, exact chunk boundaries, SHA-256 verification and full split/merge equality, preserved source hashes, mid-write simulated cancellation and temporary-file cleanup, pre-existing incomplete-part collisions and old temporary-file preservation. Progress tests cover measured rate/ETA/percentage, zero elapsed time, empty data and Int64 byte/part counts. Diagnostics tests cover opt-in output, actual type/source/line/stack fields and nested exceptions.

Existing boundary tests still cover 500MB, 1GB, 2GB, 4GB, Int32.MaxValue, Int32.MaxValue + 1, 200GB and 1TB parsing/read arithmetic. PowerShell source/test syntax validation passed.

Test summaries are retained in `.test-work/results-768.json` and `.test-work/results-765-v102.json`.

## Actual multi-gigabyte interactive tests

All three configurations used the same disposable **5,368,709,137-byte** random source, separate fresh part/restored directories, and PowerShell **7.6.8** with **Console.IsOutputRedirected = False**. Split, verify, merge preflight and merge all rendered normal progress; neither Quiet nor output redirection bypassed the fixed code.

| Configured chunk | Exact generated part lengths (bytes) | Result |
| --- | --- | --- |
| 1GB | 1073741824 x 5, then 17 | Split / verify / merge / independent SHA-256 passed |
| 2GB | 2147483648, 2147483648, 1073741841 | Split / verify / merge / independent SHA-256 passed |
| 4GB | 4294967296, 1073741841 | Split / verify / merge / independent SHA-256 passed |

All restored files had the exact original byte length. All source/restored SHA-256 hashes matched:

```text
DF1B641E1E8E7D0F6C7A6506AE68DB831D1BB7E511E64934D436042D7F03ED53
```

Measured per-configuration times were approximately 75, 77 and 78 seconds, including independent restored hashing, excluding initial source generation and initial/final source hashing. Results are retained in `.test-work/runtime768-60153957-242e-4e8b-91cb-eb15b0451281/fixed-integration-results.json`. Generated large disposable data may be cleaned after final verification; the evidence records are retained.

The user's `E:\Win11_Arabic_x64v1.iso` and `.smm` backup files were **never opened, modified or deleted**. Only generated test data was used. No previous incomplete user output was reused. No physical 200GB or 1TB file test is claimed.

## Source, version and Git-state checks

The checkout is on main, with origin `https://github.com/SamiAlmouss/Tqsim.git`. Git HEAD was `ed92a1b` (installer repository-path fix following the initial v1.0.0 commit). The previous v1.0.1 work was already uncommitted; it was preserved and the focused v1.0.2 correction was applied on top. Nothing was reset, committed or pushed automatically.

The bundled tool shell was 7.6.5, whereas the Windows Store pwsh executable was confirmed as 7.6.8. Switching to that executable and a real terminal exposed the exact original failure. This distinction explains why an initial small redirected reproduction did not fail.

Changed files for this correction: `src/Core/Tqsim.psm1`, `tqsim.ps1`, `version.json`, `examples/help.txt`, `tests/Runtime.Tests.ps1`, CLI/installer version and diagnostics tests, README, CHANGELOG and this report. The existing v1.0.1 Int64 tests and integration helper remain part of the cumulative working tree. Installer/update/uninstall behavior is unchanged.

## Build and publish v1.0.2

Build after reviewing/testing:

```powershell
./scripts/build-release.ps1
```

This produces `dist/Tqsim-v1.0.2.zip` and `dist/Tqsim-v1.0.2.zip.sha256`. The builder refuses to overwrite an existing ZIP. v1.0.0 and v1.0.1 assets are preserved and compared with their pre-change hashes. The final ZIP checksum and an extracted CLI smoke check are verified separately after packaging.

To publish from this repository after reviewing the cumulative patch:

```powershell
git add src/Core/Tqsim.psm1 tqsim.ps1 version.json examples/help.txt scripts/test-large-file.ps1 tests/CLI.Tests.ps1 tests/Installer.Tests.ps1 tests/Int64.Tests.ps1 tests/Runtime.Tests.ps1 README.md CHANGELOG.md IMPLEMENTATION.md
git commit -m 'Fix interactive progress property access; release Tqsim 1.0.2'
git push origin main
gh release create v1.0.2 ./dist/Tqsim-v1.0.2.zip ./dist/Tqsim-v1.0.2.zip.sha256 --repo SamiAlmouss/Tqsim --target (git rev-parse HEAD) --title 'Tqsim v1.0.2' --notes-file CHANGELOG.md
gh release view v1.0.2 --repo SamiAlmouss/Tqsim
```

GitHub CLI must be authenticated and have repository write access. Upload both assets. Do not replace earlier tags or assets. No GitHub publication has been performed for this patch.

## Update the installed global application

The real global Tqsim installation was **not updated** during investigation or testing. Once the verified v1.0.2 release is published as the latest stable release:

```powershell
tqsim update
tqsim version -NoLogo
```

Expected version: `1.0.2`. Alternatively, download and inspect the published installer before running it:

```powershell
Invoke-WebRequest https://raw.githubusercontent.com/SamiAlmouss/Tqsim/main/install.ps1 -OutFile ./install-tqsim.ps1
Get-Content ./install-tqsim.ps1
pwsh -NoProfile -File ./install-tqsim.ps1 -Repository SamiAlmouss/Tqsim
```

Open a fresh terminal if PATH needs refreshing. Use a fresh output directory when retrying a split after an interrupted attempt; Tqsim deliberately rejects existing part-name collisions. Add -Diagnostics if an operation fails to get the exact runtime location. These update/retry instructions were documented, not executed against the user's installation or ISO.

## Remaining limits

Physical disk disconnection, real Ctrl+C/power loss, other filesystems and 200GB/terabyte integrations were not newly tested. Interruption cleanup tests simulate a cancellation during an actual part write. Binary data memory stays bounded; manifest/rollback metadata still uses memory proportional to the number of parts. No unrelated interface redesign, deployment locking or resume behavior was added.
