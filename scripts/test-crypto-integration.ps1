#requires -Version 7.0
[CmdletBinding()]param([long]$Bytes=67108881,[string]$WorkRoot=(Join-Path $PSScriptRoot '../.test-work/crypto-integration'))
$ErrorActionPreference='Stop';$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$work=Join-Path ([IO.Path]::GetFullPath($WorkRoot)) ([guid]::NewGuid().ToString());$null=[IO.Directory]::CreateDirectory($work)
$savedLocal=$env:LOCALAPPDATA;$env:LOCALAPPDATA=Join-Path $work 'local-appdata'
Import-Module (Join-Path $root 'src/Core/Tqsim.psm1') -Force
# Only the secret reader is replaced, within this disposable test process. This
# publicly documented nonsecret test credential never becomes a CLI option.
& (Get-Module Tqsim) {function script:Read-TqsimSecret {ConvertTo-SecureString 'nonsecret integration passphrase 106' -AsPlainText -Force}}
$source=Join-Path $work 'fixture.bin';$s=New-TqsimStream $source CreateNew Write;$buffer=[byte[]]::new(4194304);[long]$remaining=$Bytes
try {while($remaining -gt 0){[Security.Cryptography.RandomNumberGenerator]::Fill($buffer);$n=Get-TqsimReadCount $buffer.Length $remaining;$s.Write($buffer,0,$n);$remaining-=$n};$s.Flush($true)} finally {$s.Dispose()}
$hash=(Get-FileHash -LiteralPath $source).Hash;$results=[Collections.Generic.List[object]]::new()
$cases=@(@{Encrypt='false';Ds='false';Verify='true';Size='1GB'},@{Encrypt='true';Ds='false';Verify='true';Size='1GB'},@{Encrypt='true';Ds='false';Verify='false';Size='2GB'},@{Encrypt='true';Ds='true';Verify='true';Size='4GB'},@{Encrypt='true';Ds='true';Verify='false';Size='4GB'})
try {foreach($case in $cases){
    $dir=Join-Path $work ($case.Encrypt+'-'+$case.Ds+'-'+$case.Verify);$null=[IO.Directory]::CreateDirectory($dir);$file=Join-Path $dir 'نسخة large.bin';[IO.File]::Copy($source,$file);$parts=Join-Path $dir 'parts'
    Write-Output "Testing encrypted=$($case.Encrypt), ds=$($case.Ds), verify=$($case.Verify), size=$($case.Size), bytes=$Bytes"
    $clock=[Diagnostics.Stopwatch]::StartNew();Split-Tqsim -File $file -Size $case.Size -Output $parts -encrypt $case.Encrypt -ds $case.Ds -verify $case.Verify -Quiet;$clock.Stop();$splitSeconds=$clock.Elapsed.TotalSeconds
    if([IO.File]::Exists($file) -ne ($case.Ds -eq 'false')){throw 'Source-retention mismatch.'}
    $manifest=Join-Path $parts 'نسخة large.bin.tqsim.json';$m=Read-TqsimManifest $manifest
    foreach($part in $m.parts){if($part.size -gt (ConvertTo-TqsimSize $case.Size)){throw 'Physical part exceeds configured size.'}}
    $clock.Restart();Merge-Tqsim -PartsPath $parts -ds $case.Ds -verify $case.Verify -Quiet;$clock.Stop();$mergeSeconds=$clock.Elapsed.TotalSeconds
    $output=Join-Path $parts 'نسخة large.bin';if((Get-FileHash -LiteralPath $output).Hash -cne $hash -or (Get-Item -LiteralPath $output).Length -ne $Bytes){throw 'Independent plaintext SHA256/length mismatch.'}
    if([IO.Directory]::Exists((Join-Path $parts 'Output'))){throw 'Unexpected Output directory.'}
    if(@(Get-ChildItem -LiteralPath $parts -Filter '.tqsim-cleanup-*.json').Count){throw 'Successful cleanup left a journal.'}
    if($case.Ds -eq 'true' -and ([IO.File]::Exists($manifest) -or @(Get-ChildItem $parts -Filter '*.part*').Count)){throw 'Incomplete source cleanup.'}
    $row=[ordered]@{encrypted=$case.Encrypt;ds=$case.Ds;verify=$case.Verify;partSize=$case.Size;bytes=$Bytes;partLengths=@($m.parts.size);splitSeconds=$splitSeconds;mergeSeconds=$mergeSeconds;splitMiBps=($Bytes/1MB/$splitSeconds);mergeMiBps=($Bytes/1MB/$mergeSeconds);sha256=$hash;output=$output};$results.Add($row);Write-Output ($row|ConvertTo-Json -Compress)
};$report=Join-Path $work 'results.json';[IO.File]::WriteAllText($report,($results|ConvertTo-Json -Depth 8));Write-Output "PASS: $report"}finally{$env:LOCALAPPDATA=$savedLocal;Import-Module (Join-Path $root 'src/Core/Tqsim.psm1') -Force}
