. "$PSScriptRoot/TestSupport.ps1"
Describe 'Public CLI' {
    It 'reports version without logo' {$result=& pwsh -NoProfile -File "$projectRoot/tqsim.ps1" version -NoLogo;$LASTEXITCODE|Should Be 0;$result|Should Be '1.0.0'}
    It 'rejects unknown commands with usage exit code' {& pwsh -NoProfile -File "$projectRoot/tqsim.ps1" unknown -Quiet 2>$null;$LASTEXITCODE|Should Be 2}
    It 'supports mixed-case split and merge alias' {$f=New-TestFixture 101;& pwsh -NoProfile -File "$projectRoot/tqsim.ps1" SpLiT -File $f.Source -Size 20 -Output $f.Parts -Quiet;$LASTEXITCODE|Should Be 0;& pwsh -NoProfile -File "$projectRoot/tqsim.ps1" MeRgE -PartsPath $f.Parts -Output $f.Restored -Quiet;$LASTEXITCODE|Should Be 0}
    It 'returns integrity exit code for malformed metadata' {$f=New-SplitFixture;$null=Change-TestManifest $f {param($m)$m.manifestVersion=99};& pwsh -NoProfile -File "$projectRoot/tqsim.ps1" verify -PartsPath $f.Parts -Quiet 2>$null;$LASTEXITCODE|Should Be 3}
}
