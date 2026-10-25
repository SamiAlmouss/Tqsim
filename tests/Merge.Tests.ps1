. "$PSScriptRoot/TestSupport.ps1"
Describe 'Verified reconstruction' {
    It 'round trips random binary data' {$f=New-SplitFixture;Merge-Tqsim -PartsPath $f.Parts -Output $f.Restored -Quiet;(Get-FileHash $f.Source).Hash|Should Be (Get-FileHash (Join-Path $f.Restored 'data.bin')).Hash}
    It 'round trips empty data' {$f=New-SplitFixture 0;Merge-Tqsim -PartsPath $f.Parts -Output $f.Restored -Quiet;(Get-Item (Join-Path $f.Restored 'data.bin')).Length|Should Be 0}
    It 'round trips Unicode and spaces with different buffers' {$f=New-TestFixture 25001 '測試 file.bin';Split-Tqsim -File $f.Source -Size 8000 -Output $f.Parts -BufferSize 4096 -Quiet;Merge-Tqsim -PartsPath $f.Parts -Output $f.Restored -BufferSize 8192 -Quiet;(Get-FileHash $f.Source).Hash|Should Be (Get-FileHash (Join-Path $f.Restored '測試 file.bin')).Hash}
    It 'requires overwrite authorization' {$f=New-SplitFixture;Merge-Tqsim -PartsPath $f.Parts -Output $f.Restored -Quiet;{Merge-Tqsim -PartsPath $f.Parts -Output $f.Restored -Quiet}|Should Throw;Merge-Tqsim -PartsPath $f.Parts -Output $f.Restored -Overwrite -Quiet}
    It 'never publishes corrupt output' {$f=New-SplitFixture;[IO.File]::WriteAllBytes((Join-Path $f.Parts 'data.bin.part0001'),[byte[]]::new(1000));{Merge-Tqsim -PartsPath $f.Parts -Output $f.Restored -Quiet}|Should Throw;(Test-Path (Join-Path $f.Restored 'data.bin'))|Should Be $false}
}
