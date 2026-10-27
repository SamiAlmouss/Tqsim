#requires -Version 7.0
$ErrorActionPreference='Stop'
function Get-TqsimUserPath { [Environment]::GetEnvironmentVariable('Path','User') }
function Set-TqsimUserPath([AllowNull()][string]$Value) { [Environment]::SetEnvironmentVariable('Path',$Value,'User') }
function Remove-TqsimEmptyInstallDirectory([string]$Path,[string]$Root) {
    $full=[IO.Path]::GetFullPath($Path);$boundary=[IO.Path]::GetFullPath($Root)
    if ($full -ine $boundary -and !$full.StartsWith($boundary+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {throw 'Directory cleanup escaped the installation root.'}
    $walk=[IO.DirectoryInfo]::new($full)
    while ($walk) {if ($walk.Exists -and ($walk.Attributes -band [IO.FileAttributes]::ReparsePoint)) {return};$walk=$walk.Parent}
    if ([IO.Directory]::Exists($full) -and [IO.Directory]::GetFileSystemEntries($full).Length -eq 0) {
        # Nonrecursive delete also fails closed if a file appears after enumeration.
        [IO.Directory]::Delete($full,$false)
    }
}
function Uninstall-Tqsim {
param([string]$InstallRoot)
$root=[IO.Path]::GetFullPath($InstallRoot);$marker=Join-Path $root '.tqsim-install.json'
foreach ($relative in '', 'versions', 'bin') {
    $walk=[IO.DirectoryInfo]::new($(if ($relative) {Join-Path $root $relative} else {$root}))
    while ($walk) {if ($walk.Exists -and ($walk.Attributes -band [IO.FileAttributes]::ReparsePoint)) {throw 'Uninstall paths cannot contain reparse points.'};$walk=$walk.Parent}
}
if (!(Test-Path -LiteralPath $marker)) {throw 'Run the installed tqsim uninstall command.'}
if ((Get-Item -LiteralPath $marker -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {throw 'Unsafe installation marker.'}
try {$m=[IO.File]::ReadAllText($marker)|ConvertFrom-Json -ErrorAction Stop} catch {throw 'Invalid or unreadable installation ownership marker. No application files were removed.'}
if ($m.application -cne 'Tqsim' -or !([IO.Path]::GetFullPath($m.current)).StartsWith((Join-Path $root 'versions')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {throw 'Invalid installation ownership marker.'}
$bin=Join-Path $root 'bin'
$entries=(Get-TqsimUserPath) -split ';'
Set-TqsimUserPath (($entries|Where-Object {$_.TrimEnd('\') -ine $bin.TrimEnd('\')})-join ';')
$env:Path=(($env:Path -split ';'|Where-Object {$_.TrimEnd('\') -ine $bin.TrimEnd('\')})-join ';')
# Delete only application file names, preserving arbitrary data even inside the install directory.
$owned=@('tqsim.ps1','install.ps1','update.ps1','uninstall.ps1','version.json','README.md','README.ar.md','CHANGELOG.md','docs/COMMANDS.md','docs/PARAMETERS.md','docs/TROUBLESHOOTING.md','docs/HELP-COVERAGE.md','docs/INSTALLER-BOOTSTRAP.md','docs/PERFORMANCE-v1.0.5.md','docs/VALIDATION-v1.0.4.md','docs/VALIDATION-v1.0.5.md','docs/VALIDATION-v1.0.6.md','docs/VALIDATION-v1.0.7.md','docs/VALIDATION-v1.0.8.md','IMPLEMENTATION.md','LICENSE','src/Core/Tqsim.psm1','src/Core/Deletion.ps1','src/Core/Encryption.ps1','src/Core/Crypto.cs','src/Core/Errors.ps1','docs/ENCRYPTED-FORMAT-v1.md','examples/help.txt','src/Commands/CLI.ps1','src/Console/Branding.ps1','examples/help/split.txt','examples/help/merge.txt','examples/help/verify.txt','examples/help/info.txt','examples/help/update.txt','examples/help/uninstall.txt','examples/help/version.txt','examples/help/help.txt')
$versions=Join-Path $root 'versions'
foreach ($version in @(if ([IO.Directory]::Exists($versions)) {Get-ChildItem -LiteralPath $versions -Directory -Force})) {
    if ($version.Attributes -band [IO.FileAttributes]::ReparsePoint) {continue}
    if ($version.Name -notmatch '^\d+\.\d+\.\d+-[0-9a-fA-F-]{36}$') {continue}
    $versionMetadata=Join-Path $version.FullName 'version.json'
    $managed=$false
    if ([IO.File]::Exists($versionMetadata) -and !((Get-Item -LiteralPath $versionMetadata -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        try {$managed=([IO.File]::ReadAllText($versionMetadata)|ConvertFrom-Json).application -ceq 'Tqsim'} catch {}
    }
    # Keep each version's ownership proof until its file cleanup completes, so
    # an interrupted/denied deletion can be retried without guessing ownership.
    if ($managed) {foreach ($relative in @($owned|Where-Object {$_ -ne 'version.json'})+@('version.json')) {
        $path=Join-Path $version.FullName $relative;$walk=[IO.DirectoryInfo]::new([IO.Path]::GetDirectoryName($path));$safe=$true
        while ($walk -and $walk.FullName.Length -ge $root.Length) {if ($walk.Exists -and ($walk.Attributes -band [IO.FileAttributes]::ReparsePoint)) {$safe=$false;break};$walk=$walk.Parent}
        if ($safe -and [IO.File]::Exists($path) -and !((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {[IO.File]::Delete($path)}
    }}
    foreach ($relative in 'src/Core','src/Commands','src/Console','src','examples/help','examples','docs','') {
        $path=if ($relative) {Join-Path $version.FullName $relative} else {$version.FullName}
        Remove-TqsimEmptyInstallDirectory $path $root
    }
}
foreach ($relative in 'bin/tqsim.cmd','bin/dispatch.ps1') {
    $path=Join-Path $root $relative
    if ([IO.File]::Exists($path) -and !((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {[IO.File]::Delete($path)}
}
foreach ($relative in 'bin','versions') {Remove-TqsimEmptyInstallDirectory (Join-Path $root $relative) $root}
$remaining=@([IO.Directory]::GetFileSystemEntries($root)|Where-Object {$_ -ine $marker})
if ($remaining.Count -eq 0) {
    # Ownership is removed last, only after all other owned content is cleaned up.
    [IO.File]::Delete($marker);Remove-TqsimEmptyInstallDirectory $root $root
    Write-Output 'Tqsim uninstalled. Empty application directories removed. Restart your terminal to refresh PATH.'
} else {
    # Keep provenance so preserved user files do not prevent a later reinstall.
    # The retained marker is not an active launcher and is removed on clean uninstall.
    Write-Output 'Tqsim uninstalled. Remaining user files/directories and the ownership marker were preserved for safe reinstallation. Restart your terminal to refresh PATH.'
}
}
if ($MyInvocation.InvocationName -ne '.') {Uninstall-Tqsim -InstallRoot ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')))}
