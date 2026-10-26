function Resolve-TqsimDeleteSourceOption([string]$Value='false') {
    if ($Value -ieq 'true') {return $true}
    if ($Value -ieq 'false') {return $false}
    throw [ArgumentException]::new('-ds requires the string true or false. Default: false (keep source).')
}
function Resolve-TqsimVerifyOption([string]$Value='true') {
    if ($Value -ieq 'true') {return $true}
    if ($Value -ieq 'false') {return $false}
    throw [ArgumentException]::new('-verify requires the string true or false. Default: true.')
}
function Assert-TqsimDeletionPath([string]$Path) {
    $full=[IO.Path]::GetFullPath($Path)
    Assert-TqsimRegular $full
    $parent=[IO.DirectoryInfo]::new([IO.Path]::GetDirectoryName($full))
    while ($parent) {
        if ($parent.Attributes -band [IO.FileAttributes]::ReparsePoint) {throw "Unsafe reparse-point ancestor: $full"}
        $parent=$parent.Parent
    }
    if ($full.IndexOf(':',2) -ge 0) {throw "Alternate data streams are not supported for deletion: $full"}
    return $full
}
function Get-TqsimFileIdentity($Stream) {
    # A pathname, length and timestamp alone cannot detect same-content substitution.
    # Fail closed on platforms/filesystems without a usable Windows file identity.
    if (!$IsWindows) {throw 'Delete Source requires Windows file identity support.'}
    if (!('TqsimFileIdentity' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class TqsimFileIdentity {
    [StructLayout(LayoutKind.Sequential)] struct Info {
        public uint Attributes, CreationLow, CreationHigh, AccessLow, AccessHigh,
            WriteLow, WriteHigh, Volume, SizeHigh, SizeLow, Links, IndexHigh, IndexLow;
    }
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool GetFileInformationByHandle(SafeFileHandle file, out Info info);
    public static string Get(SafeFileHandle file) {
        Info i;
        if (!GetFileInformationByHandle(file, out i)) throw new Win32Exception(Marshal.GetLastWin32Error());
        if (i.Links != 1) throw new InvalidOperationException("Delete Source refuses hard-linked files.");
        if (i.IndexHigh == 0 && i.IndexLow == 0) throw new InvalidOperationException("Filesystem did not provide a usable file identity.");
        return i.Volume.ToString("X8")+":"+i.IndexHigh.ToString("X8")+i.IndexLow.ToString("X8");
    }
}
'@
    }
    return [TqsimFileIdentity]::Get($Stream.SafeFileHandle)
}
function Get-TqsimStreamDigest($Stream,[switch]$ShowProgress,[switch]$Quiet) {
    $Stream.Position=0
    $hash=[Security.Cryptography.IncrementalHash]::CreateHash('SHA256');$buffer=[byte[]]::new(4194304)
    [long]$done=0;$clock=[Diagnostics.Stopwatch]::StartNew();[long]$tick=0
    try {while (($n=$Stream.Read($buffer,0,$buffer.Length)) -gt 0) {$hash.AppendData($buffer,0,$n);$done+=$n
        if ($ShowProgress -and !$Quiet -and $clock.ElapsedMilliseconds-$tick -ge 250) {Show-TqsimProgress VERIFYING $done $Stream.Length 1 1 $clock;$tick=$clock.ElapsedMilliseconds}
    };return ConvertTo-TqsimHex ($hash.GetHashAndReset())} finally {$hash.Dispose();$Stream.Position=0; if ($ShowProgress) {Complete-TqsimProgress}}
}
function New-TqsimDeletionContext {
    return [pscustomobject]@{Handles=[Collections.Generic.List[object]]::new();Entries=[Collections.Generic.List[object]]::new();StreamingComplete=$false;ReadBackVerified=$false}
}
function Close-TqsimDeletionContext($Context) {
    foreach ($handle in $Context.Handles) {$handle.Dispose()}
    $Context.Handles.Clear()
}
function Add-TqsimDeletionFile($Context,[string]$Path,[string]$ExpectedHash='',[long]$ExpectedLength=-1,[switch]$Target,[switch]$ReadBack,[string]$ExpectedIdentity='',[switch]$Quiet) {
    $full=Assert-TqsimDeletionPath $Path
    if (@($Context.Entries|Where-Object {$_.Path -ieq $full}).Count) {throw "Duplicate cleanup/protected path: $full"}
    $stream=New-TqsimStream $full Open Read
    $Context.Handles.Add($stream)
    $identity=Get-TqsimFileIdentity $stream
    if ($ExpectedIdentity -and $identity -cne $ExpectedIdentity) {throw "Published file identity changed: $full"}
    $digest=if ($ReadBack) {Get-TqsimStreamDigest $stream -ShowProgress -Quiet:$Quiet} else {$ExpectedHash}
    if (($ExpectedLength -ge 0 -and $stream.Length -ne $ExpectedLength) -or ($ExpectedHash -and $digest -ine $ExpectedHash)) {throw [IO.InvalidDataException]::new("Independent verification failed: $full")}
    $item=Get-Item -LiteralPath $full -Force
    $entry=[pscustomobject]@{Path=$full;Identity=$identity;Length=$stream.Length;SHA256=$digest;WriteTicks=$item.LastWriteTimeUtc.Ticks;CreationTicks=$item.CreationTimeUtc.Ticks;Target=[bool]$Target;Status='pending';Stream=$stream}
    $Context.Entries.Add($entry)
    return $entry
}
function Assert-TqsimReceipt($Entry,$Stream) {
    $null=Assert-TqsimDeletionPath $Entry.Path
    $item=Get-Item -LiteralPath $Entry.Path -Force
    if ((Get-TqsimFileIdentity $Stream) -cne $Entry.Identity -or $Stream.Length -ne $Entry.Length -or $item.LastWriteTimeUtc.Ticks -ne $Entry.WriteTicks -or $item.CreationTimeUtc.Ticks -ne $Entry.CreationTicks) {throw "Deletion/protected file changed: $($Entry.Path)"}
}
function Assert-TqsimUnsharedParts([string]$Manifest,$Metadata) {
    $directory=[IO.Path]::GetDirectoryName($Manifest)
    $names=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($part in $Metadata.parts) {$null=$names.Add($part.fileName)}
    foreach ($other in Get-ChildItem -LiteralPath $directory -Filter '*.tqsim.json' -Force -File) {
        if ($other.FullName -ieq $Manifest) {continue}
        $null=Assert-TqsimDeletionPath $other.FullName
        # Invalid neighbouring manifests make ownership ambiguous: do not guess.
        $m=Read-TqsimManifest $other.FullName
        foreach ($part in $m.parts) {if ($names.Contains($part.fileName)) {throw "Automatic deletion refused: part '$($part.fileName)' is shared with $($other.FullName)."}}
    }
}
function Save-TqsimCleanupJournal($Journal,[string]$Path) {
    $directory=[IO.Path]::GetDirectoryName($Path)
    $null=New-TqsimDestination $directory 0
    if ([IO.File]::Exists($Path)) {$null=Assert-TqsimDeletionPath $Path}
    $temp=Join-Path $directory ('.tqsim-'+[guid]::NewGuid()+'.tmp')
    $stream=$null
    try {
        $bytes=[Text.Encoding]::UTF8.GetBytes(($Journal|ConvertTo-Json -Depth 8))
        $stream=New-TqsimPrivateStream $temp
        $stream.Write($bytes,0,$bytes.Length);$stream.Flush($true);$stream.Dispose();$stream=$null
        [IO.File]::Move($temp,$Path,$true)
    } finally {if ($stream) {$stream.Dispose()};if ([IO.File]::Exists($temp)) {[IO.File]::Delete($temp)}}
}
function Remove-TqsimVerifiedFile($Entry) {
    $null=Assert-TqsimDeletionPath $Entry.Path
    $stream=New-TqsimStream $Entry.Path Open Read
    try {
        Assert-TqsimReceipt $Entry $stream
    } finally {$stream.Dispose()}
    # All processing/read handles for this file are closed. Check ancestors again
    # immediately before the exact-path deletion; never recurse or expand wildcards.
    $null=Assert-TqsimDeletionPath $Entry.Path
    try {[IO.File]::Delete($Entry.Path)} catch {
        $originalFailure=$_;$base=$_.Exception.GetBaseException()
        if ((Get-Item -LiteralPath $Entry.Path -Force).Attributes -band [IO.FileAttributes]::ReadOnly) {throw (New-TqsimUserError 'SOURCE_READ_ONLY' 'SOURCE DELETION FAILED' 'The selected source is marked read-only. Its data and the completed output have been preserved.' 'Remove the read-only attribute only if you intend to delete this exact file; no permissions were broadened.' $base)}
        if ($base -is [UnauthorizedAccessException]) {
            $oldDacl=$null
            try {
                $oldDacl=Grant-TqsimExactDeletePermission $Entry
                $check=New-TqsimStream $Entry.Path Open Read;try {Assert-TqsimReceipt $Entry $check} finally {$check.Dispose()}
                $null=Assert-TqsimDeletionPath $Entry.Path;[IO.File]::Delete($Entry.Path)
            } catch {
                $aclFailure=$_
                if ($oldDacl -and [IO.File]::Exists($Entry.Path)) {try {Restore-TqsimExactDacl $Entry $oldDacl} catch {throw (New-TqsimUserError 'DACL_RESTORE_FAILED' 'SOURCE DELETION FAILED' 'Windows denied deletion and the temporary Delete permission could not be restored. The source remains.' 'Ask an authorized administrator to review this exact file DACL. Completed output remains available; do not rerun the large operation.' $_.Exception)}}
                throw (New-TqsimUserError 'DELETE_ACCESS_DENIED' 'SOURCE DELETION FAILED' 'Windows denied source deletion. A minimum per-file Delete permission adjustment was not permitted or did not resolve the denial.' 'Completed output is preserved. Grant Delete permission to your account or ask an authorized administrator to clean up the exact source files. Do not rerun split/merge; no elevation was attempted.' $aclFailure.Exception)
            }
        } elseif (($base.HResult -band 65535) -in 32,33) {throw (New-TqsimUserError 'SOURCE_LOCKED' 'SOURCE DELETION FAILED' 'Another process appears to be holding the selected source file open.' 'Close the application using this file, then review the completed output before manually cleaning up the exact source. Do not rerun split/merge.' $base)} else {throw (New-TqsimUserError 'DELETE_IO_FAILURE' 'SOURCE DELETION FAILED' 'A disk or filesystem error prevented source deletion. The exact cause is available with -Diagnostics.' 'Keep the completed output and remaining sources. Check disk health and permissions before manual cleanup.' $base)}
    }
    if ([IO.File]::Exists($Entry.Path)) {throw "Deletion did not remove $($Entry.Path)"}
}
function Invoke-TqsimVerifiedSourceDeletion($Context,[string]$JournalDirectory,[string]$Operation) {
    $targets=@($Context.Entries|Where-Object Target)
    $protected=@($Context.Entries|Where-Object {!$_.Target})
    if (!$Context.StreamingComplete -or !$protected.Count -or !$targets.Count) {throw 'Deletion requires complete streaming integrity, safe publication, targets and protected data.'}
    # Validate the entire set before the first destructive action. Protected data
    # remains locked against writing/renaming through the whole cleanup.
    foreach ($entry in $Context.Entries) {
        Assert-TqsimReceipt $entry $entry.Stream
        if ($entry.SHA256 -notmatch '^[a-fA-F0-9]{64}$') {throw 'Missing completed streaming hash; cleanup refused.'}
    }
    foreach ($entry in $targets) {if (@($protected|Where-Object {$_.Path -ieq $entry.Path -or $_.Identity -ceq $entry.Identity}).Count) {throw 'Deletion target collides with protected output.'}}
    $journalPath=Join-Path (Get-TqsimRecoveryDirectory) ('.tqsim-cleanup-'+[guid]::NewGuid()+'.json')
    $journal=[ordered]@{application='Tqsim';journalVersion=1;operation=$Operation;authorizedDeleteSource=$true;independentReadBackVerified=$Context.ReadBackVerified;createdUtc=[datetime]::UtcNow.ToString('o');state='prepared';targets=@($targets|Select-Object Path,Identity,Length,SHA256,Status);protected=@($protected|Select-Object Path,Identity,Length,SHA256)}
    Save-TqsimCleanupJournal $journal $journalPath
    if (!$Context.ReadBackVerified) {Write-Warning -WarningAction Continue 'Independent read-back verification is disabled. Source deletion is irreversible.'}
    $deleted=0
    try {
        for ($i=0;$i -lt $targets.Count;$i++) {
            $journal.state='cleaning';$journal.targets[$i].Status='deleting'
            Save-TqsimCleanupJournal $journal $journalPath
            # Keep every other target locked until its own deletion boundary.
            $targets[$i].Stream.Dispose()
            Remove-TqsimVerifiedFile $targets[$i]
            $deleted++;$journal.targets[$i].Status='deleted'
            Save-TqsimCleanupJournal $journal $journalPath
        }
        $journal.state='completed';Save-TqsimCleanupJournal $journal $journalPath
        $null=Assert-TqsimDeletionPath $journalPath;[IO.File]::Delete($journalPath)
    } catch {
        $failure=$_;$journal.state='incomplete'
        # Keep the write-ahead "deleting" entry if deletion or its acknowledgement
        # was interrupted. A manual check is required; journals never authorize retries.
        $hasPartial=$deleted -gt 0 -or @($targets|Where-Object {![IO.File]::Exists($_.Path)}).Count -gt 0
        $recovery=if ($hasPartial) {try {Save-TqsimCleanupJournal $journal $journalPath} catch {Write-Warning 'Recovery acknowledgement failed; preserve the existing write-ahead record.'};"Recovery record: $journalPath"} else {$null=Assert-TqsimDeletionPath $journalPath;[IO.File]::Delete($journalPath);'No source files were deleted; no partial-cleanup journal is needed.'}
        $reason=if ($failure.Exception.Data.Contains('TqsimCode')) {$failure.Exception.Message} else {'Cleanup stopped because of a file, identity, permission, cancellation or filesystem error. Use -Diagnostics for details.'}
        throw (New-TqsimUserError 'CLEANUP_INCOMPLETE' "$Operation COMPLETED — CLEANUP INCOMPLETE" "$deleted deleted, $($targets.Count-$deleted) remaining/unconfirmed. $reason" "Completed output is preserved. $recovery Do not rerun the completed large operation; review remaining files for manual cleanup." $failure.Exception)
    }
    return "Source deletion: COMPLETED ($deleted files)."
}
