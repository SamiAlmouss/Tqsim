. "$PSScriptRoot/TestSupport.ps1"
Describe 'Integrity verification' {
    It 'verifies all parts and the original digest' {$f=New-SplitFixture;Test-Tqsim -PartsPath $f.Parts -Quiet}
    It 'rejects missing parts' {$f=New-SplitFixture;[IO.File]::Delete((Join-Path $f.Parts 'data.bin.part0002'));{Test-Tqsim -PartsPath $f.Parts -Quiet}|Should Throw}
    It 'detects same-length content modification' {$f=New-SplitFixture;$p=Join-Path $f.Parts 'data.bin.part0001';$bytes=[IO.File]::ReadAllBytes($p);$bytes[0]=$bytes[0] -bxor 255;[IO.File]::WriteAllBytes($p,$bytes);{Test-Tqsim -PartsPath $f.Parts -Quiet}|Should Throw}
    It 'detects truncation' {$f=New-SplitFixture;[IO.File]::WriteAllBytes((Join-Path $f.Parts 'data.bin.part0001'),[byte[]]::new(2));{Test-Tqsim -PartsPath $f.Parts -Quiet}|Should Throw}
    It 'rejects a false original digest' {$f=New-SplitFixture;$null=Change-TestManifest $f {param($m)$m.originalSHA256='0'*64};{Test-Tqsim -PartsPath $f.Parts -Quiet}|Should Throw}
}
