# Tqsim v1.0.5 validation — 2026-10-26

See [performance measurements and limitations](PERFORMANCE-v1.0.5.md), [implementation/file changes](../IMPLEMENTATION.md), and [manual publication/update steps](../README.md#publish-to-github).

| Actual check | Result |
| --- | --- |
| Final full Pester 4.10.1, PowerShell 7.6.5 | 178 passed, 0 failed, 0 skipped |
| Final full Pester 4.10.1, PowerShell 7.6.9 | 178 passed, 0 failed, 0 skipped |
| Previous tests preserved | All 168 retained; only version expectations updated |
| New strict/default/pass tests | Ten additional tests; real byte counters assert one input read and zero/one output read for every ds/verify combination |
| Native CLI / Windows launcher | Defaults, explicit options, invalid Boolean values, Unicode/spaces and help routing passed |
| Real multi-gigabyte integration | Four independently checked 5 GiB + 17 random-data round trips, using 1GB/2GB/4GB part configurations; verified and fast destructive modes passed |
| Remaining safeguards | Existing corruption, identity/link/shared-manifest, cancellation, forced process termination, read-only partial-cleanup, installer bootstrap/rollback and update/uninstall tests passed |
| Extracted final ZIP | All four combinations passed split, standalone verify, merge and independent SHA-256 equality |
| Extracted ZIP fast cleanup failure | Actual read-only second source part: exit 1; reports 1 deleted / 11 remaining-unconfirmed, retains intact output and manifest |
| Final ZIP entries | All 21 match local source bytes; no profiling scripts/C# counters/tests/data included |
| Earlier archives | All ten previous v1.0.0–v1.0.4 ZIP/checksum files retain baseline hashes |

Final archive: `dist/Tqsim-v1.0.5.zip`, **52,301 bytes**.

SHA-256 (`dist/Tqsim-v1.0.5.zip.sha256`):

```text
198faa6a5b8d72d1705211cb77826de9c10825879d0b24747f35388cba698f15
```

Executable evidence: `.test-work/v105-final-765.xml`, `.test-work/v105-final-store.xml`, `.test-work/v105-release-validation.json`, and the raw benchmark JSON paths listed in the performance report. Benchmark files were generated solely for testing; retained large-data and baseline test copies occupy disk space under `.test-work/performance`.

Defaults are ds=false and verify=true. Explicit ds=true/verify=false warns and skips independent read-back without disabling mandatory streaming integrity, lengths, flush/close, safe publication, identity/path checks or journals. No hidden payload pass is introduced for deletion. Retained-source default output does not print default Boolean statuses. Multi-file cleanup remains non-atomic and a final close-to-delete race remains; read the implementation limitations before destructive use.

No Git commit/push, GitHub publication or installed-global-app update occurred. Original user ISO/backup files were not read or changed. The public one-line installation check remains post-deployment; current live URLs cannot install an unpublished release. Hardware power-loss/network-filesystem durability, physical 200GB/1TB data runs and controlled cold-cache/statistical benchmarks were not performed. Measured local improvements are not general throughput guarantees.
