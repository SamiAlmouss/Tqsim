# Tqsim v1.0.6 validation — 2026-10-26

## Result and scope

Prepared locally; not committed, pushed, published or installed globally. No original user ISO or .smm backup was accessed or modified. All binary fixtures were disposable random data. Version promotion followed passing relevant pre-version tests. The final full suites include all earlier tests; none were removed or skipped.

| Final full suite | Passed | Failed | Skipped / pending / inconclusive | Elapsed |
| --- | ---: | ---: | --- | ---: |
| PowerShell 7.6.5, bundled runtime | 219 | 0 | 0 / 0 / 0 | 178.83 s |
| PowerShell 7.6.9, installed Store runtime | 219 | 0 | 0 / 0 / 0 | 189.96 s |

Evidence: `.test-work/v106-final-765.xml` and `.test-work/v106-final-store.xml`. Pester 4.10.1. Native Windows PowerShell 5.1.26100.9711 installer handoff is exercised within the installer suite. Tests use disposable installation fixtures and mocked network/persistent PATH; they do not replace the user's command. An initial full run exposed a rollback retry failure caused by the newly packaged empty docs directory; rollback was corrected and both final suites above passed. There are no outstanding failures or skipped tests.

## Compatibility and functional coverage

- Authentic fixtures were generated with the preserved release ZIPs 1.0.2, 1.0.3, 1.0.4 and 1.0.5 before changing the engine. Static parts/manifests plus provenance hashes are checked into `tests/fixtures/legacy`; tests do not regenerate them. Each restored from relocated parts with default and explicit destinations, unchanged original manifest bytes and no password prompt. Original source SHA-256: `D9A09AC2F685D83E56623348912B65A368D277E87A9C7C60BA0BE3E6B13FE099`. No months-old remote archive was supplied; these are authentic version-generated compatibility fixtures.
- Legacy schema/part bytes, Int64 size parsing/arithmetic, SHA-256, empty/small/multipart/exact boundaries, Unicode names, aliases, defaults, strict Boolean validation, overwrite/collisions, progress/branding, diagnostics, cancellation and real cleanup-process termination remain covered.
- Encryption: empty and single-byte input, multiple physical parts, 4 MiB record boundaries, 1TB configured maximum on a tiny file, every ds/verify combination, fresh salt/nonce domains, nonce exhaustion, plaintext absence from parts, wrong password, modified metadata/KDF/version/order/nonce/ordinal/ciphertext/tag, missing/truncated parts and resource bounds. Mandatory GCM/HMAC/whole-file integrity remains active with verify=false.
- Hidden interactive split password confirmation and automatic merge prompt were exercised in native pseudo-terminals. Noninteractive invocation fails before output creation; no CLI password parameter exists. Mocked secure-input tests cover long passphrases, mismatch, short, empty and excessive length. Real terminal entry did not echo the password.
- Actual normal-user NTFS tests cover a Delete denial repaired through already-authorized per-file WRITE_DAC, both Delete and WRITE_DAC denied, sharing violations, read-only failure, no source ACL edits with ds=false, private atomic temporary-file creation, CreateNew collisions, successful cleanup without journals, partial/interrupted cleanup and unrelated-record preservation. The test token was not an elevated administrator.
- Installer checksum/ZIP safety, 5.1 handoff, rollback/retry, PATH, update/uninstall and launcher forwarding pass. All 12 previous release ZIP/checksum files retain their original SHA-256.

## Independent cryptographic checks

.NET AES-256-GCM passes the NIST zero-key/zero-IV known-answer vector. A separate Python 3.13 implementation using cryptography 50.0.2 independently derives PBKDF2 keys, reconstructs manifest canonical encoding and HMAC, decrypts GCM records with documented nonce/AAD and validates ciphertext-part and whole-plaintext SHA-256. An 8,388,641-byte / three-record fixture passed with SHA-256 `09a3663b2cc5377d45acd6b07382392fd3ed2aaf793b475e25ad84ccd628491a`. Python's same NIST vector also passed. Evidence harness: `.test-work/independent_crypto.py`; fixture location is in `.test-work/independent-crypto-path.txt`. These cross-checks are not an external security audit.

## Actual multi-gigabyte measurements

Five completed round trips used a real, non-sparse random **5,368,709,137-byte (5 GiB + 17)** source. Every final output was independently hashed by the harness, including verify=false cases. Default output was directly in the parts directory. ds=true deleted only disposable sources after success. No success recovery record remained. All cases produced SHA-256 `FE91CCC4178503D294A929C2EB13D198E72E97D4D0D2B2FEFA610771DCB4E62C`.

| Encryption | ds | verify | Size | Split seconds / MiB/s | Merge seconds / MiB/s |
| --- | --- | --- | --- | --- | --- |
| false | false | true | 1GB | 33.396 / 153.31 | 31.637 / 161.83 |
| true | false | true | 1GB | 35.113 / 145.82 | 31.735 / 161.34 |
| true | false | false | 2GB | 22.158 / 231.07 | 20.734 / 246.94 |
| true | true | true | 4GB | 34.023 / 150.49 | 31.900 / 160.50 |
| true | true | false | 4GB | 22.006 / 232.67 | 21.088 / 242.79 |

Actual encrypted physical lengths: 1GB configuration has five 1,073,741,824-byte parts plus 35,885 bytes; 2GB has two 2,147,483,648-byte parts plus 1,073,777,709 bytes; 4GB has one 4,294,967,296-byte part plus 1,073,777,709 bytes. Thus real 2GB and 4GB parts were exercised; no Int32 conversion error occurred. Plain mode has five 1GB parts plus 17 bytes.

Raw report: `.test-work/crypto-integration/994e8308-1c62-4291-b383-9223095201ba/results.json`. These are single local runs with uncontrolled cache/storage, not universal speed claims. Option/part-size differences prevent treating every row as an isolated cipher comparison. After the final atomic private-file creation hardening, both full suites and a fresh five-case 67,108,881-byte integration passed; its evidence is `.test-work/crypto-integration/d93c36ad-bc68-4379-bb21-74f3ba45f7cc/results.json`. The earlier 5 GiB runs used the same crypto/record algorithms but preceded that final file-creation hardening.

## Release package verification

- `dist/Tqsim-v1.0.6.zip`: 70,738 bytes, 25 entries.
- SHA-256: `9fb8fab3717ee6068ff32715615582e9a5e4a7c6034ceaf87b1a2a44828d90c9`.
- Matching `dist/Tqsim-v1.0.6.zip.sha256` created. Existing release assets preserved.
- Every entry matches the local validated source byte for byte. Names checked for duplicates, unsafe paths and accidental test/developer payloads. Crypto.cs, Encryption.ps1, Errors.ps1 and the encrypted-format specification are included. Only built-in .NET crypto is required; there is no downloaded cryptographic DLL.
- Freshly extracted package passes version, real CLI plain split/verify/merge for all four ds/verify combinations, default same-directory plain merging, encrypted auto-detection/default destination with verified and fast destructive modes, independent SHA-256 and truthful partial-cleanup exit code 1 with completed output preserved. The encrypted package harness replaces only its secret reader with a public nonsecret fixture credential; production CLI has no password option.
- Evidence: `.test-work/v106-release-validation.json` and `.test-work/validate-v106-release.ps1`. Build refuses to overwrite an existing ZIP. `git diff --check` passes (only normal Windows line-ending notices).

## Security and deployment limits

See [encrypted format and security considerations](ENCRYPTED-FORMAT-v1.md) and [implementation map](../IMPLEMENTATION.md). AES-256-GCM uses 16-byte tags, 12-byte unique per-key record nonces and bounded 4 MiB records. PBKDF2-HMAC-SHA256 uses 600,000 iterations, random 32-byte salts and domain-separated encryption/manifest keys. A manifest HMAC authenticates semantic metadata before paths are used. Passwords are hidden and confirmed, 12–1,024 characters; loss is unrecoverable. Filename, size and hashes remain visible metadata.

No external cryptographic audit, elevated administrator/UAC flow, physical 200GB/1TB dataset, network-storage crash or hardware power-loss testing is claimed. No UAC helper is implemented: insufficient WRITE_DAC means actionable manual authorized cleanup, not privilege escalation. Legacy unkeyed manifests require trusted provenance and cannot be retroactively authenticated. Private temporary plaintext removal is not secure erasure; OS/runtime copies, snapshots and caches may remain. Multi-file deletion cannot be atomic; retained records require manual reconciliation and never authorize automatic deletion. The real published one-line installer is untested for unpublished v1.0.6 and must be exercised after authorized publication in both Windows PowerShell 5.1 and PowerShell 7. Publication and installed update commands are documented in [README](../README.md#publish-to-github). No publication/global update was performed.