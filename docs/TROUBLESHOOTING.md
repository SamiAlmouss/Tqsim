# Troubleshooting

[English](../README.md) · [العربية](../README.ar.md) · [Parameters and exits](PARAMETERS.md)

Preserve originals, every available part and the original manifest. Test with disposable copies. Never edit hashes or authentication metadata to silence an error. `-Diagnostics` adds the exception type, script/line, ScriptStackTrace and inner exceptions; normal errors remain readable. Review paths before sharing logs and never share a password/key.

| Symptom | Likely causes | Recommended action |
| --- | --- | --- |
| Access denied / deletion denied | NTFS permissions, read-only attributes, another program's handle, security software or another Windows restriction | Close programs using the exact file; inspect attributes/access. Keep completed output. Resolve permission with an authorized account if needed; do not grant broad drive permissions or bypass UAC. Do not rerun completed processing just for cleanup. |
| File in use / sharing violation | Another process holds an incompatible handle | Close the program or wait; check only the affected disposable/source path. Keep verified output and pending recovery state. |
| Required part missing | Incomplete download, renamed or moved part | Restore the exact named part alongside the selected manifest, then run verify. All required parts are needed. |
| Corrupted part / SHA-256 mismatch | Changed bytes, wrong part set, truncated transfer or storage damage | Re-download/re-copy original bytes from a trusted source; compare an independently held hash. Never replace the manifest hash with the damaged hash. |
| Incorrect password / DECRYPTION FAILED | Wrong secret, damaged/missing ciphertext or changed authenticated metadata | Check password/case/input layout; restore original parts/manifest and retry. Errors intentionally do not prove whether secret or data is wrong. No password recovery exists. |
| Authentication failure despite verify=false | GCM/HMAC authentication is mandatory | Restore authentic data/correct password. verify=false only skips independent read-back, never authentication. |
| Destination already exists | Previous successful restore or another file with the original name | Choose another Output directory. Use merge -Overwrite only after explicitly deciding to replace the existing destination. Split has no Overwrite option. |
| Insufficient free disk space | Parts/output/temp require more space; encrypted framing overhead | Choose a larger local destination and retain sources. Merge needs full reconstructed-file space before publication. Verify does not reconstruct data. |
| Unsupported archive format / invalid manifest | Newer unsupported schema, damaged/edited JSON, duplicate/unsafe metadata | Keep original files; restore the manifest or use a compatible Tqsim version. Do not downgrade fields manually. |
| PowerShell 7 missing / app fails under 5.1 | Application requires 7+; runtime not installed/discoverable | Run `winget install --id Microsoft.PowerShell --source winget`, open pwsh and retry. 5.1 is installer bootstrap compatibility only. |
| tqsim not found | PATH not refreshed or installation unavailable | Open a fresh terminal, inspect current-user PATH/managed installation; rerun the inspected official installer if repair is needed. |
| Update fails | Source checkout, missing ownership marker, network/rate limit, release/checksum/ZIP validation, permissions | Run managed tqsim update; check GitHub connectivity and matching ZIP/checksum. Preserve prior working version and archives. No check-only/Force bypass exists. |
| Cleanup incomplete | Locked/read-only/denied/changed source after output completed | Check reported deleted and remaining/unconfirmed counts; independently inspect output. Reconcile exact remaining sources against private %LOCALAPPDATA%\Tqsim\Recovery record with authorized access. Do not execute record contents or blindly rerun. |
| Operation interrupted | Ctrl+C, process termination, storage/OS interruption | Keep originals/parts and inspect partial files. Before retrying split use a fresh destination. Before merge resolve any existing restored output. After interrupted deletion reconcile the private record: some sources may already be gone. |
| Manifest missing / expected exactly one manifest | Lost .tqsim.json or multiple manifests in the directory | Retrieve the original manifest, or select one with -Manifest. There is no supported manifest-reconstruction or parts-only guessing command. Explicit manifest paths are relative to current working directory, not PartsPath. |
| Password prompt unavailable | Redirected input/output or noninteractive host | Use an interactive PowerShell terminal. Do not place secrets in arguments, environment variables or scripts. |

## What success does and does not mean

Exit 0 means the requested operation completed. Nonzero indicates failure: 1 operational/deployment/cleanup, 2 usage/arguments, 3 metadata/integrity/authentication. Missing-part classification can depend on pipeline. A successful streaming/read-back check is time-specific and does not guarantee durable storage, safe future deletion or an independent backup. Info is metadata-only, including for encrypted data; it does not authenticate HMAC or hash parts.

Deletion is not atomic across multiple files. Fully successful cleanup removes its own recovery record; zero-deletion failures leave no useless record; partial or uncertain deletion keeps actionable state without removing unrelated records. Tqsim may grant the current SID Delete on the exact source only if WRITE_DAC already permits it; no ownership takeover/automatic elevation/helper or directory-wide ACL edits occur. Source checkout update/uninstall errors are expected safeguards.
