#requires -Version 7.0
[CmdletBinding()]param([string]$ApplicationRoot=(Join-Path $PSScriptRoot '..'),[long]$Bytes=536870929,[string]$Label='baseline',[switch]$Optimized,[switch]$TimingOnly,[string[]]$PartSizes=@('134217728'),[string]$WorkRoot=(Join-Path $PSScriptRoot '../.test-work/performance'))
$ErrorActionPreference='Stop'
$work=Join-Path ([IO.Path]::GetFullPath($WorkRoot)) ($Label+'-'+[guid]::NewGuid());$app=Join-Path $work 'app'
$null=[IO.Directory]::CreateDirectory($app)
foreach ($name in 'src','examples','version.json') {Copy-Item -LiteralPath (Join-Path $ApplicationRoot $name) -Destination $app -Recurse}
Add-Type -Path (Join-Path $PSScriptRoot 'ProfileStreams.cs')
# Instrument only this isolated copy. Normal application code has no timing hooks.
if (!$TimingOnly) { foreach ($file in Get-ChildItem (Join-Path $app 'src') -Recurse -File -Include *.ps1,*.psm1) {
    $text=[IO.File]::ReadAllText($file.FullName)
    $text=$text.Replace('[IO.FileStream]::new($Path,$Mode,$Access,[IO.FileShare]::Read,4096,[IO.FileOptions]::SequentialScan)','[TqsimProfileStream]::new($Path,$Mode,$Access)')
    $text=$text.Replace('$hash.ComputeHash($Stream)','[TqsimProfile]::Digest($hash,$Stream)')
    $text=[regex]::Replace($text,'\$(hash|whole)\.AppendData\(([^)]+)\)','[TqsimProfile]::Append($$$1,$2)')
    foreach ($method in 'Move','Replace','Delete','WriteAllText') {$text=$text.Replace("[IO.File]::$method(","[TqsimProfile]::$method(")}
    # Inclusive phase timers, not additive: hashing/read times nest inside phases.
    $ast=[Management.Automation.Language.Parser]::ParseInput($text,[ref]$null,[ref]$null)
    $functions=@($ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst]},$true)|Sort-Object {$_.Extent.StartOffset} -Descending)
    foreach ($function in $functions) {
        $category=switch ($function.Name) {
            {$_ -in 'Assert-TqsimRegular','ConvertTo-TqsimSize','Read-TqsimManifest','New-TqsimDestination','Assert-TqsimDeletionPath','Assert-TqsimUnsharedParts'} {'validation'}
            Invoke-TqsimParts {'independentOrPreverification'}
            Get-TqsimStreamDigest {'additionalHashRead'}
            Invoke-TqsimVerifiedSourceDeletion {'cleanupIncludingRevalidation'}
            Close-TqsimDeletionContext {'finalCleanup'}
            default {''}
        }
        if (!$category) {continue}
        # Skip param block; it must remain the first statement in the function.
        $start=if ($function.Body.ParamBlock) {$function.Body.ParamBlock.Extent.EndOffset} else {$function.Body.Extent.StartOffset+1}
        $end=$function.Body.Extent.EndOffset-1
        $categoryExpression=if ($function.Name -eq 'Invoke-TqsimParts') {"if (`$Destination) {'streaming'} else {'independentOrPreverification'}"} elseif ($function.Name -eq 'Get-TqsimStreamDigest') {"if (`$Stream.Name -like '*.tqsim.json') {'manifestReadBack'} else {'additionalHashRead'}"} else {"'$category'"}
        $text=$text.Insert($end,"`n} finally {[TqsimProfile]::Add(`$tqsimProfileCategory,[Diagnostics.Stopwatch]::GetTimestamp()-`$tqsimProfileStart)}`n").Insert($start,"`n`$tqsimProfileCategory=$categoryExpression;`$tqsimProfileStart=[Diagnostics.Stopwatch]::GetTimestamp();try {`n")
    }
    $text=$text.Replace('$manifestJson=$m|ConvertTo-Json -Depth 8',"`$tqsimManifestStart=[Diagnostics.Stopwatch]::GetTimestamp();`$manifestJson=`$m|ConvertTo-Json -Depth 8;[TqsimProfile]::Add('manifestSerialization',[Diagnostics.Stopwatch]::GetTimestamp()-`$tqsimManifestStart)")
    [IO.File]::WriteAllText($file.FullName,$text)
}
}
Import-Module (Join-Path $app 'src/Core/Tqsim.psm1') -Force
$results=[Collections.Generic.List[object]]::new()
$combinations=if ($Optimized) {@(@('false','true'),@('false','false'),@('true','true'),@('true','false'))} else {@(@('false','legacy'),@('true','legacy'))}
$combinationIndex=0
foreach ($combination in $combinations) {
    $partSize=$PartSizes[$combinationIndex % $PartSizes.Count];$combinationIndex++
    $ds=$combination[0];$verify=$combination[1];$dir=Join-Path $work "$ds-$verify";$null=[IO.Directory]::CreateDirectory($dir)
    $source=Join-Path $dir 'source.bin';$s=[IO.File]::Open($source,[IO.FileMode]::CreateNew);$buffer=[byte[]]::new(4194304);[long]$remaining=$Bytes
    try {while ($remaining -gt 0) {[Security.Cryptography.RandomNumberGenerator]::Fill($buffer);$n=[int][math]::Min([long]$buffer.Length,$remaining);$s.Write($buffer,0,$n);$remaining-=$n}} finally {$s.Dispose()}
    $expected=(Get-FileHash -LiteralPath $source).Hash;$parts=Join-Path $dir 'parts';$output=Join-Path $dir 'restored'
    $options=@{ds=$ds;Quiet=$true};if ($Optimized) {$options.verify=$verify}
    foreach ($operation in 'split','merge') {
        [TqsimProfile]::Reset();$clock=[Diagnostics.Stopwatch]::StartNew()
        if ($operation -eq 'split') {Split-Tqsim -File $source -Size $partSize -Output $parts @options} else {Merge-Tqsim -PartsPath $parts -Output $output @options}
        $clock.Stop()
        $phases=@{};foreach($key in [TqsimProfile]::Seconds.Keys){$phases[$key]=[TqsimProfile]::Seconds[$key]};$paths=@{};foreach($key in [TqsimProfile]::BytesByPath.Keys){$paths[$key]=[TqsimProfile]::BytesByPath[$key]};$row=[ordered]@{label=$Label;operation=$operation;ds=$ds;verify=$verify;bytes=$Bytes;elapsed=$clock.Elapsed.TotalSeconds;MiBPerSecond=($Bytes/1MB/$clock.Elapsed.TotalSeconds);readBytes=[TqsimProfile]::ReadBytes;writtenBytes=[TqsimProfile]::WrittenBytes;readCalls=[TqsimProfile]::ReadCalls;writeCalls=[TqsimProfile]::WriteCalls;phases=$phases;readsByPath=$paths}
        $readTimes=@{};foreach($key in [TqsimProfile]::ReadSecondsByPath.Keys){$readTimes[$key]=[TqsimProfile]::ReadSecondsByPath[$key]}
        $row.readSecondsByPath=$readTimes;$row.instrumented=!$TimingOnly;$row.partSize=$partSize;$results.Add($row);Write-Output ([pscustomobject]$row|Select-Object label,operation,ds,verify,elapsed,MiBPerSecond,readBytes,readCalls|ConvertTo-Json -Compress)
    }
    if ((Get-FileHash -LiteralPath (Join-Path $output 'source.bin')).Hash -cne $expected) {throw 'Independent benchmark harness hash mismatch.'}
}
$path=Join-Path $work 'profile.json';[IO.File]::WriteAllText($path,($results|ConvertTo-Json -Depth 10));Write-Output "Profile: $path"
