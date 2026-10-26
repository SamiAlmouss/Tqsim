. "$PSScriptRoot/TestSupport.ps1"
$documentationCommands=@('split','merg','merge','verify','info','update','uninstall','version','help')
Describe 'Documentation inventory and examples' {
    It 'lists every command and current version in main help without unresolved placeholders' {
        $main=Get-TqsimHelp
        foreach($command in $documentationCommands){$main|Should Match "(?m)^  $command\s"}
        $main|Should Match ([regex]::Escape("Version: $(Get-TqsimVersion)"))
        $main|Should Not Match '\{\{VERSION\}\}'
    }
    It 'documents every actual parser option in the unified inventory and each applicable page' {
        $parser=[IO.File]::ReadAllText((Join-Path $projectRoot 'src/Commands/CLI.ps1'))
        $reference=[IO.File]::ReadAllText((Join-Path $projectRoot 'docs/PARAMETERS.md'))
        $names=@();foreach($variable in 'switches','values'){
            $list=[regex]::Match($parser,('\$'+$variable+'=@\(([^\r\n]+)\)')).Groups[1].Value
            $list|Should Not BeNullOrEmpty
            $names+=@([regex]::Matches($list,"'([a-z]+)'")|ForEach-Object {$_.Groups[1].Value})
        }
        $names.Count|Should Be 14
        foreach($name in $names){$reference|Should Match ('(?im)^\| `-'+[regex]::Escape($name)+'` \|')}
        $map=@{split=@('File','Size','Output','BufferSize','ds','verify','encrypt');merge=@('PartsPath','Manifest','Output','Overwrite','BufferSize','ds','verify');verify=@('PartsPath','Manifest','BufferSize');info=@('PartsPath','Manifest');update=@();uninstall=@();version=@();help=@()}
        foreach($topic in $map.Keys){$page=Get-TqsimHelp $topic;foreach($name in @($map[$topic])+@('NoLogo','NoColor','Quiet','Diagnostics')){$page|Should Match ([regex]::Escape('-'+$name))}}
    }
    It 'states all three defaults and mandatory encrypted authentication consistently' {
        $split=Get-TqsimHelp split
        $split|Should Match '(?s)-ds <true\|false>\s+Default: false'
        $split|Should Match '(?s)-verify <true\|false>\s+Default: true'
        $split|Should Match '(?s)-encrypt <true\|false>\s+Default: false'
        $split|Should Match 'Split-only'
        $merge=Get-TqsimHelp merge
        $merge|Should Match 'automatically detected'
        $merge|Should Match '(?s)authentication\s+is mandatory even with -verify false'
        $merge|Should Match 'Old unencrypted archives never request a password'
        $merge|Should Match 'Default: directly beside input parts'
        (Get-TqsimHelp verify)|Should Match 'Standalone verify differs'
    }
    It 'mirrors every built-in topic in the extended command guide' {
        $guide=[IO.File]::ReadAllText((Join-Path $projectRoot 'docs/COMMANDS.md')).Replace('{{VERSION}}',(Get-TqsimVersion))
        foreach($topic in 'split','merge','verify','info','update','uninstall','version','help'){$guide.Contains((Get-TqsimHelp $topic))|Should Be $true}
    }
    It 'keeps English and Arabic executable tqsim examples identical and parser-valid' {
        $inventories=@()
        foreach($file in 'README.md','README.ar.md'){
            $text=[IO.File]::ReadAllText((Join-Path $projectRoot $file))
            $examples=@([regex]::Matches($text,'(?m)^tqsim[^\r\n]*')|ForEach-Object {$_.Value.Trim()}|Where-Object {$_ -notmatch '[<>]'}|Sort-Object -Unique)
            $examples.Count|Should BeGreaterThan 20
            foreach($example in $examples){
                $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseInput($example,[ref]$tokens,[ref]$errors)
                $errors.Count|Should Be 0
                $command=$ast.Find({param($n)$n -is [Management.Automation.Language.CommandAst]},$true)
                $arguments=@($command.CommandElements|Select-Object -Skip 1|ForEach-Object {if($_ -is [Management.Automation.Language.StringConstantExpressionAst]){$_.Value}else{$_.Extent.Text}})
                $invocation=Resolve-TqsimInvocation $arguments
                $invocation.Command|Should Not BeNullOrEmpty
            }
            $inventories+=,($examples -join "`n")
        }
        $inventories[0]|Should BeExactly $inventories[1]
    }
    It 'resolves local Markdown links and heading anchors in current documentation' {
        foreach($file in 'README.md','README.ar.md','docs/COMMANDS.md','docs/PARAMETERS.md','docs/TROUBLESHOOTING.md','docs/HELP-COVERAGE.md'){
            $path=Join-Path $projectRoot $file;$text=[IO.File]::ReadAllText($path)
            foreach($match in [regex]::Matches($text,'\[[^\]\r\n]+\]\(([^)]+)\)')){
                $url=$match.Groups[1].Value;if($url -match '^[a-z]+://'){continue}
                $parts=$url -split '#',2;$target=if($parts[0]){[IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetDirectoryName($path)) $parts[0]))}else{$path}
                [IO.File]::Exists($target)|Should Be $true
                if($parts.Count -eq 2 -and $parts[1]){
                    $headings=@([regex]::Matches([IO.File]::ReadAllText($target),'(?m)^#{1,6} (.+)')|ForEach-Object {($_.Groups[1].Value.ToLowerInvariant() -replace '[^\p{L}\p{N}_\- ]','') -replace ' ','-'})
                    $headings -contains $parts[1]|Should Be $true
                }
            }
        }
    }
    It 'has complete trouble symptoms and no obsolete current merge destination instruction' {
        $guide=[IO.File]::ReadAllText((Join-Path $projectRoot 'docs/TROUBLESHOOTING.md'))
        foreach($phrase in 'Access denied','Missing','SHA-256 mismatch','Incorrect password','Authentication failure','Destination already exists','Insufficient free disk space','Unsupported archive format','PowerShell 7','Update fails','Cleanup incomplete','Operation interrupted','Manifest missing'){$guide|Should Match ([regex]::Escape($phrase))}
        foreach($file in 'README.md','docs/COMMANDS.md'){
            $text=[IO.File]::ReadAllText((Join-Path $projectRoot $file))
            $text|Should Not Match '(?i)merge.{0,30}defaults to.{0,10}Output'
        }
    }
}
InModuleScope Tqsim {
    Describe 'Help isolation and terminal layouts' {
        It 'handles every help alias on every topic without data, secret, ACL or deployment calls' {
            Mock Split-Tqsim {throw 'Unexpected split'};Mock Merge-Tqsim {throw 'Unexpected merge'};Mock Test-Tqsim {throw 'Unexpected verify'}
            Mock Read-TqsimManifest {throw 'Unexpected metadata read'};Mock Read-TqsimSecret {throw 'Unexpected password'}
            Mock Invoke-TqsimDeployment {throw 'Unexpected deployment'};Mock Grant-TqsimExactDeletePermission {throw 'Unexpected ACL'}
            Mock Save-TqsimCleanupJournal {throw 'Unexpected journal'}
            foreach($topic in 'split','merg','merge','verify','info','update','uninstall','version','help'){
                foreach($alias in '-help','--help','-h','--h','-?','/?','/help'){
                    Invoke-TqsimCommand (Resolve-TqsimInvocation @($topic,$alias,'-NoLogo','-encrypt','true','-ds','true'))|Out-Null
                }
            }
            foreach($name in 'Split-Tqsim','Merge-Tqsim','Test-Tqsim','Read-TqsimManifest','Read-TqsimSecret','Invoke-TqsimDeployment','Grant-TqsimExactDeletePermission','Save-TqsimCleanupJournal'){Assert-MockCalled $name -Times 0 -Exactly}
        }
        It 'keeps narrow help within the terminal width without losing text' {
            Mock Get-TqsimTerminal {[pscustomobject]@{Interactive=$true;Width=20;Height=25;TrueColor=$false}}
            foreach($topic in '', 'split','merge','verify','info','update','uninstall','version','help'){
                $text=Get-TqsimHelp $topic;$output=@(Show-TqsimHelp $text -NoColor)
                foreach($line in $output){$line.Length|Should BeLessThan 20}
                (($output -join '') -replace '\s','')|Should BeExactly ($text -replace '\s','')
            }
        }
        It 'handles a one-column terminal without an infinite loop or dropped text' {
            Mock Get-TqsimTerminal {[pscustomobject]@{Interactive=$true;Width=1;Height=25;TrueColor=$false}}
            (@(Show-TqsimHelp 'LONGWORD' -NoColor) -join '')|Should Be 'LONGWORD'
        }
        It 'honors NoLogo and forwards NoColor for requested help even with Quiet' {
            Mock Show-TqsimBanner {throw 'NoLogo was ignored'}
            Mock Show-TqsimHelp {}
            Invoke-TqsimCommand (Resolve-TqsimInvocation @('help','split','-NoLogo','-NoColor','-Quiet'))
            Assert-MockCalled Show-TqsimBanner -Times 0 -Exactly
            Assert-MockCalled Show-TqsimHelp -Times 1 -Exactly -ParameterFilter {$NoColor -and $Text -match 'SPLIT'}
        }
        It 'emits no decorative escape sequences when redirected or NoColor is requested' {
            Mock Get-TqsimTerminal {[pscustomobject]@{Interactive=$false;Width=80;Height=25;TrueColor=$true}}
            foreach($noColor in $false,$true){(Show-TqsimHelp (Get-TqsimHelp) -NoColor:$noColor|Out-String)|Should Not Match ([regex]::Escape([string][char]27))}
        }
    }
}
