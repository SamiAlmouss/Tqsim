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
