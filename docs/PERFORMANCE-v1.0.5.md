# Tqsim 1.0.5: measured performance and verification semantics

## Investigation and root cause

Measurements started against unchanged v1.0.4, before optimizing production code. `scripts/profile-performance.ps1` copies the application to a unique test directory and injects Stopwatch timers and a counting FileStream subclass only into that copy. `scripts/ProfileStreams.cs` and the profiling script are developer tools, excluded from application ZIPs. Normal execution has no profiling hooks.

For a real random 536,870,929-byte file (512 MiB + 17), v1.0.4 with deletion read **seven payload equivalents** in both pipelines. Split read the original four times and the parts three times. Merge read the parts five times and the output twice. The extra passes came from Add-TqsimDeletionFile hashing, preverification/independent verification, pre-cleanup rehashes, and Remove-TqsimVerifiedFile hashing. Payload was already hashed during streaming. Default v1.0.4 merge also had a redundant pre-read before its writing pass.

The original HashAlgorithm.ComputeHash(Stream) path issued many 4 KiB reads: measured total read calls were 655,640 for split and 655,646 for merge with deletion. This added API/loop overhead as well as redundant bytes. File publication/deletion itself was small compared with repeated reads and SHA-256 work. Per-part Flush(true) was also material, around one second per operation in this sample, and is retained for safe finalization. No evidence justified changing the public 4 MiB BufferSize default, removing flushes, introducing parallel disk work or rewriting the streaming engine.

## Resulting data passes

| Operation | verify=false | verify=true | ds effect |
| --- | --- | --- | --- |
| Split | Source read once; parts written once | Same plus one ordered parts read | No additional payload reads |
| Merge | Parts read once, checking each part and whole hash while writing temporary output | Same plus one published-output read | No additional payload reads |

Deletion with verification eliminates five full payload scans versus v1.0.4 (7 to 2); explicit fast deletion eliminates six (7 to 1). Mandatory small manifest reads and flushed cleanup-journal writes are metadata exceptions, not hidden data verification. File IDs, lengths and creation/write timestamps are captured under restrictive locks and revalidated immediately before exact deletion. Each target remains locked until its own deletion boundary; protected output remains locked throughout. Published file IDs must match their created temporary files. Existing shared-manifest, link, path, collision and partial-cleanup protections remain.

Measured v1.0.5 payload-read counts agree with that design. With deletion, total read bytes including small manifest reads were 1,073,743,228 with verification and 536,872,299 without it. Read calls fell to 260/261 (split/merge verified) and 131/131 (fast). Without deletion, read bytes were exactly 2N or N. Read-back hashing now uses a reusable bounded 4 MiB buffer. Streaming part/whole hashing remains mandatory in every mode.

## Timing without profiling overhead

These are actual single-run measurements on the same local D: volume, PowerShell 7.6.5, 512 MiB + 17 random bytes, five 128 MiB-sized parts (last 17 bytes). `-TimingOnly` copies the uninstrumented application and times only each operation. Data creation and the independent test-harness final SHA-256 are outside operation elapsed time. Cache/device state was not controlled or flushed; other light tests were running, so these are local observations rather than statistically established throughput guarantees. MiB/s = payload size / elapsed, not aggregate disk bandwidth.

| Version | ds | verify | Split seconds | Split MiB/s | Merge seconds | Merge MiB/s |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| 1.0.4 | false | Legacy behavior | 2.409 | 212.5 | 3.419 | 149.8 |
| 1.0.4 | true | Legacy full verification | 13.158 | 38.9 | 9.835 | 52.1 |
| 1.0.5 | false | true | 3.636 | 140.8 | 2.633 | 194.4 |
| 1.0.5 | false | false | 2.711 | 188.9 | 2.324 | 220.3 |
| 1.0.5 | true | true | 3.595 | 142.4 | 2.865 | 178.7 |
| 1.0.5 | true | false | 2.264 | 226.1 | 2.357 | 217.2 |

The measured deletion+verification sample improved approximately 3.66x for split and 3.43x for merge. This is a comparison of those runs, not a general speed promise. New default split is slower than old default split because verification now defaults to true even without deletion; the old default did not read back parts. That is required new assurance, not a hidden regression. Fast retained-source split was 0.302 s slower in this one sample; it has the same payload pass count, adds mandatory flushed/validated manifest publication, and is subject to cache/flush variability. No claim of improvement is made for that case. Default merge reads the same total data volume as before but uses one integrity-checked input pass plus an output read-back instead of two input passes.

## Phase profiling

Seconds below are from separately instrumented runs. They include instrumentation overhead and must not be used as speedup measurements. Inclusive phase timers overlap with read/write/hash timers and are not additive. Hash timing is elapsed hashing API time (for the old ComputeHash path, native read-call time is subtracted as an estimate); it is not sampled CPU utilization. Validation may include nested checks.

| Phase | 1.0.4 split ds=true | 1.0.4 merge ds=true | 1.0.5 split ds=true verify=true | 1.0.5 merge ds=true verify=true |
| --- | ---: | ---: | ---: | ---: |
| Input/path/manifest validation | 0.096 | 0.179 | 0.099 | 0.192 |
| All FileStream read APIs | 6.804 | 8.795 | 0.704 | 1.187 |
| Part/output write APIs | 0.267 | 0.274 | 0.263 | 0.265 |
| Hash API elapsed excluding native read estimate | 3.265 | 3.301 | 1.119 | 0.838 |
| Manifest write/serialization | 0.000434 write | Not applicable | 0.000175 serialization | Not applicable |
| Independent parts / destination read-back | 1.020 parts | Included in repeated hash reads | 1.138 parts | 1.070 output |
| Publication/atomic journal replacement | 0.0099 | 0.0161 | 0.0124 | 0.0160 |
| Source File.Delete calls | 0.0616 | 0.0883 | 0.0661 | 0.0028 |
| Final handle cleanup | 0.00022 | 0.00018 | 0.00027 | 0.00013 |
| Retained Flush(true) calls | 1.089 | 1.120 | 1.181 | 0.946 |

The instrumented JSON includes exact byte totals, write totals, calls, paths and phase times. The final profiler also records per-path read time so input reading can be separated from verification reading. Baseline counters measure FileStream payload/metadata calls; small ReadAllText manifest reads are not counted and are explicitly excluded from payload-pass claims. Large data remains streaming; memory/handle metadata is proportional to part count. Very small parts can be limited by filesystem metadata and journal/flush costs; CPU hashing or device throughput can dominate once redundant passes are removed.

For the optimized verified/deleting sample, input-read API time was 0.161 s (split) and 0.405 s (merge); independent-output read API time was 0.541 s and 0.781 s respectively. These are native FileStream read-call elapsed times only; hashing and PowerShell loop time are outside those per-path values. Independent verification phase totals above include that work.

## Real multi-gigabyte integration

Each row below used a newly generated, physically written 5,368,709,137-byte source and independently compared initial/restored SHA-256 in the harness. No profiler hooks were enabled. All cases passed:

| ds | verify | Part size | Split seconds / MiB/s | Merge seconds / MiB/s |
| --- | --- | --- | --- | --- |
| false | true | 1GB (six parts) | 29.743 / 172.1 | 31.529 / 162.4 |
| false | false | 2GB (three parts) | 21.920 / 233.6 | 20.807 / 246.1 |
| true | true | 4GB (two parts) | 33.309 / 153.7 | 31.596 / 162.0 |
| true | false | 4GB (two parts) | 21.857 / 234.3 | 22.483 / 227.7 |

Source deletion occurred in the last two cases only; final restored data remained intact. These rows use different part sizes and cannot establish a pure verification-only speed ratio. They demonstrate real operation and independent final hash equality, including an actual 4,294,967,296-byte part with verification disabled. No 200GB/1TB physical data test was performed; existing arithmetic boundary tests remain.

## Reproduction and evidence

```powershell
# Against an extracted, unchanged v1.0.4 application directory:
./scripts/profile-performance.ps1 -ApplicationRoot 'D:\test\v104' -Label v104 -Bytes 536870929
./scripts/profile-performance.ps1 -ApplicationRoot 'D:\test\v104' -Label v104-timing -Bytes 536870929 -TimingOnly
# Optimized implementation, all four ds/verify configurations:
./scripts/profile-performance.ps1 -Optimized -Label v105 -Bytes 536870929
./scripts/profile-performance.ps1 -Optimized -Label v105-timing -Bytes 536870929 -TimingOnly
./scripts/profile-performance.ps1 -Optimized -Label v105-large -Bytes 5368709137 -TimingOnly -PartSizes 1GB,2GB,4GB,4GB
```

The last array syntax is for invocation inside PowerShell; when using native `pwsh -File`, use `pwsh -Command` and pass an actual array. Each benchmark creates unique disposable files and independently compares restored SHA-256 with the initial source, even with application verification disabled. Test data remains for inspection.

Raw evidence in `.test-work/performance`:

- `v104-c781dc84-5a5a-42d1-aa95-abe1b0293037/profile.json` — original instrumented profile.
- `v104-timing-d4a6d20d-4cd8-40be-b079-47134e03e2f5/profile.json` — original uninstrumented elapsed timing.
- `v105-timing-63a7c574-7f39-4bc9-a679-0b55f8ae0d8c/profile.json` — optimized uninstrumented timing.
- `v105-final-profile-3dcee701-826c-4c06-bc43-f2d2c1c64cef/profile.json` — optimized phase profile and measured passes.
- `v105-large-4b04702c-892e-48dd-829c-3ef287399e36/profile.json` — real 5 GiB + 17 round trips across all four configurations and 1GB/2GB/4GB part sizes.

TimingOnly records have counters disabled (zero means unmeasured, not zero I/O). Timing and counter evidence intentionally come from separate runs. Source data is randomly generated per configuration, not sparse. No actual ISO/.smm user data was read or changed. See IMPLEMENTATION.md for final regression/release validation.
