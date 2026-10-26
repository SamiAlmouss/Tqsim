. "$PSScriptRoot/TestSupport.ps1"
Describe 'Literal Tqsim logo registry' {
    It 'contains exactly the three byte-for-byte user designs' {
        $logos=Get-TqsimLogos;$logos.Count | Should Be 3
        foreach ($i in 0..2) {
            $expected=[IO.File]::ReadAllText((Join-Path $PSScriptRoot "fixtures/logos/$($i+1).txt"))
            $logos[$i] | Should BeExactly $expected
        }
        @($logos[0] -split '\r?\n').Count | Should Be 5
        @($logos[1] -split '\r?\n').Count | Should Be 8
        @($logos[2] -split '\r?\n').Count | Should Be 7
        ($logos[2] -split '\r?\n')[-1] | Should BeExactly '              :'
    }
    It 'gets valid indexes from the real cryptographic RNG' {
        foreach ($i in 1..200) {$index=Get-TqsimRandomIndex;($index -ge 0 -and $index -lt 3) | Should Be $true}
    }
}
InModuleScope Tqsim {
    Describe 'Deterministic selection, layout and invocation state' {
        It 'can select each registered logo without altering its literal text' {
            foreach ($index in 0..2) {
                $script:forcedIndex=$index;Mock Get-TqsimRandomIndex {$script:forcedIndex}
                $state=New-TqsimRenderState
                $state.LogoIndex | Should Be $index
            }
        }
        It 'has an approximately uniform distribution with a reproducible large sample' {
            $script:seededRng=[Random]::new(103);Mock Get-TqsimRandomIndex {$script:seededRng.Next(0,3)}
            $counts=@(0,0,0);foreach ($i in 1..12000) {$counts[(Select-TqsimRandomLogo)]++}
            foreach ($count in $counts) {($count -gt 3600 -and $count -lt 4400) | Should Be $true}
            # Distribution is deterministic; the production cryptographic API is range-tested separately.
        }
        It 'centers all logo widths and heights as whole blocks' {
            foreach ($index in 0..2) {
                $state=[pscustomobject]@{LogoIndex=$index;BodyHeight=4;Secure=$false;NoColor=$true;LastWidth=-1;LastHeight=-1}
                $terminal=[pscustomobject]@{Width=120;Height=40;Interactive=$true;TrueColor=$false}
                $layout=Get-TqsimBannerLayout $state $terminal;$logo=(Get-TqsimLogos)[$index];$lines=@($logo -split '\r?\n')
                $pad=[int][math]::Floor((120-(Get-TqsimLogoWidth $logo))/2.0)
                $layout.LeftPadding | Should Be $pad
                foreach ($n in 0..($lines.Count-1)) {$layout.Lines[$n] | Should BeExactly ((' '*$pad)+$lines[$n])}
                $layout.LogoHeight | Should Be $lines.Count
                $layout.TopPadding | Should Be ([int][math]::Floor((40-$layout.Lines.Count-4-1)/2.0))
                $layout.Compact | Should Be $false
            }
        }
        It 'falls back narrowly and restores the same selected logo on resize' {
            $state=[pscustomobject]@{LogoIndex=2;BodyHeight=4;Secure=$false;NoColor=$true;LastWidth=-1;LastHeight=-1}
            $script:terminal=[pscustomobject]@{Width=20;Height=20;Interactive=$true;TrueColor=$false}
            Mock Get-TqsimTerminal {$script:terminal};Mock Select-TqsimRandomLogo {throw 'Resize must not select again'}
            (Get-TqsimBannerLayout $state $script:terminal).Compact | Should Be $true
            Show-TqsimBanner $state | Out-Null
            $script:terminal.Width=120
            Update-TqsimBanner $state | Out-Null
            $state.LogoIndex | Should Be 2
            $state.LastWidth | Should Be 120
            (Get-TqsimBannerLayout $state $script:terminal).Compact | Should Be $false
            Assert-MockCalled Select-TqsimRandomLogo -Times 0 -Exactly -Scope It
        }
        It 'selects once per invocation and keeps state out of module globals' {
            Mock Select-TqsimRandomLogo {1}
            Mock Get-TqsimTerminal {[pscustomobject]@{Width=80;Height=25;Interactive=$false;TrueColor=$false}}
            Mock Split-Tqsim {
                $state=Get-Variable TqsimRenderState -ValueOnly -ErrorAction Stop
                $state.LogoIndex | Should Be 1
                Update-TqsimBanner $state | Out-Null
                Update-TqsimBanner $state | Out-Null
            }
            Invoke-TqsimCommand (Resolve-TqsimInvocation @('split','-File','unused','-Size','1GB')) | Out-Null
            Invoke-TqsimCommand (Resolve-TqsimInvocation @('version')) | Out-Null
            Assert-MockCalled Select-TqsimRandomLogo -Times 2 -Exactly -Scope It
            (Get-Variable TqsimRenderState -Scope Script -ErrorAction SilentlyContinue) | Should BeNullOrEmpty
        }
        It 'suppresses every logo and random selection with NoLogo or Quiet' {
            Mock Select-TqsimRandomLogo {throw 'Suppressed branding must not select'}
            foreach ($flag in '-NoLogo','-Quiet') {
                foreach ($index in 0..2) {
                    $result=Invoke-TqsimCommand (Resolve-TqsimInvocation @('version',$flag))
                    $result | Should Be (Get-TqsimVersion)
                }
            }
            Assert-MockCalled Select-TqsimRandomLogo -Times 0 -Exactly -Scope It
        }
        It 'prints redirected branding without ANSI escapes or artificial centering' {
            Mock Get-TqsimTerminal {[pscustomobject]@{Width=0;Height=0;Interactive=$false;TrueColor=$true}}
            $state=[pscustomobject]@{LogoIndex=0;BodyHeight=0;Secure=$false;NoColor=$false;LastWidth=-1;LastHeight=-1}
            $output=@(Show-TqsimBanner $state)
            ($output -join "`n") | Should Not Match ([regex]::Escape([string][char]27))
            $output[0] | Should BeExactly ((Get-TqsimLogos)[0] -split '\r?\n')[0]
        }
    }
}
