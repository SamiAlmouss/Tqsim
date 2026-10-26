Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. "$PSScriptRoot/../Console/Branding.ps1"
. "$PSScriptRoot/../Commands/CLI.ps1"
. "$PSScriptRoot/Deletion.ps1"
. "$PSScriptRoot/Encryption.ps1"
. "$PSScriptRoot/Errors.ps1"
function ConvertTo-TqsimHex([byte[]]$Bytes) { return [BitConverter]::ToString($Bytes).Replace('-','').ToLowerInvariant() }
function Assert-TqsimJsonKeys($Element) {
    if ($Element.ValueKind -eq [Text.Json.JsonValueKind]::Object) {
        $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($property in $Element.EnumerateObject()) {if (!$seen.Add($property.Name)) {throw 'Duplicate JSON property.'};Assert-TqsimJsonKeys $property.Value}
    } elseif ($Element.ValueKind -eq [Text.Json.JsonValueKind]::Array) {foreach ($entry in $Element.EnumerateArray()) {Assert-TqsimJsonKeys $entry}}
}
function ConvertTo-TqsimSize([string]$Size) {
    if ($Size -notmatch '^(\d+)(B|KB|MB|GB|TB|KiB|MiB|GiB|TiB)?$') { throw [ArgumentException]::new('Invalid size. Use positive bytes, MB, GB, MiB, or GiB.') }
    $n=[Numerics.BigInteger]::Parse($Matches[1]); $unit=([string]$Matches[2]).ToUpperInvariant()
    $power=switch ($unit) { {$_ -in 'KB','KIB'} {1} {$_ -in 'MB','MIB'} {2} {$_ -in 'GB','GIB'} {3} {$_ -in 'TB','TIB'} {4} default {0} }
    $n*= [Numerics.BigInteger]::Pow(1024,$power)
    if ($n -le 0 -or $n -gt [long]::MaxValue) { throw [ArgumentException]::new('Size must be within positive Int64 range.') }; return [long]$n
}
function Get-TqsimReadCount([int]$BufferLength,[long]$Remaining) {
    # Select Min(Int64, Int64) before narrowing the bounded FileStream count.
    # Casting only the result cannot prevent PowerShell selecting Min(Int32, Int32).
    return [int][math]::Min([long]$BufferLength,[long]$Remaining)
}
function Assert-TqsimName($Name) {
    if ($Name -isnot [string] -or !$Name -or $Name -in '.','..' -or $Name -match '[<>:"/\\|?*\x00-\x1f]' -or $Name -match '[ .]$' -or $Name -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)') { throw [IO.InvalidDataException]::new('Unsafe manifest filename.') }
}
function Assert-TqsimInteger($Value,[long]$Minimum=0) {
    if (($Value -isnot [long] -and $Value -isnot [int] -and $Value -isnot [System.Numerics.BigInteger]) -or $Value -lt $Minimum -or $Value -gt [long]::MaxValue) { throw [IO.InvalidDataException]::new('Invalid integer in manifest.') }
}
function Read-TqsimManifest([string]$Path) {
    try {
        $metadataStream=[IO.FileStream]::new([IO.Path]::GetFullPath($Path),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
        try {
            if($metadataStream.Length -gt 16777216){Initialize-TqsimCrypto;if([Tqsim.CryptoSession]::PeekManifestVersion($metadataStream) -ne 1){throw 'Encrypted manifest exceeds the 16 MiB safety limit.'}}
            $metadataReader=[IO.StreamReader]::new($metadataStream,[Text.Encoding]::UTF8,$true,4096,$true)
            try {$json=$metadataReader.ReadToEnd()} finally {$metadataReader.Dispose()}
        } finally {$metadataStream.Dispose()}
        $document=[Text.Json.JsonDocument]::Parse($json)
        try {Assert-TqsimJsonKeys $document.RootElement
            $createdString=$document.RootElement.GetProperty('createdUtc').GetString()
            if ($createdString -notmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$') {throw 'Timestamp must be ISO 8601 UTC.'}
        } finally {$document.Dispose()}
        $m=$json | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        Assert-TqsimInteger $m.manifestVersion 1
        if ($m.manifestVersion -eq 2) {if ([Text.Encoding]::UTF8.GetByteCount($json) -gt 16777216) {throw 'Encrypted manifest exceeds 16 MiB.'};$m.createdUtc=$createdString;Assert-TqsimEncryptedManifest $m;return $m}
        if ($m.ContainsKey('encryption')) {throw 'Encrypted metadata requires supported manifest schema 2.'}
        if ($m.application -cne 'Tqsim' -or $m.manifestVersion -ne 1 -or $m.hashAlgorithm -cne 'SHA256' -or $m.applicationVersion -notmatch '^\d+\.\d+\.\d+$') { throw 'Unsupported manifest.' }
        $null=[guid]::Parse($m.operationId)
        if ($m.createdUtc -isnot [datetime]) { $null=[datetimeoffset]::Parse($m.createdUtc,[Globalization.CultureInfo]::InvariantCulture) }
        Assert-TqsimName $m.originalFileName; Assert-TqsimInteger $m.originalSize; Assert-TqsimInteger $m.partSize 1; Assert-TqsimInteger $m.totalParts
        if ($m.originalSHA256 -notmatch '^[a-fA-F0-9]{64}$' -or $m.parts -isnot [array] -or $m.parts.Count -ne $m.totalParts) { throw 'Invalid hash or part count.' }
        $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase); $sum=[Numerics.BigInteger]0; $index=0L
        foreach ($p in $m.parts) {
            $index++; Assert-TqsimInteger $p.index 1; Assert-TqsimInteger $p.size 1; Assert-TqsimName $p.fileName
            if ($p.index -ne $index -or !$seen.Add($p.fileName) -or $p.sha256 -notmatch '^[a-fA-F0-9]{64}$' -or $p.size -gt $m.partSize -or ($index -lt $m.totalParts -and $p.size -ne $m.partSize)) { throw 'Invalid part metadata.' }
            $sum+=$p.size
        }
        if ($sum -ne $m.originalSize -or ($m.originalSize -eq 0 -and $m.totalParts -ne 0)) { throw 'Invalid total length.' }
        return $m
    } catch { throw [IO.InvalidDataException]::new("Invalid manifest: $($_.Exception.Message)",$_.Exception) }
}
function Find-TqsimManifest([string]$PartsPath,[string]$Manifest) {
    if ($Manifest) { return [IO.Path]::GetFullPath($Manifest) }
    $found=@(Get-ChildItem -LiteralPath $PartsPath -Filter '*.tqsim.json' -File)
    if ($found.Count -ne 1) { throw [ArgumentException]::new('Select -Manifest explicitly: expected exactly one manifest.') }; return $found[0].FullName
}
function Assert-TqsimRegular([string]$Path) {
    $item=Get-Item -LiteralPath $Path -Force
    if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw [IO.InvalidDataException]::new("Not a regular file: $Path") }
}
function New-TqsimDestination([string]$Path,[long]$Bytes) {
    $full=[IO.Path]::GetFullPath($Path); $null=[IO.Directory]::CreateDirectory($full)
    $walk=[IO.DirectoryInfo]::new($full)
    while ($walk) { if ($walk.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Reparse-point destinations are not supported.' }; $walk=$walk.Parent }
    $driveRoot=[IO.Path]::GetPathRoot($full)
    if (!$driveRoot.StartsWith('\\')) {
        $drive=[IO.DriveInfo]::new($driveRoot)
        if ($drive.IsReady -and $drive.AvailableFreeSpace -lt $Bytes) { throw 'Insufficient disk space.' }
    }
    return $full
}
function New-TqsimStream([string]$Path,[IO.FileMode]$Mode,[IO.FileAccess]$Access) {
    return [IO.FileStream]::new($Path,$Mode,$Access,[IO.FileShare]::Read,4096,[IO.FileOptions]::SequentialScan)
}
function Get-TqsimProgressMetrics([long]$Done,[long]$Total,[long]$Part,[double]$ElapsedSeconds) {
    # The leading zero is required: [double].001 is property access under StrictMode.
    $seconds=[math]::Max([double]0.001,$ElapsedSeconds); $rate=$Done/$seconds
    $eta=if ($rate -gt 0) { [math]::Min([double]2147483647,[double](($Total-$Done)/$rate)) } else {0}
    return [pscustomobject]@{Rate=$rate;Eta=$eta;CompletedParts=[math]::Max([long]0,[long]($Part-1L));Percent=$(if ($Total) {[math]::Min([double]100,[double](100.0*$Done/$Total))} else {100})}
}
function Show-TqsimProgress($State,[long]$Done,[long]$Total,[long]$Part,[long]$Count,$Clock,[switch]$Quiet) {
    if ($Quiet -or !(Get-TqsimTerminal).Interactive) { return }
    $render=Get-Variable -Name TqsimRenderState -ValueOnly -ErrorAction SilentlyContinue
    if ($null -ne $render) {Update-TqsimBanner $render}
    $metrics=Get-TqsimProgressMetrics $Done $Total $Part $Clock.Elapsed.TotalSeconds
    if ($State -eq 'COMPLETED') {$metrics.CompletedParts=$Count}
    $label=switch ($State) {SPLITTING {'SPLIT'} MERGING {'MERGE'} VERIFYING {'VERIFY'} COMPLETED {'DONE'} default {$State}}
    $status="{0} {1}/{2} ({3} done) {4}/{5}B {6:N1}MiB/s {7} ETA{8:N0}s" -f $label,$Part,$Count,$metrics.CompletedParts,$Done,$Total,($metrics.Rate/1MB),$Clock.Elapsed.ToString('hh\:mm\:ss'),$metrics.Eta
    Write-TqsimProgressFrame $render $metrics.Percent $status
}
function Split-Tqsim {
    param([string]$File,[string]$Size,[string]$Output,[switch]$Quiet,[int]$BufferSize=4194304,[string]$ds='false',[string]$verify='true',[string]$encrypt='false')
    if (Resolve-TqsimEncryptOption $encrypt) {Split-TqsimEncrypted -File $File -Size $Size -Output $Output -Quiet:$Quiet -ds $ds -verify $verify;return}
    $readBack=Resolve-TqsimVerifyOption $verify
    $deleteSource=Resolve-TqsimDeleteSourceOption $ds;$cleanup=New-TqsimDeletionContext
    if (!$Quiet -and ![Console]::IsOutputRedirected -and $null -eq (Get-Variable TqsimRenderState -ValueOnly -ErrorAction SilentlyContinue)) {$TqsimRenderState=New-TqsimRenderState -SkipLogo}
    [long]$chunk=ConvertTo-TqsimSize $Size; $source=[IO.Path]::GetFullPath($File); Assert-TqsimRegular $source
    $inputStream=New-TqsimStream $source Open Read; $whole=[Security.Cryptography.IncrementalHash]::CreateHash('SHA256'); $owned=[Collections.Generic.List[string]]::new(); $success=$false
    try {
        if ($deleteSource) {$sourceEntry=Add-TqsimDeletionFile $cleanup $source -Target}
        [long]$length=$inputStream.Length; $stamp=[IO.File]::GetLastWriteTimeUtc($source)
        if (!$Output) {$Output=Join-Path ([IO.Path]::GetDirectoryName($source)) 'Output'}
        $dest=New-TqsimDestination $Output $length; $name=[IO.Path]::GetFileName($source)
        [long]$count=[Numerics.BigInteger]::Divide(([Numerics.BigInteger]$length+$chunk-1),$chunk); $width=[math]::Max([long]4,[long]$count.ToString().Length)
        $manifestPath=Join-Path $dest "$name.tqsim.json"
        if (Test-Path -LiteralPath $manifestPath) { throw 'Manifest already exists.' }
        for ($i=1L;$i -le $count;$i++) { if (Test-Path -LiteralPath (Join-Path $dest ($name+'.part'+$i.ToString("D$width")))) {throw 'Part already exists.'} }
        $buffer=[byte[]]::new($BufferSize); $parts=[Collections.Generic.List[object]]::new(); [long]$done=0; $clock=[Diagnostics.Stopwatch]::StartNew(); [long]$tick=0
        for ($i=1L;$i -le $count;$i++) {
            $partName=$name+'.part'+$i.ToString("D$width"); $final=Join-Path $dest $partName; $temp=Join-Path $dest ('.tqsim-'+[guid]::NewGuid()+'.tmp'); $owned.Add($temp)
            $stream=New-TqsimStream $temp CreateNew Write; $hash=[Security.Cryptography.IncrementalHash]::CreateHash('SHA256'); [long]$written=0; [long]$target=[math]::Min([long]$chunk,[long]($length-$done))
            try { while ($written -lt $target) {
                $read=$inputStream.Read($buffer,0,(Get-TqsimReadCount $buffer.Length ([long]($target-$written)))); if (!$read) {throw 'Unexpected EOF.'}
                $stream.Write($buffer,0,$read); $hash.AppendData($buffer,0,$read); $whole.AppendData($buffer,0,$read); $written+=$read; $done+=$read
                if ($clock.ElapsedMilliseconds-$tick -ge 250) {Show-TqsimProgress SPLITTING $done $length $i $count $clock -Quiet:$Quiet; $tick=$clock.ElapsedMilliseconds}
            }; $stream.Flush($true); $digest=ConvertTo-TqsimHex ($hash.GetHashAndReset());$partIdentity=if ($deleteSource) {Get-TqsimFileIdentity $stream} else {''} } finally {$stream.Dispose();$hash.Dispose()}
            if ((Get-Item -LiteralPath $temp).Length -ne $target) {throw 'Part length mismatch.'}
            [IO.File]::Move($temp,$final); $owned.Add($final); $parts.Add(@{index=$i;fileName=$partName;size=$written;sha256=$digest})
            if ($deleteSource) {$null=Add-TqsimDeletionFile $cleanup $final $digest $written -ExpectedIdentity $partIdentity}
        }
        if ($inputStream.Length -ne $length -or [IO.File]::GetLastWriteTimeUtc($source) -ne $stamp -or $inputStream.ReadByte() -ne -1) {throw 'Source changed during split.'}
        $m=[ordered]@{application='Tqsim';applicationVersion=(Get-TqsimVersion);manifestVersion=1;operationId=[guid]::NewGuid().ToString();originalFileName=$name;originalSize=$length;partSize=$chunk;totalParts=$count;hashAlgorithm='SHA256';originalSHA256=(ConvertTo-TqsimHex ($whole.GetHashAndReset()));createdUtc=[datetime]::UtcNow.ToString('o');parts=@($parts.ToArray())}
        $manifestJson=$m|ConvertTo-Json -Depth 8
        $temp=Join-Path $dest ('.tqsim-'+[guid]::NewGuid()+'.tmp');$owned.Add($temp)
        $manifestStream=New-TqsimStream $temp CreateNew Write
        try {$jsonBytes=[Text.Encoding]::UTF8.GetBytes($manifestJson);$manifestStream.Write($jsonBytes,0,$jsonBytes.Length);$manifestStream.Flush($true);$manifestIdentity=if ($deleteSource) {Get-TqsimFileIdentity $manifestStream} else {''}} finally {$manifestStream.Dispose()}
        [IO.File]::Move($temp,$manifestPath);$success=$true
        $deletionResult=''
        if ($deleteSource) {
            $sourceEntry.SHA256=$m.originalSHA256
            $expectedManifest=ConvertTo-TqsimHex ([Security.Cryptography.SHA256]::HashData($jsonBytes))
            $null=Add-TqsimDeletionFile $cleanup $manifestPath $expectedManifest -ReadBack -ExpectedIdentity $manifestIdentity -Quiet:$Quiet
        }
        $null=Read-TqsimManifest $manifestPath
        if ([IO.File]::ReadAllText($manifestPath) -cne $manifestJson) {throw [IO.InvalidDataException]::new('Published manifest changed.')}
        if ($readBack) {Invoke-TqsimParts $m $dest -Quiet:$Quiet -BufferSize $BufferSize}
        if ($deleteSource) {
            $cleanup.StreamingComplete=$true;$cleanup.ReadBackVerified=$readBack
            $inputStream.Dispose()
            $deletionResult=Invoke-TqsimVerifiedSourceDeletion $cleanup $dest SPLIT
        }
        Show-TqsimProgress COMPLETED $length $length $count $count $clock -Quiet:$Quiet
        Complete-TqsimProgress
        if (!$Quiet) {Write-Output "COMPLETED: $count parts, $length bytes; $manifestPath";if (!$readBack) {Write-Output 'Independent verification skipped.'};if ($deletionResult) {Write-Output $deletionResult}}
    } finally { $inputStream.Dispose();$whole.Dispose();Close-TqsimDeletionContext $cleanup; Complete-TqsimProgress; if (!$success) {foreach ($path in $owned) {if ([IO.File]::Exists($path)) {[IO.File]::Delete($path)}}} }
}
function Invoke-TqsimParts {
    param($Metadata,[string]$Directory,$Destination,[switch]$Quiet,[int]$BufferSize=4194304,[string]$State='VERIFYING',$Session)
    if ($Metadata.manifestVersion -eq 2) {
        $ownsSession=$null -eq $Session
        try {if ($ownsSession) {$Session=New-TqsimCryptoSession $Metadata};Assert-TqsimManifestAuthentication $Metadata $Session;Invoke-TqsimEncryptedParts $Metadata $Directory $Session $Destination -Quiet:$Quiet} finally {if ($ownsSession -and $Session) {$Session.Dispose()}}
        return
    }
    $buffer=[byte[]]::new($BufferSize);$whole=[Security.Cryptography.IncrementalHash]::CreateHash('SHA256');[long]$done=0;$clock=[Diagnostics.Stopwatch]::StartNew();[long]$tick=0
    try { foreach ($part in $Metadata.parts) {
        $path=Join-Path $Directory $part.fileName
        if (![IO.File]::Exists($path)) {throw (New-TqsimUserError 'MISSING_PART' 'MERGE / VERIFY FAILED' "Missing required part: $($part.fileName)" 'Restore this part from the original archive and try again. No source files were deleted.' $null 3)}
        Assert-TqsimRegular $path; $s=New-TqsimStream $path Open Read;$hash=[Security.Cryptography.IncrementalHash]::CreateHash('SHA256')
        try {if ($s.Length -ne $part.size) {throw [IO.InvalidDataException]::new("Wrong size: $($part.fileName)")};[long]$remaining=$part.size
            while ($remaining -gt 0) {$n=$s.Read($buffer,0,(Get-TqsimReadCount $buffer.Length $remaining));if (!$n) {throw [IO.InvalidDataException]::new('Unexpected EOF.')};$hash.AppendData($buffer,0,$n);$whole.AppendData($buffer,0,$n);if ($Destination) {$Destination.Write($buffer,0,$n)};$remaining-=$n;$done+=$n
                if ($clock.ElapsedMilliseconds-$tick -ge 250) {Show-TqsimProgress $State $done $Metadata.originalSize $part.index $Metadata.totalParts $clock -Quiet:$Quiet;$tick=$clock.ElapsedMilliseconds}
            }
            if ((ConvertTo-TqsimHex ($hash.GetHashAndReset())) -ine $part.sha256) {throw [IO.InvalidDataException]::new("SHA256 mismatch: $($part.fileName)")}
        } finally {$s.Dispose();$hash.Dispose()}
    }; if ($done -ne $Metadata.originalSize -or (ConvertTo-TqsimHex ($whole.GetHashAndReset())) -ine $Metadata.originalSHA256) {throw [IO.InvalidDataException]::new('Original SHA256 or length mismatch.')}
    } finally {$whole.Dispose();Complete-TqsimProgress}
}
function Test-Tqsim {
    param([string]$PartsPath='.',[string]$Manifest,[switch]$Quiet,[int]$BufferSize=4194304)
    $path=Find-TqsimManifest $PartsPath $Manifest;$m=Read-TqsimManifest $path
    Invoke-TqsimParts $m ([IO.Path]::GetDirectoryName($path)) -Quiet:$Quiet -BufferSize $BufferSize
    if (!$Quiet) {Write-Output "COMPLETED: verified $($m.totalParts) parts and original SHA256."}
}
function Merge-Tqsim {
    param([string]$PartsPath='.',[string]$Manifest,[string]$Output,[switch]$Overwrite,[switch]$Quiet,[int]$BufferSize=4194304,[string]$ds='false',[string]$verify='true')
    $readBack=Resolve-TqsimVerifyOption $verify
    $deleteSource=Resolve-TqsimDeleteSourceOption $ds;$cleanup=New-TqsimDeletionContext;$crypto=$null
    if (!$Quiet -and ![Console]::IsOutputRedirected -and $null -eq (Get-Variable TqsimRenderState -ValueOnly -ErrorAction SilentlyContinue)) {$TqsimRenderState=New-TqsimRenderState -SkipLogo}
    $operationClock=[Diagnostics.Stopwatch]::StartNew()
    try {
    $path=Find-TqsimManifest $PartsPath $Manifest
    if ($deleteSource) {$manifestEntry=Add-TqsimDeletionFile $cleanup $path -Target -ReadBack -Quiet:$Quiet}
    $m=Read-TqsimManifest $path;$directory=[IO.Path]::GetDirectoryName($path)
    if ($m.manifestVersion -eq 2) {$crypto=New-TqsimCryptoSession $m;Assert-TqsimManifestAuthentication $m $crypto}
    if ($deleteSource) {
        Assert-TqsimUnsharedParts $path $m
        foreach ($part in $m.parts) {$null=Add-TqsimDeletionFile $cleanup (Join-Path $directory $part.fileName) $part.sha256 $part.size -Target}
        $null=$cleanup.Entries.Remove($manifestEntry);$cleanup.Entries.Add($manifestEntry) # Manifest is always deleted last.
    }
    if (!$Output) {$Output=$directory};$dest=New-TqsimDestination $Output $m.originalSize;$final=Join-Path $dest $m.originalFileName
    if ($final -ieq $path -or @($m.parts|Where-Object {(Join-Path $directory $_.fileName) -ieq $final}).Count) {throw 'Output collides with input.'}
    if ((Test-Path -LiteralPath $final) -and !$Overwrite) {throw (New-TqsimUserError 'OUTPUT_EXISTS' 'MERGE CANNOT START' "The output file already exists: $final" 'Choose another -Output location, move the existing file, or explicitly authorize replacement with -Overwrite.' $null)}
    if (Test-Path -LiteralPath $final) {Assert-TqsimRegular $final}
    $temp=Join-Path $dest ('.tqsim-'+[guid]::NewGuid()+'.tmp');$s=$null;$tempCreated=$false
    try {$s=if($crypto){New-TqsimPrivateStream $temp}else{New-TqsimStream $temp CreateNew Write};$tempCreated=$true;Invoke-TqsimParts $m $directory $s -Quiet:$Quiet -BufferSize $BufferSize -State MERGING -Session $crypto;$s.Flush($true);if ($s.Length -ne $m.originalSize) {throw [IO.InvalidDataException]::new('Written output length mismatch.')};$outputIdentity=if ($deleteSource) {Get-TqsimFileIdentity $s} else {''};$s.Dispose();$s=$null
        if ([IO.File]::Exists($final) -and $Overwrite) {[IO.File]::Replace($temp,$final,[System.Management.Automation.Language.NullString]::Value)} else {[IO.File]::Move($temp,$final)}
        $deletionResult=''
        if ($deleteSource) {
            $null=Add-TqsimDeletionFile $cleanup $final $m.originalSHA256 $m.originalSize -ReadBack:$readBack -ExpectedIdentity $outputIdentity -Quiet:$Quiet
            Assert-TqsimUnsharedParts $path $m
            $cleanup.StreamingComplete=$true;$cleanup.ReadBackVerified=$readBack
            $deletionResult=Invoke-TqsimVerifiedSourceDeletion $cleanup $dest MERGE
        } elseif ($readBack) {
            Assert-TqsimRegular $final;$verifyStream=New-TqsimStream $final Open Read
            try {if ($verifyStream.Length -ne $m.originalSize -or (Get-TqsimStreamDigest $verifyStream -ShowProgress -Quiet:$Quiet) -ine $m.originalSHA256) {throw [IO.InvalidDataException]::new('Independent published output verification failed.')}} finally {$verifyStream.Dispose()}
        }
        Show-TqsimProgress COMPLETED $m.originalSize $m.originalSize $m.totalParts $m.totalParts $operationClock -Quiet:$Quiet
        Complete-TqsimProgress
        if (!$Quiet) {Write-Output "COMPLETED: restored $($m.originalSize) bytes to $final";if (!$readBack) {Write-Output 'Independent verification skipped.'};if ($deletionResult) {Write-Output $deletionResult}}
    } finally {if ($s) {$s.Dispose()};if ($tempCreated -and [IO.File]::Exists($temp)) {[IO.File]::Delete($temp)}}
    } finally {Close-TqsimDeletionContext $cleanup;if ($crypto) {$crypto.Dispose()};Complete-TqsimProgress}
}
Export-ModuleMember -Function *-Tqsim*
