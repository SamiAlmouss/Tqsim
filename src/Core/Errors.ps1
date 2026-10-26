function New-TqsimUserError([string]$Code,[string]$Title,[string]$Cause,[string]$Action,[Exception]$Inner,[int]$ExitCode=1) {
    $error=[IO.IOException]::new($Cause,$Inner)
    $error.Data['TqsimCode']=$Code;$error.Data['TqsimTitle']=$Title;$error.Data['TqsimOperation']=($Title -split ' ')[0];$error.Data['TqsimAction']=$Action;$error.Data['TqsimExitCode']=$ExitCode
    return $error
}
function Write-TqsimUserFailure($Record) {
    $e=$Record.Exception
    while ($e.InnerException -and !$e.Data.Contains('TqsimCode')) {$e=$e.InnerException}
    if ($e.Data.Contains('TqsimCode')) {
        [Console]::Error.WriteLine($e.Data['TqsimTitle']);[Console]::Error.WriteLine($e.Message);[Console]::Error.WriteLine($e.Data['TqsimAction']);return [int]$e.Data['TqsimExitCode']
    }
    $message=$e.Message
    if ($e -is [OperationCanceledException] -or $e -is [Management.Automation.PipelineStoppedException]) {[Console]::Error.WriteLine('OPERATION CANCELLED: Processing stopped. Preserve the source files and review any completed output/recovery record before cleanup.');return 1}
    if ($e -is [Security.Cryptography.CryptographicException] -or $Record.Exception.Message -match 'DECRYPTION FAILED') {
        $part=if($Record.Exception.Message -match 'Affected part: ([^\r\n]+)\. No source'){" Affected part: $($Matches[1])."}else{''}
        [Console]::Error.WriteLine("DECRYPTION FAILED: The password may be incorrect, or the archive may be damaged or modified.$part No source files were deleted.");return 3
    }
    if ($Record.Exception -is [ArgumentException]) {[Console]::Error.WriteLine("FAILED: $($Record.Exception.Message)");return 2}
    if ($Record.Exception -is [IO.InvalidDataException]) {
        if ($Record.Exception.Message -match 'Unsupported encrypted') {[Console]::Error.WriteLine('UNSUPPORTED ENCRYPTED ARCHIVE: Update Tqsim or use a compatible version. Keep all original archive files.');return 3}
        $text=if ($Record.Exception.Message -like 'Invalid manifest:*') {'INVALID ARCHIVE MANIFEST: The manifest is damaged or uses unsupported metadata. Restore its original copy or use a compatible Tqsim version.'} else {$Record.Exception.Message}
        [Console]::Error.WriteLine("FAILED: $text");return 3
    }
    if ($e -is [IO.FileNotFoundException] -or $e -is [Management.Automation.ItemNotFoundException]) {$message='A required file is missing. Restore the missing source part and try again.'}
    elseif ($e -is [UnauthorizedAccessException]) {$message='Windows denied access. Check account permissions, file read-only state and whether another program is using the file.'}
    elseif ($message -match 'Exception calling|argument\(s\)') {$message='The file operation could not be completed. Check the selected paths, permissions, free space and whether a file is in use. Use -Diagnostics for technical details.'}
    [Console]::Error.WriteLine("FAILED: $message");return 1
}
function Protect-TqsimPrivateFile([string]$Path) {
    if (!$IsWindows) {throw 'Protected temporary plaintext requires Windows ACL support.'}
    $null=Assert-TqsimDeletionPath $Path
    $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User
    $acl=[Security.AccessControl.FileSecurity]::new();$acl.SetOwner($sid);$acl.SetAccessRuleProtection($true,$false)
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,[Security.AccessControl.FileSystemRights]::FullControl,[Security.AccessControl.AccessControlType]::Allow))
    [IO.FileSystemAclExtensions]::SetAccessControl([IO.FileInfo]::new($Path),$acl)
}
function New-TqsimPrivateStream([string]$Path) {
    if (!$IsWindows) {throw 'Protected plaintext creation requires Windows ACL support.'}
    $full=[IO.Path]::GetFullPath($Path);$walk=[IO.DirectoryInfo]::new([IO.Path]::GetDirectoryName($full))
    while($walk){if($walk.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Unsafe temporary-file ancestor.'};$walk=$walk.Parent}
    $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User;$acl=[Security.AccessControl.FileSecurity]::new();$acl.SetOwner($sid);$acl.SetAccessRuleProtection($true,$false)
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,[Security.AccessControl.FileSystemRights]::FullControl,[Security.AccessControl.AccessControlType]::Allow))
    # Apply the private DACL in the atomic CreateNew call. There is no interval
    # in which another account can open an inherited-readable plaintext file.
    return [IO.FileSystemAclExtensions]::Create([IO.FileInfo]::new($full),[IO.FileMode]::CreateNew,([Security.AccessControl.FileSystemRights]::Read -bor [Security.AccessControl.FileSystemRights]::Write),[IO.FileShare]::Read,4096,[IO.FileOptions]::SequentialScan,$acl)
}
function Grant-TqsimExactDeletePermission($Entry) {
    $null=Assert-TqsimDeletionPath $Entry.Path
    $s=New-TqsimStream $Entry.Path Open Read;try {Assert-TqsimReceipt $Entry $s} finally {$s.Dispose()}
    $acl=Get-Acl -LiteralPath $Entry.Path -ErrorAction Stop
    $original=$acl.GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::Access)
    $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,[Security.AccessControl.FileSystemRights]::Delete,[Security.AccessControl.AccessControlType]::Allow))
    # Windows itself enforces WRITE_DAC. No ownership takeover, privilege change,
    # shell execution, directory ACL modification or UAC bypass is performed.
    [IO.FileSystemAclExtensions]::SetAccessControl([IO.FileInfo]::new($Entry.Path),$acl)
    return $original
}
function Restore-TqsimExactDacl($Entry,[string]$Original) {
    $s=New-TqsimStream $Entry.Path Open Read;try {Assert-TqsimReceipt $Entry $s} finally {$s.Dispose()}
    $acl=Get-Acl -LiteralPath $Entry.Path -ErrorAction Stop;$acl.SetSecurityDescriptorSddlForm($Original,[Security.AccessControl.AccessControlSections]::Access)
    [IO.FileSystemAclExtensions]::SetAccessControl([IO.FileInfo]::new($Entry.Path),$acl)
}
function Get-TqsimRecoveryDirectory {
    if (!$env:LOCALAPPDATA -or ![IO.Path]::IsPathFullyQualified($env:LOCALAPPDATA)) {throw 'A valid per-user LocalAppData directory is required for safe cleanup recovery.'}
    $root=Join-Path $env:LOCALAPPDATA 'Tqsim/Recovery'
    $existed=[IO.Directory]::Exists($root)
    $null=New-TqsimDestination $root 0
    if ($existed) {return $root}
    $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User;$acl=[Security.AccessControl.DirectorySecurity]::new();$acl.SetOwner($sid);$acl.SetAccessRuleProtection($true,$false)
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,[Security.AccessControl.FileSystemRights]::FullControl,([Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit),[Security.AccessControl.PropagationFlags]::None,[Security.AccessControl.AccessControlType]::Allow))
    [IO.FileSystemAclExtensions]::SetAccessControl([IO.DirectoryInfo]::new($root),$acl)
    return $root
}
