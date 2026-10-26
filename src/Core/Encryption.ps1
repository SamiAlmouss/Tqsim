function Resolve-TqsimEncryptOption([string]$Value='false') {
    if ($Value -ieq 'true') {return $true};if ($Value -ieq 'false') {return $false}
    throw [ArgumentException]::new('-encrypt requires true or false. Default: false; split only.')
}
function Initialize-TqsimCrypto {
    if (!('Tqsim.CryptoSession' -as [type])) {Add-Type -Path (Join-Path $PSScriptRoot 'Crypto.cs')}
}
function Test-TqsimSecureInputAvailable {return ![Console]::IsInputRedirected -and ![Console]::IsOutputRedirected}
function Read-TqsimSecret([switch]$Confirm) {
    if (!(Test-TqsimSecureInputAvailable)) {throw [ArgumentException]::new('Secure interactive password input is unavailable. Run Tqsim in an interactive PowerShell terminal.')}
    Initialize-TqsimCrypto
    if ($Confirm) {Write-Host 'ENCRYPTION ENABLED';Write-Warning 'Keep your password safely. If lost, Tqsim cannot recover your encrypted file.'} else {Write-Host 'ENCRYPTED ARCHIVE DETECTED'}
    $secret=Read-Host $(if($Confirm){'Enter encryption password'}else{'Enter decryption password'}) -AsSecureString
    try {
        if ($secret.Length -lt 12 -or $secret.Length -gt 1024) {throw [ArgumentException]::new('Use a passphrase of 12 to 1024 characters.')}
        if ($Confirm) {
            $second=Read-Host 'Confirm encryption password' -AsSecureString
            try {if (![Tqsim.CryptoSession]::SameSecret($secret,$second)) {throw [ArgumentException]::new('Passwords do not match. No archive was created.')}} finally {$second.Dispose()}
        }
        return $secret
    } catch {$secret.Dispose();throw}
}
function Assert-TqsimExactKeys($Object,[string[]]$Keys) {
    if ($Object -isnot [Collections.IDictionary] -or $Object.Count -ne $Keys.Count) {throw 'Unsupported encrypted metadata fields.'}
    foreach ($key in $Object.Keys) {if ($key -cnotin $Keys) {throw 'Unsupported encrypted metadata fields.'}}
}
function Assert-TqsimEncryptedManifest($m) {
    Assert-TqsimExactKeys $m @('application','applicationVersion','manifestVersion','operationId','originalFileName','originalSize','partSize','totalParts','hashAlgorithm','originalSHA256','createdUtc','parts','encryption')
    if ($m.application -cne 'Tqsim' -or $m.applicationVersion -notmatch '^\d+\.\d+\.\d+$' -or $m.hashAlgorithm -cne 'SHA256') {throw 'Unsupported encrypted archive.'}
    $null=[guid]::ParseExact($m.operationId,'D');Assert-TqsimName $m.originalFileName
    Assert-TqsimInteger $m.originalSize;Assert-TqsimInteger $m.partSize 29;Assert-TqsimInteger $m.totalParts
    if ($m.parts -isnot [array] -or $m.parts.Count -ne $m.totalParts -or $m.totalParts -gt 100000 -or $m.originalSHA256 -notmatch '^[a-fA-F0-9]{64}$') {throw 'Invalid encrypted archive size or hashes.'}
    $e=$m.encryption
    Assert-TqsimExactKeys $e @('enabled','formatVersion','algorithm','kdf','kdfVersion','iterations','salt','noncePrefix','chunkSize','tagSize','recordCount','manifestHMAC')
    foreach ($key in 'formatVersion','kdfVersion','iterations','chunkSize','tagSize','recordCount') {Assert-TqsimInteger $e[$key]}
    if ($e.enabled -isnot [bool] -or !$e.enabled -or $e.formatVersion -ne 1 -or $e.kdfVersion -ne 1 -or $e.algorithm -cne 'AES-256-GCM' -or $e.kdf -cne 'PBKDF2-HMAC-SHA256' -or $e.iterations -lt 600000 -or $e.iterations -gt 2000000 -or $e.chunkSize -ne 4194304 -or $e.tagSize -ne 16 -or $e.manifestHMAC -notmatch '^[a-fA-F0-9]{64}$') {throw 'Unsupported encrypted format or KDF parameters.'}
    if ($e.salt.Length -ne 44 -or $e.noncePrefix.Length -ne 8 -or [Convert]::FromBase64String($e.salt).Length -ne 32 -or [Convert]::FromBase64String($e.noncePrefix).Length -ne 4) {throw 'Invalid encryption salt or nonce prefix.'}
    [Numerics.BigInteger]$sum=0;[long]$index=0;$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($part in $m.parts) {
        Assert-TqsimExactKeys $part @('index','fileName','size','sha256');Assert-TqsimName $part.fileName;Assert-TqsimInteger $part.index 1;Assert-TqsimInteger $part.size 29;$index++
        if ($part.index -ne $index -or !$seen.Add($part.fileName) -or $part.size -gt $m.partSize -or $part.sha256 -notmatch '^[a-fA-F0-9]{64}$') {throw 'Invalid encrypted part metadata.'};$sum+=$part.size
    }
    if ($sum -ne ([Numerics.BigInteger]$m.originalSize+[Numerics.BigInteger]28*$e.recordCount) -or $sum -gt [long]::MaxValue -or $e.recordCount -gt 4294967295L -or $e.recordCount -gt $m.originalSize -or $m.totalParts -gt $e.recordCount -or ($m.originalSize -eq 0 -and ($m.totalParts -ne 0 -or $e.recordCount -ne 0)) -or ($m.originalSize -gt 0 -and ($e.recordCount -eq 0 -or $m.totalParts -eq 0))) {throw 'Invalid encrypted aggregate lengths.'}
}
function Get-TqsimManifestAuthenticationBytes($m) {
    $memory=[IO.MemoryStream]::new();$writer=[IO.BinaryWriter]::new($memory,[Text.Encoding]::UTF8,$true)
    try {
        $writer.Write([uint32]2)
        foreach ($value in @($m.applicationVersion)) {$b=[Text.Encoding]::UTF8.GetBytes([string]$value);$writer.Write([uint32]$b.Length);$writer.Write($b)}
        $writer.Write(([guid]$m.operationId).ToByteArray());$b=[Text.Encoding]::UTF8.GetBytes($m.originalFileName);$writer.Write([uint32]$b.Length);$writer.Write($b)
        foreach ($value in @($m.originalSize,$m.partSize,$m.totalParts)) {$writer.Write([long]$value)}
        $writer.Write([Tqsim.CryptoSession]::Hex($m.originalSHA256))
        foreach ($value in @($m.createdUtc,$m.encryption.algorithm,$m.encryption.kdf)) {$b=[Text.Encoding]::UTF8.GetBytes([string]$value);$writer.Write([uint32]$b.Length);$writer.Write($b)}
        foreach ($key in 'formatVersion','kdfVersion','iterations','chunkSize','tagSize') {$writer.Write([uint32]$m.encryption[$key])}
        $writer.Write([Convert]::FromBase64String($m.encryption.salt));$writer.Write([Convert]::FromBase64String($m.encryption.noncePrefix));$writer.Write([ulong]$m.encryption.recordCount)
        foreach ($part in $m.parts) {$writer.Write([long]$part.index);$b=[Text.Encoding]::UTF8.GetBytes($part.fileName);$writer.Write([uint32]$b.Length);$writer.Write($b);$writer.Write([long]$part.size);$writer.Write([Tqsim.CryptoSession]::Hex($part.sha256))}
        $writer.Flush();return ,$memory.ToArray()
    } finally {$writer.Dispose();$memory.Dispose()}
}
function New-TqsimCryptoSession($m,[switch]$Confirm) {
    Initialize-TqsimCrypto;$secret=Read-TqsimSecret -Confirm:$Confirm
    try {return [Tqsim.CryptoSession]::new($secret,[Convert]::FromBase64String($m.encryption.salt),$m.encryption.iterations,[Convert]::FromBase64String($m.encryption.noncePrefix),$m.operationId)} finally {$secret.Dispose()}
}
function Assert-TqsimManifestAuthentication($m,$Session) {
    if (!$Session.VerifyMAC((Get-TqsimManifestAuthenticationBytes $m),[Tqsim.CryptoSession]::Hex($m.encryption.manifestHMAC))) {throw [IO.InvalidDataException]::new('DECRYPTION FAILED: The password is incorrect or the encrypted archive could not be authenticated. No source files were deleted.')}
}
function Invoke-TqsimEncryptedParts($Metadata,[string]$Directory,$Session,$Destination,[switch]$Quiet) {
    $whole=[Security.Cryptography.IncrementalHash]::CreateHash('SHA256');[long]$done=0;[ulong]$ordinal=0;$clock=[Diagnostics.Stopwatch]::StartNew();[long]$tick=0;$activePart=''
    try {
        foreach ($part in $Metadata.parts) {
            $activePart=$part.fileName
            $path=Join-Path $Directory $part.fileName;Assert-TqsimRegular $path;$s=New-TqsimStream $path Open Read;$hash=[Security.Cryptography.IncrementalHash]::CreateHash('SHA256')
            try {
                if ($s.Length -ne $part.size) {throw [IO.InvalidDataException]::new("Wrong encrypted part size: $($part.fileName)")}
                while ($s.Position -lt $s.Length) {
                    $n=$Session.ReadRecord($s,$Destination,($s.Length-$s.Position),$part.index,$ordinal,$Metadata.originalSize,$Metadata.partSize,$whole,$hash);$done+=$n;$ordinal++
                    if ($done -gt $Metadata.originalSize) {throw [IO.InvalidDataException]::new('Encrypted plaintext exceeds declared length.')}
                    if (!$Quiet -and $clock.ElapsedMilliseconds-$tick -ge 250) {Show-TqsimProgress DECRYPTING $done $Metadata.originalSize $part.index $Metadata.totalParts $clock;$tick=$clock.ElapsedMilliseconds}
                }
                if ((ConvertTo-TqsimHex ($hash.GetHashAndReset())) -ine $part.sha256) {throw [IO.InvalidDataException]::new("Encrypted part integrity failed: $($part.fileName)")}
            } finally {$hash.Dispose();$s.Dispose()}
        }
        if ($done -ne $Metadata.originalSize -or $ordinal -ne $Metadata.encryption.recordCount -or (ConvertTo-TqsimHex ($whole.GetHashAndReset())) -ine $Metadata.originalSHA256) {throw [IO.InvalidDataException]::new('Encrypted archive plaintext length/hash/record count mismatch.')}
    } catch {$affected=if($activePart){" Affected part: $activePart."}else{''};throw [IO.InvalidDataException]::new("DECRYPTION FAILED: The password is incorrect or the encrypted archive is missing, damaged or modified.$affected No source files were deleted.",$_.Exception)} finally {$whole.Dispose();Complete-TqsimProgress}
}
function Split-TqsimEncrypted {
    param([string]$File,[string]$Size,[string]$Output,[switch]$Quiet,[string]$ds='false',[string]$verify='true')
    $deleteSource=Resolve-TqsimDeleteSourceOption $ds;$readBack=Resolve-TqsimVerifyOption $verify
    [long]$maximum=ConvertTo-TqsimSize $Size;if ($maximum -lt 29) {throw [ArgumentException]::new('Encrypted nonempty parts require -Size of at least 29 bytes (28 bytes framing plus payload).')}
    $source=[IO.Path]::GetFullPath($File);Assert-TqsimRegular $source
    $input=New-TqsimStream $source Open Read;$session=$null;$cleanup=New-TqsimDeletionContext;$owned=[Collections.Generic.List[string]]::new();$published=$false;$whole=[Security.Cryptography.IncrementalHash]::CreateHash('SHA256')
    try {
        [long]$length=$input.Length;$stamp=[IO.File]::GetLastWriteTimeUtc($source)
        [long]$fullRecords=[Numerics.BigInteger]::Divide($maximum,4194332);[long]$tail=$maximum % 4194332
        [long]$capacity=$fullRecords*4194304L+[math]::Max([long]0,[long]($tail-28))
        [long]$count=[Numerics.BigInteger]::Divide(([Numerics.BigInteger]$length+$capacity-1),$capacity)
        if ($count -gt 100000) {throw [ArgumentException]::new('Encrypted archive exceeds the supported part-count limit; choose a larger part size.')}
        Initialize-TqsimCrypto
        $name=[IO.Path]::GetFileName($source);$id=[guid]::NewGuid().ToString();$e=@{enabled=$true;formatVersion=1;algorithm='AES-256-GCM';kdf='PBKDF2-HMAC-SHA256';kdfVersion=1;iterations=600000;salt=[Convert]::ToBase64String([Tqsim.CryptoSession]::RandomBytes(32));noncePrefix=[Convert]::ToBase64String([Tqsim.CryptoSession]::RandomBytes(4));chunkSize=4194304;tagSize=16;recordCount=0L;manifestHMAC=('0'*64)}
        $m=[ordered]@{application='Tqsim';applicationVersion=(Get-TqsimVersion);manifestVersion=2;operationId=$id;originalFileName=$name;originalSize=$length;partSize=$maximum;totalParts=$count;hashAlgorithm='SHA256';originalSHA256=('0'*64);createdUtc=[datetime]::UtcNow.ToString('o');parts=@();encryption=$e}
        # Secret input/confirmation and KDF complete before creating any output.
        $session=New-TqsimCryptoSession $m -Confirm
        if (!$Output) {$Output=Join-Path ([IO.Path]::GetDirectoryName($source)) 'Output'}
        [long]$fullParts=if($length){[Numerics.BigInteger]::Divide(($length-1L),$capacity)}else{0}
        [long]$lastPlain=$length-$fullParts*$capacity
        [Numerics.BigInteger]$records=$fullParts*([Numerics.BigInteger]$fullRecords+$(if($tail -ge 29){1}else{0}))+[Numerics.BigInteger]::Divide(([Numerics.BigInteger]$lastPlain+4194303),4194304)
        if ($records -gt 4294967295L) {throw [ArgumentException]::new('Encrypted record/nonce limit exceeded. Choose larger parts.')}
        $bound=[Numerics.BigInteger]$length+28*$records;if ($bound -gt [long]::MaxValue) {throw [ArgumentException]::new('Encrypted physical archive size exceeds Int64.')}
        $dest=New-TqsimDestination $Output ([long]$bound);$manifest=Join-Path $dest "$name.tqsim.json";$width=[math]::Max(4,$count.ToString().Length)
        if (Test-Path -LiteralPath $manifest) {throw 'Manifest already exists.'}
        for ($i=1L;$i -le $count;$i++) {if (Test-Path -LiteralPath (Join-Path $dest ($name+'.part'+$i.ToString("D$width")))) {throw 'Part already exists.'}}
        if ($deleteSource) {$entry=Add-TqsimDeletionFile $cleanup $source -Target}
        $parts=[Collections.Generic.List[object]]::new();[long]$done=0;[ulong]$ordinal=0;$clock=[Diagnostics.Stopwatch]::StartNew();[long]$tick=0
        for ($i=1L;$i -le $count;$i++) {
            $partName=$name+'.part'+$i.ToString("D$width");$temp=Join-Path $dest ('.tqsim-'+[guid]::NewGuid()+'.tmp');$owned.Add($temp);$final=Join-Path $dest $partName
            $out=New-TqsimStream $temp CreateNew Write;$hash=[Security.Cryptography.IncrementalHash]::CreateHash('SHA256');[long]$written=0
            try {
                while ($done -lt $length -and $maximum-$written -ge 29) {
                    $n=[int][math]::Min([long]4194304,[math]::Min([long]($maximum-$written-28),[long]($length-$done)))
                    $session.WriteRecord($input,$out,$n,$i,$ordinal,$length,$maximum,$whole,$hash);$ordinal++;$done+=$n;$written+=[long]$n+28L
                    if (!$Quiet -and $clock.ElapsedMilliseconds-$tick -ge 250) {Show-TqsimProgress ENCRYPTING $done $length $i $count $clock;$tick=$clock.ElapsedMilliseconds}
                }
                $out.Flush($true);if ($out.Length -ne $written -or $written -gt $maximum) {throw 'Encrypted part length mismatch.'}
                $digest=ConvertTo-TqsimHex ($hash.GetHashAndReset());$identity=if($deleteSource){Get-TqsimFileIdentity $out}else{''}
            } finally {$hash.Dispose();$out.Dispose()}
            [IO.File]::Move($temp,$final);$owned.Add($final);$parts.Add(@{index=$i;fileName=$partName;size=$written;sha256=$digest})
            if ($deleteSource) {$null=Add-TqsimDeletionFile $cleanup $final $digest $written -ExpectedIdentity $identity}
        }
        if ($done -ne $length -or $input.ReadByte() -ne -1 -or $input.Length -ne $length -or [IO.File]::GetLastWriteTimeUtc($source) -ne $stamp) {throw 'Source changed during encryption.'}
        $m.parts=@($parts.ToArray());$m.originalSHA256=ConvertTo-TqsimHex ($whole.GetHashAndReset());$e.recordCount=[long]$ordinal;$e.manifestHMAC=ConvertTo-TqsimHex ($session.ManifestMAC((Get-TqsimManifestAuthenticationBytes $m)))
        Assert-TqsimEncryptedManifest $m
        $json=$m|ConvertTo-Json -Depth 8;$bytes=[Text.Encoding]::UTF8.GetBytes($json);if($bytes.Length -gt 16777216){throw 'Encrypted manifest exceeds safety limit.'}
        $temp=Join-Path $dest ('.tqsim-'+[guid]::NewGuid()+'.tmp');$owned.Add($temp);$out=New-TqsimStream $temp CreateNew Write
        try {$out.Write($bytes,0,$bytes.Length);$out.Flush($true);$identity=if($deleteSource){Get-TqsimFileIdentity $out}else{''}} finally {$out.Dispose()}
        [IO.File]::Move($temp,$manifest);$published=$true
        if ($deleteSource) {$entry.SHA256=$m.originalSHA256;$null=Add-TqsimDeletionFile $cleanup $manifest (ConvertTo-TqsimHex ([Security.Cryptography.SHA256]::HashData($bytes))) -ReadBack -ExpectedIdentity $identity -Quiet:$Quiet}
        $disk=Read-TqsimManifest $manifest;Assert-TqsimManifestAuthentication $disk $session
        if ($readBack) {Invoke-TqsimEncryptedParts $disk $dest $session -Quiet:$Quiet}
        $result='';if ($deleteSource) {$input.Dispose();$cleanup.StreamingComplete=$true;$cleanup.ReadBackVerified=$readBack;$result=Invoke-TqsimVerifiedSourceDeletion $cleanup $dest SPLIT}
        Show-TqsimProgress COMPLETED $done $length $count $count $clock -Quiet:$Quiet;Complete-TqsimProgress
        if (!$Quiet) {Write-Output "COMPLETED: encrypted $count parts; $manifest";if(!$readBack){Write-Output 'Independent verification skipped.'};if($result){Write-Output $result}}
    } finally {$input.Dispose();$whole.Dispose();if($session){$session.Dispose()};Close-TqsimDeletionContext $cleanup;Complete-TqsimProgress;if(!$published){foreach($path in $owned){if([IO.File]::Exists($path)){[IO.File]::Delete($path)}}}}
}
