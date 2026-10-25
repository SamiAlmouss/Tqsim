. "$PSScriptRoot/TestSupport.ps1"
Describe 'Streaming split' {
    It 'handles empty files without empty parts' {$f=New-SplitFixture 0;$m=Read-TqsimManifest (Join-Path $f.Parts 'data.bin.tqsim.json');$m.totalParts|Should Be 0;$m.originalSize|Should Be 0}
    It 'handles tiny files' {$f=New-SplitFixture 1;@(Get-ChildItem $f.Parts -Filter '*.part*').Count|Should Be 1}
    It 'does not create an extra divisible part' {$f=New-SplitFixture 2000;@(Get-ChildItem $f.Parts -Filter '*.part*').Count|Should Be 2}
    It 'writes the exact smaller final part' {$f=New-SplitFixture 2001;(Get-Item (Join-Path $f.Parts 'data.bin.part0003')).Length|Should Be 1}
    It 'rejects collisions and preserves source' {$f=New-SplitFixture;{Split-Tqsim -File $f.Source -Size 1000 -Output $f.Parts -Quiet}|Should Throw;(Get-Item $f.Source).Length|Should Be 10003}
    It 'uses Int64 size arithmetic' {(ConvertTo-TqsimSize '4GB')|Should Be 4294967296;(ConvertTo-TqsimSize '1024MiB')|Should Be 1073741824}
    It 'rejects overflow and zero sizes' {{ConvertTo-TqsimSize '9223372036854775808'}|Should Throw;{ConvertTo-TqsimSize '0'}|Should Throw}
    It 'rejects missing source' {{Split-Tqsim -File (Join-Path $TestDrive 'absent') -Size 1 -Quiet}|Should Throw}
    It 'cleans up when a write is interrupted' {
        $f=New-TestFixture
        Mock New-TqsimStream {throw [OperationCanceledException]::new('Cancelled')} -ModuleName Tqsim -ParameterFilter {$Access -eq [IO.FileAccess]::Write}
        {Split-Tqsim -File $f.Source -Size 1000 -Output $f.Parts -Quiet}|Should Throw
        @(Get-ChildItem -LiteralPath $f.Parts -Force).Count|Should Be 0
        (Get-Item $f.Source).Length|Should Be 10003
    }
}
