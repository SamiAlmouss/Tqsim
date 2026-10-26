# Complete command help

[English](../README.md) · [العربية](../README.ar.md) · [Every parameter/default/value](PARAMETERS.md)

These pages reproduce built-in help. {{VERSION}} is resolved at runtime from version.json. The four global switches apply to every command and default off; help is non-destructive. Use the parameter reference for full accepted-value tables and warnings.

Contents: [split](#split), [merg](#merg), [merge](#merge), [verify](#verify), [info](#info), [update](#update), [uninstall](#uninstall), [version](#version), [help](#help).

## split

```text
SPLIT
  tqsim split -File <path> -Size <size> [-Output <directory>]
    [-ds <true|false>] [-verify <true|false>] [-encrypt <true|false>]
    [-BufferSize <bytes>] [-NoLogo] [-NoColor] [-Quiet] [-Diagnostics]

OPTIONS
  -File <path>       Required original file; no implicit source.
  -Size <size>       Required maximum physical part size, not buffer size.
  -Output <dir>      Default: Output beside the source file.
  -ds <true|false>
    Default: false. Keep original. true deletes it only after completed
    writes, required integrity checks and read-back when enabled.
  -verify <true|false>
    Default: true. Read finished parts back once; check exact lengths,
    per-part and whole-file SHA-256. false skips this independent pass;
    mandatory streaming hashes/counts and encryption authentication remain.
  -encrypt <true|false>
    Default: false. Split-only. true securely asks for a hidden
    12..1024-character password and confirmation. AES-256-GCM;
    no password/key CLI parameter and no password recovery.
  -BufferSize <bytes> Default: 4194304; integer 4096..67108864.
    Ordinary I/O buffer; encrypted records remain at most 4 MiB.
  -NoLogo            Default: off; hide branding.
  -NoColor           Default: off; disable colors. NO_COLOR also applies.
  -Quiet             Default: off; hide routine output/progress, not errors.
  -Diagnostics       Default: off; add type, line, stack and inner errors.
  Help: -help, --help, -h, --h, -?, /?, /help; also split help.
  Omitted optional parameters use defaults. true/false is case insensitive,
  quoted or unquoted; yes/no/1/0 are usage errors.

SIZES AND FILES
  Positive integer bytes or B, KB/KiB, MB/MiB, GB/GiB, TB/TiB; no fractions,
  spaces or negative values. Maximum: positive Int64 bytes.
  All suffixes are binary: 1GB = 1GiB = 1,073,741,824 bytes.
  Decimal 1 gigabyte = 1,000,000,000 bytes: use -Size 1000000000.
  backup.iso becomes backup.iso.part0001, .part0002, ... and
  backup.iso.tqsim.json. Keep ALL parts and the original manifest together.
  No silent overwrite. Empty input creates a zero-part manifest.
  Unencrypted schema 1 and raw part bytes remain unchanged.
  Encrypted schema 2 adds 28 bytes per bounded record; physical parts
  never exceed Size. Minimum encrypted Size: 29 bytes. Metadata is visible.

FAILURE AND DELETION
  Failure/cancellation before cleanup preserves the original. Partial output
  may remain: inspect it and choose a fresh directory before retrying.
  Deletion is irreversible, not secure erasure and not a backup.
  Protect the password and test recovery BEFORE deleting important data.
  Do not redirect password prompts. Cleanup failure keeps completed parts;
  resolve exact source access with an authorized account, not a repeated split.
  Success removes its cleanup record; partial/interrupted cleanup keeps
  private state in %LOCALAPPDATA%\Tqsim\Recovery. No automatic retry.
  -ds true -verify false has less assurance: no independent read-back.
  Successful writes/flushes do not guarantee durability after power loss.

EXAMPLES
  Basic: defaults keep original, verify output, no encryption:
    tqsim split -File "D:\backup.iso" -Size "1GB"
  2GB maximum parts:
    tqsim split -File "D:\backup.iso" -Size "2GB"
  Custom destination:
    tqsim split -File "D:\backup.iso" -Size "1GB" -Output "E:\MyParts"
  Maximum-speed mode skips independent verification, reducing assurance:
    tqsim split -File "D:\backup.iso" -Size "1GB" -verify "false"
  Delete original after required completion/integrity checks:
    tqsim split -File "D:\backup.iso" -Size "1GB" -ds "true"
  Encrypt: hidden password and confirmation:
    tqsim split -File "D:\backup.iso" -Size "1GB" -encrypt "true"
  Encrypt and delete: protect password and prove recoverability first:
    tqsim split -File "D:\backup.iso" -Size "1GB" -encrypt "true" -ds "true"

GET HELP
  tqsim help split
  tqsim split --help
  tqsim split -h
```

## merg

Identical alias of merge. All syntax, parameters and defaults in the merge page apply. Example: `tqsim merg -PartsPath "E:\Parts"`.

## merge

```text
MERGE / MERG
  tqsim merge [-PartsPath <directory>] [-Manifest <path>]
              [-Output <directory>] [-Overwrite] [-ds <true|false>]
              [-verify <true|false>] [-BufferSize <bytes>]
              [-NoLogo] [-NoColor] [-Quiet] [-Diagnostics]
  tqsim merg is an identical alias for merge.

OPTIONS
  -PartsPath    Parts directory; defaults to the current working directory.
  -Manifest     Explicit .tqsim.json file; required if multiple manifests exist.
                Parts are resolved relative to the selected manifest.
  -Output       Optional destination. Default: directly beside input parts in
                the selected manifest directory. No Output folder is created.
  -Overwrite    Explicit authorization to replace an existing restored file.
  -ds           true or false (case insensitive). Default: false, keep sources.
                true deletes only the selected manifest's ordered input parts
                and its manifest after mandatory streaming checks and independent
                verification when enabled. Manifest is deleted last.
  -verify       true or false (case insensitive). Default: true.
                true independently reads the published output once for SHA-256
                and length; false skips that extra pass, keeping all mandatory
                streaming part/whole SHA-256, lengths and publication checks.
  -BufferSize   I/O buffer bytes, 4096..67108864; default 4194304.
  -NoLogo       Hide branding.
  -Quiet        Suppress routine output and progress; retain errors.
  -Diagnostics  Add development error details.
  -NoColor      Disable Tqsim text colors.

INTEGRITY
  Checks manifest metadata, ordered filenames, lengths and every SHA-256.
  Checks part and whole hashes in the single merge streaming pass.
  Publishes after mandatory streaming integrity/authentication succeeds;
  optional independent read-back occurs after publication, before source deletion.
  Source parts are retained unless -ds true is explicitly supplied.
  Old unencrypted archives never request a password. Encrypted schema 2 is
  automatically detected and prompts securely for the decryption password.
  Do not pass -encrypt to merge: it is split-only. GCM/manifest authentication
  is mandatory even with -verify false. Wrong passwords/corruption preserve
  sources and do not publish partial plaintext.

DELETE SOURCE WARNING
  Delete Source is irreversible. Use true only when reconstructed data has
  been verified and is stored safely. SHA-256 does not replace a backup or
  guarantee future storage durability. Shared/ambiguous parts are not deleted.
  Multiple-file cleanup is not atomic. An interruption can leave some parts
  deleted: the completed output and a private recovery record remain. Errors report
  deleted and remaining/unconfirmed counts and return nonzero. Journals do
  not authorize retries: inspect them and independently check output manually.
  Successful cleanup leaves no cleanup JSON. Exceptional recovery records are
  under %LOCALAPPDATA%\Tqsim\Recovery, never routinely in the parts directory.
  On access denial, only this file's Delete permission may be added if Windows
  permits DACL changes. No drive/parent ACL edits, ownership takeover or UAC
  bypass occurs. If authorization is required, keep output and clean up exact
  sources with an authorized account; do not rerun the completed operation.
  -ds true -verify false skips independent read-back and has less assurance.
  Flush/successful writes do not guarantee storage durability after power loss.

EXAMPLES
  tqsim merg
  tqsim merg -PartsPath "E:\Parts"
  tqsim merge -PartsPath "E:\Parts"
  tqsim merge -PartsPath "E:\Parts" -Output "D:\Restored"
  tqsim merg -Manifest "E:\Parts\backup.iso.tqsim.json"
  tqsim merg -PartsPath "E:\Parts" -ds false
  tqsim merg -PartsPath "E:\Parts" -ds true
  tqsim merg -PartsPath "E:\Parts" -verify false
  tqsim merg -PartsPath "E:\Parts" -ds true -verify false
  tqsim merg -PartsPath "E:\EncryptedParts"
  The last example detects encryption and asks for the password automatically.

DEFAULTS AND FAILURES
  All switches default off. -Manifest defaults to discovery of exactly one
  manifest; -Output defaults to the selected manifest directory. Omitting an
  optional parameter uses its default. true/false is case insensitive and may
  be quoted or unquoted; other values are usage errors. -encrypt is split-only.
  Password/mandatory integrity failure prevents publication and source deletion.
  Existing output is preserved unless -Overwrite explicitly allows replacement.
  Independent read-back failure can leave published output; sources are preserved.
  Help aliases: -help, --help, -h, --h, -?, /?, /help; also merg help.
```

## verify

```text
VERIFY
  tqsim verify [-PartsPath <directory>] [-Manifest <path>] [-BufferSize <bytes>]
    [-NoLogo] [-NoColor] [-Quiet] [-Diagnostics]

OPTIONS
  -PartsPath    Parts directory; default is the current working directory.
  -Manifest     Explicit .tqsim.json; select it when several manifests exist.
  -BufferSize   I/O buffer bytes, 4096..67108864; default 4194304.
  -NoLogo       Hide branding.
  -Quiet        Suppress routine output and progress; retain errors.
  -Diagnostics  Add development error details.
  -NoColor      Disable Tqsim text colors.

INTEGRITY
  Validates manifest schema, ordering, duplicate names and declared metadata.
  Checks missing parts, exact byte lengths, each SHA-256 and the original hash.
  Does not reconstruct a file. Missing or corrupted required parts fail nonzero.
  Encrypted archives securely prompt for their password and authenticate the
  manifest and every GCM record. No plaintext output is created.
  Old unencrypted archives require no password. Success means all required
  checks passed, not future durability or proof of trusted provenance.
  This command reads data only; it never deletes or reconstructs files.
  Standalone verify differs from split/merge -verify true|false, which controls
  an optional additional output read-back during those operations.
  No -verify, -ds, -encrypt, -Output or -Overwrite option is accepted here.
  -Manifest defaults to exactly one discovered manifest; an explicit manifest's
  own directory determines part locations. All switches default off.
  Help: -help, --help, -h, --h, -?, /?, /help; also verify help.

EXAMPLES
  tqsim verify -PartsPath "E:\Parts"
  tqsim verify -Manifest "E:\Parts\backup.iso.tqsim.json" -NoLogo
```

## info

```text
INFO
  tqsim info -Manifest <path>
  tqsim info [-PartsPath <directory>] [-Manifest <path>]
    [-NoLogo] [-NoColor] [-Quiet] [-Diagnostics]

OPTIONS
  -Manifest     Path to the .tqsim.json metadata file.
  -PartsPath    Discover one manifest in this directory; default current directory.
  -NoLogo       Hide branding.
  -Quiet        Suppress routine branding; requested metadata remains visible.
  -Diagnostics  Add development error details.
  -NoColor      Disable Tqsim text colors.

METADATA
  Displays original filename, exact/human size, part size/count, original SHA-256,
  creation timestamp, application version and manifest schema version.
  Metadata inspection is not cryptographic verification of the actual parts.
  Shows declared maximum part size, not a per-part listing. Schema 2 identifies
  encrypted metadata, but info has no explicit encryption-status field and does
  not request a password or authenticate its HMAC. Treat metadata as untrusted
  until verify/merge succeeds. Missing/damaged/ambiguous metadata fails.
  -Manifest defaults to exactly one discovered manifest; an explicit manifest
  takes precedence over PartsPath. All switches default off.
  Help: -help, --help, -h, --h, -?, /?, /help; also info help.

EXAMPLE
  tqsim info -Manifest "E:\Parts\backup.iso.tqsim.json"
  tqsim info -PartsPath "E:\Parts" -NoLogo
```

## update

```text
UPDATE
  tqsim update
    [-NoLogo] [-NoColor] [-Quiet] [-Diagnostics]

  Requires a managed installation. Queries the latest stable GitHub Release,
  checks its ZIP checksum, stages it and switches the selected installation.
  Preserves the prior working version on failure and never changes split data.
  Network access is required for updates; split/merge/verify work offline.
  If latest is not newer, reports this installation is current. No separate
  check-only flag or confirmation prompt exists. Source checkouts cannot
  self-update. No command-specific CLI options; all switches default off.
  Help: -help, --help, -h, --h, -?, /?, /help; also update help.

OPTIONS
  -NoLogo       Hide branding.
  -Quiet        Suppress CLI branding (installer messages may still appear).
  -Diagnostics  Add development error details.
  -NoColor      Disable CLI colors (installer uses its own messages).

HELP SAFETY
  tqsim help update and tqsim update --help perform no network or installation.

EXAMPLES
  tqsim update
  tqsim version -NoLogo
```

## uninstall

```text
UNINSTALL
  tqsim uninstall
    [-NoLogo] [-NoColor] [-Quiet] [-Diagnostics]

  Requires a managed current-user installation. Removes known Tqsim application
  files and its exact PATH entry. Preserves user split files and manifests.
  Restart other terminals to refresh their PATH.
  No confirmation prompt or command-specific option exists. Source checkouts
  cannot self-uninstall. Directories, arbitrary user files and private recovery
  records are preserved. All switches default off.
  Help: -help, --help, -h, --h, -?, /?, /help; also uninstall help.

EXAMPLES
  tqsim uninstall
  tqsim uninstall -NoLogo

OPTIONS
  -NoLogo       Hide branding.
  -Quiet        Suppress CLI branding; the uninstaller may report its result.
  -Diagnostics  Add development error details.
  -NoColor      Disable CLI colors.

HELP SAFETY
  tqsim help uninstall and tqsim uninstall --help never remove files or PATH.
```

## version

```text
VERSION
  tqsim version
    [-NoLogo] [-NoColor] [-Quiet] [-Diagnostics]
  tqsim -version | --version | -v | -V

  Reads the authoritative application version.json metadata.
  -NoLogo hides branding; -Quiet keeps requested version output.
  -NoColor disables colors; -Diagnostics adds development error details.
  All switches default off; no command-specific parameters. Version flags work
  as a global command, not alongside an operation (use tqsim version).
  Help: -help, --help, -h, --h, -?, /?, /help; also version help.

EXAMPLES
  tqsim version -NoLogo
  tqsim --version -NoLogo
```

## help

```text
HELP
  tqsim help [command]
  tqsim <command> --help

  Global aliases: help, -help, --help, -h, --h, -?, /?, /help.
  Case insensitive. No arguments displays the main help screen.
  Command topics: split, merge/merg, verify, info, update, uninstall, version.
  -NoLogo hides branding; -NoColor disables colors; -Diagnostics adds error detail.
  -Quiet hides branding but keeps requested help. All four switches default off.
  Topic is optional; default main help. Also: tqsim <command> help.
  Help bypasses required operation parameters/value validation, not unknown,
  duplicate or syntactically malformed options.
  Help never starts a file operation, updater or uninstaller.
```