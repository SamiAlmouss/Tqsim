#requires -Version 7.0
# Raw argument collection intentionally lets Tqsim handle -? and --help before binding.
$Diagnostics=@($args|Where-Object {$_ -is [string] -and $_ -ieq '-Diagnostics'}).Count -gt 0
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
    $invocation=Resolve-TqsimInvocation -Arguments @($args)
    if ($invocation.Options.ContainsKey('diagnostics')) {$Diagnostics=[bool]$invocation.Options.diagnostics}
    Invoke-TqsimCommand $invocation
    exit 0
} catch {
    $failure=$_
    [Console]::Error.WriteLine("FAILED: $($failure.Exception.Message)")
    if ($Diagnostics) {Write-TqsimDiagnostics $failure}
    if ($failure.Exception -is [ArgumentException]) { exit 2 }
    if ($failure.Exception -is [IO.InvalidDataException]) { exit 3 }
    exit 1
}
