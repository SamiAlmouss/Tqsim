$projectRoot=Split-Path $PSScriptRoot -Parent
. "$projectRoot/install.ps1"
Describe 'Release installer validation' {
    It 'rejects unconfigured repository' {{Install-TqsimRelease -Repository 'USERNAME/tqsim' -InstallRoot (Join-Path $TestDrive 'app')}|Should Throw}
    It 'rejects an unowned existing directory' {$root=Join-Path $TestDrive 'unowned';$null=[IO.Directory]::CreateDirectory($root);[IO.File]::WriteAllText((Join-Path $root 'user.txt'),'preserve');{Install-TqsimRelease -Repository 'example/tqsim' -InstallRoot $root}|Should Throw;[IO.File]::ReadAllText((Join-Path $root 'user.txt'))|Should Be 'preserve'}
    It 'creates a self-contained release and correct checksum' {$dist=Join-Path $TestDrive 'dist';& "$projectRoot/scripts/build-release.ps1" -OutputDirectory $dist;$zip=Join-Path $dist 'Tqsim-v1.0.6.zip';$expected=([IO.File]::ReadAllText("$zip.sha256") -split '\s+')[0];(Get-FileHash $zip).Hash|Should Be $expected;$a=[IO.Compression.ZipFile]::OpenRead($zip);try {@($a.Entries|Where-Object FullName -EQ 'src/Core/Tqsim.psm1').Count|Should Be 1;@($a.Entries|Where-Object FullName -like 'tests/*').Count|Should Be 0} finally {$a.Dispose()}}
}

. "$projectRoot/uninstall.ps1"
. "$projectRoot/update.ps1"
Describe 'Offline deployment with mocked GitHub' {
    BeforeEach {
        $script:savedSessionPath=$env:Path
        $script:fixture=Join-Path $TestDrive ([guid]::NewGuid().ToString());$null=[IO.Directory]::CreateDirectory($script:fixture)
        $script:appRoot=Join-Path $script:fixture 'app with spaces'
        $script:package= & "$projectRoot/scripts/build-release.ps1" -OutputDirectory (Join-Path $script:fixture 'release')
        $script:release=@{draft=$false;prerelease=$false;tag_name='v1.0.6';assets=@(
            @{name='Tqsim-v1.0.6.zip';size=(Get-Item $script:package).Length;browser_download_url='https://github.com/example/tqsim/releases/download/v1.0.6/Tqsim-v1.0.6.zip'},
            @{name='Tqsim-v1.0.6.zip.sha256';size=(Get-Item "$script:package.sha256").Length;browser_download_url='https://github.com/example/tqsim/releases/download/v1.0.6/Tqsim-v1.0.6.zip.sha256'}
        )}
        $script:userPath='C:\OtherApp'
        Mock Get-TqsimUserPath {$script:userPath}
        Mock Set-TqsimUserPath {param($Value)$script:userPath=$Value}
        Mock Test-TqsimRuntimeAvailable {$true}
        Mock Invoke-RestMethod {$script:release}
        Mock Invoke-WebRequest {param($Uri,$OutFile)if ($Uri.AbsoluteUri.EndsWith('.sha256')) {Copy-Item -LiteralPath "$script:package.sha256" -Destination $OutFile} else {Copy-Item -LiteralPath $script:package -Destination $OutFile}}
    }
    AfterEach {$env:Path=$script:savedSessionPath}
    It 'installs without admin-only paths and creates a working launcher' {
        Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot
        $marker=Get-Content (Join-Path $script:appRoot '.tqsim-install.json') -Raw|ConvertFrom-Json
        $marker.version|Should Be '1.0.6';$script:userPath|Should Match 'OtherApp;.*app with spaces'
        $result=& (Join-Path $script:appRoot 'bin/tqsim.cmd') version -NoLogo
        $LASTEXITCODE|Should Be 0;$result|Should Be '1.0.6'
    }
    It 'reinstalls with no duplicate PATH entry and preserves user files' {
        Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot
        [IO.File]::WriteAllText((Join-Path $script:appRoot 'user.tqsim.json'),'preserve')
        Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot
        @($script:userPath -split ';').Count|Should Be 2
        [IO.File]::ReadAllText((Join-Path $script:appRoot 'user.tqsim.json'))|Should Be 'preserve'
    }
    It 'rejects invalid release metadata' {$script:release.tag_name='latest';{Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot}|Should Throw}
    It 'rejects a missing PowerShell runtime' {Mock Test-TqsimRuntimeAvailable {$false};{Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot}|Should Throw}
    It 'rejects a missing asset' {$script:release.assets=@();{Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot}|Should Throw}
    It 'reports network failure without changing PATH' {Mock Invoke-RestMethod {throw 'Offline'};{Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot}|Should Throw;$script:userPath|Should Be 'C:\OtherApp'}
    It 'rejects a bad checksum' {
        [IO.File]::WriteAllText("$script:package.sha256",('0'*64)+'  Tqsim-v1.0.6.zip'+"`n")
        $script:release.assets[1].size=(Get-Item "$script:package.sha256").Length
        {Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot}|Should Throw
    }
    It 'rejects a broken ZIP with valid checksum' {
        [IO.File]::WriteAllText($script:package,'not a ZIP')
        [IO.File]::WriteAllText("$script:package.sha256",(Get-FileHash $script:package).Hash+'  Tqsim-v1.0.6.zip'+"`n")
        $script:release.assets[0].size=(Get-Item $script:package).Length;$script:release.assets[1].size=(Get-Item "$script:package.sha256").Length
        {Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot}|Should Throw
    }
    It 'rejects ZIP traversal even with a valid checksum' {
        $a=[IO.Compression.ZipFile]::Open($script:package,[IO.Compression.ZipArchiveMode]::Update)
        try {$e=$a.CreateEntry('../outside.txt');$s=[IO.StreamWriter]::new($e.Open());$s.Write('unsafe');$s.Dispose()} finally {$a.Dispose()}
        [IO.File]::WriteAllText("$script:package.sha256",(Get-FileHash $script:package).Hash+'  Tqsim-v1.0.6.zip'+"`n")
        $script:release.assets[0].size=(Get-Item $script:package).Length;$script:release.assets[1].size=(Get-Item "$script:package.sha256").Length
        {Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot}|Should Throw
        (Test-Path (Join-Path $script:fixture 'outside.txt'))|Should Be $false
    }
    It 'keeps the selected working version after failed update staging' {
        Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot
        $marker=Join-Path $script:appRoot '.tqsim-install.json';$before=[IO.File]::ReadAllText($marker)
        Mock Invoke-WebRequest {throw 'Disconnected'}
        {Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot}|Should Throw
        [IO.File]::ReadAllText($marker)|Should Be $before
        (& (Join-Path $script:appRoot 'bin/tqsim.cmd') version -NoLogo)|Should Be '1.0.6'
    }
    It 'updates an older selected installation through the supported command' {
        Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot
        $marker=Join-Path $script:appRoot '.tqsim-install.json';$m=Get-Content $marker -Raw|ConvertFrom-Json;$m.version='1.0.2';[IO.File]::WriteAllText($marker,($m|ConvertTo-Json))
        Update-Tqsim -InstallRoot $script:appRoot
        (Get-Content $marker -Raw|ConvertFrom-Json).version|Should Be '1.0.6'
    }
    It 'does not download an already current version' {
        Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot
        Mock Invoke-WebRequest {throw 'Must not download'}
        Update-Tqsim -InstallRoot $script:appRoot
    }
    It 'rolls back selection if the PATH update fails after publishing' {
        Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot
        $marker=Join-Path $script:appRoot '.tqsim-install.json';$before=[IO.File]::ReadAllText($marker)
        $script:userPath='C:\OtherApp';$script:pathCalls=0
        Mock Set-TqsimUserPath {param($Value)$script:pathCalls++;if ($script:pathCalls -eq 1) {throw 'PATH denied'};$script:userPath=$Value}
        {Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot}|Should Throw
        [IO.File]::ReadAllText($marker)|Should Be $before
        (& (Join-Path $script:appRoot 'bin/tqsim.cmd') version -NoLogo)|Should Be '1.0.6'
    }
    It 'can retry a clean installation after a late PATH failure' {
        $script:pathCalls=0
        Mock Set-TqsimUserPath {param($Value)$script:pathCalls++;if ($script:pathCalls -eq 1) {throw 'PATH denied'};$script:userPath=$Value}
        {Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot}|Should Throw
        Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot
        (Test-Path (Join-Path $script:appRoot '.tqsim-install.json'))|Should Be $true
    }
    It 'uninstalls owned files and preserves split data' {
        Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot
        $m=Get-Content (Join-Path $script:appRoot '.tqsim-install.json') -Raw|ConvertFrom-Json
        $data=Join-Path $m.current 'backup.part0001';[IO.File]::WriteAllText($data,'user data')
        Uninstall-Tqsim -InstallRoot $script:appRoot
        [IO.File]::ReadAllText($data)|Should Be 'user data'
        (Test-Path (Join-Path $script:appRoot 'bin/tqsim.cmd'))|Should Be $false
        $script:userPath|Should Be 'C:\OtherApp'
    }
    It 'forwards quoted Unicode paths through the launcher' {
        Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot
        $source=Join-Path $script:fixture '測試 file.bin';[IO.File]::WriteAllBytes($source,[byte[]](1,2,3,4))
        & (Join-Path $script:appRoot 'bin/tqsim.cmd') split -File $source -Size 2 -Quiet
        $LASTEXITCODE|Should Be 0
        (Test-Path (Join-Path $script:fixture 'Output/測試 file.bin.tqsim.json'))|Should Be $true
    }
    It 'forwards help and version aliases through the real Windows launcher' {
        Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot
        $launcher=Join-Path $script:appRoot 'bin/tqsim.cmd'
        foreach ($alias in @('','help','-help','--help','-h','--h','-?','/?','/help','-Help','--HELP')) {
            $arguments=@(if($alias){$alias};'-NoLogo')
            $output=(& $launcher @arguments 2>&1|Out-String)
            $LASTEXITCODE|Should Be 0
            $output|Should Match USAGE
        }
        foreach ($alias in 'version','-version','--version','-v','-V') {
            $output=& $launcher $alias -NoLogo
            $LASTEXITCODE|Should Be 0
            $output|Should Be ((Get-Content "$projectRoot/version.json" -Raw|ConvertFrom-Json).version)
        }
        foreach($topic in 'split','merg','merge','verify','info','update','uninstall') {
            $output=(& $launcher $topic --help -NoLogo 2>&1|Out-String)
            $LASTEXITCODE|Should Be 0
            $output|Should Match OPTIONS
        }
    }
}
