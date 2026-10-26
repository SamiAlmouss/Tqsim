function Get-TqsimLogos {
    # Literal strings: spaces (including trailing spaces) are part of the designs.
    return @(
@'
 _____  ___  ____ ___ __  __
|_   _|/ _ \/ ___|_ _|  \/  |
  | | | | | \___ \| || |\/| |
  | | | |_| |___) | || |  | |
  |_|  \__\_\____/___|_|  |_|
'@
@'
_________ _______  _______ _________ _______ 
\__   __/(  ___  )(  ____ \\__   __/(       )
   ) (   | (   ) || (    \/   ) (   | () () |
   | |   | |   | || (_____    | |   | || || |
   | |   | |   | |(_____  )   | |   | |(_)| |
   | |   | | /\| |      ) |   | |   | |   | |
   | |   | (_\ \ |/\____) |___) (___| )   ( |
   )_(   (____\/_)\_______)\_______/|/     \|
'@
@'
_____._._______  .________.___ ._____.___ 
\__ _:|: .___  \ |    ___/: __|:         |
  |  :|| :   |  ||___    \| : ||   \  /  |
  |   ||     :  ||       /|   ||   |\/   |
  |   | \_____. :|__:___/ |   ||___| |   |
  |___|       :/    :     |___|      |___|
              :
'@
    )
}
function Get-TqsimRandomIndex { return [Security.Cryptography.RandomNumberGenerator]::GetInt32(0,3) }
function Select-TqsimRandomLogo { return Get-TqsimRandomIndex }
function Get-TqsimLogoWidth([string]$Logo) {
    $width=0;foreach ($line in ($Logo -split '\r?\n')) {$width=[math]::Max($width,$line.Length)};return $width
}
function Get-TqsimTerminal {
    $interactive=![Console]::IsOutputRedirected;$width=80;$height=25;$trueColor=$false
    if ($interactive) {
        try {$width=[math]::Max(1,[Console]::WindowWidth);$height=[math]::Max(1,[Console]::WindowHeight)} catch {}
        try {$trueColor=$Host.UI.SupportsVirtualTerminal -and (!!$env:WT_SESSION -or $env:COLORTERM -in 'truecolor','24bit') -and $null -ne (Get-Variable PSStyle -ErrorAction SilentlyContinue)} catch {}
    }
    return [pscustomobject]@{Width=$width;Height=$height;Interactive=$interactive;TrueColor=$trueColor}
}
function Get-TqsimColorPalette {
    return @(
        @{Name='Neon Green';Rgb='63EDC6';Console='Green'},@{Name='Electric Cyan';Rgb='53DCEB';Console='Cyan'},
        @{Name='Cyber Blue';Rgb='50A8FF';Console='Blue'},@{Name='Neon Purple';Rgb='B98CFF';Console='Magenta'},
        @{Name='Hot Magenta';Rgb='F36BD2';Console='Magenta'},@{Name='Phantom Red';Rgb='FF6676';Console='Red'},
        @{Name='Amber';Rgb='F2B95B';Console='Yellow'},@{Name='Ice Blue';Rgb='8DE5FF';Console='Cyan'}
    )
}
function Get-TqsimColorIndex([int]$Maximum) {return [Security.Cryptography.RandomNumberGenerator]::GetInt32(0,$Maximum)}
function New-TqsimRenderState([int]$BodyHeight=0,[switch]$Secure,[switch]$NoColor,[switch]$SkipLogo) {
    $palette=Get-TqsimColorPalette;$logoColor=Get-TqsimColorIndex $palette.Count
    # Independently sample from the seven remaining colors, without rejection loops.
    $infoColor=Get-TqsimColorIndex ($palette.Count-1);if ($infoColor -ge $logoColor) {$infoColor++}
    $logo=if ($SkipLogo) {0} else {Select-TqsimRandomLogo}
    return [pscustomobject]@{LogoIndex=$logo;LogoColor=$palette[$logoColor];InfoColor=$palette[$infoColor];SkipLogo=[bool]$SkipLogo;BodyHeight=$BodyHeight;Secure=[bool]$Secure;NoColor=[bool]$NoColor;LastWidth=-1;LastHeight=-1;ProgressTop=-1;ProgressWidth=0}
}
function Get-TqsimBannerLayout($State,$Terminal) {
    $logo=(Get-TqsimLogos)[$State.LogoIndex];$width=Get-TqsimLogoWidth $logo
    $compact=$Terminal.Interactive -and $Terminal.Width -lt $width
    $lines=@(if ($compact) {'TQSIM'} else {$logo -split '\r?\n'})
    $width=if ($compact) {5} else {$width}
    $usable=$Terminal.Width
    $padding=if ($Terminal.Interactive) {[math]::Max(0,[int][math]::Floor(($usable-$width)/2.0))} else {0}
    $body=@('Split • Merge • Verify',"Version: $(Get-TqsimVersion)");if ($State.Secure) {$body+='[ SECURE FILE OPERATION ]'}
    $rendered=[Collections.Generic.List[string]]::new()
    foreach ($line in $lines) {$rendered.Add((' '*$padding)+$line)}
    foreach ($line in $body) {
        # Keep metadata readable on small terminals; the logo identity is unchanged.
        if ($Terminal.Interactive -and $line.Length -gt $usable) {continue}
        $pad=if ($Terminal.Interactive) {[math]::Max(0,[int][math]::Floor(($usable-$line.Length)/2.0))} else {0}
        $rendered.Add((' '*$pad)+$line)
    }
    $top=if ($Terminal.Interactive) {[math]::Max(0,[int][math]::Floor(($Terminal.Height-$rendered.Count-$State.BodyHeight-1)/2.0))} else {0}
    return [pscustomobject]@{Lines=$rendered.ToArray();TopPadding=$top;Compact=$compact;LogoHeight=$lines.Count;LeftPadding=$padding}
}
function Write-TqsimStyledLine([string]$Text,[ConsoleColor]$Color='Gray',[switch]$NoColor,[string]$Rgb,[switch]$HostOnly) {
    $terminal=Get-TqsimTerminal
    if (!$terminal.Interactive -or $NoColor -or $env:NO_COLOR) {if ($HostOnly) {Write-Host $Text} else {Write-Output $Text};return}
    if ($terminal.TrueColor -and $Rgb) {
        $style=(Get-Variable PSStyle -ValueOnly);$rgbValue=[Convert]::ToInt32($Rgb,16)
        Write-Host ($style.Foreground.FromRgb($rgbValue)+$Text+$style.Reset)
    } else {Write-Host $Text -ForegroundColor $Color}
}
function Show-TqsimBanner($State) {
    if ($null -eq $State) {$State=New-TqsimRenderState}
    $terminal=Get-TqsimTerminal;$layout=Get-TqsimBannerLayout $State $terminal
    for ($i=0;$i -lt $layout.TopPadding;$i++) {Write-Output ''}
    $color=if ($State.PSObject.Properties['LogoColor']) {$State.LogoColor} else {(Get-TqsimColorPalette)[0]}
    foreach ($line in $layout.Lines) {Write-TqsimStyledLine $line -Color $color.Console -Rgb $color.Rgb -NoColor:$State.NoColor}
    $State.LastWidth=$terminal.Width;$State.LastHeight=$terminal.Height
}
function Update-TqsimBanner($State) {
    $terminal=Get-TqsimTerminal
    if ($terminal.Interactive -and ($terminal.Width -ne $State.LastWidth -or $terminal.Height -ne $State.LastHeight)) {
        # Reflow only on dimension changes, never select again or clear the screen.
        Complete-TqsimProgress
        if (!$State.PSObject.Properties['SkipLogo'] -or !$State.SkipLogo) {Show-TqsimBanner $State}
        else {$State.LastWidth=$terminal.Width;$State.LastHeight=$terminal.Height}
    }
}
function Get-TqsimProgressLines([double]$Percent,[string]$Status,[int]$Width) {
    $usable=[math]::Max(1,$Width-1);$barWidth=[math]::Max(1,[math]::Min(40,$usable-10))
    $filled=[int][math]::Floor($barWidth*[math]::Clamp($Percent,0,100)/100)
    $bar='['+('#'*$filled)+('-'*($barWidth-$filled))+('] {0:N0}%' -f $Percent)
    return @($bar.Substring(0,[math]::Min($usable,$bar.Length)),$Status.Substring(0,[math]::Min($usable,$Status.Length)))
}
function Write-TqsimProgressFrame($Render,[double]$Percent,[string]$Status) {
    $terminal=Get-TqsimTerminal
    if (!$terminal.Interactive) {return}
    $lines=Get-TqsimProgressLines $Percent $Status $terminal.Width
    if ($null -eq $Render) {foreach ($line in $lines) {Write-Host $line};return}
    try {
        if ($Render.ProgressTop -lt 0 -or $Render.ProgressWidth -ne $terminal.Width) {
            Write-Host '';Write-Host ''
            $Render.ProgressTop=[math]::Max(0,[Console]::CursorTop-2);$Render.ProgressWidth=$terminal.Width
        }
        [Console]::SetCursorPosition(0,$Render.ProgressTop)
        foreach ($line in $lines) {Write-TqsimStyledLine $line.PadRight([math]::Max(1,$terminal.Width-1)) -Color $Render.InfoColor.Console -Rgb $Render.InfoColor.Rgb -NoColor:$Render.NoColor -HostOnly}
    } catch [IO.IOException] {$Render.ProgressTop=-1;foreach ($line in $lines) {Write-Host $line}}
      catch [ArgumentOutOfRangeException] {$Render.ProgressTop=-1;foreach ($line in $lines) {Write-Host $line}}
}
function Complete-TqsimProgress {
    $render=Get-Variable TqsimRenderState -ValueOnly -ErrorAction SilentlyContinue
    if ($null -eq $render -or !$render.PSObject.Properties['ProgressTop'] -or $render.ProgressTop -lt 0) {return}
    try {[Console]::SetCursorPosition(0,[math]::Min([Console]::BufferHeight-1,$render.ProgressTop+2))} catch [IO.IOException] {} catch [ArgumentOutOfRangeException] {}
    $render.ProgressTop=-1
}
