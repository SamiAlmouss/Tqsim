#requires -Version 7.0
param([string]$ProjectRoot,[string]$Parts,[string]$Output,[string]$Signal)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $ProjectRoot 'src/Core/Tqsim.psm1') -Force
& (Get-Module Tqsim) {
    param($Parts,$Output,$Signal)
    $script:OriginalTestRemoval=(Get-Command Remove-TqsimVerifiedFile).ScriptBlock
    $script:TerminationTestSignal=$Signal
    function Remove-TqsimVerifiedFile($Entry) {
        & $script:OriginalTestRemoval $Entry
        # Pause between the real delete and its journal acknowledgement. The
        # parent kills only this disposable child; finally blocks cannot run.
        [IO.File]::WriteAllText($script:TerminationTestSignal,'first delete completed')
        Start-Sleep -Seconds 60
    }
    Merge-Tqsim -PartsPath $Parts -Output $Output -ds true -Quiet
} $Parts $Output $Signal
