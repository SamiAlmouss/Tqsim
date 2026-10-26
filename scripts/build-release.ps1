#requires -Version 7.0
[CmdletBinding()]param([string]$OutputDirectory=(Join-Path $PSScriptRoot '../dist'))
$ErrorActionPreference='Stop';$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$v=([IO.File]::ReadAllText((Join-Path $root 'version.json'))|ConvertFrom-Json).version
if ($v -notmatch '^\d+\.\d+\.\d+$') {throw 'Invalid version.'}
$null=[IO.Directory]::CreateDirectory($OutputDirectory);$zip=Join-Path $OutputDirectory "Tqsim-v$v.zip"
if (Test-Path -LiteralPath $zip) {throw 'Release already exists. Use a fresh output directory.'}
$archive=[IO.Compression.ZipFile]::Open($zip,[IO.Compression.ZipArchiveMode]::Create)
try {foreach ($relative in 'tqsim.ps1','install.ps1','update.ps1','uninstall.ps1','version.json','README.md','IMPLEMENTATION.md','LICENSE','src/Core/Tqsim.psm1','examples/help.txt','src/Commands/CLI.ps1','src/Console/Branding.ps1','examples/help/split.txt','examples/help/merge.txt','examples/help/verify.txt','examples/help/info.txt','examples/help/update.txt','examples/help/uninstall.txt','examples/help/version.txt','examples/help/help.txt') {$null=[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,(Join-Path $root $relative),$relative,[IO.Compression.CompressionLevel]::Optimal)}} finally {$archive.Dispose()}
[IO.File]::WriteAllText("$zip.sha256",((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()+"  Tqsim-v$v.zip`n"));Write-Output $zip
