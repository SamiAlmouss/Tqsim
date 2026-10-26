# Tqsim v1.0.4 release validation — 2026-10-26

Implementation, file list, safety limitations and complete integration results are in [IMPLEMENTATION.md](../IMPLEMENTATION.md). Manual GitHub publication and installed-command update instructions are in [README.md](../README.md#publish-to-github). No publication or global update was performed.

| Check | Actual result |
| --- | --- |
| Full Pester 4.10.1, PowerShell 7.6.5 | 168 passed, 0 failed, 0 skipped |
| Full Pester 4.10.1, PowerShell 7.6.9 | 168 passed, 0 failed, 0 skipped |
| Native Windows PowerShell 5.1.26100.9711 installer handoff | Passed in the retained bootstrap suite with local HTTP/install fixtures; parent survives success/failure |
| Real random 5,368,709,137-byte source | 1GB, 2GB and 4GB split/verify/merge round trips passed with equal initial/final SHA-256 |
| Explicit deletion in real large-file cases | Passed for split and merge at 2GB and 4GB, including actual 4,294,967,296-byte part |
| Real process termination during cleanup | Verified output/manifest/remaining inputs preserved; write-ahead target remains deleting/unconfirmed |
| Interactive Windows pseudo-console | Bar and status rendered on distinct rows at 80 columns from 25% through 100% |
| Final ZIP source comparison | All 21 entries byte-for-byte match their final local source files; no tests/temporary data included |
| Final extracted ZIP CLI | Version 1.0.4; default/false retention, true deletion, independent verify/merge and SHA-256 round trips passed |
| Final extracted ZIP cleanup failure | Actual read-only second part: exit 1, reports 1 deleted / 11 remaining-unconfirmed, retains correct output and manifest |
| Prior releases | All eight v1.0.0–v1.0.3 ZIP/checksum files retain their baseline SHA-256 |

Release file: `dist/Tqsim-v1.0.4.zip`, **48,096 bytes**, 21 entries.

SHA-256:

```text
48b0f05733d77c424616d13a1fa8d7a74dff0bbf4ad3135ad8f8d5b84eb1f12c
```

Checksum sidecar: `dist/Tqsim-v1.0.4.zip.sha256`.

Large integration initial/final data SHA-256:

```text
192AF8BAD471CFCA221A4B2AE41E655A685AD9C643F573B83BC9DD418EA95320
```

Detailed executable evidence remains under `.test-work`: `v104-final-765.xml`, `v104-final-store.xml`, `v104-release-validation.json`, and `delete-integration/1f58fe24-d2e4-4375-a448-04fad64c77a6/results.json`. The large-data script deliberately reuses a prior reconstructed disposable file in the next deletion case; earlier verified files may therefore be absent after their authorized deletion. Retained test data occupies approximately 15 GiB and is entirely within that uniquely named test directory.

The public `irm https://raw.githubusercontent.com/SamiAlmouss/Tqsim/main/install.ps1 | iex` command was not run against unpublished v1.0.4. That remains a post-publication check in disposable Windows PowerShell 5.1 and PowerShell 7 sessions. Windows Terminal/VS Code visual inspection, network filesystem behavior, hardware power-loss durability and physical 200GB/1TB data tests were not performed. The original ISO, .smm backup and other user data were not used or modified.
