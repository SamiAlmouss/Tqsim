#requires -Version 7.0
[CmdletBinding()]param([long]$Bytes=67108864,[string]$WorkDirectory=(Join-Path $PSScriptRoot '../.test-work/integration'))
$ErrorActionPreference='Stop'
if ($Bytes -lt 0) {throw 'Bytes must be nonnegative.'}
$directory=Join-Path ([IO.Path]::GetFullPath($WorkDirectory)) ([guid]::NewGuid().ToString());$null=[IO.Directory]::CreateDirectory($directory)
$source=Join-Path $directory 'large binary.bin';$stream=[IO.File]::Open($source,[IO.FileMode]::CreateNew);$buffer=[byte[]]::new(4194304);$remaining=$Bytes
try {while ($remaining -gt 0) {[Security.Cryptography.RandomNumberGenerator]::Fill($buffer);$n=[int][math]::Min($remaining,$buffer.Length);$stream.Write($buffer,0,$n);$remaining-=$n}} finally {$stream.Dispose()}
Import-Module "$PSScriptRoot/../src/Core/Tqsim.psm1" -Force
$clock=[Diagnostics.Stopwatch]::StartNew();Split-Tqsim -File $source -Size 16777213 -Quiet
$parts=Join-Path $directory 'Output';Test-Tqsim -PartsPath $parts -Quiet;Merge-Tqsim -PartsPath $parts -Quiet
$restored=Join-Path $parts 'Output/large binary.bin'
if ((Get-FileHash -LiteralPath $source).Hash -cne (Get-FileHash -LiteralPath $restored).Hash) {throw 'Round-trip mismatch.'}
Write-Output "PASS: $Bytes byte binary round trip; elapsed $($clock.Elapsed); files retained at $directory"
