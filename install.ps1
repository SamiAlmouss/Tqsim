[CmdletBinding()]
param([string]$Repository='SamiAlmouss/Tqsim',[string]$InstallRoot=(Join-Path $env:LOCALAPPDATA 'Programs/Tqsim'))
$ErrorActionPreference='Stop'
function Get-TqsimUserPath { [Environment]::GetEnvironmentVariable('Path','User') }
function Set-TqsimUserPath([AllowNull()][string]$Value) { [Environment]::SetEnvironmentVariable('Path',$Value,'User') }
function Get-TqsimInstallerRuntimeVersion { return $PSVersionTable.PSVersion }
function Test-TqsimRuntimeAvailable { return ((Get-TqsimInstallerRuntimeVersion).Major -ge 7) }
function Invoke-TqsimInstallerProcess([string]$Executable,[string]$Arguments,[int]$TimeoutMilliseconds=0) {
    $info=New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName=$Executable;$info.Arguments=$Arguments
    $info.UseShellExecute=$false;$info.CreateNoWindow=$true
    $info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
    $info.StandardOutputEncoding=[Text.Encoding]::UTF8;$info.StandardErrorEncoding=[Text.Encoding]::UTF8
    $process=New-Object System.Diagnostics.Process
    $process.StartInfo=$info
    try {
        if (!$process.Start()) {throw "Could not start $Executable."}
        # Drain both pipes concurrently, including failures, to avoid pipe deadlocks.
        $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
        if ($TimeoutMilliseconds -gt 0) {
            if (!$process.WaitForExit($TimeoutMilliseconds)) {$process.Kill();$process.WaitForExit();throw "PowerShell probe timed out: $Executable"}
        } else {$process.WaitForExit()}
        return [pscustomobject]@{ExitCode=$process.ExitCode;StdOut=$stdout.GetAwaiter().GetResult();StdErr=$stderr.GetAwaiter().GetResult()}
    } finally {$process.Dispose()}
}
function Test-TqsimPowerShellExecutable([string]$Path) {
    try {
        $result=Invoke-TqsimInstallerProcess $Path '-NoLogo -NoProfile -NonInteractive -Command "$PSVersionTable.PSVersion.Major"' -TimeoutMilliseconds 15000
        $major=0
        return ($result.ExitCode -eq 0 -and [int]::TryParse($result.StdOut.Trim(),[ref]$major) -and $major -ge 7)
    } catch {return $false}
}
function Find-TqsimPowerShell {
    $candidates=New-Object 'System.Collections.Generic.List[string]'
    foreach ($command in @(Get-Command pwsh.exe -CommandType Application -All -ErrorAction SilentlyContinue)) {$candidates.Add($command.Source)}
    foreach ($base in @($env:ProgramFiles,$env:ProgramW6432,${env:ProgramFiles(x86)})) {
        if ($base) {$candidates.Add((Join-Path $base 'PowerShell/7/pwsh.exe'))}
    }
    foreach ($base in @($env:LOCALAPPDATA,[Environment]::GetFolderPath('LocalApplicationData'))) {
        if ($base) {
            $candidates.Add((Join-Path $base 'Microsoft/WindowsApps/pwsh.exe'))
            $candidates.Add((Join-Path $base 'Programs/PowerShell/7/pwsh.exe'))
        }
    }
    $seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($path in $candidates) {
        if ($seen.Add($path) -and (Test-Path -LiteralPath $path -PathType Leaf) -and (Test-TqsimPowerShellExecutable $path)) {return $path}
    }
    return $null
}
function Start-TqsimInstallerBootstrap([string]$Executable,[string]$Repository,[string]$InstallRoot) {
    # Serialize only our self-contained installer functions. No original script
    # path, second network request, or moving-branch re-download is required.
    $names=@('Get-TqsimUserPath','Set-TqsimUserPath','Get-TqsimInstallerRuntimeVersion','Test-TqsimRuntimeAvailable','Invoke-TqsimInstallerProcess','Test-TqsimPowerShellExecutable','Find-TqsimPowerShell','Start-TqsimInstallerBootstrap','Invoke-TqsimInstaller','Install-TqsimRelease')
    $definitions=foreach ($name in $names) {"function $name {`n"+(Get-Command $name -CommandType Function -ErrorAction Stop).Definition+"`n}"}
    $configuration=@{Repository=$Repository;InstallRoot=$InstallRoot}|ConvertTo-Json -Compress
    $encodedConfiguration=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($configuration))
    $payload='$ErrorActionPreference = ''Stop'''+"`n"+($definitions -join "`n")+"`n"+
        '$configuration = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('''+$encodedConfiguration+''')) | ConvertFrom-Json'+"`n"+@'
try {
    $code=Invoke-TqsimInstaller -Repository $configuration.Repository -InstallRoot $configuration.InstallRoot -Relaunched
    exit $code
} catch {
    [Console]::Error.WriteLine('Tqsim installation failed: '+$_.Exception.Message)
    exit 1
}
'@
    $directory=Join-Path ([IO.Path]::GetTempPath()) ('Tqsim-bootstrap-'+[guid]::NewGuid())
    $null=[IO.Directory]::CreateDirectory($directory);$script=Join-Path $directory 'bootstrap.ps1'
    try {
        [IO.File]::WriteAllText($script,$payload,(New-Object Text.UTF8Encoding $true))
        $encodedPath=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($script))
        # A short encoded loader avoids Windows' command-line size limit and
        # quoting hazards. Execution policy is not changed at any scope.
        $loader='$ErrorActionPreference=''Stop''; try { $path=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('''+$encodedPath+''')); & ([scriptblock]::Create([IO.File]::ReadAllText($path))) } catch { [Console]::Error.WriteLine($_.Exception.Message); exit 1 }'
        $encodedLoader=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($loader))
        $result=Invoke-TqsimInstallerProcess $Executable ('-NoLogo -NoProfile -NonInteractive -OutputFormat Text -EncodedCommand '+$encodedLoader)
        if ($result.StdOut) {[Console]::Out.Write($result.StdOut)}
        if ($result.StdErr) {[Console]::Error.Write($result.StdErr)}
        return [int]$result.ExitCode
    } finally {
        # Only this invocation's generated file is deleted; no recursive cleanup.
        if ([IO.File]::Exists($script)) {[IO.File]::Delete($script)}
        if ([IO.Directory]::Exists($directory) -and [IO.Directory]::GetFileSystemEntries($directory).Length -eq 0) {[IO.Directory]::Delete($directory)}
    }
}
function Invoke-TqsimInstaller {
    param([string]$Repository,[string]$InstallRoot,[switch]$Relaunched)
    if ($env:OS -ne 'Windows_NT') {throw 'Tqsim installation requires Windows.'}
    $runtime=Get-TqsimInstallerRuntimeVersion
    if ($runtime.Major -ge 7) {
        Install-TqsimRelease -Repository $Repository -InstallRoot $InstallRoot | Out-Host
        return 0
    }
    if ($Relaunched) {throw "Installer handoff started PowerShell $runtime instead of PowerShell 7+. Refusing to relaunch again."}
    $pwsh=Find-TqsimPowerShell
    if (!$pwsh) {throw 'PowerShell 7 was not found. Install it with: winget install --id Microsoft.PowerShell --source winget'}
    Write-Host "PowerShell $runtime detected; continuing the installer in PowerShell 7+."
    return Start-TqsimInstallerBootstrap -Executable $pwsh -Repository $Repository -InstallRoot $InstallRoot
}
# This script is intentionally self-contained for irm | iex.
function Install-TqsimRelease {
    param([string]$Repository,[string]$InstallRoot)
    if ($env:OS -ne 'Windows_NT') {throw 'Tqsim installation requires Windows.'}
    if (!(Test-TqsimRuntimeAvailable)) {throw 'Install PowerShell 7 first: winget install --id Microsoft.PowerShell --source winget'}
    if ($Repository -notmatch '^[A-Za-z0-9_.-]+/tqsim$' -or $Repository -like 'USERNAME/*') {throw 'Set -Repository to the actual GitHub owner/tqsim, or replace USERNAME in install.ps1 before publishing.'}
    $root=[IO.Path]::GetFullPath($InstallRoot);$parent=[IO.Path]::GetDirectoryName($root)
    $null=[IO.Directory]::CreateDirectory($parent)
    $walk=[IO.DirectoryInfo]::new($parent)
    while ($walk) {if ($walk.Attributes -band [IO.FileAttributes]::ReparsePoint) {throw 'Installation path cannot contain reparse points.'};$walk=$walk.Parent}
    if ((Test-Path -LiteralPath $root) -and ((Get-Item -LiteralPath $root).Attributes -band [IO.FileAttributes]::ReparsePoint)) {throw 'Installation root cannot be a reparse point.'}
    if ((Test-Path -LiteralPath $root) -and !(Test-Path -LiteralPath (Join-Path $root '.tqsim-install.json'))) {throw 'Refusing to replace an unowned directory.'}
    $rootExisted=Test-Path -LiteralPath $root
    $temp=Join-Path ([IO.Path]::GetTempPath()) ('Tqsim-'+[guid]::NewGuid())
    $stage=Join-Path $root ('versions/.stage-'+[guid]::NewGuid());$published=$null;$previousPath=Get-TqsimUserPath;$previousSession=$env:Path;$marker=Join-Path $root '.tqsim-install.json';$oldMarker=if ([IO.File]::Exists($marker)) {[IO.File]::ReadAllText($marker)} else {$null}
    if ($oldMarker -and (($oldMarker|ConvertFrom-Json).application -cne 'Tqsim')) {throw 'Invalid installation marker.'}
    foreach ($relative in 'versions','bin') { $p=Join-Path $root $relative;if ((Test-Path -LiteralPath $p) -and ((Get-Item -LiteralPath $p).Attributes -band [IO.FileAttributes]::ReparsePoint)) {throw 'Installation subdirectories cannot be reparse points.'} }
    $null=[IO.Directory]::CreateDirectory($temp)
    try {
        $release=Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases/latest" -Headers @{'User-Agent'='Tqsim-installer';Accept='application/vnd.github+json'}
        if ($release.draft -or $release.prerelease -or $release.tag_name -notmatch '^v(\d+\.\d+\.\d+)$') {throw 'Invalid stable release metadata.'};$version=$Matches[1]
        $assetName="Tqsim-v$version.zip";$assets=@($release.assets|Where-Object name -CEQ $assetName);$checks=@($release.assets|Where-Object name -CEQ "$assetName.sha256")
        if ($assets.Count -ne 1 -or $checks.Count -ne 1) {throw 'Release package or checksum missing/duplicated.'}
        foreach ($asset in @($assets[0],$checks[0])) {
            $expected="https://github.com/$Repository/releases/download/v$version/$($asset.name)"
            if ($asset.browser_download_url -cne $expected -or $asset.size -le 0) {throw 'Invalid asset identity.'}
            Invoke-WebRequest -Uri $expected -OutFile (Join-Path $temp $asset.name) -Headers @{'User-Agent'='Tqsim-installer'}
            if ((Get-Item -LiteralPath (Join-Path $temp $asset.name)).Length -ne $asset.size) {throw 'Downloaded asset size mismatch.'}
        }
        $zip=Join-Path $temp $assetName;$checksum=[IO.File]::ReadAllText("$zip.sha256").Trim()
        if ($checksum -notmatch ('^([a-fA-F0-9]{64})\s+\*?'+[regex]::Escape($assetName)+'$')) {throw 'Malformed checksum.'};$expectedHash=$Matches[1]
        if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ine $expectedHash) {throw 'Package checksum mismatch.'}
        $extract=Join-Path $temp 'extracted';$null=[IO.Directory]::CreateDirectory($extract);$archive=[IO.Compression.ZipFile]::OpenRead($zip)
        try {
            $names=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            foreach ($entry in $archive.Entries) {
                $relative=$entry.FullName.Replace('\','/');$segments=$relative.Split('/')
                if ($relative.StartsWith('/') -or $relative.Contains(':') -or @($segments|Where-Object {$_ -in '.','..' -or $_ -match '[ .]$|[<>:"|?*\x00-\x1f]' -or $_ -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)'}).Count -or !$names.Add($relative) -or (($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) {throw 'Unsafe ZIP entry.'}
                $target=[IO.Path]::GetFullPath((Join-Path $extract $relative))
                if (!$target.StartsWith($extract+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {throw 'ZIP traversal rejected.'}
                if ($relative.EndsWith('/')) {$null=[IO.Directory]::CreateDirectory($target)} else {$null=[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target));[IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$target,$false)}
            }
        } finally {$archive.Dispose()}
        foreach ($required in 'tqsim.ps1','src/Core/Tqsim.psm1','src/Core/Deletion.ps1','examples/help.txt','src/Commands/CLI.ps1','src/Console/Branding.ps1','examples/help/split.txt','examples/help/merge.txt','examples/help/verify.txt','examples/help/info.txt','examples/help/update.txt','examples/help/uninstall.txt','examples/help/version.txt','examples/help/help.txt','install.ps1','update.ps1','uninstall.ps1','version.json') {if (![IO.File]::Exists((Join-Path $extract $required))) {throw "Missing package file: $required"}}
        $metadata=[IO.File]::ReadAllText((Join-Path $extract 'version.json'))|ConvertFrom-Json
        if ($metadata.application -cne 'Tqsim' -or $metadata.version -cne $version) {throw 'Package version mismatch.'}
        $null=[IO.Directory]::CreateDirectory($stage);Copy-Item -Path "$extract/*" -Destination $stage -Recurse
        $published=Join-Path $root ('versions/'+$version+'-'+[guid]::NewGuid());[IO.Directory]::Move($stage,$published)
        $bin=Join-Path $root 'bin';$null=[IO.Directory]::CreateDirectory($bin)
        $launcher=Join-Path $bin 'tqsim.cmd';$oldLauncher=if ([IO.File]::Exists($launcher)) {[IO.File]::ReadAllText($launcher)} else {$null}
        # A stable dispatcher reads the selected immutable installation. No application code runs before checksum validation.
        $dispatcher=Join-Path $bin 'dispatch.ps1'
        [IO.File]::WriteAllText($dispatcher, '@{'+"`n"+'} | Out-Null'+"`n"+'$m=Get-Content -LiteralPath (Join-Path $PSScriptRoot ''../.tqsim-install.json'') -Raw | ConvertFrom-Json'+"`n"+'& (Join-Path $m.current ''tqsim.ps1'') @args'+"`n"+'exit $LASTEXITCODE')
        [IO.File]::WriteAllText($launcher,"@echo off`r`npwsh.exe -NoLogo -NoProfile -File `"%~dp0dispatch.ps1`" %*`r`nexit /b %errorlevel%`r`n")
        $newMarker=Join-Path $root ('.marker-'+[guid]::NewGuid()+'.tmp')
        [IO.File]::WriteAllText($newMarker,(@{application='Tqsim';version=$version;repository=$Repository;current=$published}|ConvertTo-Json))
        if ([IO.File]::Exists($marker)) {[IO.File]::Replace($newMarker,$marker,[System.Management.Automation.Language.NullString]::Value)} else {[IO.File]::Move($newMarker,$marker)}
        $entries=@($previousPath -split ';'|Where-Object {$_});if (!@($entries|Where-Object {$_.TrimEnd('\') -ieq $bin.TrimEnd('\')}).Count) {Set-TqsimUserPath (($entries+$bin)-join ';')}
        if (!@($env:Path -split ';'|Where-Object {$_.TrimEnd('\') -ieq $bin.TrimEnd('\')}).Count) {$env:Path+=";$bin"}
        Write-Host "Installed Tqsim $version ($([Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture)). Run tqsim version."
    } catch {
        Set-TqsimUserPath $previousPath;$env:Path=$previousSession
        if ($oldMarker) {[IO.File]::WriteAllText($marker,$oldMarker)} elseif ([IO.File]::Exists($marker)) {[IO.File]::Delete($marker)}
        if (!$rootExisted) {
            # Remove only known staged application files; retain any unexpected user data.
            foreach ($candidate in @($stage,$published)|Where-Object {$_}) {
                $resolved=[IO.Path]::GetFullPath($candidate)
                if (!$resolved.StartsWith((Join-Path $root 'versions')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {continue}
                foreach ($relative in 'tqsim.ps1','install.ps1','update.ps1','uninstall.ps1','version.json','README.md','IMPLEMENTATION.md','LICENSE','src/Core/Tqsim.psm1','src/Core/Deletion.ps1','examples/help.txt','src/Commands/CLI.ps1','src/Console/Branding.ps1','examples/help/split.txt','examples/help/merge.txt','examples/help/verify.txt','examples/help/info.txt','examples/help/update.txt','examples/help/uninstall.txt','examples/help/version.txt','examples/help/help.txt') {$p=Join-Path $resolved $relative;if ([IO.File]::Exists($p)) {[IO.File]::Delete($p)}}
                foreach ($relative in 'src/Core','src/Commands','src/Console','src','examples/help','examples','') {$p=if ($relative) {Join-Path $resolved $relative} else {$resolved};if ([IO.Directory]::Exists($p) -and [IO.Directory]::GetFileSystemEntries($p).Length -eq 0) {[IO.Directory]::Delete($p)}}
            }
            foreach ($relative in 'bin/tqsim.cmd','bin/dispatch.ps1') {$p=Join-Path $root $relative;if ([IO.File]::Exists($p)) {[IO.File]::Delete($p)}}
            foreach ($relative in 'bin','versions','') {$p=if ($relative) {Join-Path $root $relative} else {$root};if ([IO.Directory]::Exists($p) -and [IO.Directory]::GetFileSystemEntries($p).Length -eq 0) {[IO.Directory]::Delete($p)}}
        }
        throw
    } finally {
        # All cleanup is constrained to the unique installer-owned temporary directory.
        if ($temp -and [IO.Path]::GetFullPath($temp).StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()),[StringComparison]::OrdinalIgnoreCase)) {Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
    }
}
if ($MyInvocation.InvocationName -ne '.') {
    $installerExitCode=1
    try {
        $installerExitCode=Invoke-TqsimInstaller `
            -Repository $Repository `
            -InstallRoot $InstallRoot
        $global:LASTEXITCODE=$installerExitCode
        if ($installerExitCode -ne 0) {throw "PowerShell 7 installer exited with code $installerExitCode. See the child error above."}
    }
    catch {
        # Never exit the caller: irm | iex runs inside the user's parent shell.
        $global:LASTEXITCODE=$installerExitCode
        throw "Tqsim installation failed: $($_.Exception.Message)"
    }
}
