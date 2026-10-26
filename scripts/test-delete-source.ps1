#requires -Version 7.0
[CmdletBinding()]param([long]$Bytes=67108881,[string[]]$PartSizes=@('1MB','2MB','4MB'),[string]$WorkDirectory=(Join-Path $PSScriptRoot '../.test-work/delete-integration'))
$ErrorActionPreference='Stop'
Import-Module "$PSScriptRoot/../src/Core/Tqsim.psm1" -Force
if ($Bytes -lt 1 -or $PartSizes.Count -lt 2) {throw 'Use a positive disposable source size and at least two part sizes.'}
$directory=Join-Path ([IO.Path]::GetFullPath($WorkDirectory)) ([guid]::NewGuid().ToString())
$null=New-TqsimDestination $directory ([long]($Bytes*5))
$source=Join-Path $directory 'disposable نسخة binary.bin'
$stream=New-TqsimStream $source CreateNew Write;$buffer=[byte[]]::new(4194304);[long]$remaining=$Bytes
Write-Output "Creating $Bytes real random bytes in $directory"
try {while ($remaining -gt 0) {[Security.Cryptography.RandomNumberGenerator]::Fill($buffer);$n=Get-TqsimReadCount $buffer.Length $remaining;$stream.Write($buffer,0,$n);$remaining-=$n};$stream.Flush($true)} finally {$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $source).Hash;$results=[Collections.Generic.List[object]]::new()
for ($i=0;$i -lt $PartSizes.Count;$i++) {
    $size=$PartSizes[$i];$delete=if ($i -eq 0) {'false'} else {'true'};$clock=[Diagnostics.Stopwatch]::StartNew()
    $parts=Join-Path $directory "parts-$i";$restored=Join-Path $directory "restored-$i"
    Write-Output "Testing $size parts; Delete Source: $delete"
    Split-Tqsim -File $source -Size $size -Output $parts -ds $delete -Quiet
    if ([IO.File]::Exists($source) -ne ($delete -eq 'false')) {throw 'Unexpected split source retention.'}
    $manifest=Join-Path $parts 'disposable نسخة binary.bin.tqsim.json';$m=Read-TqsimManifest $manifest
    if ($m.totalParts -lt 2) {throw 'Integration must exercise multiple real parts.'}
    Test-Tqsim -Manifest $manifest -Quiet
    Merge-Tqsim -Manifest $manifest -Output $restored -ds $delete -Quiet
    $output=Join-Path $restored 'disposable نسخة binary.bin'
    if ((Get-Item -LiteralPath $output).Length -ne $Bytes -or (Get-FileHash -LiteralPath $output).Hash -cne $hash) {throw 'Independent round-trip SHA-256 or size mismatch.'}
    if ([IO.File]::Exists($manifest) -ne ($delete -eq 'false')) {throw 'Unexpected merge source retention.'}
    if ($delete -eq 'true' -and @(Get-ChildItem -LiteralPath $parts -Filter '*.part*').Count) {throw 'Cleanup left input parts.'}
    $result=[ordered]@{bytes=$Bytes;partSize=$size;deleteSource=$delete;partLengths=@($m.parts.size);sha256=$hash;elapsed=$clock.Elapsed.ToString();output=$output}
    $results.Add($result);Write-Output ("PASS: $size; $($m.totalParts) parts; SHA256 $hash; $($clock.Elapsed)")
    # The next stage operates only on our newly reconstructed disposable file.
    if ($delete -eq 'true') {$source=$output}
}
$report=Join-Path $directory 'results.json';[IO.File]::WriteAllText($report,($results|ConvertTo-Json -Depth 8))
Write-Output "All disposable integration cases passed. Report: $report"
