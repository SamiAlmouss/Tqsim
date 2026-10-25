Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function ConvertTo-TqsimHex([byte[]]$Bytes) { return [BitConverter]::ToString($Bytes).Replace('-','').ToLowerInvariant() }
function Assert-TqsimJsonKeys($Element) {
    if ($Element.ValueKind -eq [Text.Json.JsonValueKind]::Object) {
        $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($property in $Element.EnumerateObject()) {if (!$seen.Add($property.Name)) {throw 'Duplicate JSON property.'};Assert-TqsimJsonKeys $property.Value}
    } elseif ($Element.ValueKind -eq [Text.Json.JsonValueKind]::Array) {foreach ($entry in $Element.EnumerateArray()) {Assert-TqsimJsonKeys $entry}}
}
function Show-TqsimBanner {
    Write-Host @'
 _____  ___  ____ ___ __  __
|_   _|/ _ \/ ___|_ _|  \/  |
  | | | | | \___ \| || |\/| |
  | | | |_| |___) | || |  | |
  |_|  \__\_\____/___|_|  |_|
Split • Merge • Verify    Version: 1.0.0
'@ -ForegroundColor Cyan
}
function ConvertTo-TqsimSize([string]$Size) {
    if ($Size -notmatch '^(\d+)(B|KB|MB|GB|TB|KiB|MiB|GiB|TiB)?$') { throw [ArgumentException]::new('Invalid size. Use positive bytes, MB, GB, MiB, or GiB.') }
    $n=[Numerics.BigInteger]::Parse($Matches[1]); $unit=([string]$Matches[2]).ToUpperInvariant()
    $power=switch ($unit) { {$_ -in 'KB','KIB'} {1} {$_ -in 'MB','MIB'} {2} {$_ -in 'GB','GIB'} {3} {$_ -in 'TB','TIB'} {4} default {0} }
    $n*= [Numerics.BigInteger]::Pow(1024,$power)
    if ($n -le 0 -or $n -gt [long]::MaxValue) { throw [ArgumentException]::new('Size must be within positive Int64 range.') }; return [long]$n
}
function Assert-TqsimName($Name) {
    if ($Name -isnot [string] -or !$Name -or $Name -in '.','..' -or $Name -match '[<>:"/\\|?*\x00-\x1f]' -or $Name -match '[ .]$' -or $Name -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)') { throw [IO.InvalidDataException]::new('Unsafe manifest filename.') }
}
function Assert-TqsimInteger($Value,[long]$Minimum=0) {
    if (($Value -isnot [long] -and $Value -isnot [int] -and $Value -isnot [System.Numerics.BigInteger]) -or $Value -lt $Minimum -or $Value -gt [long]::MaxValue) { throw [IO.InvalidDataException]::new('Invalid integer in manifest.') }
}
function Read-TqsimManifest([string]$Path) {
    try {
        $json=[IO.File]::ReadAllText([IO.Path]::GetFullPath($Path));$document=[Text.Json.JsonDocument]::Parse($json)
        try {Assert-TqsimJsonKeys $document.RootElement
            if ($document.RootElement.GetProperty('createdUtc').GetString() -notmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$') {throw 'Timestamp must be ISO 8601 UTC.'}
        } finally {$document.Dispose()}
        $m=$json | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        Assert-TqsimInteger $m.manifestVersion 1
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
    } catch { throw [IO.InvalidDataException]::new("Invalid manifest: $($_.Exception.Message)") }
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
function Show-TqsimProgress($State,[long]$Done,[long]$Total,[long]$Part,[long]$Count,$Clock,[switch]$Quiet) {
    if ($Quiet -or [Console]::IsOutputRedirected) { return }
    $seconds=[math]::Max(.001,$Clock.Elapsed.TotalSeconds); $rate=$Done/$seconds
    $eta=if ($rate -gt 0) { [math]::Min([int]::MaxValue,($Total-$Done)/$rate) } else {0}
    Write-Progress -Activity "TQSIM — $State" -Status ("Part {0}/{1}; completed {2}; {3}/{4} bytes; {5:N1} MiB/s; elapsed {6}; ETA {7:N0}s" -f $Part,$Count,([math]::Max(0,$Part-1)),$Done,$Total,($rate/1MB),$Clock.Elapsed.ToString('hh\:mm\:ss'),$eta) -PercentComplete $(if ($Total) {[math]::Min(100,100.0*$Done/$Total)} else {100})
}
function Split-Tqsim {
    param([string]$File,[string]$Size,[string]$Output,[switch]$Quiet,[int]$BufferSize=4194304)
    $chunk=ConvertTo-TqsimSize $Size; $source=[IO.Path]::GetFullPath($File); Assert-TqsimRegular $source
    $inputStream=New-TqsimStream $source Open Read; $whole=[Security.Cryptography.IncrementalHash]::CreateHash('SHA256'); $owned=[Collections.Generic.List[string]]::new(); $success=$false
    try {
        $length=$inputStream.Length; $stamp=[IO.File]::GetLastWriteTimeUtc($source)
        if (!$Output) {$Output=Join-Path ([IO.Path]::GetDirectoryName($source)) 'Output'}
        $dest=New-TqsimDestination $Output $length; $name=[IO.Path]::GetFileName($source)
        $count=[long]([Numerics.BigInteger]::Divide(([Numerics.BigInteger]$length+$chunk-1),$chunk)); $width=[math]::Max(4,$count.ToString().Length)
        $manifestPath=Join-Path $dest "$name.tqsim.json"
        if (Test-Path -LiteralPath $manifestPath) { throw 'Manifest already exists.' }
        for ($i=1L;$i -le $count;$i++) { if (Test-Path -LiteralPath (Join-Path $dest ($name+'.part'+$i.ToString("D$width")))) {throw 'Part already exists.'} }
        $buffer=[byte[]]::new($BufferSize); $parts=[Collections.Generic.List[object]]::new(); $done=0L; $clock=[Diagnostics.Stopwatch]::StartNew(); $tick=0L
        for ($i=1L;$i -le $count;$i++) {
            $partName=$name+'.part'+$i.ToString("D$width"); $final=Join-Path $dest $partName; $temp=Join-Path $dest ('.tqsim-'+[guid]::NewGuid()+'.tmp'); $owned.Add($temp)
            $stream=New-TqsimStream $temp CreateNew Write; $hash=[Security.Cryptography.IncrementalHash]::CreateHash('SHA256'); $written=0L; $target=[math]::Min($chunk,$length-$done)
            try { while ($written -lt $target) {
                $read=$inputStream.Read($buffer,0,[int][math]::Min($buffer.Length,$target-$written)); if (!$read) {throw 'Unexpected EOF.'}
                $stream.Write($buffer,0,$read); $hash.AppendData($buffer,0,$read); $whole.AppendData($buffer,0,$read); $written+=$read; $done+=$read
                if ($clock.ElapsedMilliseconds-$tick -ge 250) {Show-TqsimProgress SPLITTING $done $length $i $count $clock -Quiet:$Quiet; $tick=$clock.ElapsedMilliseconds}
            }; $stream.Flush($true); $digest=ConvertTo-TqsimHex ($hash.GetHashAndReset()) } finally {$stream.Dispose();$hash.Dispose()}
            if ((Get-Item -LiteralPath $temp).Length -ne $target) {throw 'Part length mismatch.'}
            [IO.File]::Move($temp,$final); $owned.Add($final); $parts.Add(@{index=$i;fileName=$partName;size=$written;sha256=$digest})
        }
        if ($inputStream.Length -ne $length -or [IO.File]::GetLastWriteTimeUtc($source) -ne $stamp -or $inputStream.ReadByte() -ne -1) {throw 'Source changed during split.'}
        $m=[ordered]@{application='Tqsim';applicationVersion='1.0.0';manifestVersion=1;operationId=[guid]::NewGuid().ToString();originalFileName=$name;originalSize=$length;partSize=$chunk;totalParts=$count;hashAlgorithm='SHA256';originalSHA256=(ConvertTo-TqsimHex ($whole.GetHashAndReset()));createdUtc=[datetime]::UtcNow.ToString('o');parts=@($parts.ToArray())}
        $temp=Join-Path $dest ('.tqsim-'+[guid]::NewGuid()+'.tmp');$owned.Add($temp);[IO.File]::WriteAllText($temp,($m|ConvertTo-Json -Depth 8));[IO.File]::Move($temp,$manifestPath);$success=$true
        if (!$Quiet) {Write-Output "COMPLETED: $count parts, $length bytes; $manifestPath"}
    } finally { $inputStream.Dispose();$whole.Dispose(); Write-Progress -Activity TQSIM -Completed; if (!$success) {foreach ($path in $owned) {if ([IO.File]::Exists($path)) {[IO.File]::Delete($path)}}} }
}
function Invoke-TqsimParts {
    param($Metadata,[string]$Directory,$Destination,[switch]$Quiet,[int]$BufferSize=4194304,[string]$State='VERIFYING')
    $buffer=[byte[]]::new($BufferSize);$whole=[Security.Cryptography.IncrementalHash]::CreateHash('SHA256');$done=0L;$clock=[Diagnostics.Stopwatch]::StartNew();$tick=0L
    try { foreach ($part in $Metadata.parts) {
        $path=Join-Path $Directory $part.fileName; Assert-TqsimRegular $path; $s=New-TqsimStream $path Open Read;$hash=[Security.Cryptography.IncrementalHash]::CreateHash('SHA256')
        try {if ($s.Length -ne $part.size) {throw [IO.InvalidDataException]::new("Wrong size: $($part.fileName)")};$remaining=[long]$part.size
            while ($remaining -gt 0) {$n=$s.Read($buffer,0,[int][math]::Min($buffer.Length,$remaining));if (!$n) {throw [IO.InvalidDataException]::new('Unexpected EOF.')};$hash.AppendData($buffer,0,$n);$whole.AppendData($buffer,0,$n);if ($Destination) {$Destination.Write($buffer,0,$n)};$remaining-=$n;$done+=$n
                if ($clock.ElapsedMilliseconds-$tick -ge 250) {Show-TqsimProgress $State $done $Metadata.originalSize $part.index $Metadata.totalParts $clock -Quiet:$Quiet;$tick=$clock.ElapsedMilliseconds}
            }
            if ((ConvertTo-TqsimHex ($hash.GetHashAndReset())) -ine $part.sha256) {throw [IO.InvalidDataException]::new("SHA256 mismatch: $($part.fileName)")}
        } finally {$s.Dispose();$hash.Dispose()}
    }; if ($done -ne $Metadata.originalSize -or (ConvertTo-TqsimHex ($whole.GetHashAndReset())) -ine $Metadata.originalSHA256) {throw [IO.InvalidDataException]::new('Original SHA256 or length mismatch.')}
    } finally {$whole.Dispose();Write-Progress -Activity TQSIM -Completed}
}
function Test-Tqsim {
    param([string]$PartsPath='.',[string]$Manifest,[switch]$Quiet,[int]$BufferSize=4194304)
    $path=Find-TqsimManifest $PartsPath $Manifest;$m=Read-TqsimManifest $path
    Invoke-TqsimParts $m ([IO.Path]::GetDirectoryName($path)) -Quiet:$Quiet -BufferSize $BufferSize
    if (!$Quiet) {Write-Output "COMPLETED: verified $($m.totalParts) parts and original SHA256."}
}
function Merge-Tqsim {
    param([string]$PartsPath='.',[string]$Manifest,[string]$Output,[switch]$Overwrite,[switch]$Quiet,[int]$BufferSize=4194304)
    $path=Find-TqsimManifest $PartsPath $Manifest;$m=Read-TqsimManifest $path;$directory=[IO.Path]::GetDirectoryName($path)
    if (!$Output) {$Output=Join-Path $directory 'Output'};$dest=New-TqsimDestination $Output $m.originalSize;$final=Join-Path $dest $m.originalFileName
    if ($final -ieq $path -or @($m.parts|Where-Object {(Join-Path $directory $_.fileName) -ieq $final}).Count) {throw 'Output collides with input.'}
    if ((Test-Path -LiteralPath $final) -and !$Overwrite) {throw 'Output exists; use -Overwrite to authorize replacement.'}
    if (Test-Path -LiteralPath $final) {Assert-TqsimRegular $final}
    Invoke-TqsimParts $m $directory -Quiet:$Quiet -BufferSize $BufferSize
    $temp=Join-Path $dest ('.tqsim-'+[guid]::NewGuid()+'.tmp');$s=$null
    try {$s=New-TqsimStream $temp CreateNew Write;Invoke-TqsimParts $m $directory $s -Quiet:$Quiet -BufferSize $BufferSize -State MERGING;$s.Flush($true);$s.Dispose();$s=$null
        if ([IO.File]::Exists($final) -and $Overwrite) {[IO.File]::Replace($temp,$final,[System.Management.Automation.Language.NullString]::Value)} else {[IO.File]::Move($temp,$final)}
        if (!$Quiet) {Write-Output "COMPLETED: restored $($m.originalSize) bytes to $final"}
    } finally {if ($s) {$s.Dispose()};if ([IO.File]::Exists($temp)) {[IO.File]::Delete($temp)}}
}
Export-ModuleMember -Function *-Tqsim*
