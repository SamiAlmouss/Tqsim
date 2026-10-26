# Tqsim

[English](README.md) | [العربية](README.ar.md)

**Secure file splitter and merger for Windows · Documentation release 1.0.7 · MIT**

Tqsim splits large binary files into upload-sized parts and reconstructs the original bytes from those parts and their manifest. Use it to transfer backups, work around cloud upload limits, verify downloaded archives, or encrypt parts before storing them elsewhere. The original source is not needed for restoration.

Tqsim keeps its CyberHorror terminal identity: three randomly selected ASCII logos, independent bright logo/status colors, centered branding, and a two-row progress display with bytes, speed and ETA. `-NoLogo`, `-NoColor`, `NO_COLOR` and `-Quiet` let it fit terminals and scripts.

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Command reference](#command-reference)
- [Parameter defaults](#parameter-defaults)
- [Encryption guide](#encryption-guide)
- [Delete source guide](#delete-source-guide)
- [Verification guide](#verification-guide)
- [File structures](#file-structures)
- [Performance](#performance)
- [Troubleshooting](#troubleshooting)
- [Updating and uninstalling](#updating-and-uninstalling)
- [Security notes](#security-notes)
- [FAQ](#faq)
- [Development and release](#development-and-release)
- [License and contributing](#license-and-contributing)

## Features

- Streaming binary splitting and lossless merging with Int64 sizes/offsets and bounded payload buffers, including files larger than 4GB.
- SHA-256 for every part and the original stream; optional independent output read-back enabled by default.
- Optional AES-256-GCM encrypted archives; merge/verify automatically detect them and request a password.
- Explicit source deletion after required completion/integrity checks; safe collision handling and partial-cleanup reporting.
- Offline split/merge/verify after installation; no downloaded cryptographic dependencies.
- PowerShell 7+ application, Windows PowerShell 5.1 installer handoff, managed update/uninstall and backward compatibility with older unencrypted archives.

## Requirements

Windows and PowerShell **7 or newer** for the application. Install PowerShell if needed:

```powershell
winget install --id Microsoft.PowerShell --source winget
```

Open a new `pwsh` terminal. Windows PowerShell 5.1 can launch the installer and hand off to an available PowerShell 7; it cannot run the file-processing application. Local Windows/NTFS is the tested target. Protected decrypted temporary files and source-deletion safeguards use Windows ACL/file-identity APIs. Linux/macOS, network-storage crash guarantees and all older PowerShell 7 builds have not been certified. v1.0.6 was tested on 7.6.5 and 7.6.9; see [measured validation](docs/VALIDATION-v1.0.6.md). Destination paths containing junctions/symlinks are rejected. Ensure enough free space for the output and keep a separate backup.

## Installation

Official repository: [SamiAlmouss/Tqsim](https://github.com/SamiAlmouss/Tqsim). Downloads: [GitHub Releases](https://github.com/SamiAlmouss/Tqsim/releases).

```powershell
irm https://raw.githubusercontent.com/SamiAlmouss/Tqsim/main/install.ps1 | iex
```

This executes internet-hosted code and requires trust in the publisher. A safer inspect-before-execution method is:

```powershell
Invoke-WebRequest https://raw.githubusercontent.com/SamiAlmouss/Tqsim/main/install.ps1 -OutFile install.ps1
Get-Content ./install.ps1
# Read the file before running this next line:
pwsh -NoProfile -File ./install.ps1 -Repository SamiAlmouss/Tqsim
```

The installer downloads the latest stable release and checksum, validates asset identity/length, SHA-256 and ZIP paths, stages an immutable version and switches the ownership marker with rollback on failure. Checksums detect mismatches but do not independently establish publisher authenticity. Current-user default: `%LOCALAPPDATA%\Programs\Tqsim`; its `bin` directory is added to the user PATH without profile edits or administrator access.

In PowerShell 7 it continues normally. In Windows PowerShell 5.1 it discovers/probes `pwsh.exe` (including Store/per-user installs) and relaunches the already-loaded installer in a separate process without relying on PSScriptRoot/PSCommandPath. It prevents recursion, preserves failure status and never closes the parent `irm | iex` window. It does not install PowerShell or bypass execution policy. Open a fresh terminal after installation, particularly after 5.1 handoff, then run `tqsim version -NoLogo`. See [installer details](docs/INSTALLER-BOOTSTRAP.md).

## Quick start

These are example paths: substitute your own files. Start with disposable data.

```powershell
tqsim split -File "D:\backup.iso" -Size "1GB"
tqsim verify -PartsPath "D:\Output"
tqsim merg -PartsPath "D:\Output"
```

1. Split creates `D:\Output\backup.iso.part0001`, subsequent parts and `backup.iso.tqsim.json`. It keeps the original, uses no encryption and reads back the finished archive once by default.
2. Verify reads the manifest and all parts, checking lengths and SHA-256 without reconstructing or deleting data.
3. Merge restores `D:\Output\backup.iso` **directly in the parts directory**. It creates no nested Output directory. Existing restored files require explicit `-Overwrite`; source parts remain by default.

Keep all parts and the original manifest together when uploading/downloading. You can restore on another computer without the original source file. Multiple manifests in a directory require `-Manifest` selection.

## Command reference

Every command supports `-NoLogo`, `-NoColor`, `-Quiet`, `-Diagnostics` (all off by default). [Complete command help](docs/COMMANDS.md) reproduces every built-in page, with full syntax/defaults/examples. [Unified parameter reference](docs/PARAMETERS.md) covers accepted values, applicability, defaults, warnings and all aliases.

### split

```powershell
tqsim split -File <path> -Size <size> [-Output <directory>] [-ds <true|false>] [-verify <true|false>] [-encrypt <true|false>] [-BufferSize <bytes>]
```

| Parameters | Default / behavior |
| --- | --- |
| `-File`, `-Size` | Required; source file and maximum physical part size |
| `-Output` | Output beside source |
| `-ds`, `-verify`, `-encrypt` | false, true, false |
| `-BufferSize` | 4194304 bytes; integer 4096..67108864 |

Sizes accept positive integer bytes or B, KB/KiB, MB/MiB, GB/GiB, TB/TiB; suffixes are binary, case insensitive. `1GB = 1GiB = 1,073,741,824 bytes`; for decimal one gigabyte use `1000000000`. No fractions/spaces/negative sizes. Part sizes must fit positive Int64; encrypted minimum is 29 bytes. Part names use the source filename and `.part0001`, `.part0002`, etc. No silent overwrite. Empty source produces a zero-part manifest.

```powershell
tqsim split -File "D:\backup.iso" -Size "2GB"
tqsim split -File "D:\backup.iso" -Size "1GB" -Output "E:\MyParts"
tqsim split -File "D:\backup.iso" -Size "1GB" -verify "false"
tqsim split -File "D:\backup.iso" -Size "1GB" -ds "true"
tqsim split -File "D:\backup.iso" -Size "1GB" -encrypt "true"
tqsim split -File "D:\backup.iso" -Size "1GB" -encrypt "true" -ds "true"
```

The fast configuration `-verify false` skips independent output read-back and has less assurance. Mandatory streaming checks remain. Encryption asks for a hidden password and confirmation. Before combining encryption and deletion, keep the password safely and prove you can restore disposable data; losing it makes recovery impossible. Failure/cancellation before cleanup keeps the original, but partial outputs can remain: inspect and use a fresh destination before retrying.

### merg

```powershell
tqsim merg [-PartsPath <directory>] [-Manifest <path>] [-Output <directory>] [-Overwrite] [-ds <true|false>] [-verify <true|false>] [-BufferSize <bytes>]
```

| Parameters | Default / behavior |
| --- | --- |
| `-PartsPath` | Current working directory |
| `-Manifest` | Discover exactly one .tqsim.json; explicit path overrides discovery |
| `-Output` | Selected manifest's directory; directly beside parts |
| `-Overwrite` | Off; explicit replacement authorization |
| `-ds`, `-verify` | false, true |
| `-BufferSize` | 4194304 bytes; integer 4096..67108864 |

```powershell
tqsim merg -PartsPath "E:\Parts"
tqsim merg -PartsPath "E:\Parts" -Output "D:\Restored"
tqsim merg -Manifest "E:\Parts\backup.iso.tqsim.json"
tqsim merg -PartsPath "E:\Parts" -ds "true"
tqsim merg -PartsPath "E:\Parts" -verify "false"
tqsim merg -PartsPath "E:\Parts" -ds "true" -verify "false"
tqsim merg -PartsPath "E:\EncryptedParts"
```

An explicit manifest's directory determines the parts even if PartsPath is also supplied. Relative manifest paths are relative to the current working directory. Encrypted archives are detected automatically; enter their password once. No merge `-encrypt` or password parameter exists. Wrong password/mandatory integrity failure prevents publication and source deletion. Optional independent read-back happens after publication and before source deletion; if it fails, published output can remain and sources are kept. Fast destructive mode reduces assurance and warns.

### merge

`merge` is an identical alias for `merg`: same syntax, parameters, defaults and safeguards. `tqsim merge -PartsPath "E:\Parts"` restores beside the manifest, just like `merg`. See the table above; neither spelling is deprecated.

```powershell
tqsim merge -PartsPath "E:\Parts"
```

### verify

```powershell
tqsim verify [-PartsPath <directory>] [-Manifest <path>] [-BufferSize <bytes>]
```

| Parameters | Default / behavior |
| --- | --- |
| `-PartsPath`, `-Manifest` | Current directory, exactly one discovered manifest; explicit manifest overrides |
| `-BufferSize` | 4194304 bytes; integer 4096..67108864 |

`tqsim verify -PartsPath "E:\Parts"` reads every required part and checks schema/order, exact lengths, individual SHA-256 and original whole SHA-256. Encrypted archives request a password, authenticate metadata/every GCM record and check plaintext integrity without writing plaintext output. Old plain archives never request a password. Missing/corrupt parts fail nonzero. No reconstruction/deletion or source/manifest modification occurs. **Standalone verify differs from the split/merge `-verify` option**, and accepts none of `-verify`, `-ds`, `-encrypt`, `-Output`, `-Overwrite`.

```powershell
tqsim verify -PartsPath "E:\Parts"
```

### info

```powershell
tqsim info [-PartsPath <directory>] [-Manifest <path>]
tqsim info -PartsPath "E:\Parts"
tqsim info -Manifest "E:\Parts\backup.iso.tqsim.json" -NoLogo
```

| Parameters | Default / behavior |
| --- | --- |
| `-PartsPath`, `-Manifest` | Current directory, exactly one discovered manifest; explicit manifest overrides |

Shows original filename/size, human size, declared maximum part size, part count, original SHA-256, creation UTC, application version and manifest version. It does not list individual part sizes or an explicit encryption-status field. Schema 2 identifies encrypted metadata. Info validates metadata structure but does not hash parts, authenticate the encrypted manifest HMAC or request a password; treat displayed metadata as untrusted until verify/merge succeeds.

### update

```powershell
tqsim update
```

| Parameters | Default / behavior |
| --- | --- |
| Globals only | No command-specific options; requires managed installation |

Checks the latest stable GitHub release and applies it if newer; otherwise reports current version. It has no check-only switch or confirmation prompt. Checksums/staging/rollback remain active. Network required; archives are untouched. A source checkout cannot self-update. `tqsim version -NoLogo` checks the selected version, not whether an update is available.

### uninstall

```powershell
tqsim uninstall
```

| Parameters | Default / behavior |
| --- | --- |
| Globals only | No command-specific options or confirmation prompt; requires managed installation |

Removes known owned application files/launcher/marker and its exact user PATH entry. Arbitrary user data, directories and private recovery records remain. Other terminals must restart to refresh PATH. This command does not uninstall a source checkout or clean archive data.

### version

```powershell
tqsim version -NoLogo
tqsim --version -NoLogo
```

| Parameters / aliases | Default / behavior |
| --- | --- |
| Globals only | Prints authoritative version.json; Quiet keeps requested output |
| `version`, `-version`, `--version`, `-v`, `-V` | Case insensitive; version flags are global commands, not operation modifiers |

### help

```powershell
tqsim
tqsim help
tqsim --help
tqsim -h
tqsim help split
tqsim split --help
tqsim merg -h
```

| Parameters / aliases | Default / behavior |
| --- | --- |
| Optional command topic | Main help; topics include every command |
| `help`, `-help`, `--help`, `-h`, `--h`, `-?`, `/?`, `/help` | Main help, `help <command>`, `<command> help` or flag beside command |
| Globals | NoLogo hides branding; NoColor disables colors; Quiet keeps help |

Help bypasses mandatory operation arguments/value validation, but not malformed syntax, unknown topics/options or duplicate options. It never starts processing, reads manifests, requests passwords, changes permissions, creates recovery records or invokes deployment. Named parameters use one dash; `--File` is unsupported. Read [parameter reference](docs/PARAMETERS.md) for colon syntax and switch values.

## Parameter defaults

| Parameter | Commands | Default |
| --- | --- | --- |
| `-ds` | split, merg/merge | false |
| `-verify` | split, merg/merge | true |
| `-encrypt` | split only | false |

Optional parameters need not be written when their defaults are desired. Values `true`/`false` can be quoted or unquoted and are case insensitive. Empty/missing/yes/no/1/0/other values are usage errors. The four globals and Overwrite are switches, default off; do not confuse `-Quiet:false` with `-ds false`. Every parameter's accepted values and examples appear in the [unified reference](docs/PARAMETERS.md).

## Encryption guide

```powershell
tqsim split -File "D:\backup.iso" -Size "1GB" -Output "E:\EncryptedParts" -encrypt "true"
tqsim verify -PartsPath "E:\EncryptedParts"
tqsim merg -PartsPath "E:\EncryptedParts"
```

Split asks twice for a hidden 12–1,024-character password; verify/merge automatically ask once. Use an interactive terminal (no redirected input/output). No password is accepted as a CLI option. Store a strong unique passphrase safely: Tqsim has no recovery service and cannot recover a lost password.

AES-256-GCM uses bounded records (up to 4 MiB), unique 12-byte per-key nonces and 16-byte tags. PBKDF2-HMAC-SHA256 uses 600,000 iterations and a fresh 32-byte random salt; domain separation derives distinct AES and manifest-HMAC keys. Schema 2 authenticates semantic metadata and record ordering. Preserve the manifest: it contains indispensable salt/layout/authentication data, but no plaintext password/key. Metadata filenames/sizes/hashes remain visible. Each record adds 28 bytes; physical parts never exceed Size. Empty files have an authenticated zero-part manifest.

Wrong passwords, modified metadata/ciphertext/tags and missing parts fail restoration without source deletion or publication of partial plaintext. Temporary plaintext is created with an owner-only protected DACL and removed on failure; removal is not secure erasure. **Authentication stays mandatory even with `-verify false`**; optional read-back is a separate storage assurance. Original schema 1 and raw unencrypted parts remain readable without secrets. This container has **not received an external security audit**. Read the [versioned format specification and limits](docs/ENCRYPTED-FORMAT-v1.md).

## Delete source guide

`-ds false` (default) retains sources. `-ds true` deletes the original input after split, or the selected parts followed by their manifest after merge, only after completed writes/publication and required integrity/read-back checks. Deletion is irreversible and is not secure erasure. Keep a separate backup and prove recoverability before deleting important data. `-verify false` skips independent read-back and reduces assurance even though mandatory hashes/authentication remain.

Cleanup uses exact identities/lengths/timestamps and locks; ambiguous/shared/link targets fail closed. Multi-file cleanup is not atomic. A partial failure reports deleted and remaining/unconfirmed counts, preserves completed output and keeps a private recovery record under `%LOCALAPPDATA%\Tqsim\Recovery`. Fully successful cleanup removes its record; a zero-deletion failure leaves no pointless journal; unrelated records are untouched. Crash records require manual reconciliation, never automatic execution/retry.

Access denied may involve ACLs, read-only attributes, locks or other Windows restrictions. Only ds=true can attempt a current-SID **Delete-only grant on the exact source file**, and only when already authorized to change its DACL. No parent/drive ACL change, FullControl on sources, ownership takeover or UAC bypass occurs. If permission remains denied, keep completed output and resolve only the remaining files with an authorized account; administrator authorization may sometimes be necessary. There is no automatic elevation helper. Do not repeat a completed huge operation merely to retry deletion.

## Verification guide

| Mechanism | What it establishes |
| --- | --- |
| Mandatory streaming checks | Exact lengths, per-part/whole SHA-256 while processing; safe publication |
| Encrypted authentication | Manifest HMAC and every GCM record; always required, even in fast mode |
| Split/merge `-verify true` | One additional independent output read-back (default) |
| Split/merge `-verify false` | Skips that extra read-back only; less storage assurance |
| Standalone `tqsim verify` | Full archive check without reconstruction/deletion; encrypted password required |

A successful check establishes consistency at the time read. It is not an independent backup, trusted publisher signature, protection against later damage or guarantee against hardware/power failure. Legacy SHA-256 manifests are unkeyed: keep a trusted manifest/independently held expected hash.

## File structures

Basic split, with original retained:

```text
D:\
  backup.iso
  Output\
    backup.iso.part0001
    backup.iso.part0002
    backup.iso.tqsim.json
```

Basic merge adds `backup.iso` directly to that Output folder and keeps the three archive files. `merg -ds true` leaves only the restored file there after complete cleanup:

```text
D:\Output\
  backup.iso
```

Encrypted split uses the same naming with a schema-2 manifest and ciphertext parts:

```text
E:\EncryptedParts\
  backup.iso.part0001
  backup.iso.part0002
  backup.iso.tqsim.json
```

Encrypted merge adds plaintext `E:\EncryptedParts\backup.iso`; there is no extra encrypted filename suffix or nested Output directory. Parts/manifest remain unless ds=true; successful ds=true leaves only plaintext. An explicit `-Output "D:\Restored"` instead puts plaintext in that directory. Protect its access permissions.

## Performance

v1.0.5 removed redundant full-file reads: split reads source once; merge validates parts in its writing pass; verify=true adds exactly one output pass. Source deletion adds metadata/identity checks, not another payload scan. Data buffers remain bounded; manifest memory and cleanup handles scale with part count. Encryption adds KDF startup and per-record framing/authentication work.

Historical v1.0.6 measurements on local Windows storage, PowerShell 7, real random **5 GiB + 17 bytes**: encrypted 1GB parts with read-back split/merge took **35.113/31.735 seconds** (145.82/161.34 MiB/s). Encrypted fast-mode 2GB parts took **22.158/20.734 seconds**. Single runs used uncontrolled cache/storage; hardware was not standardized and these are not guaranteed speeds or an isolated cipher benchmark. Actual 2GB/4GB parts were exercised. See [full v1.0.6 measurements](docs/VALIDATION-v1.0.6.md) and [v1.0.5 optimization report](docs/PERFORMANCE-v1.0.5.md). These are historical engine results, not newly executed v1.0.7 multi-gigabyte benchmarks. No physical 200GB/1TB test is claimed.

## Troubleshooting

See [symptoms, causes and remedies](docs/TROUBLESHOOTING.md) for access denied, missing/corrupt parts, SHA-256 mismatch, passwords/authentication, existing destination, free space, unsupported formats, runtime/update failures, incomplete cleanup, interrupted operations and missing manifests. Keep original parts/manifests; never edit hashes to hide failures. `-Diagnostics` exposes technical details for debugging. Exit codes: 0 success, 1 operational/deployment/cleanup failure, 2 usage, 3 metadata/integrity/authentication failure; missing-part classification depends on pipeline. Treat all nonzero codes as failure.

## Updating and uninstalling

```powershell
tqsim version -NoLogo
tqsim update
tqsim version -NoLogo
# Only when you intend to remove the managed application:
tqsim uninstall
```

Update checks and applies a newer stable release; no check-only flag exists. Uninstall has no confirmation prompt, removes known app files/PATH only, and preserves arbitrary user data/directories/recovery records. Both require an installer-managed ownership marker and do not operate on a source checkout. Open a fresh terminal after PATH changes. Neither operation should be used as archive cleanup.

## Security notes

Protect passwords and source backups; test encrypted recovery before deleting originals. SHA-256 is not a backup or legacy manifest authentication. Encrypted authentication cannot guarantee future storage durability. Metadata stays visible. Managed/runtime/OS copies and filesystem snapshots may retain secrets/plaintext despite best-effort buffer clearing/temp removal. Private recovery records contain paths/hashes, not secrets; review before sharing. Windows permissions/UAC remain in force. Hardware failure, later corruption and interrupted multi-file deletion remain possible. No external cryptographic certification is claimed.

## FAQ

| Question | Answer |
| --- | --- |
| Can I merge older parts? | Yes: unencrypted schema 1 is preserved; authentic 1.0.2–1.0.5 fixtures pass. Keep their original manifest. |
| Can I upload to cloud storage? | Yes; upload every part plus the manifest unchanged. Tqsim does not upload for you. |
| Is the original source required to merge? | No, only complete valid parts/manifest and the password for encrypted data. |
| Must I specify default parameters? | No. ds=false, verify=true and encrypt=false apply when omitted. |
| Can I merge encrypted archives? | Yes; encryption is detected and a password requested automatically. |
| What if I forget the password? | Encrypted data cannot be recovered by Tqsim. |
| Can sources be deleted automatically? | Yes, explicitly with ds=true after required success/integrity conditions. |
| Why can deletion fail? | Permissions, read-only state, locks, changed identity or unsafe/shared targets; preserve output and resolve the exact cause. |
| Are files larger than 4GB supported? | Yes, Int64 streaming; real 5 GiB+17 round trips and 4GB parts were tested in v1.0.6. |
| Where is merged output saved? | Directly beside the selected manifest/parts, unless Output is supplied. |
| Is SHA-256 automatic? | Yes, mandatory streaming hashes; independent read-back also defaults on for split/merge. |
| Does info prove integrity? | No, use verify. |

## Development and release

Source checkout: `pwsh -NoProfile -File ./tqsim.ps1 help`. Run the full suite with Pester 4.10.1 or a compatible Pester version; the system Pester 3 is unsuitable for modern PowerShell:

```powershell
Invoke-Pester ./tests
pwsh -NoProfile -File ./scripts/build-release.ps1
```

The build produces `dist/Tqsim-v1.0.7.zip` and `.zip.sha256`, refuses an existing ZIP, and excludes tests/profilers/test data. [Documentation coverage and audit](docs/HELP-COVERAGE.md) tracks command/parameter coverage; [release validation](docs/VALIDATION-v1.0.7.md) records actual results. The v1.0.7 scope is help/docs only: the binary/SHA/encryption/cleanup engine remains byte-identical to v1.0.6.

Maintainer publication is manual and must be authorized. Review/stage only intended files, commit to the release branch, then after approval (assuming main is the intended branch and origin is SamiAlmouss/Tqsim):

```powershell
git status --short
git diff
# Review, stage intended files and commit before tagging:
git tag v1.0.7
# Upload the reviewed commit/tag without changing main/install.ps1 yet:
git push origin v1.0.7
gh release create v1.0.7 ./dist/Tqsim-v1.0.7.zip ./dist/Tqsim-v1.0.7.zip.sha256 --repo SamiAlmouss/Tqsim --title 'Tqsim v1.0.7' --notes-file CHANGELOG.md
# Only after both assets are live, deploy the matching main installer:
git push origin main
```

After authorized deployment, test the exact public installer above in disposable Windows PowerShell 5.1 and PowerShell 7 sessions, then confirm `tqsim version -NoLogo` reports 1.0.7. This live-URL test is pending publication. Existing managed users can then run `tqsim update`. Nothing is pushed, tagged, published or installed automatically by this task.

## License and contributing

[MIT License](LICENSE). For contributions, review the parser before changing examples, keep both languages/help synchronized, add relevant regression coverage and run the full suite. Report reproducible issues at [GitHub Issues](https://github.com/SamiAlmouss/Tqsim/issues) with version/runtime, a disposable reproduction and diagnostics if helpful; do not share passwords, keys or private backup contents. This repository does not currently supply a separate contribution policy.