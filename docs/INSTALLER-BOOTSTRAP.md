# Installer bootstrap: Windows PowerShell 5.1 and PowerShell 7+

The application still requires PowerShell 7+. The installer can now be launched from either Windows PowerShell 5.1 or PowerShell 7+ using the unchanged public command:

```powershell
irm https://raw.githubusercontent.com/SamiAlmouss/Tqsim/main/install.ps1 | iex
```

## Defect and correction

The previous runtime predicate combined the current shell's version with discovery of pwsh. It always returned false under 5.1, even when PowerShell 7 was installed. The installer now:

1. Reads the running runtime version. A version 7+ caller continues in-process and does not require a second pwsh lookup.
2. In a legacy caller, checks application commands and standard machine/per-user/Windows Store locations. Candidate executables are probed for their actual major version; an old or unusable candidate is skipped. Probes have a 15-second timeout.
3. Stages only its own self-contained installer function definitions and JSON/base64-encoded configuration in a unique temporary file. It uses a short encoded loader in a separate hidden pwsh process, with no command-line interpolation of repository/install paths.
4. Runs the same loaded installer implementation in that child. It does not need the original PSScriptRoot or PSCommandPath and does not re-download a potentially different moving-branch script. The child guard rejects a handoff still running below version 7 instead of relaunching recursively.
5. Captures stdout/stderr concurrently as UTF-8, preserves the child return code, and cleans only its generated staging file/empty directory. Execution policy is not changed.

Only the generated child payload/loader has exit statements. The parent installer has no executable exit statement: failures throw a readable error and set LASTEXITCODE, so an irm/iex failure leaves the user's interactive shell alive. Ordinary success/failure codes are 0/1. An unusual child code is retained in LASTEXITCODE and the parent error message; an uncaught standalone `powershell -File` exception follows PowerShell's normal nonzero failure behavior.

If no runnable PowerShell 7+ is found, the message includes:

```powershell
winget install --id Microsoft.PowerShell --source winget
```

No dependency is installed silently. A 5.1 handoff updates the persistent user PATH from the child but cannot modify the already-running parent's process environment; open a fresh terminal after success.

Checksum verification, GitHub asset identity checks, ZIP traversal/symlink checks, package validation, staging, rollback, launcher creation, PATH deduplication, updates and uninstall behavior remain in the existing release installer. The split/merge engine is unchanged. No versioned release archive has been overwritten; this bootstrap fix is delivered by updating the root install.ps1 on main, independently of the existing application release assets.

## Local verification

`tests/InstallerBootstrap.Tests.ps1` covers runtime branching, missing-runtime guidance, the loop guard, child exit-code forwarding, the absence of executable parent exits, candidate version probes and real child processes. The fixture in `tests/fixtures/InstallerBootstrapHarness.ps1` uses the exact public pipeline syntax with a **local HTTP response fixture**, replacing only the download/install effect with a harmless receipt writer. It does not claim to download from the public URL.

The process matrix exercises both Windows PowerShell 5.1 and PowerShell 7 callers, both piped and downloaded-script invocation, and success/failure. It verifies separate PIDs for the legacy handoff, no second process for a 7+ caller, preservation of spaces/apostrophes/Unicode in the install root, unchanged repository identity, empty original script paths in the legacy child, the correct return code, and execution continuing in the parent after failure.

Test results are recorded during this change in `.test-work/installer-runtime-results-*.json`. The initial real legacy handoff used 5.1.26100.9711 → 7.6.8. The Store runtime updated to 7.6.9 during the session; the final full PowerShell 7 installer suite therefore used 7.6.9 rather than misreporting it as 7.6.8.

- Windows PowerShell **5.1.26100.9711**: **15 bootstrap tests**.
- PowerShell **7.6.9**: **35 installer tests**, comprising the 15 bootstrap tests plus 20 existing release/security/rollback/PATH/launcher/update/uninstall tests.
- The earlier bundled PowerShell **7.6.5** bootstrap run passed all 14 tests then present, before the additional static parent-exit guard was added.

Installer release tests use local ZIP/checksum fixtures and mocked GitHub/PATH writes. Real user application files, PATH entries, ISO and backup files are not modified by these tests. Native Windows PowerShell parses and runs the bootstrap itself; the application remains PowerShell 7+ only.

To rerun on a Windows machine with Pester 4.10.1:

```powershell
# From pwsh, run both the existing installer and new bootstrap tests:
Import-Module Pester -RequiredVersion 4.10.1
$result = Invoke-Pester -Script ./tests/Installer.Tests.ps1,./tests/InstallerBootstrap.Tests.ps1 -PassThru
if ($result.FailedCount) { throw 'Installer tests failed' }

# From a separate Windows PowerShell 5.1 session:
Import-Module Pester -RequiredVersion 4.10.1
$result = Invoke-Pester -Script ./tests/InstallerBootstrap.Tests.ps1 -PassThru
if ($result.FailedCount) { throw 'Bootstrap tests failed' }
```

## Deployment and the still-pending live URL test

**The fixed public URL has not been tested live after deployment because this change has not been published.** Local HTTP fixtures prove the execution shape, not that main already serves this fix. No automatic push or publication was performed.

After review, a maintainer can deploy the root installer without replacing any existing release assets:

```powershell
git add install.ps1 tests/InstallerBootstrap.Tests.ps1 tests/fixtures/InstallerBootstrapHarness.ps1 README.md CHANGELOG.md IMPLEMENTATION.md docs/INSTALLER-BOOTSTRAP.md
git commit -m 'Fix PowerShell 5.1 installer bootstrap and preserve parent shell'
git push origin main
```

Then, from a disposable standard Windows user account or VM, test the **unmodified public command** in a fresh Windows PowerShell 5.1 window:

```powershell
$PSVersionTable.PSVersion
irm https://raw.githubusercontent.com/SamiAlmouss/Tqsim/main/install.ps1 | iex
$LASTEXITCODE
```

Repeat from a fresh PowerShell 7+ window:

```powershell
$PSVersionTable.PSVersion
irm https://raw.githubusercontent.com/SamiAlmouss/Tqsim/main/install.ps1 | iex
$LASTEXITCODE
```

Success should report exit code 0 and the installed release version. Open a fresh terminal and run `tqsim version -NoLogo`. Confirm that 5.1 reports a single handoff and that 7+ does not relaunch. Repeat installation to check PATH deduplication. Record the exact runtime versions and live results before claiming public one-line installation is deployed and verified.

## v1.0.8 install/uninstall/reinstall lifecycle correction

Earlier uninstallers deleted only known files and the root ownership marker, leaving empty bin/versions and nested application directories. The next installer correctly refused the now-unowned root. Merely deleting the ownership check would risk unrelated data.

The corrected uninstaller prunes only known empty directories, bottom-up, using nonrecursive directory deletion and checking root boundaries/reparse points. Each version's version.json is deleted last, so denied/interrupted file cleanup keeps ownership proof for retry. The root marker is removed only after all other content is gone, followed by the empty root. When unrelated files/directories remain, they and the marker remain for safe reinstallation; the launcher/PATH entry is removed. Private recovery records remain untouched.

The corrected installer accepts a genuinely empty target or a markerless directory-only legacy layout: top-level bin (empty), versions, version-number/GUID children and only known empty src/Core, src/Commands, src/Console, examples/help and docs directory structures. It never deletes files to make a candidate qualify. Hidden entries are enumerated; files, unknown directory names, reparse points and corrupt/unreadable/linked markers fail closed with guidance to preserve data and choose another InstallRoot or restore ownership. Fresh-install rollback also applies to adopted empty targets, making a late failure retryable.

Run the corrected local install.ps1 from this checkout to use that preflight; it is not deployed automatically. Earlier published/release ZIPs remain unchanged; the prepared v1.0.8 release packages the corrected uninstaller. A corrected main installer can recover the recognized empty remnants of an older packaged uninstaller. The public one-line command changes only after authorized deployment.

Lifecycle regressions cover repeated cycles, recovered old scaffolds, empty targets, preserved user data/root provenance, hidden files/unknown directories, invalid/directory/locked markers, junctions, interrupted read-only cleanup/retry and late PATH rollback. Persistent PATH/network are mocked in isolated fixtures; native Windows PowerShell 5.1 bootstrap and real Windows launchers are exercised without updating the user's application.
Initial local lifecycle verification before the additional mandatory regressions: full Pester 4.10.1 suite on PowerShell 7.6.5 — 241 passed, 0 failed/skipped/pending/inconclusive, 192.64 seconds. Installer/bootstrap/documentation suite on installed PowerShell 7.6.9 — 57 passed, 0 failed/skipped/pending/inconclusive, 75.46 seconds. Evidence: .test-work/lifecycle-full.xml and .test-work/lifecycle-store.xml. Existing release ZIP/checksum hashes remain unchanged; no deployment/global install was performed.

## Additional mandatory legacy-layout and installed-command regressions

The exact initial tree is created beneath an isolated LOCALAPPDATA, with no ownership marker and no extra version child:

```text
%LOCALAPPDATA%\Programs\Tqsim\
    bin\        (empty)
    versions\   (empty)
```

The test asserts both directories exist and are empty, root has exactly those two entries, and marker is absent. Installation, clean uninstall (root absent) and reinstallation then succeed with one PATH entry. Additional cases reject nonempty bin, versions and nested version content before network/download/PATH changes, preserving exact binary hashes. Five actual NTFS junction tests cover root, bin, versions, a nested version docs directory and the marker path; target sentinel data remains unchanged. Corrupt/empty/wrong-application/locked ownership markers block recovery, including alongside the exact empty legacy tree.

A native test resolves tqsim from the fixture installation's PATH and executes the actual tqsim.cmd → pwsh → dispatch.ps1 → tqsim.ps1 → uninstall.ps1 chain. It performs two install/uninstall cycles and a final reinstall, asserts the complete installation root disappears after each uninstall, verifies exit codes 0/1/2/3, checks Unicode/space/! argument forwarding with an actual split/verify/merge SHA-256 round trip, and proves a parent CALL batch resumes after uninstall. No manual directory cleanup is used.

This native test exposed a real additional bug: deleting tqsim.cmd during uninstall caused cmd to reopen its deleted batch context and return an error. The corrected launcher leaves that context with `(goto) 2>nul` before invoking pwsh on the same expanded line. It naturally propagates the child status without exiting the parent shell, reopening the deleted file, or enabling delayed expansion that would alter ! in paths. Tests verify both PowerShell and parent-batch callers survive. An intermediate bare exit /b approach failed to preserve nonzero codes and was replaced, not accepted.

Isolation: installs use mocked release metadata/downloads and normal checksum/ZIP validation. Only the two persistent-PATH accessor bodies in the native test's packaged uninstaller are redirected to a fixture text file; its checksum/asset lengths are recalculated. Application CLI, dispatcher, ownership checks and cleanup run unchanged. The real user registry PATH is independently checked unchanged. No global Tqsim installation, published URL or release archive is modified. Initial synthetic-attribute mock leakage was corrected by explicitly limiting its activation to that test; safety assertions were not weakened.

**Native symbolic-link limitation:** Windows denied both PowerShell and .NET file-symlink creation because the client lacks the required privilege. No actual file-symlink creation test is claimed. Actual junction/reparse tests and a direct shared-ReparsePoint-flag test pass; the latter confirms rejection before scaffold inspection. No UAC elevation or permission bypass was attempted. This limitation is separate from the final Pester skip count (zero).

Final complete suites (Pester 4.10.1):

| Runtime | Passed | Failed | Skipped / pending / inconclusive | Time |
| --- | ---: | ---: | --- | ---: |
| PowerShell 7.6.5 | 253 | 0 | 0 / 0 / 0 | 217.50 s |
| PowerShell 7.6.9 | 253 | 0 | 0 / 0 / 0 | 236.88 s |

All 241 preceding tests remain; 12 additional parameterized cases were added. Full suites include native Windows PowerShell 5.1 installer handoff, checksum/ZIP rejection, rollback/retry, PATH deduplication and previous binary/encryption/cleanup/help coverage. Evidence: `.test-work/legacy-exact-full-765.xml` and `.test-work/legacy-exact-full-store.xml`. The final focused installer run also passed 42/42. Initial new focused tests exposed the launcher failure and a test-isolation defect; all final completed suites above have zero outstanding failures. Existing release ZIPs/checksums and all processing/branding source hashes remain unchanged. Public deployment/global installation is not performed.