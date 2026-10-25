#requires -Version 7.0
$ErrorActionPreference='Stop'
. "$PSScriptRoot/install.ps1"
function Update-Tqsim {
param([string]$InstallRoot)
$root=[IO.Path]::GetFullPath($InstallRoot)
$marker=Join-Path $root '.tqsim-install.json'
if (!(Test-Path -LiteralPath $marker)) {throw 'Run updates from the installed tqsim command.'}
$installed=[IO.File]::ReadAllText($marker)|ConvertFrom-Json
$release=Invoke-RestMethod "https://api.github.com/repos/$($installed.repository)/releases/latest" -Headers @{'User-Agent'='Tqsim-update'}
if ($release.tag_name -notmatch '^v(\d+\.\d+\.\d+)$') {throw 'Invalid release version.'}
if ([version]$Matches[1] -le [version]$installed.version) {Write-Output "Tqsim $($installed.version) is current.";return}
Install-TqsimRelease -Repository $installed.repository -InstallRoot $root
}
if ($MyInvocation.InvocationName -ne '.') {Update-Tqsim -InstallRoot ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')))}
