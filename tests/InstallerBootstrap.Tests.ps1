$projectRoot=Split-Path $PSScriptRoot -Parent
. "$projectRoot/install.ps1"
Describe 'Installer runtime bootstrap' {
    BeforeEach {
        Mock Get-TqsimInstallerRuntimeVersion {[version]'7.6.8'}
        Mock Install-TqsimRelease {}
        Mock Find-TqsimPowerShell {'C:\installed\pwsh.exe'}
        Mock Start-TqsimInstallerBootstrap {0}
    }
    It 'accepts the current PowerShell 7 runtime without requiring PATH discovery' {
        Mock Find-TqsimPowerShell {throw 'Must not search'}
        Test-TqsimRuntimeAvailable | Should Be $true
        (Invoke-TqsimInstaller -Repository SamiAlmouss/Tqsim -InstallRoot (Join-Path $TestDrive app)) | Should Be 0
        Assert-MockCalled Install-TqsimRelease -Times 1 -Exactly -Scope It
        Assert-MockCalled Start-TqsimInstallerBootstrap -Times 0 -Exactly -Scope It
    }
    It 'hands a Windows PowerShell 5.1 invocation to a separate validated runtime' {
        Mock Get-TqsimInstallerRuntimeVersion {[version]'5.1.26100.9711'}
        (Invoke-TqsimInstaller -Repository SamiAlmouss/Tqsim -InstallRoot 'D:\Space 測試\app') | Should Be 0
        Assert-MockCalled Start-TqsimInstallerBootstrap -Times 1 -Exactly -Scope It -ParameterFilter {$Executable -eq 'C:\installed\pwsh.exe' -and $Repository -ceq 'SamiAlmouss/Tqsim' -and $InstallRoot -ceq 'D:\Space 測試\app'}
        Assert-MockCalled Install-TqsimRelease -Times 0 -Exactly -Scope It
    }
    It 'reports genuinely missing PowerShell 7 with the installation command' {
        Mock Get-TqsimInstallerRuntimeVersion {[version]'5.1'}
        Mock Find-TqsimPowerShell {$null}
        {Invoke-TqsimInstaller -Repository SamiAlmouss/Tqsim -InstallRoot unused} | Should Throw 'winget install --id Microsoft.PowerShell --source winget'
        Assert-MockCalled Start-TqsimInstallerBootstrap -Times 0 -Exactly -Scope It
    }
    It 'rejects a relaunch still running below version 7 without another process' {
        Mock Get-TqsimInstallerRuntimeVersion {[version]'5.1'}
        {Invoke-TqsimInstaller -Repository SamiAlmouss/Tqsim -InstallRoot unused -Relaunched} | Should Throw 'Refusing to relaunch again'
        Assert-MockCalled Start-TqsimInstallerBootstrap -Times 0 -Exactly -Scope It
        Assert-MockCalled Find-TqsimPowerShell -Times 0 -Exactly -Scope It
    }
    It 'preserves a failed child exit code' {
        Mock Get-TqsimInstallerRuntimeVersion {[version]'5.1'}
        Mock Start-TqsimInstallerBootstrap {23}
        (Invoke-TqsimInstaller -Repository SamiAlmouss/Tqsim -InstallRoot unused) | Should Be 23
    }
}
Describe 'Installed runtime executable probes' {
    It 'has no executable exit statement in the parent installer script' {
        $tokens=$null;$parseErrors=$null
        $ast=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $projectRoot 'install.ps1'),[ref]$tokens,[ref]$parseErrors)
        @($parseErrors).Count | Should Be 0
        @($ast.FindAll({param($node)$node -is [System.Management.Automation.Language.ExitStatementAst]},$true)).Count | Should Be 0
    }
    It 'accepts actual version 7 output and rejects older versions and failures' {
        Mock Invoke-TqsimInstallerProcess {[pscustomobject]@{ExitCode=0;StdOut="7`r`n";StdErr=''}}
        Test-TqsimPowerShellExecutable 'candidate.exe' | Should Be $true
        Mock Invoke-TqsimInstallerProcess {[pscustomobject]@{ExitCode=0;StdOut="6`r`n";StdErr=''}}
        Test-TqsimPowerShellExecutable 'candidate.exe' | Should Be $false
        Mock Invoke-TqsimInstallerProcess {[pscustomobject]@{ExitCode=1;StdOut='';StdErr='failed'}}
        Test-TqsimPowerShellExecutable 'candidate.exe' | Should Be $false
    }
}

Describe 'Real piped and downloaded-script bootstrap processes' {
    It 'runs from <Runtime> using <Scenario> and file=<AsFile> without closing the parent' -TestCases @(
        @{Runtime='5.1';Scenario='success';AsFile=$false}
        @{Runtime='5.1';Scenario='failure';AsFile=$false}
        @{Runtime='5.1';Scenario='success';AsFile=$true}
        @{Runtime='5.1';Scenario='failure';AsFile=$true}
        @{Runtime='7';Scenario='success';AsFile=$false}
        @{Runtime='7';Scenario='failure';AsFile=$false}
        @{Runtime='7';Scenario='success';AsFile=$true}
        @{Runtime='7';Scenario='failure';AsFile=$true}
    ) {
        param($Runtime,$Scenario,$AsFile)
        $executable=if($Runtime -eq '5.1'){@(Get-Command powershell.exe -CommandType Application)[0].Source}elseif($PSVersionTable.PSVersion.Major -ge 7){Join-Path $PSHOME 'pwsh.exe'}else{@(Get-Command pwsh.exe -CommandType Application)[0].Source}
        $report=Join-Path $TestDrive ([guid]::NewGuid().ToString()+'.json')
        $fixture=Join-Path $projectRoot 'tests/fixtures/InstallerBootstrapHarness.ps1'
        $arguments='-NoLogo -NoProfile -NonInteractive -File "'+$fixture+'" -ProjectRoot "'+$projectRoot+'" -WorkDirectory "'+$TestDrive+'" -ResultPath "'+$report+'" -Scenario '+$Scenario
        if($AsFile){$arguments+=' -FileInvocation'}
        $process=Invoke-TqsimInstallerProcess -Executable $executable -Arguments $arguments
        if($process.ExitCode -ne 0){throw "Bootstrap harness failed: $($process.StdOut) $($process.StdErr)"}
        $result=[IO.File]::ReadAllText($report)|ConvertFrom-Json
        $result.ParentSurvived | Should Be $true
        $result.ExitCode | Should Be $(if($Scenario -eq 'success'){0}else{1})
        if($Runtime -eq '5.1'){
            $result.ParentRuntime | Should Match '^5\.1'
            $result.InstallPid | Should Not Be $result.ParentPid
            $result.OriginalScriptPath | Should BeNullOrEmpty
            $result.OriginalScriptRoot | Should BeNullOrEmpty
        } else {$result.InstallPid | Should Be $result.ParentPid}
        if($Scenario -eq 'failure'){$result.Caught | Should Match 'Tqsim installation failed'}
    }
}
