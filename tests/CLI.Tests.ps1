. "$PSScriptRoot/TestSupport.ps1"
Describe 'Public CLI' {
    It 'reports version without logo' {$result=& pwsh -NoProfile -File "$projectRoot/tqsim.ps1" version -NoLogo;$LASTEXITCODE|Should Be 0;$result|Should Be '1.0.5'}
    It 'rejects unknown commands with usage exit code' {& pwsh -NoProfile -File "$projectRoot/tqsim.ps1" unknown -Quiet 2>$null;$LASTEXITCODE|Should Be 2}
    It 'supports mixed-case split and merge alias' {$f=New-TestFixture 101;& pwsh -NoProfile -File "$projectRoot/tqsim.ps1" SpLiT -File $f.Source -Size 20 -Output $f.Parts -Quiet;$LASTEXITCODE|Should Be 0;& pwsh -NoProfile -File "$projectRoot/tqsim.ps1" MeRgE -PartsPath $f.Parts -Output $f.Restored -Quiet;$LASTEXITCODE|Should Be 0}
    It 'returns integrity exit code for malformed metadata' {$f=New-SplitFixture;$null=Change-TestManifest $f {param($m)$m.manifestVersion=99};& pwsh -NoProfile -File "$projectRoot/tqsim.ps1" verify -PartsPath $f.Parts -Quiet 2>$null;$LASTEXITCODE|Should Be 3}
    It 'keeps normal errors readable and diagnostics opt-in' {
        $result=(& pwsh -NoProfile -File "$projectRoot/tqsim.ps1" split -File unused -Size invalid -Quiet 2>&1|Out-String)
        $LASTEXITCODE | Should Be 2
        $result | Should Match 'FAILED: Invalid size'
        $result | Should Not Match 'ScriptStackTrace|DEVELOPER DIAGNOSTICS'
    }
    It 'reports actual exception type, script line and stack in diagnostics mode' {
        $result=(& pwsh -NoProfile -File "$projectRoot/tqsim.ps1" split -File unused -Size invalid -Quiet -Diagnostics 2>&1|Out-String)
        $LASTEXITCODE | Should Be 2
        $result | Should Match 'Exception type: System.ArgumentException'
        $result | Should Match 'Source script: .*Tqsim.psm1'
        $result | Should Match 'Line: [1-9][0-9]*'
        $result | Should Match 'ScriptStackTrace: at ConvertTo-TqsimSize'
    }
    It 'preserves inner exceptions from manifest validation' {
        $path=Join-Path $TestDrive 'bad.json';[IO.File]::WriteAllText($path,'{')
        $result=(& pwsh -NoProfile -File "$projectRoot/tqsim.ps1" info -Manifest $path -Quiet -Diagnostics 2>&1|Out-String)
        $LASTEXITCODE | Should Be 3
        $result | Should Match 'Inner exception:'
        $result | Should Match 'ScriptStackTrace:'
    }
}
