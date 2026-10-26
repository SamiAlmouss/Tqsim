. "$PSScriptRoot/TestSupport.ps1"
Describe 'Encrypted format, authentication and bounded records' {
    BeforeEach {Mock Read-TqsimSecret -ModuleName Tqsim {ConvertTo-SecureString 'nonsecret test passphrase 106' -AsPlainText -Force}}
    It 'keeps normal and explicit false part bytes/schema unchanged and restricts encrypt to split' {
        $f=New-TestFixture;$a=Join-Path $f.Directory 'a';$b=Join-Path $f.Directory 'b'
        Split-Tqsim -File $f.Source -Size 1000 -Output $a -Quiet
        Split-Tqsim -File $f.Source -Size 1000 -Output $b -encrypt false -Quiet
        (Read-TqsimManifest (Join-Path $a 'data.bin.tqsim.json')).manifestVersion|Should Be 1
        foreach ($part in Get-ChildItem $a -Filter '*.part*') {(Get-FileHash -LiteralPath $part.FullName).Hash|Should Be (Get-FileHash -LiteralPath (Join-Path $b $part.Name)).Hash}
        Assert-MockCalled Read-TqsimSecret -ModuleName Tqsim -Times 0 -Exactly -Scope It
        foreach ($value in '','yes','0','1','text') {{Resolve-TqsimInvocation @('split','-encrypt',$value)}|Should Throw}
        {Resolve-TqsimInvocation @('merge','-encrypt','true')}|Should Throw
        {Resolve-TqsimInvocation @('merg','-encrypt','false')}|Should Throw
        (Resolve-TqsimInvocation @('split','-encrypt','TRUE','--help')).Command|Should Be help
    }
    It 'round trips <Length> encrypted bytes with a strict physical part cap <Cap>' -TestCases @(@{Length=0;Cap=29},@{Length=1;Cap=29},@{Length=10003;Cap=1000},@{Length=4194321;Cap=1048576},@{Length=123;Cap=1099511627776L}) {
        param($Length,$Cap)
        $f=New-TestFixture $Length 'نسخة secret.bin';$expected=(Get-FileHash -LiteralPath $f.Source).Hash
        Split-Tqsim -File $f.Source -Size $Cap -Output $f.Parts -encrypt TRUE -Quiet
        $path=Join-Path $f.Parts 'نسخة secret.bin.tqsim.json';$m=Read-TqsimManifest $path
        $m.manifestVersion|Should Be 2;$m.encryption.enabled|Should Be $true;$m.encryption.iterations|Should Be 600000
        foreach ($part in $m.parts) {$part.size -le $Cap|Should Be $true}
        Test-Tqsim -Manifest $path -Quiet
        Merge-Tqsim -PartsPath $f.Parts -Quiet
        (Get-FileHash -LiteralPath (Join-Path $f.Parts 'نسخة secret.bin')).Hash|Should Be $expected
        [IO.Directory]::Exists((Join-Path $f.Parts 'Output'))|Should Be $false
        @(Get-ChildItem $f.Parts -Filter '*.tmp').Count|Should Be 0
        ([IO.File]::ReadAllText($path))|Should Not Match 'nonsecret test passphrase'
    }
    It 'retains strong authentication and cleanup correctness in every option combination' -TestCases @(@{Ds='false';Verify='false'},@{Ds='true';Verify='false'},@{Ds='true';Verify='true'},@{Ds='false';Verify='true'}) {
        param($Ds,$Verify)
        $f=New-TestFixture;$hash=(Get-FileHash $f.Source).Hash
        Split-Tqsim -File $f.Source -Size 1000 -Output $f.Parts -encrypt true -ds $Ds -verify $Verify -Quiet
        [IO.File]::Exists($f.Source)|Should Be ($Ds -eq 'false')
        Merge-Tqsim -PartsPath $f.Parts -ds $Ds -verify $Verify -Quiet
        (Get-FileHash (Join-Path $f.Parts 'data.bin')).Hash|Should Be $hash
        @(Get-ChildItem $f.Parts -Filter '*.tqsim.json').Count|Should Be $(if($Ds -eq 'true'){0}else{1})
        @(Get-TestRecoveryJournal $f).Count|Should Be 0
    }
    It 'uses fresh salts/prefixes and does not expose plaintext in encrypted parts' {
        $f=New-TestFixture 3000;[IO.File]::WriteAllText($f.Source,('THIS IS PRIVATE PLAINTEXT '*120));$a=Join-Path $f.Directory 'a';$b=Join-Path $f.Directory 'b'
        Split-Tqsim -File $f.Source -Size 1000 -Output $a -encrypt true -Quiet
        Split-Tqsim -File $f.Source -Size 1000 -Output $b -encrypt true -Quiet
        $ma=Read-TqsimManifest (Join-Path $a 'data.bin.tqsim.json');$mb=Read-TqsimManifest (Join-Path $b 'data.bin.tqsim.json')
        $ma.encryption.salt|Should Not Be $mb.encryption.salt
        $ma.operationId|Should Not Be $mb.operationId
        [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes((Join-Path $a $ma.parts[0].fileName)))|Should Not Match 'THIS IS PRIVATE PLAINTEXT'
    }
    Context 'Wrong password' {
        It 'never publishes or deletes sources on wrong password with verify false' {
            $f=New-TestFixture;Split-Tqsim -File $f.Source -Size 1000 -Output $f.Parts -encrypt true -Quiet
            Mock Read-TqsimSecret -ModuleName Tqsim {ConvertTo-SecureString 'different test passphrase' -AsPlainText -Force}
            {Merge-Tqsim -PartsPath $f.Parts -ds true -verify false -Quiet}|Should Throw
            [IO.File]::Exists((Join-Path $f.Parts 'data.bin'))|Should Be $false
            @(Get-ChildItem $f.Parts -Filter '*.part*').Count|Should Be 11
            @(Get-TestRecoveryJournal $f).Count|Should Be 0
        }
    }
    It 'rejects changed ciphertext, tags, record ordinals, truncation and missing parts in fast mode' -TestCases @(@{Kind='cipher'},@{Kind='tag'},@{Kind='ordinal'},@{Kind='truncate'},@{Kind='missing'}) {
        param($Kind)
        $f=New-TestFixture;Split-Tqsim -File $f.Source -Size 1000 -Output $f.Parts -encrypt true -Quiet
        $part=Join-Path $f.Parts 'data.bin.part0001';$bytes=[IO.File]::ReadAllBytes($part)
        switch($Kind) {cipher {$bytes[12]=$bytes[12] -bxor 1} tag {$bytes[-1]=$bytes[-1] -bxor 1} ordinal {$bytes[4]=4} truncate {$bytes=$bytes[0..($bytes.Length-2)]} missing {[IO.File]::Delete($part)}}
        if($Kind -ne 'missing'){[IO.File]::WriteAllBytes($part,$bytes)}
        {Merge-Tqsim -PartsPath $f.Parts -ds true -verify false -Quiet}|Should Throw
        [IO.File]::Exists((Join-Path $f.Parts 'data.bin'))|Should Be $false
        [IO.File]::Exists((Join-Path $f.Parts 'data.bin.tqsim.json'))|Should Be $true
        @(Get-ChildItem $f.Parts -Filter '.tqsim-*.tmp').Count|Should Be 0
    }
    It 'detects metadata tampering and hostile KDF parameters before source deletion' -TestCases @(@{Field='name'},@{Field='hash'},@{Field='kdf'},@{Field='version'},@{Field='reorder'}) {
        param($Field)
        $f=New-TestFixture;Split-Tqsim -File $f.Source -Size 1000 -Output $f.Parts -encrypt true -Quiet
        $p=Join-Path $f.Parts 'data.bin.tqsim.json';$m=Get-Content $p -Raw|ConvertFrom-Json -AsHashtable
        switch($Field){name {$m.originalFileName='changed.bin'} hash {$m.originalSHA256='0'*64} kdf {$m.encryption.iterations=2147483647} version {$m.encryption.formatVersion=99} reorder {$m.parts[0].fileName=$m.parts[1].fileName}}
        [IO.File]::WriteAllText($p,($m|ConvertTo-Json -Depth 8))
        {Merge-Tqsim -PartsPath $f.Parts -ds true -verify false -Quiet}|Should Throw
        @(Get-ChildItem $f.Parts -Filter '*.part*').Count|Should Be 11
    }
    It 'detects nonce exhaustion and uses unique full 12-byte nonces' {
        Initialize-TqsimCrypto;$prefix=[byte[]](1,2,3,4)
        ([Convert]::ToHexString([Tqsim.CryptoSession]::Nonce($prefix,0)))|Should Be '010203040000000000000000'
        ([Convert]::ToHexString([Tqsim.CryptoSession]::Nonce($prefix,1)))|Should Be '010203040000000000000001'
        {[Tqsim.CryptoSession]::Nonce($prefix,[uint32]::MaxValue)}|Should Throw
        {[Tqsim.CryptoSession]::Nonce($prefix,[ulong]::MaxValue)}|Should Throw
    }
    It 'matches the AES-256-GCM zero-key, zero-IV standard vector' {
        $c=[byte[]]::new(16);$tag=[byte[]]::new(16);$aes=[Security.Cryptography.AesGcm]::new([byte[]]::new(32))
        try {$aes.Encrypt([byte[]]::new(12),[byte[]]::new(16),$c,$tag,[byte[]]::new(0));([Convert]::ToHexString($c))|Should Be CEA7403D4D606B6E074EC5D3BAF39D18;([Convert]::ToHexString($tag))|Should Be D0D1C8A799996BF0265B98B5D48AB919} finally {$aes.Dispose()}
    }
    It 'bounds oversized encrypted metadata while retaining large legacy JSON support' {
        $f=New-TestFixture;$legacy=Join-Path $PSScriptRoot 'fixtures/legacy/1.0.2/legacy-1.0.2.bin.tqsim.json';$p=Join-Path $f.Directory 'large.json'
        [IO.File]::WriteAllText($p,([IO.File]::ReadAllText($legacy)+(' '*16777216)))
        (Read-TqsimManifest $p).manifestVersion|Should Be 1
        [IO.File]::WriteAllText($p,('{"manifestVersion":2}'+(' '*16777216)))
        {Read-TqsimManifest $p}|Should Throw
    }
}
Describe 'Secure interactive input boundaries' {
    Context 'Mocked secure console' {
        BeforeEach {Mock Test-TqsimSecureInputAvailable -ModuleName Tqsim {$true}}
        It 'accepts hidden confirmed long passphrases without returning plaintext' {
            Mock Read-Host -ModuleName Tqsim {ConvertTo-SecureString ('long passphrase '*30) -AsPlainText -Force}
            $secret=Read-TqsimSecret -Confirm
            try {$secret|Should BeOfType ([Security.SecureString]);$secret.Length|Should Be 480} finally {$secret.Dispose()}
            Assert-MockCalled Read-Host -ModuleName Tqsim -Times 2 -Exactly -Scope It -ParameterFilter {$AsSecureString}
        }
        Context 'Mismatched entries' {
            It 'rejects a mismatch' {
                Mock Read-Host -ModuleName Tqsim {if($Prompt -like 'Confirm*'){ConvertTo-SecureString 'other nonsecret password' -AsPlainText -Force}else{ConvertTo-SecureString 'first nonsecret password' -AsPlainText -Force}}
                {Read-TqsimSecret -Confirm}|Should Throw
            }
        }
        Context 'Empty entries' {
            It 'rejects empty, short and overlong entries' {
                foreach($length in 0,5,1025) {
                    $script:passwordLength=$length
                    Mock Read-Host -ModuleName Tqsim {$s=[Security.SecureString]::new();foreach($i in 1..$script:passwordLength){if($script:passwordLength){$s.AppendChar('x')}};return $s}
                    # Set the test value in the module used by the secure input mock.
                    & (Get-Module Tqsim) {param($n)$script:passwordLength=$n} $length
                    {Read-TqsimSecret -Confirm}|Should Throw
                }
            }
        }
    }
    It 'rejects secure input in noninteractive execution before output creation' {
        $f=New-TestFixture;& pwsh -NoProfile -File "$projectRoot/tqsim.ps1" split -File $f.Source -Size 1MB -encrypt true -Output $f.Parts -Quiet 2>$null
        $LASTEXITCODE|Should Be 2;[IO.Directory]::Exists($f.Parts)|Should Be $false
        [IO.File]::Exists($f.Source)|Should Be $true
    }
}
