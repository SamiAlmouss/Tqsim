. "$PSScriptRoot/TestSupport.ps1"
Describe 'Strict Delete Source parsing' {
    It 'defaults to retention and accepts only the two boolean strings, case insensitive' {
        Resolve-TqsimDeleteSourceOption | Should Be $false
        foreach ($value in 'false','FALSE','False') {Resolve-TqsimDeleteSourceOption $value | Should Be $false}
        foreach ($value in 'true','TRUE','True') {Resolve-TqsimDeleteSourceOption $value | Should Be $true}
        foreach ($value in 'yes','no','1','0','',' true','false ','anything','$false') {{Resolve-TqsimDeleteSourceOption $value}|Should Throw}
        foreach ($command in 'split','merge','merg') {
            foreach ($value in 'true','false','TRUE','FALSE') {(Resolve-TqsimInvocation @($command,'-ds',$value)).Options.ds | Should Be $value}
            foreach ($arguments in @(@($command,'-ds'),@($command,'-ds',''),@($command,'-ds','yes'),@($command,'-ds','1'),@($command,'-ds','true','-ds','false'))) {{Resolve-TqsimInvocation $arguments}|Should Throw}
        }
    }
    It 'help with ds true never calls the processing engine' {
        (Resolve-TqsimInvocation @('split','-ds','true','--help')).Command | Should Be help
        (Resolve-TqsimInvocation @('merg','-ds','true','-h')).Command | Should Be help
        {Resolve-TqsimInvocation @('verify','-ds','true')} | Should Throw
    }
}
Describe 'Real disposable verified deletion' {
    It 'retains sources by default and with explicit false for both commands' {
        foreach ($value in @($null,'false')) {
            $f=New-TestFixture;$p=@{};if ($value) {$p.ds=$value}
            Split-Tqsim -File $f.Source -Size 1000 -Output $f.Parts -Quiet @p
            Merge-Tqsim -PartsPath $f.Parts -Output $f.Restored -Quiet @p
            [IO.File]::Exists($f.Source)|Should Be $true
            @(Get-ChildItem $f.Parts).Count|Should Be 12
            (Get-FileHash "$($f.Restored)/data.bin").Hash|Should Be (Get-FileHash $f.Source).Hash
        }
    }
    It 'deletes only verified sources in a Unicode multipart round trip' {
        $f=New-TestFixture 10003 'نسخة 測試 with spaces.bin';$expected=(Get-FileHash $f.Source).Hash
        Split-Tqsim -File $f.Source -Size 1000 -Output $f.Parts -ds TRUE -Quiet
        [IO.File]::Exists($f.Source)|Should Be $false
        Test-Tqsim -PartsPath $f.Parts -Quiet
        [IO.File]::WriteAllText((Join-Path $f.Parts 'unrelated.part9999'),'preserve')
        Merge-Tqsim -PartsPath $f.Parts -Output $f.Restored -ds true -Quiet
        (Get-FileHash (Join-Path $f.Restored 'نسخة 測試 with spaces.bin')).Hash|Should Be $expected
        [IO.File]::ReadAllText((Join-Path $f.Parts 'unrelated.part9999'))|Should Be preserve
        @(Get-ChildItem $f.Parts -Filter '*.tqsim.json').Count|Should Be 0
        $journal=Get-Content (Get-ChildItem $f.Restored -Filter '.tqsim-cleanup-*.json').FullName -Raw|ConvertFrom-Json
        $journal.state|Should Be completed;$journal.targets.Count|Should Be 12
        $journal.targets[-1].Path|Should Match '\.tqsim\.json$'
        @($journal.targets|Where-Object Status -ne deleted).Count|Should Be 0
    }
    It 'handles zero bytes and exact chunk boundaries' {
        foreach ($length in 0,2000) {
            $f=New-TestFixture $length;$expected=(Get-FileHash $f.Source).Hash
            Split-Tqsim -File $f.Source -Size 1000 -Output $f.Parts -ds true -Quiet
            Merge-Tqsim -PartsPath $f.Parts -Output $f.Restored -ds true -Quiet
            (Get-FileHash "$($f.Restored)/data.bin").Hash|Should Be $expected
            [IO.File]::Exists($f.Source)|Should Be $false
        }
    }
    It 'preserves sources on split collisions and invalid ds' {
        $f=New-SplitFixture;$expected=(Get-FileHash $f.Source).Hash
        {Split-Tqsim -File $f.Source -Size 1000 -Output $f.Parts -ds true -Quiet}|Should Throw
        {Split-Tqsim -File $f.Source -Size 1000 -Output $f.Parts -ds invalid -Quiet}|Should Throw
        (Get-FileHash $f.Source).Hash|Should Be $expected
    }
    It 'preserves every remaining merge source on corrupt or missing parts' {
        foreach ($missing in $true,$false) {
            $f=New-SplitFixture;$part=Join-Path $f.Parts 'data.bin.part0002'
            if ($missing) {[IO.File]::Delete($part)} else {[IO.File]::WriteAllBytes($part,[byte[]]::new(1000))}
            {Merge-Tqsim -PartsPath $f.Parts -Output $f.Restored -ds true -Quiet}|Should Throw
            [IO.File]::Exists((Join-Path $f.Parts 'data.bin.part0001'))|Should Be $true
            [IO.File]::Exists((Join-Path $f.Parts 'data.bin.tqsim.json'))|Should Be $true
        }
    }
    It 'refuses shared or ambiguous manifests without deleting anything' {
        foreach ($invalid in $true,$false) {
            $f=New-SplitFixture;$manifest=Join-Path $f.Parts 'data.bin.tqsim.json';$other=Join-Path $f.Parts 'other.tqsim.json'
            if ($invalid) {[IO.File]::WriteAllText($other,'{}')} else {[IO.File]::Copy($manifest,$other)}
            {Merge-Tqsim -Manifest $manifest -Output $f.Restored -ds true -Quiet}|Should Throw
            @(Get-ChildItem $f.Parts).Count|Should Be 13
        }
    }
    It 'keeps unrelated valid split sets and directories intact' {
        $f=New-SplitFixture;$other=Join-Path $f.Directory 'other.bin';[IO.File]::WriteAllText($other,'unrelated')
        Split-Tqsim -File $other -Size 1000 -Output $f.Parts -Quiet
        Merge-Tqsim -Manifest (Join-Path $f.Parts 'data.bin.tqsim.json') -Output $f.Restored -ds true -Quiet
        Test-Tqsim -Manifest (Join-Path $f.Parts 'other.bin.tqsim.json') -Quiet
        [IO.Directory]::Exists($f.Parts)|Should Be $true
    }
    It 'rejects source/output collisions before cleanup' {
        $f=New-SplitFixture;$p=Change-TestManifest $f {param($m)$m.originalFileName=$m.parts[0].fileName}
        {Merge-Tqsim -Manifest $p -Output $f.Parts -Overwrite -ds true -Quiet}|Should Throw
        @(Get-ChildItem $f.Parts).Count|Should Be 12
    }
    It 'deletes disposable sources safely across the C and D volumes' {
        $f=New-TestFixture;$hash=(Get-FileHash $f.Source).Hash
        $cross=Join-Path $projectRoot ('.test-work/cross-drive-'+[guid]::NewGuid())
        [IO.Path]::GetPathRoot($f.Source)|Should Not Be ([IO.Path]::GetPathRoot($cross))
        Split-Tqsim -File $f.Source -Size 1000 -Output $cross -ds true -Quiet
        Merge-Tqsim -PartsPath $cross -Output $f.Restored -ds true -Quiet
        (Get-FileHash "$($f.Restored)/data.bin").Hash|Should Be $hash
    }
    It 'reports an actual read-only-file cleanup failure without deleting the manifest' {
        $f=New-SplitFixture;$part=Join-Path $f.Parts 'data.bin.part0002';$hash=(Get-FileHash $f.Source).Hash
        [IO.File]::SetAttributes($part,[IO.FileAttributes]::ReadOnly)
        try {
            {Merge-Tqsim -PartsPath $f.Parts -Output $f.Restored -ds true -Quiet}|Should Throw
            [IO.File]::Exists($part)|Should Be $true
            [IO.File]::Exists((Join-Path $f.Parts 'data.bin.part0001'))|Should Be $false
            [IO.File]::Exists((Join-Path $f.Parts 'data.bin.tqsim.json'))|Should Be $true
            (Get-FileHash "$($f.Restored)/data.bin").Hash|Should Be $hash
        } finally {[IO.File]::SetAttributes($part,[IO.FileAttributes]::Normal)}
    }
    It 'rejects hard links and reparse-point ancestors' {
        $f=New-TestFixture;$link=Join-Path $f.Directory 'linked.bin'
        $null=New-Item -ItemType HardLink -Path $link -Target $f.Source
        {Split-Tqsim -File $link -Size 1000 -Output $f.Parts -ds true -Quiet}|Should Throw
        [IO.File]::Exists($link)|Should Be $true
        $g=New-TestFixture;$junction=Join-Path $g.Directory 'junction'
        $null=New-Item -ItemType Junction -Path $junction -Target $f.Directory
        {Split-Tqsim -File (Join-Path $junction 'data.bin') -Size 1000 -Output $g.Parts -ds true -Quiet}|Should Throw
        [IO.File]::Exists($f.Source)|Should Be $true
    }
    It 'leaves an honest write-ahead journal and verified output after forced process termination' {
        $f=New-SplitFixture;$hash=(Get-FileHash $f.Source).Hash;$signal=Join-Path $f.Directory 'pause.signal'
        $info=[Diagnostics.ProcessStartInfo]::new((Join-Path $PSHOME 'pwsh.exe'))
        $info.UseShellExecute=$false;$info.CreateNoWindow=$true
        foreach ($argument in @('-NoProfile','-File',"$PSScriptRoot/fixtures/CleanupTerminationHarness.ps1",'-ProjectRoot',$projectRoot,'-Parts',$f.Parts,'-Output',$f.Restored,'-Signal',$signal)) {$info.ArgumentList.Add($argument)}
        $process=[Diagnostics.Process]::new();$process.StartInfo=$info
        try {
            $null=$process.Start();$deadline=[datetime]::UtcNow.AddSeconds(30)
            while (![IO.File]::Exists($signal) -and !$process.HasExited -and [datetime]::UtcNow -lt $deadline) {Start-Sleep -Milliseconds 100}
            [IO.File]::Exists($signal)|Should Be $true
            $process.Kill($true);$process.WaitForExit(10000)|Should Be $true
            (Get-FileHash "$($f.Restored)/data.bin").Hash|Should Be $hash
            [IO.File]::Exists((Join-Path $f.Parts 'data.bin.part0001'))|Should Be $false
            [IO.File]::Exists((Join-Path $f.Parts 'data.bin.tqsim.json'))|Should Be $true
            $j=Get-Content (Get-ChildItem $f.Restored -Filter '.tqsim-cleanup-*.json').FullName -Raw|ConvertFrom-Json
            $j.state|Should Be cleaning;$j.targets[0].Status|Should Be deleting
            @($j.targets|Where-Object Status -eq pending).Count|Should Be 11
            @(Get-ChildItem $f.Parts -Filter '*.part*').Count|Should Be 10
        } finally {if (!$process.HasExited) {$process.Kill($true);$process.WaitForExit()};$process.Dispose()}
    }
    It 'forwards ds through the real CLI and an installed-style cmd launcher' {
        $launcher=Join-Path $TestDrive 'tqsim.cmd'
        [IO.File]::WriteAllText($launcher,"@echo off`r`npwsh -NoProfile -File `"$projectRoot\tqsim.ps1`" %*`r`nexit /b %errorlevel%`r`n")
        foreach ($run in 'direct','launcher') {
            $f=New-TestFixture 10003 'نسخة space.bin';$hash=(Get-FileHash $f.Source).Hash
            if ($run -eq 'direct') {& pwsh -NoProfile -File "$projectRoot/tqsim.ps1" split -File $f.Source -Size 1000 -Output $f.Parts -ds false -Quiet}
            else {& $launcher split -File $f.Source -Size 1000 -Output $f.Parts -ds false -Quiet}
            $LASTEXITCODE|Should Be 0;[IO.File]::Exists($f.Source)|Should Be $true
            & $launcher merg -PartsPath $f.Parts -Output $f.Restored -ds TRUE -Quiet
            $LASTEXITCODE|Should Be 0;(Get-FileHash (Join-Path $f.Restored 'نسخة space.bin')).Hash|Should Be $hash
        }
        foreach ($value in '','yes','0') {
            $f=New-TestFixture
            & pwsh -NoProfile -File "$projectRoot/tqsim.ps1" split -File $f.Source -Size 1000 -Output $f.Parts -ds $value -Quiet 2>$null
            $LASTEXITCODE|Should Be 2;[IO.File]::Exists($f.Source)|Should Be $true
        }
    }
}
    Describe 'Deletion failures and interruption boundaries' {
        Context 'keeps the source if independent disk verification fails after split' {
        It 'keeps the source if independent disk verification fails after split' {
            $f=New-TestFixture
            Mock Invoke-TqsimParts -ModuleName Tqsim {throw [IO.InvalidDataException]::new('injected disk mismatch')}
            {Split-Tqsim -File $f.Source -Size 1000 -Output $f.Parts -ds true -Quiet}|Should Throw
            [IO.File]::Exists($f.Source)|Should Be $true
            [IO.File]::Exists((Join-Path $f.Parts 'data.bin.tqsim.json'))|Should Be $true
        }
        }
        Context 'keeps all sources on cancellation before cleanup' {
        It 'keeps all sources on cancellation before cleanup' {
            $f=New-TestFixture
            Mock Invoke-TqsimParts -ModuleName Tqsim {throw [OperationCanceledException]::new('cancel verification')}
            {Split-Tqsim -File $f.Source -Size 1000 -Output $f.Parts -ds true -Quiet}|Should Throw
            [IO.File]::Exists($f.Source)|Should Be $true
        }
        }
        Context 'keeps merge sources if the independently reopened output fails verification' {
        It 'keeps merge sources if the independently reopened output fails verification' {
            $f=New-SplitFixture
            Mock Get-TqsimStreamDigest -ModuleName Tqsim {
                param($Stream)
                if ($Stream.Name -like '*restored*') {return ('0'*64)}
                $h=[Security.Cryptography.SHA256]::Create();try {$Stream.Position=0;return ConvertTo-TqsimHex ($h.ComputeHash($Stream))} finally {$h.Dispose();$Stream.Position=0}
            }
            {Merge-Tqsim -PartsPath $f.Parts -Output $f.Restored -ds true -Quiet}|Should Throw
            @(Get-ChildItem $f.Parts).Count|Should Be 12
            [IO.File]::Exists((Join-Path $f.Restored 'data.bin'))|Should Be $true
        }
        }
        Context 'preserves sources if publishing fails before cleanup' {
        It 'preserves sources if publishing fails before cleanup' {
            $f=New-SplitFixture;$null=[IO.Directory]::CreateDirectory((Join-Path $f.Restored 'data.bin'))
            {Merge-Tqsim -PartsPath $f.Parts -Output $f.Restored -ds true -Quiet}|Should Throw
            @(Get-ChildItem $f.Parts).Count|Should Be 12
        }
        }
        Context 'preserves sources on split write I/O failure and interrupted merge writes' {
        It 'preserves sources on split write I/O failure and interrupted merge writes' {
            $f=New-TestFixture
            Mock New-TqsimStream -ModuleName Tqsim {throw [IO.IOException]::new('injected write failure')} -ParameterFilter {$Access -eq [IO.FileAccess]::Write}
            {Split-Tqsim -File $f.Source -Size 1000 -Output $f.Parts -ds true -Quiet}|Should Throw
            [IO.File]::Exists($f.Source)|Should Be $true
        }
        }
        Context 'preserves every source when merge is interrupted before publication' {
        It 'preserves every source when merge is interrupted before publication' {
            $f=New-SplitFixture
            Mock Invoke-TqsimParts -ModuleName Tqsim {throw [OperationCanceledException]::new('interrupted merging')} -ParameterFilter {$State -eq 'MERGING'}
            {Merge-Tqsim -PartsPath $f.Parts -Output $f.Restored -ds true -Quiet}|Should Throw
            @(Get-ChildItem $f.Parts).Count|Should Be 12
            [IO.File]::Exists((Join-Path $f.Restored 'data.bin'))|Should Be $false
        }
        }
        Context 'records an actual partial deletion and keeps the manifest and verified output' {
        It 'records an actual partial deletion and keeps the manifest and verified output' {
            $f=New-SplitFixture;$hash=(Get-FileHash $f.Source).Hash;& (Get-Module Tqsim) {$script:cleanupCalls=0}
            Mock Remove-TqsimVerifiedFile -ModuleName Tqsim {
                param($Entry)
                $script:cleanupCalls++
                if ($script:cleanupCalls -eq 2) {throw [IO.IOException]::new('injected interrupted cleanup')}
                [IO.File]::Delete($Entry.Path)
            }
            $message='';try {Merge-Tqsim -PartsPath $f.Parts -Output $f.Restored -ds true -Quiet} catch {$message=$_.Exception.Message}
            $message|Should Match '1 deleted, 11 remaining/unconfirmed'
            (Get-FileHash "$($f.Restored)/data.bin").Hash|Should Be $hash
            [IO.File]::Exists((Join-Path $f.Parts 'data.bin.tqsim.json'))|Should Be $true
            [IO.File]::Exists((Join-Path $f.Parts 'data.bin.part0001'))|Should Be $false
            $j=Get-Content (Get-ChildItem $f.Restored -Filter '.tqsim-cleanup-*.json').FullName -Raw|ConvertFrom-Json
            $j.state|Should Be incomplete;$j.targets[0].Status|Should Be deleted;$j.targets[1].Status|Should Be deleting
            @($j.targets|Where-Object Status -eq pending).Count|Should Be 10
            # No automatic retry: the next normal invocation stops at the missing part.
            {Merge-Tqsim -PartsPath $f.Parts -Output (Join-Path $f.Directory 'retry') -ds true -Quiet}|Should Throw
            (& (Get-Module Tqsim) {$script:cleanupCalls})|Should Be 2
        }
        }
        Context 'does not delete anything if a write-ahead journal cannot be persisted' {
        It 'does not delete anything if a write-ahead journal cannot be persisted' {
            $f=New-SplitFixture
            Mock Save-TqsimCleanupJournal -ModuleName Tqsim {throw [IO.IOException]::new('journal disk full')}
            Mock Remove-TqsimVerifiedFile -ModuleName Tqsim {throw 'must not delete'}
            {Merge-Tqsim -PartsPath $f.Parts -Output $f.Restored -ds true -Quiet}|Should Throw
            @(Get-ChildItem $f.Parts).Count|Should Be 12
            Assert-MockCalled Remove-TqsimVerifiedFile -ModuleName Tqsim -Times 0 -Exactly -Scope It
        }
        }
        Context 'rejects same-content file substitution by identity immediately before deletion' {
        It 'rejects same-content file substitution by identity immediately before deletion' {
            $f=New-TestFixture;$context=New-TqsimDeletionContext
            try {$entry=Add-TqsimDeletionFile $context $f.Source -Target;$entry.Stream.Dispose()
                $replacement=Join-Path $f.Directory 'replacement';[IO.File]::Copy($f.Source,$replacement)
                [IO.File]::Move($replacement,$f.Source,$true)
                {Remove-TqsimVerifiedFile $entry}|Should Throw
                [IO.File]::Exists($f.Source)|Should Be $true
            } finally {Close-TqsimDeletionContext $context}
        }
        }
    }

