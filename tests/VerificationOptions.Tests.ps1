. "$PSScriptRoot/TestSupport.ps1"
if (!('TqsimProfileStream' -as [type])) {Add-Type -Path (Join-Path $projectRoot 'scripts/ProfileStreams.cs')}
Describe 'Verification parsing and optional defaults' {
    It 'uses true verification and false deletion defaults with strict boolean strings' {
        Resolve-TqsimVerifyOption|Should Be $true;Resolve-TqsimDeleteSourceOption|Should Be $false
        foreach ($value in 'false','FALSE','FaLsE') {Resolve-TqsimVerifyOption $value|Should Be $false}
        foreach ($value in 'true','TRUE','TrUe') {Resolve-TqsimVerifyOption $value|Should Be $true}
        foreach ($value in '','yes','no','0','1','text',' true','false ') {{Resolve-TqsimVerifyOption $value}|Should Throw}
        foreach ($command in 'split','merge','merg') {
            foreach ($arguments in @(@($command,'-verify'),@($command,'-verify',''),@($command,'-verify','yes'),@($command,'-verify','true','-verify','false'))) {{Resolve-TqsimInvocation $arguments}|Should Throw}
            (Resolve-TqsimInvocation @($command,'-verify','FaLsE','-ds','false')).Options.verify|Should Be FaLsE
        }
        (Resolve-TqsimInvocation @('split','-verify','true','--help')).Command|Should Be help
        {Resolve-TqsimInvocation @('verify','-verify','false')}|Should Throw
    }
    It 'documents both strict defaults in split and merge help' {
        foreach ($topic in 'split','merge') {$help=Get-TqsimHelp $topic;$help|Should Match '\-verify';$help|Should Match 'Default: true';$help|Should Match 'Default: false'}
    }
    It 'default operations independently verify but omit default boolean status noise' {
        $f=New-TestFixture;$hash=(Get-FileHash $f.Source).Hash
        Mock New-TqsimStream {[TqsimProfileStream]::new($Path,$Mode,$Access)} -ModuleName Tqsim
        [TqsimProfile]::Reset();$text=Split-Tqsim -File $f.Source -Size 1000 -Output $f.Parts|Out-String
        $text|Should Not Match 'Delete Source|Source retained|Verify =|Verification skipped'
        [TqsimProfile]::ReadBytes|Should Be 20006
        [IO.File]::Exists($f.Source)|Should Be $true
        [TqsimProfile]::Reset();$text=Merge-Tqsim -PartsPath $f.Parts -Output $f.Restored|Out-String
        $text|Should Not Match 'Delete Source|Source retained|Verify =|Verification skipped'
        [TqsimProfile]::ReadBytes|Should Be 20006
        (Get-FileHash "$($f.Restored)/data.bin").Hash|Should Be $hash
    }
}
Describe 'Measured data passes for every option combination' {
    It 'reads each input once and each output <Passes> times with ds=<Ds> verify=<Verify>' -TestCases @(
        @{Ds='false';Verify='true';Passes=1},@{Ds='false';Verify='false';Passes=0},@{Ds='true';Verify='true';Passes=1},@{Ds='true';Verify='false';Passes=0}
    ) {
        param($Ds,$Verify,$Passes)
        $f=New-TestFixture 10003 'نسخة with spaces.bin';$expected=(Get-FileHash -LiteralPath $f.Source).Hash
        Mock New-TqsimStream {[TqsimProfileStream]::new($Path,$Mode,$Access)} -ModuleName Tqsim
        [TqsimProfile]::Reset()
        $warnings=@(Split-Tqsim -File $f.Source -Size 1000 -Output $f.Parts -ds $Ds -verify $Verify -Quiet 3>&1|Where-Object {$_ -is [Management.Automation.WarningRecord]})
        [TqsimProfile]::BytesByPath[$f.Source]|Should Be 10003
        [long]$readBackBytes=0
        foreach ($key in [TqsimProfile]::BytesByPath.Keys) {if ($key -match '\.part\d+$') {$readBackBytes+=[TqsimProfile]::BytesByPath[$key]}}
        $readBackBytes|Should Be (10003*$Passes)
        [IO.File]::Exists($f.Source)|Should Be ($Ds -eq 'false')
        if ($Ds -eq 'true' -and $Verify -eq 'false') {($warnings|Out-String)|Should Match 'Independent read-back verification is disabled'} else {$warnings.Count|Should Be 0}
        [TqsimProfile]::Reset()
        Merge-Tqsim -PartsPath $f.Parts -Output $f.Restored -ds $Ds -verify $Verify -Quiet
        [long]$inputBytes=0
        foreach ($key in [TqsimProfile]::BytesByPath.Keys) {if ($key -match '\.part\d+$') {$inputBytes+=[TqsimProfile]::BytesByPath[$key]}}
        $inputBytes|Should Be 10003
        $final=Join-Path $f.Restored 'نسخة with spaces.bin'
        $outputReads=if ([TqsimProfile]::BytesByPath.ContainsKey($final)) {[TqsimProfile]::BytesByPath[$final]} else {0}
        $outputReads|Should Be (10003*$Passes)
        (Get-FileHash -LiteralPath $final).Hash|Should Be $expected
        @(Get-ChildItem $f.Parts -Filter '*.part*').Count|Should Be $(if($Ds -eq 'true'){0}else{11})
        if ($Ds -eq 'true') {@(Get-TestRecoveryJournal $f).Count|Should Be 0}
    }
}
Describe 'Fast path keeps mandatory integrity and publication safeguards' {
    It 'detects corrupted part data during streaming with verify false and preserves every source' {
        $f=New-SplitFixture;$part=Join-Path $f.Parts 'data.bin.part0002';[IO.File]::WriteAllBytes($part,[byte[]]::new(1000))
        {Merge-Tqsim -PartsPath $f.Parts -Output $f.Restored -ds true -verify false -Quiet}|Should Throw
        @(Get-ChildItem $f.Parts).Count|Should Be 12
        [IO.File]::Exists((Join-Path $f.Restored 'data.bin'))|Should Be $false
    }
    It 'preserves input on malformed manifest, invalid size and existing output in fast mode' {
        $f=New-SplitFixture
        {Split-Tqsim -File $f.Source -Size invalid -Output $f.Parts -ds true -verify false -Quiet}|Should Throw
        {Split-Tqsim -File $f.Source -Size 1000 -Output $f.Parts -ds true -verify false -Quiet}|Should Throw
        [IO.File]::Exists($f.Source)|Should Be $true
        $null=Change-TestManifest $f {param($m)$m.totalParts=99}
        {Merge-Tqsim -PartsPath $f.Parts -Output $f.Restored -ds true -verify false -Quiet}|Should Throw
        @(Get-ChildItem $f.Parts).Count|Should Be 12
    }
    It 'forwards omitted options and explicit values through native CLI and Windows launcher' {
        $launcher=Join-Path $TestDrive 'tqsim.cmd';[IO.File]::WriteAllText($launcher,"@echo off`r`npwsh -NoProfile -File `"$projectRoot\tqsim.ps1`" %*`r`nexit /b %errorlevel%`r`n")
        foreach ($run in 'direct','launcher') {
            foreach ($parameters in @(@(),@('-ds','false'),@('-verify','true'),@('-ds','true','-verify','false'))) {
                $f=New-TestFixture 10003 '測試 file.bin';$hash=(Get-FileHash -LiteralPath $f.Source).Hash
                $command=if ($run -eq 'direct') {(Get-Command pwsh).Source} else {$launcher}
                $prefix=if ($run -eq 'direct') {@('-NoProfile','-File',"$projectRoot/tqsim.ps1")} else {@()}
                & $command @prefix split -File $f.Source -Size 1GB -Output $f.Parts @parameters -Quiet
                $LASTEXITCODE|Should Be 0
                & $command @prefix merg -PartsPath $f.Parts -Output $f.Restored @parameters -Quiet
                $LASTEXITCODE|Should Be 0
                (Get-FileHash -LiteralPath (Join-Path $f.Restored '測試 file.bin')).Hash|Should Be $hash
            }
        }
        foreach ($value in '','yes','0','anything') {$f=New-TestFixture;& pwsh -NoProfile -File "$projectRoot/tqsim.ps1" split -File $f.Source -Size 1GB -verify $value -Quiet 2>$null;$LASTEXITCODE|Should Be 2;[IO.File]::Exists($f.Source)|Should Be $true}
    }
}
