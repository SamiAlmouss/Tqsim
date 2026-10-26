function Get-TqsimVersion {
    $metadata=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../../version.json'))|ConvertFrom-Json
    if ($metadata.application -cne 'Tqsim' -or $metadata.version -notmatch '^\d+\.\d+\.\d+$') {throw 'Invalid application version metadata.'}
    return [string]$metadata.version
}
function Get-TqsimSuggestion([string]$Command) {
    if ($Command.Length -gt 32) {return ''}
    $scores=@();foreach ($candidate in 'split','merge','merg','verify','info','help','version','update','uninstall') {
        $a=$Command.ToLowerInvariant();$b=$candidate;$previous=0..$b.Length
        for ($i=1;$i -le $a.Length;$i++) {
            $row=[int[]]::new($b.Length+1);$row[0]=$i
            for ($j=1;$j -le $b.Length;$j++) {$cost=if($a[$i-1] -ceq $b[$j-1]){0}else{1};$row[$j]=[math]::Min([math]::Min($previous[$j]+1,$row[$j-1]+1),$previous[$j-1]+$cost)}
            $previous=$row
        }
        $scores+=@{Name=$candidate;Distance=$previous[$b.Length]}
    }
    $sorted=@($scores|Sort-Object Distance)
    if ($Command.Length -ge 3 -and $Command.Length -le 12 -and $sorted[0].Distance -le 2 -and $sorted[0].Distance -lt $sorted[1].Distance) {return $sorted[0].Name}
    # Prefer the public spelling when both merge aliases are plausible.
    if ($Command -ieq 'merger') {return 'merge'}
    return ''
}
function Resolve-TqsimInvocation([object[]]$Arguments) {
    if ($null -eq $Arguments) {$Arguments=@()}
    $helpAliases=@('-help','--help','-h','--h','-?','/?','/help')
    $versionAliases=@('-version','--version','-v')
    $switches=@('overwrite','nologo','quiet','diagnostics','nocolor')
    $values=@('file','size','output','partspath','manifest','buffersize','ds','verify','encrypt')
    $options=@{};$positionals=[Collections.Generic.List[string]]::new();$help=$false;$version=$false
    for ($i=0;$i -lt $Arguments.Count;$i++) {
        $token=[string]$Arguments[$i];$lower=$token.ToLowerInvariant()
        if ($lower -in $helpAliases) {$help=$true;continue}
        if ($lower -in $versionAliases) {$version=$true;continue}
        if ($token.StartsWith('-')) {
            if ($token -notmatch '^-(?<name>[A-Za-z]+)(?::(?<value>.*))?$') {throw [ArgumentException]::new("Unsupported argument '$token'. Run 'tqsim help'.")}
            $name=$Matches['name'].ToLowerInvariant();$hasColon=$token.Contains(':');$inline=if ($hasColon){$Matches['value']}else{''}
            if ($name -notin ($switches+$values)) {throw [ArgumentException]::new("Unsupported argument '$token'. Run 'tqsim help'.")}
            if ($options.ContainsKey($name)) {throw [ArgumentException]::new("Duplicate parameter -$name.")}
            if ($name -in $switches) {
                $enabled=$true
                if ($hasColon) {
                    $value=$inline;if ($value -eq '' -and $i+1 -lt $Arguments.Count) {$i++;$value=[string]$Arguments[$i]}
                    switch ($value.ToLowerInvariant()) {'true' {$enabled=$true} '$true' {$enabled=$true} 'false' {$enabled=$false} '$false' {$enabled=$false} default {throw [ArgumentException]::new("Invalid Boolean value for -$name.")}}
                }
                $options[$name]=$enabled
            } else {
                if ($hasColon -and $inline -ne '') {$options[$name]=$inline}
                elseif ($i+1 -lt $Arguments.Count) {
                    $i++;$value=[string]$Arguments[$i]
                    if ($value.ToLowerInvariant() -in $helpAliases) {$help=$true;continue}
                    if ($value.StartsWith('-')) {throw [ArgumentException]::new("Missing value for -$name. Use a path beginning with .\ for filenames starting with a dash.")}
                    $options[$name]=$value
                } else {throw [ArgumentException]::new("Missing value for -$name.")}
            }
        } else {$positionals.Add($lower)}
    }
    $commands=@('split','merge','merg','verify','info','update','uninstall','version','help')
    $command=if ($positionals.Count) {$positionals[0]} elseif ($version) {'version'} else {'help'};$topic=''
    if ($positionals.Count -gt 2) {throw [ArgumentException]::new('Unexpected positional arguments. Run tqsim help.')}
    if ($command -notin $commands) {
        $suggestion=Get-TqsimSuggestion $command;$hint=if ($suggestion){"`nDid you mean '$suggestion'?"}else{''}
        throw [ArgumentException]::new("Unknown command '$command'.$hint`nRun 'tqsim help' for available commands.")
    }
    if ($command -eq 'help') {$help=$true;if ($positionals.Count -eq 2) {$topic=$positionals[1]}}
    elseif ($positionals.Count -eq 2) {if ($positionals[1] -eq 'help') {$help=$true} else {throw [ArgumentException]::new("Unexpected argument '$($positionals[1])'.")}}
    if ($help) {if ($command -ne 'help') {$topic=$command};$command='help'}
    elseif ($version) {if ($positionals.Count -and $command -ne 'version'){throw [ArgumentException]::new('Use version flags as a global command.')};$command='version'}
    if ($topic -and $topic -notin $commands) {throw [ArgumentException]::new("Unknown help topic '$topic'.")}
    if ($topic -eq 'merg') {$topic='merge'};if ($command -eq 'merg') {$command='merge'}
    $globals=@('nologo','quiet','diagnostics','nocolor')
    $allowed=switch ($command) {split {@('file','size','output','buffersize','ds','verify','encrypt')} merge {@('partspath','manifest','output','overwrite','buffersize','ds','verify')} verify {@('partspath','manifest','buffersize')} info {@('manifest','partspath')} help {@($values+$switches)} default {@()}}
    foreach ($name in $options.Keys) {if ($name -notin ($globals+$allowed)) {throw [ArgumentException]::new("-$name is not supported by $command.")}}
    if ($command -ne 'help' -and $options.ContainsKey('buffersize')) {
        $buffer=0;if (![int]::TryParse([string]$options.buffersize,[ref]$buffer) -or $buffer -lt 4096 -or $buffer -gt 67108864) {throw [ArgumentException]::new('BufferSize must be 4096..67108864 bytes.')};$options.buffersize=$buffer
    }
    if ($command -ne 'help' -and $options.ContainsKey('ds')) {$null=Resolve-TqsimDeleteSourceOption $options.ds}
    if ($command -ne 'help' -and $options.ContainsKey('verify')) {$null=Resolve-TqsimVerifyOption $options.verify}
    if ($command -ne 'help' -and $options.ContainsKey('encrypt')) {$null=Resolve-TqsimEncryptOption $options.encrypt}
    return [pscustomobject]@{Command=$command;Topic=$topic;Options=$options}
}
function Get-TqsimHelp([string]$Topic='') {
    $path=if ($Topic) {Join-Path $PSScriptRoot "../../examples/help/$Topic.txt"} else {Join-Path $PSScriptRoot '../../examples/help.txt'}
    return [IO.File]::ReadAllText($path).Replace('{{VERSION}}',(Get-TqsimVersion)).TrimEnd("`r","`n")
}
function Show-TqsimHelp([string]$Text,[switch]$NoColor) {
    $terminal=Get-TqsimTerminal
    $width=if ($terminal.Interactive) {[math]::Max(1,$terminal.Width-1)} else {[int]::MaxValue}
    foreach ($line in ($Text -split '\r?\n')) {
        $heading=$line -cmatch '^[A-Z][A-Z /-]+$'
        $remaining=$line
        do {
            $count=[math]::Min($width,$remaining.Length)
            if ($remaining.Length -gt $width) {
                $space=$remaining.LastIndexOf(' ',$count-1,$count)
                if ($space -gt 0) {$count=$space}
            }
            $segment=$remaining.Substring(0,$count)
            if ($heading) {Write-TqsimStyledLine $segment -Color Cyan -NoColor:$NoColor} else {Write-Output $segment}
            $remaining=$remaining.Substring($count).TrimStart(' ')
        } while ($remaining.Length)
    }
}
function Invoke-TqsimDeployment([ValidateSet('update','uninstall')][string]$Command) {
    & (Join-Path $PSScriptRoot "../../$Command.ps1")
}
function Invoke-TqsimCommand($Invocation) {
    $o=$Invocation.Options;$quiet=$o.ContainsKey('quiet') -and $o.quiet;$noLogo=$o.ContainsKey('nologo') -and $o.nologo;$noColor=$o.ContainsKey('nocolor') -and $o.nocolor
    $text=if ($Invocation.Command -eq 'help') {Get-TqsimHelp $Invocation.Topic} else {''}
    # This local state belongs to the invocation. Progress can consult it through
    # the module's call scope, but no logo choice is stored in a module/global variable.
    $TqsimRenderState=$null
    if (!$quiet -and $Invocation.Command -in 'split','merge','verify') {$TqsimRenderState=New-TqsimRenderState -BodyHeight 10 -Secure -NoColor:$noColor -SkipLogo:$noLogo}
    if (!$quiet -and !$noLogo) {
        $height=if ($text){@($text -split '\r?\n').Count}elseif($Invocation.Command -eq 'version'){1}else{10}
        if ($null -eq $TqsimRenderState) {$TqsimRenderState=New-TqsimRenderState -BodyHeight $height -Secure:($Invocation.Command -in 'split','merge','verify') -NoColor:$noColor}
        Show-TqsimBanner $TqsimRenderState
    }
    $parameters=@{};foreach ($name in $o.Keys) {if ($name -notin @('nologo','nocolor','diagnostics')) {$parameters[$name]=$o[$name]}}
    switch ($Invocation.Command) {
        help {Show-TqsimHelp $text -NoColor:$noColor}
        version {Write-Output (Get-TqsimVersion)}
        split {if (!$o.ContainsKey('file') -or !$o.ContainsKey('size') -or !$o.file -or !$o.size) {throw [ArgumentException]::new('split requires -File and -Size.')};Split-Tqsim @parameters}
        merge {Merge-Tqsim @parameters}
        verify {Test-Tqsim @parameters}
        info {
            $parts=if ($o.ContainsKey('partspath')) {$o.partspath}else{'.'};$manifest=if($o.ContainsKey('manifest')){$o.manifest}else{''}
            $m=Read-TqsimManifest (Find-TqsimManifest $parts $manifest)
            $m|Select-Object originalFileName,originalSize,@{n='humanSize';e={'{0:N2} GiB' -f ($_.originalSize/1GB)}},partSize,totalParts,originalSHA256,createdUtc,applicationVersion,manifestVersion|Format-List
            Write-Output 'Metadata only; parts have not been verified.'
        }
        update {Invoke-TqsimDeployment update}
        uninstall {Invoke-TqsimDeployment uninstall}
    }
}
