#requires -Version 7.0
[CmdletBinding()]
param([Parameter(Position=0)][string]$Command='help',[string]$File,[string]$Size,[string]$Output,[string]$PartsPath='.',[string]$Manifest,[switch]$Overwrite,[switch]$NoLogo,[switch]$Quiet,[ValidateRange(4096,67108864)][int]$BufferSize=4194304)
$ErrorActionPreference='Stop'
try {
    Import-Module "$PSScriptRoot/src/Core/Tqsim.psm1" -Force
    if (!$NoLogo -and !$Quiet) { Show-TqsimBanner }
    $options=@{Quiet=$Quiet;BufferSize=$BufferSize}
    switch ($Command.ToLowerInvariant()) {
        split { if (!$File -or !$Size) { throw [ArgumentException]::new('split requires -File and -Size.') }; Split-Tqsim -File $File -Size $Size -Output $Output @options }
        {$_ -in 'merg','merge'} { Merge-Tqsim -PartsPath $PartsPath -Manifest $Manifest -Output $Output -Overwrite:$Overwrite @options }
        verify { Test-Tqsim -PartsPath $PartsPath -Manifest $Manifest @options }
        info { $m=Read-TqsimManifest (Find-TqsimManifest $PartsPath $Manifest); $m | Select-Object originalFileName,originalSize,@{n='humanSize';e={'{0:N2} GiB' -f ($_.originalSize/1GB)}},partSize,totalParts,originalSHA256,createdUtc,applicationVersion,manifestVersion | Format-List; Write-Output 'Metadata only; parts have not been verified.' }
        version { Write-Output '1.0.0' }
        update { & "$PSScriptRoot/update.ps1" }
        uninstall { & "$PSScriptRoot/uninstall.ps1" }
        help { Get-Content -LiteralPath "$PSScriptRoot/examples/help.txt" }
        default { throw [ArgumentException]::new("Unknown command: $Command") }
    }
    exit 0
} catch {
    [Console]::Error.WriteLine("FAILED: $($_.Exception.Message)")
    if ($_.Exception -is [ArgumentException]) { exit 2 }
    if ($_.Exception -is [IO.InvalidDataException]) { exit 3 }
    exit 1
}
