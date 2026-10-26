# CLI parameter reference

[English guide](../README.md) · [الدليل العربي](../README.ar.md) · [Command pages](COMMANDS.md)

Audited against `Resolve-TqsimInvocation`, the processing function signatures and deployment scripts. All named operation parameters use one dash, are case insensitive and reject duplicates. There are no short aliases for File, Size, PartsPath or other operation parameters. Quote paths containing spaces. Prefix a filename starting with a dash with `.\`. Values can use `-Size 1GB` or `-Size:1GB`. Unrecognized arguments are usage errors.

## Complete inventory

| Name | Commands | Mandatory / default | Accepted values and purpose | Practical example / warning |
| --- | --- | --- | --- | --- |
| `-File` | split | Required | Existing regular source-file path | `tqsim split -File "D:\backup.iso" -Size 1GB`; no default source |
| `-Size` | split | Required | Positive integer bytes, optionally B, KB/KiB, MB/MiB, GB/GiB, TB/TiB; <= Int64.MaxValue after scaling | `tqsim split -File "D:\backup.iso" -Size 2GB`; all suffixes binary; encrypted minimum 29 bytes |
| `-Output` | split, merg/merge | Optional; split: Output beside source; merge: selected manifest directory | Destination directory, created if needed | `tqsim merg -PartsPath "E:\Parts" -Output "D:\Restored"`; ensure free space |
| `-PartsPath` | merg/merge, verify, info | Optional; current directory (`.`) | Directory in which to discover exactly one manifest | `tqsim verify -PartsPath "E:\Parts"`; multiple manifests need selection |
| `-Manifest` | merg/merge, verify, info | Optional; discover exactly one .tqsim.json in PartsPath | Explicit manifest path, relative to current working directory if not absolute | `tqsim info -Manifest "E:\Parts\backup.iso.tqsim.json"`; overrides discovery; parts resolved beside manifest |
| `-BufferSize` | split, merg/merge, verify | Optional; 4194304 bytes | Integer 4096..67108864; bounded ordinary I/O buffer | `tqsim verify -PartsPath "E:\Parts" -BufferSize 4194304`; encrypted record buffer stays <=4 MiB |
| `-ds` | split, merg/merge | Optional; false | String true or false, case insensitive; opt into source deletion after required completion/integrity checks | `tqsim merg -PartsPath "E:\Parts" -ds true`; irreversible, not secure erasure |
| `-verify` | split, merg/merge | Optional; true | String true or false; enable/skip one independent output read-back | `tqsim split -File "D:\backup.iso" -Size 1GB -verify false`; false reduces assurance, does not disable streaming hashes/GCM |
| `-encrypt` | split only | Optional; false | String true or false; hidden confirmed password enables encryption | `tqsim split -File "D:\backup.iso" -Size 1GB -encrypt true`; protect password, no recovery |
| `-Overwrite` | merg/merge | Optional; switch off | Enable explicit replacement of an existing reconstructed filename | `tqsim merg -PartsPath "E:\Parts" -Overwrite`; replacement may destroy existing destination content |
| `-NoLogo` | All commands | Optional; switch off | Hide logos/banner; keep requested results/help | `tqsim version -NoLogo` |
| `-NoColor` | All commands | Optional; switch off | Disable Tqsim text colors; NO_COLOR environment variable also disables them | `tqsim help -NoColor`; deployment scripts may emit their own messages |
| `-Quiet` | All commands | Optional; switch off | Suppress CLI branding/routine processing output/progress; requested help/info/version, errors, safety warnings and deployment messages can remain | `tqsim verify -PartsPath "E:\Parts" -Quiet` |
| `-Diagnostics` | All commands | Optional; switch off | Add exception type, source script/line, ScriptStackTrace and inner exceptions on failure | `tqsim verify -PartsPath "E:\Parts" -Diagnostics`; review paths before sharing logs |

All four global options and Overwrite are switches: supplying one enables it. Explicit switch syntax also accepts `-Quiet:false`, `-Quiet:true`, `-Quiet:$false`, `-Quiet:$true` (quote the whole token if PowerShell would expand it). A separate `-Quiet false` is not switch syntax. These switch rules differ from the three string-valued Boolean options below.

## Boolean defaults

| Parameter | Default | Explicit preservation/default | Explicit opt-in/fast mode |
| --- | --- | --- | --- |
| `-ds` | false | `-ds false` or `-ds "false"` | `-ds true` or `-ds "true"` |
| `-verify` | true | `-verify true` or `-verify "true"` | `-verify false` or `-verify "false"` |
| `-encrypt` | false | `-encrypt false` or `-encrypt "false"` | `-encrypt true` or `-encrypt "true"` (split only) |

Omitting an optional parameter uses its default; you do not need to spell it out. true/false values are case insensitive. Empty, missing, yes, no, 1, 0 and arbitrary values are usage errors. For these string-valued options use the words `true`/`false`, not literal `$true`/`$false` text. A PowerShell Boolean expression may stringify before reaching the parser, but is unnecessary.

## Commands, help and version aliases

Commands: `split`, `merg`, `merge`, `verify`, `info`, `update`, `uninstall`, `version`, `help`. merg and merge are identical; neither spelling is deprecated. Command names are case insensitive.

| Form | Accepted aliases / default | Example and restriction |
| --- | --- | --- |
| Main help | No arguments, help, -help, --help, -h, --h, -?, /?, /help | `tqsim --help`; no operation |
| Topic help | help command; command help; any help flag beside command | `tqsim help split`, `tqsim split --help`, `tqsim split -h` |
| Help topic | Optional; main page | `tqsim help merg`; every command has a topic |
| Version command | version, -version, --version, -v (including -V) | `tqsim --version -NoLogo`; version flags cannot accompany another operation |

Help takes precedence over mandatory operation-parameter/value checks. It still rejects unknown commands/topics, unknown/duplicate options and malformed syntax. Help does not process files, read manifests, change ACLs, create cleanup records, request passwords, contact GitHub or invoke uninstall. `-Quiet` never hides requested help. `-NoLogo` removes branding; `-NoColor` and redirected output omit decorative ANSI escapes.

## Manifest selection and exits

`-Manifest` is not resolved relative to PartsPath: an explicit relative path is relative to the current working directory. The selected manifest's directory supplies its parts and the default merge destination. The complete ordered part set and original manifest are required; no filename guessing or manifest recovery command exists.

Exit codes from tqsim.ps1: 0 successful command/help, 1 operational/deployment/cleanup failure, 2 usage or invalid arguments, 3 invalid metadata/integrity/authentication. A missing part may surface as operational or integrity failure depending on the pipeline; scripts should treat every nonzero status as failure. Info does not test ciphertext authentication. Split/merge/verify errors never imply that an independent backup exists.

Direct deployment-script parameters are not tqsim CLI options: `install.ps1` accepts `-Repository` (default SamiAlmouss/Tqsim) and `-InstallRoot` (default %LOCALAPPDATA%\Programs\Tqsim). `update.ps1`/`uninstall.ps1` use their managed ownership marker; do not invent `tqsim update -Check`, `-Force`, `-Password`, `-Source` or `-encrypt` on merge.
