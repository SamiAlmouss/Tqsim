# Tqsim

```text
 _____  ___  ____ ___ __  __
|_   _|/ _ \/ ___|_ _|  \/  |
  | | | | | \___ \| || |\/| |
  | | | |_| |___) | || |  | |
  |_|  \__\_\____/___|_|  |_|
Split • Merge • Verify
```

Fast and reliable PowerShell CLI for splitting, merging, and verifying massive files. Windows, PowerShell 7+, MIT licensed. No third-party binary dependencies; works offline after installation.

Tqsim streams binary data through a reusable 4 MiB buffer, calculates SHA-256 for every part and the original stream, and restores files only after verification. It uses Int64 counters and supports binary units through TiB. The file data buffer stays bounded; JSON manifest metadata consumes memory proportional to the number of parts. Choose sensible part sizes for very large files. No 200 GB or terabyte benchmark has been run for this release.

## Requirements

Windows and PowerShell 7 or newer. If needed, run `winget install --id Microsoft.PowerShell --source winget`, then open `pwsh`. Windows PowerShell 5.1 is not supported. Local NTFS storage is recommended; network share capacity reporting and atomic replacement depend on the filesystem. Destinations containing directory junctions/symlinks are rejected.

## Install

**Publication prerequisite:** this source checkout does not imply that a GitHub repository or release exists. Before advertising the following command as working, publish the repository and versioned release assets. Replace every `USERNAME` in this README **and the default repository in install.ps1** with the actual owner. Forks must change that default too.

```powershell
irm https://raw.githubusercontent.com/USERNAME/tqsim/main/install.ps1 | iex
```

This runs remote code. A safer alternative lets you download and inspect the installer first:

```powershell
Invoke-WebRequest https://raw.githubusercontent.com/USERNAME/tqsim/main/install.ps1 -OutFile install.ps1
Get-Content ./install.ps1
pwsh -NoProfile -File ./install.ps1 -Repository USERNAME/tqsim
```

Installation downloads the latest stable GitHub Release ZIP and its checksum, checks asset names, lengths, SHA-256 and ZIP paths, then stages an immutable version under `%LOCALAPPDATA%\Programs\Tqsim\versions`. The selected version is recorded in `.tqsim-install.json`. A `bin\tqsim.cmd` launcher forwards arguments through `pwsh`; bin is added to the current user's PATH without administrator privileges or profile edits. A piped installer can refresh its session PATH; a child-process installer cannot change the parent terminal, so restart it after installation.

Checksums from the same GitHub repository detect corruption; they do not provide independent publisher authentication. Trust the repository owner, release assets, and downloaded installer. Inspect or pin the installer to a trusted commit when appropriate. Do not weaken machine execution policy.

## Commands

```powershell
tqsim split -File 'D:\Backup\disk.iso' -Size 2GB
tqsim split -File 'D:\Backup\disk.iso' -Size 500MB -Output 'E:\Parts'
tqsim merg -PartsPath 'E:\Parts'
tqsim merge -PartsPath 'E:\Parts' -Output 'D:\Restored'
tqsim verify -PartsPath 'E:\Parts'
tqsim info -Manifest 'E:\Parts\disk.iso.tqsim.json'
tqsim help
tqsim version
```

From this checkout, use `pwsh -NoProfile -File ./tqsim.ps1` in place of `tqsim`. Commands are case insensitive. `merg` and `merge` are aliases. All commands accept `-NoLogo`, `-Quiet`, `-Diagnostics`, and `-NoColor`; streaming commands also accept `-BufferSize` (4096 to 67108864 bytes). `info` reports metadata only and does not verify the parts.

For development failures, add `-Diagnostics` to print the exception type, source script, exact line number, PowerShell ScriptStackTrace, and inner exceptions to stderr. Normal mode retains readable errors and the same exit codes. To retry after an incomplete split, choose a fresh output directory; Tqsim refuses to overwrite existing part names:

```powershell
pwsh -NoProfile -File ./tqsim.ps1 split -File 'E:\Win11_Arabic_x64v1.iso' -Size 1GB -Output 'E:\Tqsim-parts-v1.0.3' -Diagnostics
```

That example is for a user-initiated retry; automated tests use disposable binary data and never the original ISO.

Sizes are positive integer bytes, or binary suffixes B, KB/KiB, MB/MiB, GB/GiB, TB/TiB. Thus 1GB = 1,073,741,824 bytes. Fractional, negative and overflowing sizes are rejected.

Split defaults to `Output` alongside the source. Parts are `disk.iso.part0001`, etc., with numbering width expanded as needed. Empty input produces zero parts and a manifest containing the SHA-256 of the empty stream. Merge and verify default to the current directory. Merge defaults to its `Output` subdirectory. When multiple manifests exist, provide `-Manifest` explicitly. The manifest's directory defines the location of its relative parts, including when `-PartsPath` is also supplied.

Existing split outputs are never overwritten. Merge requires explicit `-Overwrite` to replace a restored file and uses atomic filesystem replacement where supported. Inputs are never automatically removed. A complete preflight integrity pass runs before merge; the writing pass checks hashes again to detect changed parts. Failed output is removed. Ctrl+C unwinds finally blocks; forced termination or power loss can leave `.tqsim-*.tmp` or unreferenced parts. Review these manually before removal. No resumable operations are implemented.

Interactive progress updates at most four times per second, with percentage, current/completed parts, exact bytes, cumulative measured average speed, elapsed time and ETA. Cumulative averaging smooths throughput. Redirected logs omit progress and retain completion/error messages. Quiet suppresses informational output, but failures still go to stderr.

Example completion (illustrative):

```text
COMPLETED: 100 parts, 214748364800 bytes; E:\Parts\disk.iso.tqsim.json
COMPLETED: verified 100 parts and original SHA256.
COMPLETED: restored 214748364800 bytes to D:\Restored\disk.iso
```

Exit codes: **0** success, **1** operational/I/O/deployment failure, **2** invalid CLI usage, **3** invalid manifest or cryptographic integrity mismatch. Some OS errors such as missing part paths use code 1. Every failure is nonzero.

## Help and version compatibility (1.0.3)

No arguments displays full help. These forms are case insensitive:

| Purpose | Syntax |
| --- | --- |
| Main help | `tqsim`, `tqsim help`, `tqsim -help`, `tqsim --help`, `tqsim -h`, `tqsim --h`, `tqsim -?`, `tqsim /?`, `tqsim /help` |
| Command help | `tqsim help split`, `tqsim split help`, `tqsim split -help`, `tqsim split --help`, `tqsim split -h`, `tqsim split /?` |
| Other topics | Replace split with `merge`, `merg`, `verify`, `info`, `update`, `uninstall`, or `version` |
| Version | `tqsim version`, `tqsim -version`, `tqsim --version`, `tqsim -v`, `tqsim -V` |

Help runs before mandatory file/size and buffer-value validation and never starts processing or deployment. Successful help/version requests return 0; unknown commands and unsupported/duplicate arguments return 2. Clear typos get a suggestion (`splitt` → `split`, `merger` → `merge`, `verfiy` → `verify`). Diagnostics remain opt-in.

All forms work through the installed Windows `.cmd` launcher and after `pwsh -NoProfile -File ./tqsim.ps1`. A raw-argument script entry point intentionally handles `-?` itself instead of letting an advanced-script binder substitute generic PowerShell help. Put help/version arguments **after** `-File ./tqsim.ps1`; `pwsh -?` before the script requests PowerShell's own help.

Existing named file parameters use one dash and exact full names, case insensitive: `-File`, `-Size`, `-Output`, `-PartsPath`, `-Manifest`, `-BufferSize`, `-Overwrite`. Quoted spaces/Unicode and explicit Boolean switches such as `-Quiet:$false` are supported; parameter abbreviations, GNU `--file`, and arbitrary PowerShell common parameters are not accepted. Use a relative prefix such as `.\-notes.bin` for a filename beginning with a dash. Arguments are never evaluated as code. The application version comes from `version.json`.

## Three literal ASCII logos

Each invocation with branding selects one of exactly three stored designs with `RandomNumberGenerator.GetInt32(0, 3)`. Repeated choices are valid; no forced rotation occurs. Source literals are in `src/Console/Branding.ps1`, with exact reference fixtures in `tests/fixtures/logos`.

| Logo | Literal design | Lines | Theme |
| --- | --- | ---: | --- |
| 1 | Original compact TQSIM design shown above | 5 | Neon green `#63EDC6` |
| 2 | Wide outlined design beginning `_________ _______` | 8 | Electric cyan `#53DCEB` |
| 3 | Block design beginning `_____._._______`, ending with the colon line | 7 | Warning red `#EF5965` |

Spacing, trailing spaces, punctuation and backslashes are preserved. Layout centers the entire logo using its widest line and separately centers the tagline, version and secure-operation label. Tall terminals get vertical padding based on the selected logo height and the help/body/dashboard space. The terminal background is never changed.

When a design is wider than the terminal, branding uses a compact `TQSIM` label. This is a display fallback, not a fourth registered logo. During active operations, dimension changes reflow the **same** selection and restore its full literal when it fits. Resize reflow prints a fresh block only on dimension changes, without clearing the screen or emitting cursor-position codes; static completed help screens do not run a background resize listener. Native PowerShell progress remains host-managed.

`-NoLogo` suppresses branding and random selection; `-Quiet` also suppresses routine progress. `-NoColor` and `NO_COLOR` disable Tqsim logo/help styling (native host progress may retain host colors). Supported virtual terminals with `WT_SESSION` or `COLORTERM=truecolor/24bit` get the theme RGB values; other interactive hosts use ConsoleColor equivalents. Redirected output uses plain text without ANSI codes, centering padding, animations, or redraws. No animation is implemented, so no `-NoAnimation` flag is advertised. Terminal APIs have a safe 80×25 fallback.

## Manifest version 1

UTF-8 JSON, `.tqsim.json`. Required fields:

| Field | Type / meaning |
| --- | --- |
| application / applicationVersion | `Tqsim` / semantic release version |
| manifestVersion | Integer 1 |
| operationId | UUID |
| originalFileName | Safe single filename |
| originalSize | Nonnegative Int64 bytes |
| originalSHA256 | 64 hexadecimal characters |
| partSize | Positive Int64 bytes |
| totalParts | Nonnegative integer matching ordered parts |
| hashAlgorithm | `SHA256` |
| createdUtc | ISO 8601 UTC timestamp |
| parts | Ordered array of index, fileName, size, sha256 |

Part indexes start at 1 without gaps; all but the final part equal partSize; lengths sum exactly to originalSize. Part filenames are relative single names without traversal, drive prefixes, reserved Windows device names, or invalid characters. Duplicate names are rejected case insensitively, hashes must be well formed, and unknown schema versions fail. Manifests are never executed. Extra files in the parts directory are ignored. SHA-256 checks consistency with the manifest; an attacker who can replace both manifest and parts can replace content. Keep a trusted manifest/hash separately for authenticity-sensitive use.

## Update and uninstall

Version 1.0.2 fixes an interactive-progress failure: `[double].001` was parsed as property access, producing a StrictMode error for property `1`. The corrected numeric literal is `[double]0.001`. Progress arithmetic now has direct regression coverage even when tests run with redirected output. The Int64 streaming fix from 1.0.1 remains in place. Existing manifests remain compatible; the manifest schema and existing CLI syntax are unchanged. Version 1.0.3 adds the help compatibility and randomized branding described above while preserving that fix. Once the v1.0.3 release has been published, update the installed global command and check its version:

```powershell
tqsim update
tqsim version -NoLogo
# Expected after updating: 1.0.3
```

If the installed updater is unavailable, download and inspect the current `install.ps1` as described above, then rerun it with your repository name. It installs the latest stable release and preserves prior versions. Updating the application does not modify your original backup, parts, or manifests.

```powershell
tqsim uninstall
```

Update compares installed and latest stable versions, then uses the same checked download/staging installer. The prior version remains on disk for recovery if staging fails. Uninstall removes only known application filenames from version directories, the launcher, marker, and exact Tqsim PATH entry. User data and directories remain. The uninstaller is a separate script invoked from the CLI; PowerShell script files do not require a detached deletion helper. Restart terminals to refresh their PATH. These commands require a managed installation and reject a source checkout.

## Test and build

Pester 4.10.1 is used by release CI. Install the test dependency separately; it is not shipped with the application:

```powershell
Install-Module Pester -RequiredVersion 4.10.1 -Scope CurrentUser -Force
Import-Module Pester -RequiredVersion 4.10.1
Invoke-Pester ./tests
./scripts/build-release.ps1
```

The build produces `dist/Tqsim-v1.0.3.zip` and `.zip.sha256`, including the CLI, module, deployment scripts, help, version metadata, README and license. Existing ZIPs are rejected to avoid accidental replacement. Automated tests use small real binary files and local fixtures. See IMPLEMENTATION.md for actual test results and outstanding deployment/integration coverage. Pester 3 is incompatible with modern PowerShell and is not supported.

## Publish to GitHub

No publication has been performed by this project generator. Install Git and GitHub CLI, replace USERNAME as above, then run these commands from the repository root:

```powershell
git init -b main
git add .
git commit -m 'Release Tqsim 1.0.3'
gh auth login
gh repo create USERNAME/tqsim --public --source . --remote origin --description 'Fast and reliable PowerShell CLI for splitting, merging, and verifying massive files.'
gh repo edit USERNAME/tqsim --add-topic powershell,file-splitter,file-merger,large-files,sha256,cli,backup,windows
git push -u origin main
./scripts/build-release.ps1
git tag v1.0.3
git push origin v1.0.3
```

The tag workflow validates syntax/version, runs mandatory tests, builds and publishes assets. Alternatively publish manually **instead of pushing the release tag workflow**:

```powershell
gh release create v1.0.3 ./dist/Tqsim-v1.0.3.zip ./dist/Tqsim-v1.0.3.zip.sha256 --target main --title 'Tqsim v1.0.3' --notes-file CHANGELOG.md
gh release view v1.0.3 --repo USERNAME/tqsim
Invoke-WebRequest https://raw.githubusercontent.com/USERNAME/tqsim/main/install.ps1 -Method Head
```

Do not run both release publication methods for the same tag. Confirm both assets exist before testing one-command installation. For a real deployment smoke test, use a disposable Windows user account, install, open a fresh terminal, run `tqsim version`, round trip a Unicode filename with spaces, repeat installation, update, uninstall, and confirm user files remain.

## Troubleshooting

Missing `pwsh`: install PowerShell 7 and reopen the terminal. Missing `tqsim`: refresh the terminal and check the user PATH. Multiple manifests: select `-Manifest`. Corrupt/missing parts: recover the original parts; do not edit hashes to silence failures. Insufficient space: choose a larger destination; merging temporarily needs the full original size. Locked/read-only files: close other applications or choose a writable directory. Failed install: inspect the error, check GitHub connectivity/rate limits and both release assets. Unknown old directories are preserved to protect user data.

## License

[MIT](LICENSE).
