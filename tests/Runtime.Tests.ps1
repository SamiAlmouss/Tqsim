. "$PSScriptRoot/TestSupport.ps1"
Describe 'Split runtime regression coverage' {
    It 'round trips <Length> bytes through the CLI with 1GB configured parts' -TestCases @(@{Length=1048576},@{Length=5242880}) {
        param($Length)
        $f=New-TestFixture $Length 'disposable data.bin';$hash=(Get-FileHash -LiteralPath $f.Source).Hash
        & pwsh -NoProfile -File "$projectRoot/tqsim.ps1" split -File $f.Source -Size 1GB -Output $f.Parts -NoLogo -Diagnostics
        $LASTEXITCODE | Should Be 0
        & pwsh -NoProfile -File "$projectRoot/tqsim.ps1" verify -PartsPath $f.Parts -Quiet -Diagnostics
        $LASTEXITCODE | Should Be 0
        & pwsh -NoProfile -File "$projectRoot/tqsim.ps1" merge -PartsPath $f.Parts -Output $f.Restored -Quiet -Diagnostics
        $LASTEXITCODE | Should Be 0
        (Get-FileHash -LiteralPath (Join-Path $f.Restored 'disposable data.bin')).Hash | Should Be $hash
        (Get-FileHash -LiteralPath $f.Source).Hash | Should Be $hash
    }
    It 'handles an exact chunk boundary and multiple full parts' {
        $f=New-TestFixture 2097152;Split-Tqsim -File $f.Source -Size 1MB -Output $f.Parts -Quiet
        $m=Read-TqsimManifest (Join-Path $f.Parts 'data.bin.tqsim.json')
        $m.totalParts | Should Be 2
        $m.parts[0].size | Should Be 1048576
        $m.parts[1].size | Should Be 1048576
        Merge-Tqsim -PartsPath $f.Parts -Output $f.Restored -Quiet
        (Get-FileHash -LiteralPath (Join-Path $f.Restored 'data.bin')).Hash | Should Be (Get-FileHash -LiteralPath $f.Source).Hash
    }
    It 'refuses pre-existing incomplete part names without changing data' {
        $f=New-TestFixture 2097169;$null=[IO.Directory]::CreateDirectory($f.Parts)
        $part=Join-Path $f.Parts 'data.bin.part0001';[IO.File]::WriteAllText($part,'incomplete previous attempt')
        $hash=(Get-FileHash -LiteralPath $f.Source).Hash;$partHash=(Get-FileHash -LiteralPath $part).Hash
        {Split-Tqsim -File $f.Source -Size 1MB -Output $f.Parts -Quiet} | Should Throw
        (Get-FileHash -LiteralPath $part).Hash | Should Be $partHash
        (Get-FileHash -LiteralPath $f.Source).Hash | Should Be $hash
        @(Get-ChildItem -LiteralPath $f.Parts -File).Count | Should Be 1
    }
    It 'preserves foreign temporary files and uses a unique staging name' {
        $f=New-TestFixture 1048593;$null=[IO.Directory]::CreateDirectory($f.Parts)
        $foreign=Join-Path $f.Parts '.tqsim-old-attempt.tmp';[IO.File]::WriteAllText($foreign,'preserve')
        Split-Tqsim -File $f.Source -Size 1MB -Output $f.Parts -Quiet
        [IO.File]::ReadAllText($foreign) | Should Be 'preserve'
        Test-Tqsim -PartsPath $f.Parts -Quiet
    }
    It 'cleans its partial write after simulated interruption and keeps the source' {
        if (!('Tqsim.Tests.InterruptedFileStream' -as [type])) {
            Add-Type -TypeDefinition @'
namespace Tqsim.Tests {
    public class InterruptedFileStream : System.IO.FileStream {
        private int writes;
        public InterruptedFileStream(string path) : base(path, System.IO.FileMode.CreateNew, System.IO.FileAccess.Write, System.IO.FileShare.Read) {}
        public override void Write(byte[] buffer, int offset, int count) {
            if (writes++ == 1) throw new System.OperationCanceledException("Simulated mid-part interruption");
            base.Write(buffer, offset, count);
        }
    }
}
'@
        }
        $f=New-TestFixture 1048576;$hash=(Get-FileHash -LiteralPath $f.Source).Hash
        Mock New-TqsimStream {[Tqsim.Tests.InterruptedFileStream]::new($Path)} -ModuleName Tqsim -ParameterFilter {$Access -eq [IO.FileAccess]::Write}
        {Split-Tqsim -File $f.Source -Size 1GB -Output $f.Parts -BufferSize 4096 -Quiet} | Should Throw
        @(Get-ChildItem -LiteralPath $f.Parts -Force).Count | Should Be 0
        (Get-FileHash -LiteralPath $f.Source).Hash | Should Be $hash
    }
}

Describe 'Strict size parsing' {
    It 'keeps caller match state intact and parses a missing optional suffix' {
        $null='caller-value' -match '(caller)-(value)';$before=$Matches.Clone()
        (ConvertTo-TqsimSize '1GB') | Should Be 1073741824L
        (ConvertTo-TqsimSize '2gb') | Should Be 2147483648L
        (ConvertTo-TqsimSize '4GiB') | Should Be 4294967296L
        (ConvertTo-TqsimSize '17') | Should Be 17L
        $Matches[1] | Should Be $before[1]
        $Matches[2] | Should Be $before[2]
    }
    It 'rejects invalid input under StrictMode' -TestCases @(@{Size=''},@{Size='0'},@{Size='-1GB'},@{Size='1.5GB'},@{Size='1GBjunk'},@{Size='9223372036854775808'}) {
        param($Size)
        {ConvertTo-TqsimSize $Size} | Should Throw
    }
}

Describe 'Progress calculations under StrictMode' {
    It 'calculates measured speed, percentage, completed parts and ETA' {
        $metrics=Get-TqsimProgressMetrics 100L 200L 2L 2.0
        $metrics.Rate | Should Be 50
        $metrics.Percent | Should Be 50
        $metrics.CompletedParts | Should Be 1
        $metrics.Eta | Should Be 2
    }
    It 'handles zero elapsed time without property access or division by zero' {
        $metrics=Get-TqsimProgressMetrics 1L 2L 1L 0.0
        $metrics.Rate | Should Be 1000
        $metrics.Eta | Should Be 0.001
        $metrics.Percent | Should Be 50
    }
    It 'handles empty data and Int64 byte and part counts' {
        $empty=Get-TqsimProgressMetrics 0L 0L 0L 0.0
        $empty.Rate | Should Be 0
        $empty.Percent | Should Be 100
        $large=Get-TqsimProgressMetrics 2147483648L 4294967296L 2147483649L 2.0
        $large.CompletedParts | Should Be 2147483648L
        $large.Percent | Should Be 50
        $large.Eta | Should Be 2
    }
}
