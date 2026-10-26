#requires -Version 7.0
$ErrorActionPreference='Stop'
function Get-TqsimUserPath { [Environment]::GetEnvironmentVariable('Path','User') }
function Set-TqsimUserPath([AllowNull()][string]$Value) { [Environment]::SetEnvironmentVariable('Path',$Value,'User') }
function Uninstall-Tqsim {
param([string]$InstallRoot)
$root=[IO.Path]::GetFullPath($InstallRoot);$marker=Join-Path $root '.tqsim-install.json'
foreach ($relative in '', 'versions', 'bin') {
    $walk=[IO.DirectoryInfo]::new($(if ($relative) {Join-Path $root $relative} else {$root}))
    while ($walk) {if ($walk.Exists -and ($walk.Attributes -band [IO.FileAttributes]::ReparsePoint)) {throw 'Uninstall paths cannot contain reparse points.'};$walk=$walk.Parent}
}
if (!(Test-Path -LiteralPath $marker)) {throw 'Run the installed tqsim uninstall command.'}
if ((Get-Item -LiteralPath $marker -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {throw 'Unsafe installation marker.'}
$m=[IO.File]::ReadAllText($marker)|ConvertFrom-Json
if ($m.application -cne 'Tqsim' -or !([IO.Path]::GetFullPath($m.current)).StartsWith((Join-Path $root 'versions')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {throw 'Invalid installation ownership marker.'}
$bin=Join-Path $root 'bin'
$entries=(Get-TqsimUserPath) -split ';'
Set-TqsimUserPath (($entries|Where-Object {$_.TrimEnd('\') -ine $bin.TrimEnd('\')})-join ';')
$env:Path=(($env:Path -split ';'|Where-Object {$_.TrimEnd('\') -ine $bin.TrimEnd('\')})-join ';')
# Delete only application file names, preserving arbitrary data even inside the install directory.
$owned=@('tqsim.ps1','install.ps1','update.ps1','uninstall.ps1','version.json','README.md','IMPLEMENTATION.md','LICENSE','src/Core/Tqsim.psm1','examples/help.txt','src/Commands/CLI.ps1','src/Console/Branding.ps1','examples/help/split.txt','examples/help/merge.txt','examples/help/verify.txt','examples/help/info.txt','examples/help/update.txt','examples/help/uninstall.txt','examples/help/version.txt','examples/help/help.txt')
foreach ($version in @(Get-ChildItem -LiteralPath (Join-Path $root 'versions') -Directory)) {
    if ($version.Attributes -band [IO.FileAttributes]::ReparsePoint) {continue}
    if ($version.Name -notmatch '^\d+\.\d+\.\d+-[0-9a-fA-F-]{36}$') {continue}
    $versionMetadata=Join-Path $version.FullName 'version.json'
    if (![IO.File]::Exists($versionMetadata) -or ((Get-Item -LiteralPath $versionMetadata -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {continue}
    try {if (([IO.File]::ReadAllText($versionMetadata)|ConvertFrom-Json).application -cne 'Tqsim') {continue}} catch {continue}
    foreach ($relative in $owned) {
        $path=Join-Path $version.FullName $relative;$walk=[IO.DirectoryInfo]::new([IO.Path]::GetDirectoryName($path));$safe=$true
        while ($walk -and $walk.FullName.Length -ge $root.Length) {if ($walk.Exists -and ($walk.Attributes -band [IO.FileAttributes]::ReparsePoint)) {$safe=$false;break};$walk=$walk.Parent}
        if ($safe -and [IO.File]::Exists($path) -and !((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {[IO.File]::Delete($path)}
    }
}
foreach ($relative in 'bin/tqsim.cmd','bin/dispatch.ps1','.tqsim-install.json') {$path=Join-Path $root $relative;if ([IO.File]::Exists($path)) {[IO.File]::Delete($path)}}
Write-Output 'Tqsim uninstalled. User data and directories preserved. Restart your terminal to refresh PATH.'
}
if ($MyInvocation.InvocationName -ne '.') {Uninstall-Tqsim -InstallRoot ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')))}
