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

Windows and PowerShell 7 or newer. If needed, run `winget install --id Microsoft.PowerShell --source winget`, then open `pwsh`. File-processing commands require PowerShell 7+. The installer itself also accepts Windows PowerShell 5.1 and hands off automatically to an installed PowerShell 7 runtime. Local NTFS storage is recommended; network share capacity reporting and atomic replacement depend on the filesystem. Destinations containing directory junctions/symlinks are rejected.

## Install

The public installer uses `SamiAlmouss/Tqsim` and its versioned GitHub Release assets. Local installer fixes become available at the URL below only after the maintainer deploys install.ps1 to main; this change has not been deployed automatically. Forks must explicitly configure their own repository.

```powershell
irm https://raw.githubusercontent.com/SamiAlmouss/Tqsim/main/install.ps1 | iex
```

Run the same command from Windows PowerShell 5.1 or PowerShell 7+. In 7+, installation continues in the current process. In 5.1, the installer discovers and probes pwsh.exe (including Windows Store/per-user locations), then runs the already-loaded installer functions in a separate hidden process. It does not depend on `$PSScriptRoot` or `$PSCommandPath`, re-download a moving script, change execution policy, or install PowerShell itself. A child-runtime guard prevents relaunch loops. If no compatible runtime is found, it prints `winget install --id Microsoft.PowerShell --source winget`.

Failures throw a readable error and set `$LASTEXITCODE`; the installer never exits the parent shell used by `irm | iex`. A 5.1 handoff cannot update that parent process PATH: open a fresh terminal after success. [Bootstrap test results and post-deployment verification](docs/INSTALLER-BOOTSTRAP.md) describe the exact checks and the live-URL test still required after deployment.

This runs remote code. A safer alternative lets you download and inspect the installer first:

```powershell
Invoke-WebRequest https://raw.githubusercontent.com/SamiAlmouss/Tqsim/main/install.ps1 -OutFile install.ps1
Get-Content ./install.ps1
pwsh -NoProfile -File ./install.ps1 -Repository SamiAlmouss/Tqsim
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
pwsh -NoProfile -File ./tqsim.ps1 split -File 'E:\Win11_Arabic_x64v1.iso' -Size 1GB -Output 'E:\Tqsim-parts-v1.0.5' -Diagnostics
```

That example is for a user-initiated retry; automated tests use disposable binary data and never the original ISO.

Sizes are positive integer bytes, or binary suffixes B, KB/KiB, MB/MiB, GB/GiB, TB/TiB. Thus 1GB = 1,073,741,824 bytes. Fractional, negative and overflowing sizes are rejected.

Split defaults to `Output` alongside the source. Parts are `disk.iso.part0001`, etc., with numbering width expanded as needed. Empty input produces zero parts and a manifest containing the SHA-256 of the empty stream. Merge and verify default to the current directory. Merge defaults to its `Output` subdirectory. When multiple manifests exist, provide `-Manifest` explicitly. The manifest's directory defines the location of its relative parts, including when `-PartsPath` is also supplied.

Existing split outputs are never overwritten. Merge requires explicit `-Overwrite` to replace a restored file and uses atomic filesystem replacement where supported. Inputs are retained unless -ds true is explicitly supplied. Merge checks each part and the whole-file hash while streaming into an unpublished temporary output; it does not pre-read every part. Failed temporary output is removed. Ctrl+C unwinds finally blocks; forced termination or power loss can leave `.tqsim-*.tmp` or unreferenced parts. Review these manually before removal. No resumable operations are implemented.

Interactive progress updates at most four times per second. The progress bar occupies the first line; the second line shows state, current/completed parts, exact bytes, cumulative average speed, elapsed time and ETA. Text is cropped to terminal width to avoid wrapping. Redirected logs omit progress and retain completion/error messages. Quiet suppresses informational output, but failures still go to stderr.

## Verification and Delete Source (1.0.5)

`-ds` is supported only by split and merge/merg. Omitted or `-ds false` preserves all sources. Only `true` and `false` are accepted, case insensitive, quoted or unquoted. Missing, empty, yes/no, 1/0 and other values return usage code 2. Help never deletes anything. Explicit `-ds true` authorizes deletion without another prompt.

`-verify` uses the same strict string parsing and **defaults to true**. Omitted options automatically use their documented defaults; no ds or verify argument is required. Required File/Size values remain required for split. `-verify false` skips only the additional independent read-back, retaining streaming SHA-256, length checks, flush/close, manifest/path validation and safe publication.

| ds | verify | Behavior |
| --- | --- | --- |
| false (default) | true (default) | Keep sources; read back the published output once |
| false | false | Keep sources; streaming integrity only |
| true | true | Delete only after independent read-back succeeds |
| true | false | Explicit advanced fast mode: delete after streaming integrity and safe publication, without output read-back |

Split reads its source once and writes parts once. Verification adds one ordered parts read with individual and whole-file SHA-256. Merge reads parts once, checks their individual/whole hashes during writing, and optionally adds one final-output read. Deletion does not add payload scans. Small manifest reads and cleanup-journal writes remain mandatory metadata I/O. Completion omits irrelevant default Boolean statuses; when verification is disabled, it reports `Independent verification skipped.`

```powershell
# Keep the original (default), or explicitly retain it:
tqsim split -File "D:\Backup\disk.iso" -Size 2GB
tqsim split -File "D:\Backup\disk.iso" -Size 2GB -ds false
# Independently verify the published split set, then delete the original:
tqsim split -File "D:\Backup\disk.iso" -Size 2GB -ds true
# Keep parts and manifest (default), or explicitly retain them:
tqsim merg -PartsPath "D:\Backup\Output"
tqsim merg -PartsPath "D:\Backup\Output" -ds false
# Independently verify the restored output, then delete its parts/manifest:
tqsim merg -PartsPath "D:\Backup\Output" -ds true
# Advanced fast mode; warning is displayed even with Quiet:
tqsim split -File "D:\Backup\disk.iso" -Size 2GB -ds true -verify false
tqsim merg -PartsPath "D:\Backup\Output" -ds true -verify false
```

**Delete Source is irreversible.** With `-verify false`, successful writes and flushes provide less assurance than independently rereading stored bytes and do not guarantee durability for all hardware or power-failure conditions. The app warns: `WARNING: Independent read-back verification is disabled. Source deletion is irreversible.` It never secretly re-enables verification. SHA-256 does not replace an independent backup. Keep enough space for the full destination. Deletion holds file handles proportional to part count; failure to acquire resources preserves sources before cleanup.

Split hashes the original and each part in its sole source-reading pass; with verification enabled it independently rereads the generated parts once. Merge validates source hashes in its writing pass and independently rereads the published destination only if enabled. Source targets and protected output are locked against writes/renames throughout processing. Windows volume/file IDs, lengths and creation/write timestamps are captured and revalidated without rereading payload. The identity of a created temporary file must still match its published destination. Each deletion target stays locked until its own immediate close/revalidation/delete boundary. File/ancestor reparse points, hard links, collisions and unusable identities are rejected; shared parts or invalid neighbouring manifests refuse deletion.

Cleanup writes `.tqsim-cleanup-<GUID>.json` beside the protected destination. The journal records authorization, exact paths, identities, streaming hashes, whether independent read-back occurred, and per-file status. It is flushed before deletion and retained afterward. Multiple-file deletion is **not atomic**. Failure returns nonzero with confirmed deleted and remaining/unconfirmed counts; the completed output remains and the manifest is kept until every part was removed. A crash/power loss can leave an uncertain `deleting` entry. Inspect the journal and independently check the output manually. Journals never authorize automatic retries or execute recorded paths.

Use deletion mode in directories you control. Closing read handles before exact-path deletion leaves a small final path-replacement race; ancestor checks and restrictive sharing reduce it but cannot provide a filesystem transaction or defeat a privileged concurrent attacker. Ownership scans cover manifests in the selected directory, not unknown references elsewhere. Network filesystem semantics and power-loss durability are not guaranteed. Without `-ds true`, processing retains the existing retention and manifest behavior.

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

For each split or merge invocation, the logo color is sampled once from eight bright accents; the information color is sampled independently from the other seven. Colors and logo remain fixed through progress, verification, completion and resize. Palette: Neon Green `#63EDC6`, Electric Cyan `#53DCEB`, Cyber Blue `#50A8FF`, Neon Purple `#B98CFF`, Hot Magenta `#F36BD2`, Phantom Red `#FF6676`, Amber `#F2B95B`, Ice Blue `#8DE5FF`. Actual warning/error styling remains unchanged. The old yellow information line came from native `Write-Progress`; the two-line renderer now owns only routine progress styling.

| Logo | Literal design | Lines | Theme |
| --- | --- | ---: | --- |
| 1 | Original compact TQSIM design shown above | 5 | Random palette accent |
| 2 | Wide outlined design beginning `_________ _______` | 8 | Random palette accent |
| 3 | Block design beginning `_____._._______`, ending with the colon line | 7 | Random palette accent |

Spacing, trailing spaces, punctuation and backslashes are preserved. Layout centers the entire logo using its widest line and separately centers the tagline, version and secure-operation label. Tall terminals get vertical padding based on the selected logo height and the help/body/dashboard space. The terminal background is never changed.

When a design is wider than the terminal, branding uses a compact `TQSIM` label. This is a display fallback, not a fourth registered logo. During active operations, dimension changes reflow the **same** selection and restore its full literal when it fits. Resize reflow prints a fresh block only on dimension changes, without clearing the screen or emitting cursor-position codes; static completed help screens do not run a background resize listener. Progress uses two separate lines: a bar followed by a status line.

`-NoLogo` suppresses branding and logo selection; `-Quiet` also suppresses routine progress. `-NoColor` and `NO_COLOR` disable all Tqsim decorative styling, including progress. Supported virtual terminals with `WT_SESSION` or `COLORTERM=truecolor/24bit` get the selected palette RGB values; other interactive hosts use ConsoleColor equivalents. Redirected output uses plain text without ANSI codes, centering padding, animations, or redraws. No animation is implemented, so no `-NoAnimation` flag is advertised. Terminal APIs have a safe 80×25 fallback.

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

Version 1.0.2 fixes an interactive-progress failure: `[double].001` was parsed as property access, producing a StrictMode error for property `1`. The corrected numeric literal is `[double]0.001`. Progress arithmetic now has direct regression coverage even when tests run with redirected output. The Int64 streaming fix from 1.0.1 remains in place. Existing manifests remain compatible; the manifest schema and existing CLI syntax are unchanged. Version 1.0.3 adds the help compatibility and randomized branding described above while preserving that fix. Once the v1.0.5 release has been published, update the installed global command and check its version:

```powershell
tqsim update
tqsim version -NoLogo
# Expected after updating: 1.0.5
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

The build produces `dist/Tqsim-v1.0.5.zip` and `.zip.sha256`, including the CLI, module, deployment scripts, help, version metadata, README and license. Existing ZIPs are rejected to avoid accidental replacement. Automated tests use small real binary files and local fixtures. See IMPLEMENTATION.md for actual test results and outstanding deployment/integration coverage. Pester 3 is incompatible with modern PowerShell and is not supported.

## Publish to GitHub

No publication or global application update is performed automatically. Review and commit the changes, then use the existing SamiAlmouss/Tqsim repository. Release instructions:

```powershell
# Review, then stage and commit the intended application files and tests.
git status --short
git diff
git add -- tqsim.ps1 src examples install.ps1 uninstall.ps1 scripts tests version.json README.md CHANGELOG.md IMPLEMENTATION.md docs
git commit -m 'Release Tqsim 1.0.5'
git tag v1.0.5
git push origin v1.0.5
```

No release workflow is configured in this checkout. After the tests and local build pass, publish the prepared assets manually:

```powershell
gh release create v1.0.5 ./dist/Tqsim-v1.0.5.zip ./dist/Tqsim-v1.0.5.zip.sha256 --repo SamiAlmouss/Tqsim --target main --title 'Tqsim v1.0.5' --notes-file CHANGELOG.md
gh release view v1.0.5 --repo SamiAlmouss/Tqsim
# After both assets are available, deploy the matching main installer:
git push origin main
```

Publish both v1.0.5 assets before updating main/install.ps1, whose required-file validation includes the new deletion helper. Confirm the release assets and main installer match before testing the exact public command in disposable Windows PowerShell 5.1 and PowerShell 7 sessions:

```powershell
irm https://raw.githubusercontent.com/SamiAlmouss/Tqsim/main/install.ps1 | iex
# Open a fresh terminal after installation, then:
tqsim version -NoLogo
# Expected: 1.0.5
```

After publication, an existing managed installation can use `tqsim update`, then `tqsim version -NoLogo`. The same public installer can repair/update an older launcher. Live URL installation remains a post-deployment check and has not been performed for unpublished v1.0.5. Use disposable data to test retention/deletion; never use valuable backups as smoke tests.

## Troubleshooting

Missing `pwsh`: install PowerShell 7 and reopen the terminal. Missing `tqsim`: refresh the terminal and check the user PATH. Multiple manifests: select `-Manifest`. Corrupt/missing parts: recover the original parts; do not edit hashes to silence failures. Insufficient space: choose a larger destination; merging temporarily needs the full original size. Locked/read-only files: close other applications or choose a writable directory. Failed install: inspect the error, check GitHub connectivity/rate limits and both release assets. Unknown old directories are preserved to protect user data.

## License

[MIT](LICENSE).
