# Help and documentation coverage — v1.0.7

This inventory was audited before writing documentation, against src/Commands/CLI.ps1, src/Core/Tqsim.psm1, Encryption.ps1, Errors.ps1, Deletion.ps1, install.ps1, update.ps1 and uninstall.ps1. No processing behavior or archive format is changed for this release.

| Command / alias | Operation options beyond four globals | CLI page | English / Arabic | Tests |
| --- | --- | --- | --- | --- |
| split | File, Size, Output, BufferSize, ds, verify, encrypt | examples/help/split.txt | Both READMEs; COMMANDS/PARAMETERS | CLI, Split, Int64, Encryption, Documentation |
| merg / merge | PartsPath, Manifest, Output, Overwrite, BufferSize, ds, verify | examples/help/merge.txt | Both READMEs; COMMANDS/PARAMETERS | CLICompatibility, Merge, Encryption, Documentation |
| verify | PartsPath, Manifest, BufferSize | examples/help/verify.txt | Both READMEs; COMMANDS/PARAMETERS | Verify, Encryption, LegacyCompatibility, Documentation |
| info | PartsPath, Manifest | examples/help/info.txt | Both READMEs; COMMANDS/PARAMETERS | Manifest, CLI, Documentation |
| update | None | examples/help/update.txt | Both READMEs; COMMANDS/PARAMETERS | Installer, InstallerBootstrap, Documentation |
| uninstall | None | examples/help/uninstall.txt | Both READMEs; COMMANDS/PARAMETERS | Installer, Documentation |
| version | None | examples/help/version.txt | Both READMEs; COMMANDS/PARAMETERS | CLI, CLICompatibility, Documentation |
| help | Optional command topic; recognized operation options accepted safely | examples/help/help.txt | Both READMEs; COMMANDS/PARAMETERS | CLICompatibility, Documentation |

Globals: NoLogo, NoColor, Quiet, Diagnostics, default off. Help aliases: no arguments, help, -help, --help, -h, --h, -?, /?, /help. Topics also support command help. Version aliases: version, -version, --version, -v (case insensitive, including -V). Values: File, Size, Output, PartsPath, Manifest, BufferSize, ds, verify, encrypt. Additional operation switch: merge-only Overwrite. There are no operation-parameter short aliases.

## Corrections found during audit

- Merge default is the selected manifest's directory, not a nested Output folder. Split still defaults to Output beside its source.
- An explicit Manifest overrides discovery and determines part locations; a relative Manifest is relative to current working directory, not PartsPath.
- Info displays declared maximum part size and schema, not individual sizes or a dedicated encryption-status field. It neither prompts for a password nor authenticates encrypted metadata. No new field was invented.
- Independent merge read-back occurs after publication and before source deletion. Mandatory streaming checks/authentication precede publication; the earlier blanket claim that all verification preceded publication was inaccurate.
- Update checks and immediately applies a newer stable release, with no check-only flag or confirmation. Uninstall has no confirmation prompt. Both require a managed installation.
- Help bypasses mandatory operation arguments/value checks, not syntax/unknown/duplicate-option checks. Version flags cannot be combined with another operation.
- Quiet preserves requested help/info/version and errors; safety warnings/deployment messages can remain. NoColor controls Tqsim styling, not all independently emitted installer messages.
- No unsupported Password, Source, Force, Check or merge encrypt parameter was added. Existing parser and binary engine remain intact.

## Maintenance and automated checks

[Command pages](COMMANDS.md) mirror the built-in text verbatim (including a version placeholder resolved from version.json). [Parameter reference](PARAMETERS.md) adds full accepted values and cross-command rules. Both READMEs carry the same executable tqsim example inventory; examples with angle-bracket placeholders are syntax, not literal commands to execute. Documentation.Tests.ps1 checks parser option coverage, every topic/alias, defaults, no operation/password/ACL/recovery/deployment dispatch, narrow-terminal word wrapping, NoLogo/NoColor/redirected output, example parser acceptance and local Markdown targets/anchors. Existing binary/encryption/legacy and installer regression tests stay in the full suite.

Historical validation/performance/format reports retain their original version numbers deliberately. Current README/help must use same-directory merge; old reports are historical evidence, not current operational instructions. Security claims remain limited to actual testing, not external certification. See [release validation](VALIDATION-v1.0.7.md) for final actual counts and package checks.
