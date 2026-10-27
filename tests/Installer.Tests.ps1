$projectRoot=Split-Path $PSScriptRoot -Parent
. "$projectRoot/install.ps1"
Describe 'Release installer validation' {
    It 'rejects unconfigured repository' {{Install-TqsimRelease -Repository 'USERNAME/tqsim' -InstallRoot (Join-Path $TestDrive 'app')}|Should Throw}
    It 'rejects an unowned existing directory' {$root=Join-Path $TestDrive 'unowned';$null=[IO.Directory]::CreateDirectory($root);[IO.File]::WriteAllText((Join-Path $root 'user.txt'),'preserve');{Install-TqsimRelease -Repository 'example/tqsim' -InstallRoot $root}|Should Throw;[IO.File]::ReadAllText((Join-Path $root 'user.txt'))|Should Be 'preserve'}
    It 'creates a self-contained release and correct checksum' {$dist=Join-Path $TestDrive 'dist';& "$projectRoot/scripts/build-release.ps1" -OutputDirectory $dist;$zip=Join-Path $dist 'Tqsim-v1.0.8.zip';$expected=([IO.File]::ReadAllText("$zip.sha256") -split '\s+')[0];(Get-FileHash $zip).Hash|Should Be $expected;$a=[IO.Compression.ZipFile]::OpenRead($zip);try {@($a.Entries|Where-Object FullName -EQ 'src/Core/Tqsim.psm1').Count|Should Be 1;@($a.Entries|Where-Object FullName -like 'tests/*').Count|Should Be 0} finally {$a.Dispose()}}
}

. "$projectRoot/uninstall.ps1"
. "$projectRoot/update.ps1"
Describe 'Offline deployment with mocked GitHub' {
    BeforeEach {
        $script:savedSessionPath=$env:Path
        $script:savedLocalAppData=$env:LOCALAPPDATA
        $script:savedFixtureUserPath=$env:TQSIM_TEST_USER_PATH_FILE
        $script:mockRootReparse=$false
        $script:fixture=Join-Path $TestDrive ([guid]::NewGuid().ToString());$null=[IO.Directory]::CreateDirectory($script:fixture)
        $script:appRoot=Join-Path $script:fixture 'app with spaces'
        if ($env:TQSIM_RELEASE_TEST_ARCHIVE) {
            # Audit a disposable copy of the final release, never mutate dist.
            $releaseDir=Join-Path $script:fixture 'release';$null=[IO.Directory]::CreateDirectory($releaseDir)
            $script:package=Join-Path $releaseDir 'Tqsim-v1.0.8.zip'
            Copy-Item -LiteralPath $env:TQSIM_RELEASE_TEST_ARCHIVE -Destination $script:package
            Copy-Item -LiteralPath ($env:TQSIM_RELEASE_TEST_ARCHIVE+'.sha256') -Destination ($script:package+'.sha256')
        } else {
            $script:package= & "$projectRoot/scripts/build-release.ps1" -OutputDirectory (Join-Path $script:fixture 'release')
        }
        $script:release=@{draft=$false;prerelease=$false;tag_name='v1.0.8';assets=@(
            @{name='Tqsim-v1.0.8.zip';size=(Get-Item $script:package).Length;browser_download_url='https://github.com/example/tqsim/releases/download/v1.0.8/Tqsim-v1.0.8.zip'},
            @{name='Tqsim-v1.0.8.zip.sha256';size=(Get-Item "$script:package.sha256").Length;browser_download_url='https://github.com/example/tqsim/releases/download/v1.0.8/Tqsim-v1.0.8.zip.sha256'}
        )}
        $script:userPath='C:\OtherApp'
        Mock Get-TqsimUserPath {$script:userPath}
        Mock Set-TqsimUserPath {param($Value)$script:userPath=$Value}
        Mock Test-TqsimRuntimeAvailable {$true}
        Mock Invoke-RestMethod {$script:release}
        Mock Invoke-WebRequest {param($Uri,$OutFile)if ($Uri.AbsoluteUri.EndsWith('.sha256')) {Copy-Item -LiteralPath "$script:package.sha256" -Destination $OutFile} else {Copy-Item -LiteralPath $script:package -Destination $OutFile}}
    }
    AfterEach {$env:Path=$script:savedSessionPath;$env:LOCALAPPDATA=$script:savedLocalAppData;$env:TQSIM_TEST_USER_PATH_FILE=$script:savedFixtureUserPath;$script:mockRootReparse=$false}
    It 'installs without admin-only paths and creates a working launcher' {
        Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot
        $marker=Get-Content (Join-Path $script:appRoot '.tqsim-install.json') -Raw|ConvertFrom-Json
        $marker.version|Should Be '1.0.8';$script:userPath|Should Match 'OtherApp;.*app with spaces'
        $result=& (Join-Path $script:appRoot 'bin/tqsim.cmd') version -NoLogo
        $LASTEXITCODE|Should Be 0;$result|Should Be '1.0.8'
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
        [IO.File]::WriteAllText("$script:package.sha256",('0'*64)+'  Tqsim-v1.0.8.zip'+"`n")
        $script:release.assets[1].size=(Get-Item "$script:package.sha256").Length
        {Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot}|Should Throw
    }
    It 'rejects a broken ZIP with valid checksum' {
        [IO.File]::WriteAllText($script:package,'not a ZIP')
        [IO.File]::WriteAllText("$script:package.sha256",(Get-FileHash $script:package).Hash+'  Tqsim-v1.0.8.zip'+"`n")
        $script:release.assets[0].size=(Get-Item $script:package).Length;$script:release.assets[1].size=(Get-Item "$script:package.sha256").Length
        {Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot}|Should Throw
    }
    It 'rejects ZIP traversal even with a valid checksum' {
        $a=[IO.Compression.ZipFile]::Open($script:package,[IO.Compression.ZipArchiveMode]::Update)
        try {$e=$a.CreateEntry('../outside.txt');$s=[IO.StreamWriter]::new($e.Open());$s.Write('unsafe');$s.Dispose()} finally {$a.Dispose()}
        [IO.File]::WriteAllText("$script:package.sha256",(Get-FileHash $script:package).Hash+'  Tqsim-v1.0.8.zip'+"`n")
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
        (& (Join-Path $script:appRoot 'bin/tqsim.cmd') version -NoLogo)|Should Be '1.0.8'
    }
    It 'updates an older selected installation through the supported command' {
        Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot
        $marker=Join-Path $script:appRoot '.tqsim-install.json';$m=Get-Content $marker -Raw|ConvertFrom-Json;$m.version='1.0.2';[IO.File]::WriteAllText($marker,($m|ConvertTo-Json))
        Update-Tqsim -InstallRoot $script:appRoot
        (Get-Content $marker -Raw|ConvertFrom-Json).version|Should Be '1.0.8'
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
        (& (Join-Path $script:appRoot 'bin/tqsim.cmd') version -NoLogo)|Should Be '1.0.8'
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
    It 'completes install uninstall reinstall cycles without abandoned directories or PATH duplicates' {
        foreach ($cycle in 1..2) {
            Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot
            (& (Join-Path $script:appRoot 'bin/tqsim.cmd') version -NoLogo)|Should Be '1.0.8'
            Uninstall-Tqsim -InstallRoot $script:appRoot
            (Test-Path -LiteralPath $script:appRoot)|Should Be $false
            $script:userPath|Should Be 'C:\OtherApp'
        }
        Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot
        @($script:userPath -split ';'|Where-Object {$_ -ieq (Join-Path $script:appRoot bin)}).Count|Should Be 1
    }
    It 'reuses the empty bin and nested versions scaffold left by an old uninstall' {
        $version=Join-Path $script:appRoot ('versions/1.0.7-'+[guid]::NewGuid())
        foreach($relative in 'src/Core','src/Commands','src/Console','examples/help','docs') {$null=[IO.Directory]::CreateDirectory((Join-Path $version $relative))}
        $null=[IO.Directory]::CreateDirectory((Join-Path $script:appRoot bin))
        Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot
        (& (Join-Path $script:appRoot 'bin/tqsim.cmd') version -NoLogo)|Should Be '1.0.8'
        Uninstall-Tqsim -InstallRoot $script:appRoot
        [IO.Directory]::Exists($script:appRoot)|Should Be $false
    }
    It 'accepts an explicitly selected empty root' {
        $null=[IO.Directory]::CreateDirectory($script:appRoot)
        Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot
        (Test-Path (Join-Path $script:appRoot '.tqsim-install.json'))|Should Be $true
    }
    It 'recovers the exact default legacy layout with empty bin and versions and no marker' {
        $env:LOCALAPPDATA=Join-Path $script:fixture 'LocalAppData'
        $script:appRoot=Join-Path $env:LOCALAPPDATA 'Programs/Tqsim'
        foreach($name in 'bin','versions'){$null=[IO.Directory]::CreateDirectory((Join-Path $script:appRoot $name))}
        (@(Get-ChildItem -LiteralPath $script:appRoot -Force).Name|Sort-Object) -join ','|Should Be 'bin,versions'
        foreach($name in 'bin','versions'){[IO.Directory]::GetFileSystemEntries((Join-Path $script:appRoot $name)).Length|Should Be 0}
        [IO.File]::Exists((Join-Path $script:appRoot '.tqsim-install.json'))|Should Be $false
        Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot
        (& (Join-Path $script:appRoot 'bin/tqsim.cmd') version -NoLogo)|Should Be '1.0.8'
        Uninstall-Tqsim -InstallRoot $script:appRoot
        [IO.Directory]::Exists($script:appRoot)|Should Be $false
        Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot
        @($script:userPath -split ';'|Where-Object {$_ -ieq (Join-Path $script:appRoot bin)}).Count|Should Be 1
    }
    It 'preserves unowned nonempty <Location> without downloading or changing PATH' -TestCases @(
        @{Location='bin'}
        @{Location='versions'}
        @{Location=('versions/1.0.7-'+[guid]::NewGuid()+'/src/Core')}
    ) {
        param($Location)
        foreach($name in 'bin','versions'){$null=[IO.Directory]::CreateDirectory((Join-Path $script:appRoot $name))}
        $dir=Join-Path $script:appRoot $Location;$null=[IO.Directory]::CreateDirectory($dir)
        $file=Join-Path $dir 'unrelated.part0001';[IO.File]::WriteAllBytes($file,[byte[]](0,255,1,128,37))
        $before=(Get-FileHash -LiteralPath $file).Hash;$beforePath=$script:userPath;$beforeSession=$env:Path
        {Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot}|Should Throw 'unowned directory'
        (Get-FileHash -LiteralPath $file).Hash|Should Be $before
        foreach($name in 'bin','versions'){[IO.Directory]::Exists((Join-Path $script:appRoot $name))|Should Be $true}
        $script:userPath|Should Be $beforePath;$env:Path|Should Be $beforeSession
        Assert-MockCalled Invoke-RestMethod -Times 0 -Exactly -Scope It
    }
    It 'blocks a directory reparse point at <Location> and preserves its target' -TestCases @(
        @{Location='root'}
        @{Location='bin'}
        @{Location='versions'}
        @{Location=('versions/1.0.7-'+[guid]::NewGuid()+'/docs')}
        @{Location='.tqsim-install.json'}
    ) {
        param($Location)
        $outside=Join-Path $script:fixture 'outside link target';$null=[IO.Directory]::CreateDirectory($outside)
        $sentinel=Join-Path $outside 'untouched.bin';[IO.File]::WriteAllText($sentinel,'keep target data')
        $link=if($Location -eq 'root'){$script:appRoot}else{Join-Path $script:appRoot $Location}
        $null=[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($link))
        $null=New-Item -ItemType Junction -Path $link -Target $outside
        try {
            {Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot}|Should Throw
            [IO.File]::ReadAllText($sentinel)|Should Be 'keep target data'
            ((Get-Item -LiteralPath $link -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)|Should Not Be 0
            Assert-MockCalled Invoke-RestMethod -Times 0 -Exactly -Scope It
            $script:userPath|Should Be 'C:\OtherApp'
        } finally {[IO.Directory]::Delete($link)}
    }
    It 'blocks symbolic-link reparse attributes before reading or adopting the installation root' {
        # Symlinks and junctions expose the same ReparsePoint attribute. Native
        # symlink creation requires a privilege absent on this test host; actual
        # junctions above exercise NTFS, and this tests the shared flag directly.
        $null=[IO.Directory]::CreateDirectory($script:appRoot)
        $script:mockRootReparse=$true
        Mock Get-Item {[pscustomobject]@{PSIsContainer=$true;Attributes=([IO.FileAttributes]::Directory -bor [IO.FileAttributes]::ReparsePoint)}} -ParameterFilter {$script:mockRootReparse -and $LiteralPath -eq $script:appRoot}
        Mock Test-TqsimEmptyInstallScaffold {throw 'Must not inspect linked contents'} -ParameterFilter {$script:mockRootReparse}
        {Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot}|Should Throw 'reparse point'
        Assert-MockCalled Test-TqsimEmptyInstallScaffold -Times 0 -Exactly -Scope It
        Assert-MockCalled Invoke-RestMethod -Times 0 -Exactly -Scope It
    }
    It 'does not bypass a corrupt or unreadable marker in the exact legacy layout' {
        foreach($name in 'bin','versions'){$null=[IO.Directory]::CreateDirectory((Join-Path $script:appRoot $name))}
        $marker=Join-Path $script:appRoot '.tqsim-install.json'
        foreach($text in '', '{broken json', '{"application":"other"}'){
            [IO.File]::WriteAllText($marker,$text)
            {Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot}|Should Throw 'ownership marker'
            [IO.File]::ReadAllText($marker)|Should Be $text
        }
        $lock=[IO.FileStream]::new($marker,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None)
        try {{Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot}|Should Throw 'unreadable installation ownership marker'}finally{$lock.Dispose()}
        foreach($name in 'bin','versions'){[IO.Directory]::GetFileSystemEntries((Join-Path $script:appRoot $name)).Length|Should Be 0}
        Assert-MockCalled Invoke-RestMethod -Times 0 -Exactly -Scope It
        $script:userPath|Should Be 'C:\OtherApp'
    }
    It 'installs uninstalls and reinstalls through the actual PATH-resolved tqsim command' {
        $env:LOCALAPPDATA=Join-Path $script:fixture 'LocalAppData'
        $script:appRoot=Join-Path $env:LOCALAPPDATA 'Programs/Tqsim'
        $env:TQSIM_TEST_USER_PATH_FILE=Join-Path $script:fixture 'isolated-user-path.txt'
        [IO.File]::WriteAllText($env:TQSIM_TEST_USER_PATH_FILE,'C:\OtherApp')
        Mock Get-TqsimUserPath {[IO.File]::ReadAllText($env:TQSIM_TEST_USER_PATH_FILE)}
        Mock Set-TqsimUserPath {param($Value)[IO.File]::WriteAllText($env:TQSIM_TEST_USER_PATH_FILE,$Value)}
        # Only the two persistent-PATH adapters are fixture substitutions in the
        # packaged uninstaller. Actual cmd/dispatcher/CLI/deployment/uninstall and
        # ownership/checksum/rollback logic run unchanged in native child pwsh.
        # Never write the real user registry PATH just to test a child process.
        $archive=[IO.Compression.ZipFile]::Open($script:package,[IO.Compression.ZipArchiveMode]::Update)
        try {
            $entry=$archive.GetEntry('uninstall.ps1');$reader=[IO.StreamReader]::new($entry.Open())
            try{$text=$reader.ReadToEnd()}finally{$reader.Dispose()}
            $get="function Get-TqsimUserPath { [Environment]::GetEnvironmentVariable('Path','User') }"
            $set="function Set-TqsimUserPath([AllowNull()][string]`$Value) { [Environment]::SetEnvironmentVariable('Path',`$Value,'User') }"
            $text.Contains($get)|Should Be $true;$text.Contains($set)|Should Be $true
            $text=$text.Replace($get,'function Get-TqsimUserPath { [IO.File]::ReadAllText($env:TQSIM_TEST_USER_PATH_FILE) }').Replace($set,'function Set-TqsimUserPath([AllowNull()][string]$Value) { [IO.File]::WriteAllText($env:TQSIM_TEST_USER_PATH_FILE,$Value) }')
            $entry.Delete();$writer=[IO.StreamWriter]::new($archive.CreateEntry('uninstall.ps1').Open())
            try{$writer.Write($text)}finally{$writer.Dispose()}
        } finally {$archive.Dispose()}
        [IO.File]::WriteAllText("$script:package.sha256",(Get-FileHash $script:package).Hash+'  Tqsim-v1.0.8.zip'+"`n")
        $script:release.assets[0].size=(Get-Item $script:package).Length;$script:release.assets[1].size=(Get-Item "$script:package.sha256").Length
        $registryBefore=[Environment]::GetEnvironmentVariable('Path','User')
        foreach($cycle in 1..2){
            Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot
            (Get-Command tqsim -ErrorAction Stop).Source|Should Be (Join-Path $script:appRoot 'bin/tqsim.cmd')
            (& tqsim version -NoLogo)|Should Be '1.0.8';$LASTEXITCODE|Should Be 0
            & tqsim unknown-command -NoLogo 2>$null
            $LASTEXITCODE|Should Be 2
            & tqsim split -File (Join-Path $script:fixture missing.bin) -Size 2 -Quiet 2>$null
            $LASTEXITCODE|Should Be 1
            & tqsim info -Manifest (Join-Path $script:fixture missing.json) -Quiet 2>$null
            $LASTEXITCODE|Should Be 3
            if($cycle -eq 1){
                $source=Join-Path $script:fixture '測試 ! payload.bin';$parts=Join-Path $script:fixture 'parts ! folder'
                [IO.File]::WriteAllBytes($source,[byte[]](0,255,1,128,37))
                & tqsim split -File $source -Size 2 -Output $parts -Quiet
                $LASTEXITCODE|Should Be 0
                & tqsim verify -PartsPath $parts -Quiet
                $LASTEXITCODE|Should Be 0
                & tqsim merge -PartsPath $parts -Quiet
                $LASTEXITCODE|Should Be 0
                (Get-FileHash (Join-Path $parts '測試 ! payload.bin')).Hash|Should Be (Get-FileHash $source).Hash
                & tqsim uninstall -NoLogo
            }else{
                # Also prove CALL from a parent cmd batch resumes after uninstall
                # deletes the inner launcher; never exit the user's parent shell.
                $caller=Join-Path $script:fixture 'parent caller.cmd'
                $receipt=Join-Path $script:fixture 'parent-survived.txt'
                [IO.File]::WriteAllText($caller,"@echo off`r`ncall tqsim uninstall -NoLogo`r`nset tqsim_test_exit=%errorlevel%`r`necho survived> `"$receipt`"`r`nexit /b %tqsim_test_exit%`r`n")
                & $caller
            }
            $LASTEXITCODE|Should Be 0
            if($cycle -eq 2){[IO.File]::ReadAllText($receipt).Trim()|Should Be 'survived'}
            [IO.Directory]::Exists($script:appRoot)|Should Be $false
            [IO.File]::ReadAllText($env:TQSIM_TEST_USER_PATH_FILE)|Should Be 'C:\OtherApp'
            [Environment]::GetEnvironmentVariable('Path','User')|Should Be $registryBefore
        }
        Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot
        (& tqsim version -NoLogo)|Should Be '1.0.8';$LASTEXITCODE|Should Be 0
        @([IO.File]::ReadAllText($env:TQSIM_TEST_USER_PATH_FILE) -split ';'|Where-Object {$_ -ieq (Join-Path $script:appRoot bin)}).Count|Should Be 1
    }
    It 'retains ownership and all unrelated data so reinstall after a data-preserving uninstall works' {
        Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot
        $m=Get-Content (Join-Path $script:appRoot '.tqsim-install.json') -Raw|ConvertFrom-Json
        $paths=@((Join-Path $script:appRoot 'backup.tqsim.json'),(Join-Path $script:appRoot 'bin/user.txt'),(Join-Path $m.current 'src/Core/backup.part0001'))
        foreach($path in $paths){[IO.File]::WriteAllText($path,'preserve exact bytes')}
        Uninstall-Tqsim -InstallRoot $script:appRoot
        (Test-Path (Join-Path $script:appRoot '.tqsim-install.json'))|Should Be $true
        Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot
        foreach($path in $paths){[IO.File]::ReadAllText($path)|Should Be 'preserve exact bytes'}
        (& (Join-Path $script:appRoot 'bin/tqsim.cmd') version -NoLogo)|Should Be '1.0.8'
    }
    It 'refuses markerless leftovers containing hidden files or unknown directories without touching them' {
        $bin=Join-Path $script:appRoot bin;$null=[IO.Directory]::CreateDirectory($bin)
        $file=Join-Path $bin 'private.bin';[IO.File]::WriteAllText($file,'keep');[IO.File]::SetAttributes($file,[IO.FileAttributes]::Hidden)
        {Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot}|Should Throw 'unowned directory'
        [IO.File]::ReadAllText($file)|Should Be 'keep'
        [IO.File]::SetAttributes($file,[IO.FileAttributes]::Normal);[IO.File]::Delete($file)
        $unknown=Join-Path $script:appRoot unknown;$null=[IO.Directory]::CreateDirectory($unknown)
        {Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot}|Should Throw 'unowned directory'
        [IO.Directory]::Exists($unknown)|Should Be $true
    }
    It 'refuses corrupt empty or directory ownership markers without replacing them' {
        $null=[IO.Directory]::CreateDirectory($script:appRoot);$marker=Join-Path $script:appRoot '.tqsim-install.json'
        foreach($text in '', '{', '{"application":"other"}'){
            [IO.File]::WriteAllText($marker,$text)
            {Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot}|Should Throw 'ownership marker'
            [IO.File]::ReadAllText($marker)|Should Be $text
        }
        [IO.File]::Delete($marker);$null=[IO.Directory]::CreateDirectory($marker)
        {Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot}|Should Throw 'ownership marker'
        [IO.Directory]::Exists($marker)|Should Be $true
    }
    It 'reports an unreadable locked marker without changing files or PATH' {
        Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot
        $marker=Join-Path $script:appRoot '.tqsim-install.json';$before=[IO.File]::ReadAllText($marker);$beforePath=$script:userPath
        $lock=[IO.FileStream]::new($marker,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None)
        try {{Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot}|Should Throw 'unreadable installation ownership marker'} finally {$lock.Dispose()}
        [IO.File]::ReadAllText($marker)|Should Be $before;$script:userPath|Should Be $beforePath
        (& (Join-Path $script:appRoot 'bin/tqsim.cmd') version -NoLogo)|Should Be '1.0.8'
    }
    It 'refuses orphan directory junctions and never visits their target' {
        $outside=Join-Path $script:fixture outside;$null=[IO.Directory]::CreateDirectory($outside)
        $file=Join-Path $outside 'keep.txt';[IO.File]::WriteAllText($file,'keep')
        $null=[IO.Directory]::CreateDirectory($script:appRoot);$link=Join-Path $script:appRoot versions
        $null=New-Item -ItemType Junction -Path $link -Target $outside
        try {
            {Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot}|Should Throw
            [IO.File]::ReadAllText($file)|Should Be 'keep'
        } finally {[IO.Directory]::Delete($link)}
    }
    It 'keeps the marker when uninstallation cannot finish deleting owned files' {
        Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot
        $marker=Join-Path $script:appRoot '.tqsim-install.json';$m=Get-Content $marker -Raw|ConvertFrom-Json
        $file=Join-Path $m.current README.md;[IO.File]::SetAttributes($file,[IO.FileAttributes]::ReadOnly)
        try {{Uninstall-Tqsim -InstallRoot $script:appRoot}|Should Throw;[IO.File]::Exists($marker)|Should Be $true;[IO.File]::Exists((Join-Path $m.current version.json))|Should Be $true}
        finally {[IO.File]::SetAttributes($file,[IO.FileAttributes]::Normal)}
        Uninstall-Tqsim -InstallRoot $script:appRoot
        [IO.Directory]::Exists($script:appRoot)|Should Be $false
    }
    It 'can retry installation after a late failure while recovering an old empty scaffold' {
        $null=[IO.Directory]::CreateDirectory((Join-Path $script:appRoot bin));$null=[IO.Directory]::CreateDirectory((Join-Path $script:appRoot versions))
        $script:pathCalls=0
        Mock Set-TqsimUserPath {param($Value)$script:pathCalls++;if($script:pathCalls -eq 1){throw 'PATH denied'};$script:userPath=$Value}
        {Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot}|Should Throw
        Install-TqsimRelease -Repository example/tqsim -InstallRoot $script:appRoot
        (& (Join-Path $script:appRoot 'bin/tqsim.cmd') version -NoLogo)|Should Be '1.0.8'
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
