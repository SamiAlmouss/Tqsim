#requires -Version 7.0
[CmdletBinding()]param([long]$Bytes=67108864,[string]$WorkDirectory=(Join-Path $PSScriptRoot '../.test-work/integration'),[string]$PartSize='16777213')
$ErrorActionPreference='Stop'
if ($Bytes -lt 0) {throw 'Bytes must be nonnegative.'}
$directory=Join-Path ([IO.Path]::GetFullPath($WorkDirectory)) ([guid]::NewGuid().ToString());$null=[IO.Directory]::CreateDirectory($directory)
$source=Join-Path $directory 'large binary.bin';$stream=[IO.File]::Open($source,[IO.FileMode]::CreateNew);$buffer=[byte[]]::new(4194304);[long]$remaining=$Bytes
try {while ($remaining -gt 0) {[Security.Cryptography.RandomNumberGenerator]::Fill($buffer);$n=[int][math]::Min([long]$remaining,[long]$buffer.Length);$stream.Write($buffer,0,$n);$remaining-=$n}} finally {$stream.Dispose()}
Import-Module "$PSScriptRoot/../src/Core/Tqsim.psm1" -Force
$clock=[Diagnostics.Stopwatch]::StartNew();Split-Tqsim -File $source -Size $PartSize -Quiet
$parts=Join-Path $directory 'Output';Test-Tqsim -PartsPath $parts -Quiet;Merge-Tqsim -PartsPath $parts -Quiet
$restored=Join-Path $parts 'Output/large binary.bin'
$sourceHash=(Get-FileHash -LiteralPath $source).Hash;$restoredHash=(Get-FileHash -LiteralPath $restored).Hash
if ($sourceHash -cne $restoredHash) {throw 'Round-trip mismatch.'}
$manifest=Read-TqsimManifest (Join-Path $parts 'large binary.bin.tqsim.json')
Write-Output "PASS: $Bytes byte binary round trip; part size $PartSize; part lengths $($manifest.parts.size -join ', '); SHA256 $sourceHash; elapsed $($clock.Elapsed); files retained at $directory"
