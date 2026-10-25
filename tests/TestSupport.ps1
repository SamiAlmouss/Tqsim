$projectRoot=Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $projectRoot 'src/Core/Tqsim.psm1') -Force
function New-TestFixture([int]$Length=10003,[string]$Name='data.bin') {
    $dir=Join-Path $TestDrive ([guid]::NewGuid().ToString());$null=[IO.Directory]::CreateDirectory($dir)
    $source=Join-Path $dir $Name;[IO.File]::WriteAllBytes($source,[Security.Cryptography.RandomNumberGenerator]::GetBytes($Length))
    return @{Directory=$dir;Source=$source;Parts=(Join-Path $dir 'parts');Restored=(Join-Path $dir 'restored')}
}
function New-SplitFixture([int]$Length=10003) {$f=New-TestFixture $Length;Split-Tqsim -File $f.Source -Size 1000 -Output $f.Parts -Quiet;return $f}
function Change-TestManifest($Fixture,[scriptblock]$Change) {
    $path=Join-Path $Fixture.Parts 'data.bin.tqsim.json';$m=[IO.File]::ReadAllText($path)|ConvertFrom-Json -AsHashtable;& $Change $m;[IO.File]::WriteAllText($path,($m|ConvertTo-Json -Depth 10));return $path
}
