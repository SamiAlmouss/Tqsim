. "$PSScriptRoot/TestSupport.ps1"
Describe 'Two-line progress layout' {
    It 'puts only the bar on line one and status on line two' {
        $lines=Get-TqsimProgressLines 50 'MERGING: Part 2/4; speed 12 MiB/s; ETA 3s' 100
        $lines.Count|Should Be 2;$lines[0]|Should Match '^\[#+-+\] 50%$'
        $lines[0]|Should Not Match 'Part|ETA';$lines[1]|Should Match '^MERGING: Part 2/4'
        foreach ($width in 1,5,10,20,80) {
            $frame=Get-TqsimProgressLines 100 ('status '*30) $width
            $frame.Count|Should Be 2
            foreach ($line in $frame) {$line.Length -le [math]::Max(1,$width-1)|Should Be $true}
        }
    }
    It 'contains exactly the eight approved bright colors' {
        $palette=Get-TqsimColorPalette
        $palette.Count|Should Be 8
        ($palette.Rgb -join ',')|Should Be '63EDC6,53DCEB,50A8FF,B98CFF,F36BD2,FF6676,F2B95B,8DE5FF'
    }
}
InModuleScope Tqsim {
    Describe 'Per-invocation color stability' {
        It 'selects every logo and info color using two independent bounded draws' {
            foreach ($first in 0..7) {foreach ($second in 0..6) {
                $script:draws=[Collections.Generic.Queue[int]]::new();$script:draws.Enqueue($first);$script:draws.Enqueue($second)
                Mock Get-TqsimColorIndex {param($Maximum)$draw=$script:draws.Dequeue();($draw -lt $Maximum)|Should Be $true;return $draw}
                $state=New-TqsimRenderState
                $state.LogoColor.Rgb|Should Be (Get-TqsimColorPalette)[$first].Rgb
                $expected=if ($second -ge $first) {$second+1} else {$second}
                $state.InfoColor.Rgb|Should Be (Get-TqsimColorPalette)[$expected].Rgb
                $state.InfoColor.Rgb|Should Not Be $state.LogoColor.Rgb
            }}
            Assert-MockCalled Get-TqsimColorIndex -Times 112 -Exactly -Scope It
        }
        It 'does not draw colors again during progress, resize or completion' {
            Mock Get-TqsimColorIndex {0}
            $TqsimRenderState=New-TqsimRenderState -SkipLogo -NoColor
            $logo=$TqsimRenderState.LogoColor.Rgb;$info=$TqsimRenderState.InfoColor.Rgb
            $script:terminal=[pscustomobject]@{Width=80;Height=25;Interactive=$true;TrueColor=$false}
            Mock Get-TqsimTerminal {$script:terminal};Mock Write-TqsimProgressFrame {}
            $clock=[Diagnostics.Stopwatch]::StartNew()
            Show-TqsimProgress SPLITTING 1 10 1 2 $clock
            $script:terminal.Width=20
            Show-TqsimProgress VERIFYING 9 10 2 2 $clock
            Show-TqsimProgress COMPLETED 10 10 2 2 $clock
            Complete-TqsimProgress
            $TqsimRenderState.LogoColor.Rgb|Should Be $logo;$TqsimRenderState.InfoColor.Rgb|Should Be $info
            Assert-MockCalled Get-TqsimColorIndex -Times 2 -Exactly -Scope It
            Assert-MockCalled Write-TqsimProgressFrame -Times 3 -Exactly -Scope It
        }
        It 'selects new colors per invocation even when logos are suppressed' {
            Mock Get-TqsimColorIndex {0};Mock Split-Tqsim {};Mock Show-TqsimBanner {}
            foreach ($i in 1..2) {Invoke-TqsimCommand (Resolve-TqsimInvocation @('split','-File','unused','-Size','1GB','-NoLogo'))}
            Assert-MockCalled Get-TqsimColorIndex -Times 4 -Exactly -Scope It
        }
        It 'renders plain text for NoColor, NO_COLOR and redirected output' {
            Mock Get-TqsimTerminal {[pscustomobject]@{Width=80;Height=25;Interactive=$true;TrueColor=$true}}
            $text=Write-TqsimStyledLine status -NoColor -Rgb 63EDC6
            $text|Should BeExactly status
            $saved=$env:NO_COLOR
            try {$env:NO_COLOR='1';(Write-TqsimStyledLine status -Rgb 63EDC6)|Should BeExactly status} finally {$env:NO_COLOR=$saved}
            Mock Get-TqsimTerminal {[pscustomobject]@{Width=80;Height=25;Interactive=$false;TrueColor=$true}}
            $state=New-TqsimRenderState
            $output=Show-TqsimBanner $state|Out-String
            $output|Should Not Match ([regex]::Escape([string][char]27))
        }
        It 'keeps NoColor active for split progress even with NoLogo' {
            Mock Split-Tqsim {$s=Get-Variable TqsimRenderState -ValueOnly;$s.NoColor|Should Be $true;$s.SkipLogo|Should Be $true}
            Invoke-TqsimCommand (Resolve-TqsimInvocation @('split','-File','unused','-Size','1GB','-NoLogo','-NoColor'))
        }
        It 'reports every part completed in the final separate status line' {
            Mock Get-TqsimTerminal {[pscustomobject]@{Width=80;Height=25;Interactive=$true;TrueColor=$false}}
            Mock Write-TqsimProgressFrame {param($Render,$Percent,$Status)$Percent|Should Be 100;$Status|Should Match '^DONE 4/4 \(4 done\)'}
            $TqsimRenderState=New-TqsimRenderState -SkipLogo
            Show-TqsimProgress COMPLETED 4294967296L 4294967296L 4 4 ([Diagnostics.Stopwatch]::StartNew())
            Assert-MockCalled Write-TqsimProgressFrame -Times 1 -Exactly -Scope It
        }
    }
}
