. "$PSScriptRoot/TestSupport.ps1"
Describe 'Manifest validation' {
    It 'rejects traversal' {$f=New-SplitFixture;$p=Change-TestManifest $f {param($m)$m.parts[0].fileName='../outside'};{Read-TqsimManifest $p}|Should Throw}
    It 'rejects duplicate names' {$f=New-SplitFixture;$p=Change-TestManifest $f {param($m)$m.parts[1].fileName=$m.parts[0].fileName};{Read-TqsimManifest $p}|Should Throw}
    It 'rejects unsupported versions' {$f=New-SplitFixture;$p=Change-TestManifest $f {param($m)$m.manifestVersion=2};{Read-TqsimManifest $p}|Should Throw}
    It 'rejects malformed hashes' {$f=New-SplitFixture;$p=Change-TestManifest $f {param($m)$m.parts[0].sha256='bad'};{Read-TqsimManifest $p}|Should Throw}
    It 'rejects fractional lengths' {$f=New-SplitFixture;$p=Change-TestManifest $f {param($m)$m.originalSize=10003.5};{Read-TqsimManifest $p}|Should Throw}
    It 'rejects malformed JSON' {$p=Join-Path $TestDrive 'invalid.json';[IO.File]::WriteAllText($p,'{');{Read-TqsimManifest $p}|Should Throw}
    It 'rejects duplicate JSON properties' {$f=New-SplitFixture;$p=Join-Path $f.Parts 'data.bin.tqsim.json';$json=[IO.File]::ReadAllText($p);$json=$json.Replace('"manifestVersion": 1','"manifestVersion": 1, "manifestVersion": 1');[IO.File]::WriteAllText($p,$json);{Read-TqsimManifest $p}|Should Throw}
    It 'rejects absolute part paths' {$f=New-SplitFixture;$p=Change-TestManifest $f {param($m)$m.parts[0].fileName='C:\outside.bin'};{Read-TqsimManifest $p}|Should Throw}
    It 'requires selection when multiple manifests exist' {$f=New-SplitFixture;Copy-Item (Join-Path $f.Parts 'data.bin.tqsim.json') (Join-Path $f.Parts 'second.tqsim.json');{Find-TqsimManifest $f.Parts ''}|Should Throw}
}
