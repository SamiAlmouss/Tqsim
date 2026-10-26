. "$PSScriptRoot/TestSupport.ps1"
$globalAliases=@('','help','-help','--help','-h','--h','-?','/?','/help','-Help','--HELP')
$helpCases=@($globalAliases|ForEach-Object {@{Alias=$_}})
Describe 'Public global help compatibility' {
    It 'shows full main help for <Alias>' -TestCases $helpCases {
        param($Alias)
        $arguments=@(if($Alias){$Alias};'-NoLogo')
        $output=(& pwsh -NoProfile -File "$projectRoot/tqsim.ps1" @arguments 2>&1 | Out-String)
        $LASTEXITCODE | Should Be 0
        $output | Should Match 'USAGE'
        $output | Should Match 'COMMANDS'
        $output | Should Match 'GLOBAL OPTIONS'
        $output | Should Not Match 'FAILED:'
    }
}
$versionCases=@('version','-version','--version','-v','-V'|ForEach-Object {@{Alias=$_}})
Describe 'Public version compatibility' {
    It 'reads authoritative metadata for <Alias>' -TestCases $versionCases {
        param($Alias)
        $output=& pwsh -NoProfile -File "$projectRoot/tqsim.ps1" $Alias -NoLogo
        $LASTEXITCODE | Should Be 0
        $output | Should Be (Get-TqsimVersion)
    }
}
Describe 'Command help and safe dispatch' {
    It 'normalizes every requested topic and help form before mandatory validation' {
        foreach ($topic in 'split','merg','merge','verify','info','update','uninstall','version') {
            $expected=if($topic -eq 'merg'){'merge'}else{$topic}
            foreach ($form in @(@('help',$topic),@($topic,'help'),@($topic,'-help'),@($topic,'--help'),@($topic,'-h'),@($topic,'/?'))) {
                $result=Resolve-TqsimInvocation $form
                $result.Command | Should Be 'help';$result.Topic | Should Be $expected
            }
        }
        $result=Resolve-TqsimInvocation @('SpLiT','-NoLogo','--HELP','-BufferSize','invalid')
        $result.Command | Should Be help
    }
    It 'shows the actual split and merge topic screens through pwsh' {
        foreach ($form in @(@('help','split'),@('split','help'),@('split','--help'),@('split','-NoLogo','--help'),@('merg','--help'),@('merge','/?'),@('verify','-h'),@('info','--help'),@('update','--help'),@('uninstall','--help'))) {
            $arguments=@($form);if ('-NoLogo' -notin $arguments) {$arguments+='-NoLogo'}
            $output=(& pwsh -NoProfile -File "$projectRoot/tqsim.ps1" @arguments 2>&1 | Out-String)
            $LASTEXITCODE | Should Be 0
            $output | Should Match 'OPTIONS'
            $output | Should Not Match 'FAILED:'
        }
    }
    It 'rejects unsupported arguments, duplicates and invalid buffers' {
        foreach ($arguments in @(@('split','-bogus'),@('version','extra'),@('split','-File'),@('split','-Size','1GB','-Size','2GB'),@('split','-BufferSize','2GB'),@('version','-File','unused'))) {
            {Resolve-TqsimInvocation $arguments} | Should Throw
        }
    }
    It 'preserves case, spaces, Unicode values and explicit Boolean named arguments' {
        $result=Resolve-TqsimInvocation @('SPLIT','-File','D:\測試 Folder\File.bin','-Size','2GB','-Quiet:', $false,'-BufferSize:4096')
        $result.Options.file | Should BeExactly 'D:\測試 Folder\File.bin'
        $result.Options.quiet | Should Be $false
        $result.Options.buffersize | Should Be 4096
    }
    It 'provides clear typo suggestions and usage exit codes' {
        foreach ($case in @(@('splitt','split'),@('merger','merge'),@('verfiy','verify'))) {
            $output=(& pwsh -NoProfile -File "$projectRoot/tqsim.ps1" $case[0] -NoLogo 2>&1|Out-String)
            $LASTEXITCODE | Should Be 2
            $output | Should Match "Did you mean '$($case[1])'"
            $output | Should Not Match 'ScriptStackTrace'
        }
        (Get-TqsimSuggestion 'completelyunrelated') | Should Be ''
    }
    It 'keeps redirected branded help clean and renders a single logo block' {
        $output=(& pwsh -NoProfile -File "$projectRoot/tqsim.ps1" --help 2>&1|Out-String)
        $LASTEXITCODE | Should Be 0
        $output | Should Not Match ([regex]::Escape([string][char]27))
        [regex]::Matches($output,'Split • Merge • Verify').Count | Should Be 1
        $output | Should Match 'USAGE'
    }
}
InModuleScope Tqsim {
    Describe 'Help performs no operations' {
        It 'does not dispatch a file operation or deployment for any help topic' {
            Mock Split-Tqsim {throw 'Must not split'};Mock Merge-Tqsim {throw 'Must not merge'};Mock Test-Tqsim {throw 'Must not verify'}
            Mock Read-TqsimManifest {throw 'Must not inspect'};Mock Invoke-TqsimDeployment {throw 'Must not deploy'}
            foreach ($topic in 'split','merg','merge','verify','info','update','uninstall') {
                foreach ($form in @(@('help',$topic,'-NoLogo'),@($topic,'--help','-NoLogo'),@($topic,'-h','-NoLogo'))) {
                    Invoke-TqsimCommand (Resolve-TqsimInvocation $form) | Out-Null
                }
            }
            foreach ($name in 'Split-Tqsim','Merge-Tqsim','Test-Tqsim','Read-TqsimManifest','Invoke-TqsimDeployment') {Assert-MockCalled $name -Times 0 -Exactly}
        }
    }
}
