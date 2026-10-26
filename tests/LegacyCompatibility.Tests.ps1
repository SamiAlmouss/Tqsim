. "$PSScriptRoot/TestSupport.ps1"
Describe 'Authentic archived-release fixtures, without original source files' {
    BeforeEach {Mock Read-TqsimSecret -ModuleName Tqsim {throw 'Legacy archives must never request a password.'}}
    It 'merges unchanged downloaded <Version> parts with default and explicit destinations without secrets' -TestCases @(@{Version='1.0.2'},@{Version='1.0.3'},@{Version='1.0.4'},@{Version='1.0.5'}) {
        param($Version)
        $fixture=Join-Path $PSScriptRoot "fixtures/legacy/$Version";$record=Get-Content (Join-Path $fixture 'provenance.json') -Raw|ConvertFrom-Json
        foreach ($explicit in $false,$true) {
            $parts=Join-Path $TestDrive ([guid]::NewGuid().ToString());$null=[IO.Directory]::CreateDirectory($parts)
            foreach ($file in Get-ChildItem -LiteralPath $fixture -File) {[IO.File]::Copy($file.FullName,(Join-Path $parts $file.Name))}
            $manifest=(Get-ChildItem $parts -Filter '*.tqsim.json').FullName;$before=(Get-FileHash $manifest).Hash
            $m=Read-TqsimManifest $manifest;$m.applicationVersion|Should Be $Version
            $parameters=@{};$destination=$parts;if ($explicit) {$destination=Join-Path $TestDrive ([guid]::NewGuid().ToString());$parameters.Output=$destination}
            Merge-Tqsim -PartsPath $parts -Quiet @parameters
            $output=Join-Path $destination $m.originalFileName
            (Get-Item -LiteralPath $output).Length|Should Be $record.length
            (Get-FileHash -LiteralPath $output).Hash|Should Be $record.sourceSHA256
            (Get-FileHash $manifest).Hash|Should Be $before
            [IO.Directory]::Exists((Join-Path $parts 'Output'))|Should Be $false
        }
        Assert-MockCalled Read-TqsimSecret -ModuleName Tqsim -Times 0 -Exactly -Scope It
    }
}
