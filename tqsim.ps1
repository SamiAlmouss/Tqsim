#requires -Version 7.0
[CmdletBinding()]
param([Parameter(Position=0)][string]$Command='help',[string]$File,[string]$Size,[string]$Output,[string]$PartsPath='.',[string]$Manifest,[switch]$Overwrite,[switch]$NoLogo,[switch]$Quiet,[ValidateRange(4096,67108864)][int]$BufferSize=4194304,[switch]$Diagnostics)
$ErrorActionPreference='Stop'
function Write-TqsimDiagnostics([System.Management.Automation.ErrorRecord]$Record) {
    [Console]::Error.WriteLine('DEVELOPER DIAGNOSTICS')
    [Console]::Error.WriteLine("Exception type: $($Record.Exception.GetType().FullName)")
    [Console]::Error.WriteLine("Source script: $($Record.InvocationInfo.ScriptName)")
    [Console]::Error.WriteLine("Line: $($Record.InvocationInfo.ScriptLineNumber)")
    [Console]::Error.WriteLine("Source: $($Record.InvocationInfo.Line.Trim())")
    [Console]::Error.WriteLine("ScriptStackTrace: $($Record.ScriptStackTrace)")
    $inner=$Record.Exception.InnerException
    while ($null -ne $inner) {
        [Console]::Error.WriteLine("Inner exception: $($inner.GetType().FullName): $($inner.Message)")
        if ($inner -is [System.Management.Automation.RuntimeException] -and $null -ne $inner.ErrorRecord) {
            [Console]::Error.WriteLine("Inner source: $($inner.ErrorRecord.InvocationInfo.ScriptName):$($inner.ErrorRecord.InvocationInfo.ScriptLineNumber)")
            [Console]::Error.WriteLine("Inner ScriptStackTrace: $($inner.ErrorRecord.ScriptStackTrace)")
        }
        if ($inner.StackTrace) {[Console]::Error.WriteLine($inner.StackTrace)}
        $inner=$inner.InnerException
    }
}
try {
    Import-Module "$PSScriptRoot/src/Core/Tqsim.psm1" -Force
    if (!$NoLogo -and !$Quiet) { Show-TqsimBanner }
    $options=@{Quiet=$Quiet;BufferSize=$BufferSize}
    switch ($Command.ToLowerInvariant()) {
        split { if (!$File -or !$Size) { throw [ArgumentException]::new('split requires -File and -Size.') }; Split-Tqsim -File $File -Size $Size -Output $Output @options }
        {$_ -in 'merg','merge'} { Merge-Tqsim -PartsPath $PartsPath -Manifest $Manifest -Output $Output -Overwrite:$Overwrite @options }
        verify { Test-Tqsim -PartsPath $PartsPath -Manifest $Manifest @options }
        info { $m=Read-TqsimManifest (Find-TqsimManifest $PartsPath $Manifest); $m | Select-Object originalFileName,originalSize,@{n='humanSize';e={'{0:N2} GiB' -f ($_.originalSize/1GB)}},partSize,totalParts,originalSHA256,createdUtc,applicationVersion,manifestVersion | Format-List; Write-Output 'Metadata only; parts have not been verified.' }
        version { Write-Output '1.0.2' }
        update { & "$PSScriptRoot/update.ps1" }
        uninstall { & "$PSScriptRoot/uninstall.ps1" }
        help { Get-Content -LiteralPath "$PSScriptRoot/examples/help.txt" }
        default { throw [ArgumentException]::new("Unknown command: $Command") }
    }
    exit 0
} catch {
    $failure=$_
    [Console]::Error.WriteLine("FAILED: $($failure.Exception.Message)")
    if ($Diagnostics) {Write-TqsimDiagnostics $failure}
    if ($failure.Exception -is [ArgumentException]) { exit 2 }
    if ($failure.Exception -is [IO.InvalidDataException]) { exit 3 }
    exit 1
}
