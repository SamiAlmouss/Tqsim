. "$PSScriptRoot/TestSupport.ps1"
Describe 'Same-directory destination and recovery lifecycle' {
    It 'merges beside sources with no Output directory and preserves an existing collision' {
        $f=New-SplitFixture;$hash=(Get-FileHash $f.Source).Hash
        Merge-Tqsim -PartsPath $f.Parts -Quiet
        (Get-FileHash (Join-Path $f.Parts 'data.bin')).Hash|Should Be $hash
        [IO.Directory]::Exists((Join-Path $f.Parts 'Output'))|Should Be $false
        {Merge-Tqsim -PartsPath $f.Parts -ds true -Quiet}|Should Throw
        @(Get-ChildItem $f.Parts -Filter '*.part*').Count|Should Be 11
    }
    It 'removes only its own successful recovery records and never clutters parts' {
        $f=New-TestFixture;$recovery=Get-TqsimRecoveryDirectory;$unrelated=Join-Path $recovery 'old-unrelated.json';[IO.File]::WriteAllText($unrelated,'preserve')
        Split-Tqsim -File $f.Source -Size 1000 -Output $f.Parts -ds true -Quiet
        [IO.File]::Exists((Join-Path $f.Parts 'data.bin.tqsim.json'))|Should Be $true
        @(Get-ChildItem $f.Parts -Filter '.tqsim-cleanup-*.json').Count|Should Be 0
        Merge-Tqsim -PartsPath $f.Parts -ds true -Quiet
        @(Get-ChildItem $f.Parts -File).Count|Should Be 1
        [IO.File]::ReadAllText($unrelated)|Should Be preserve
        @(Get-ChildItem $recovery -Filter '.tqsim-cleanup-*.json').Count|Should Be 0
    }
    It 'retains no pointless recovery journal when the first deletion fails read-only' {
        $f=New-TestFixture;[IO.File]::SetAttributes($f.Source,[IO.FileAttributes]::ReadOnly)
        try {{Split-Tqsim -File $f.Source -Size 1000 -Output $f.Parts -ds true -Quiet}|Should Throw;[IO.File]::Exists($f.Source)|Should Be $true;@(Get-TestRecoveryJournal $f).Count|Should Be 0;Test-Tqsim -PartsPath $f.Parts -Quiet} finally {[IO.File]::SetAttributes($f.Source,[IO.FileAttributes]::Normal)}
    }
}
Describe 'Narrow Windows per-file permissions' {
    It 'creates plaintext and journal files with a protected owner-only DACL atomically' {
        $f=New-TestFixture;$temp=Join-Path $f.Directory 'private.tmp';$s=New-TqsimPrivateStream $temp
        try {$acl=Get-Acl -LiteralPath $temp;$acl.AreAccessRulesProtected|Should Be $true;$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
            foreach($rule in $acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])){$rule.IdentityReference.Value|Should Be $sid;$rule.IsInherited|Should Be $false}
            $s.WriteByte(42);$s.Flush($true)
        } finally {$s.Dispose()}
        {New-TqsimPrivateStream $temp}|Should Throw
        [IO.File]::ReadAllBytes($temp)[0]|Should Be 42
    }
    Context 'No deletion authorization' {
    It 'uses no source ACL adjustment when deletion is omitted or false' {
        Mock Grant-TqsimExactDeletePermission -ModuleName Tqsim {throw 'Not authorized'}
        $f=New-TestFixture;Split-Tqsim -File $f.Source -Size 1000 -Output $f.Parts -Quiet
        Merge-Tqsim -PartsPath $f.Parts -Quiet
        Assert-MockCalled Grant-TqsimExactDeletePermission -ModuleName Tqsim -Times 0 -Exactly -Scope It
    }
    }
    It 'legally adds only Delete after a real NTFS access denial when WRITE_DAC is available' {
        $f=New-TestFixture;$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User
        $parent=Get-Acl -LiteralPath $f.Directory;$originalParent=$parent.GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::Access)
        $originalFile=Get-Acl -LiteralPath $f.Source
        $parent.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,[Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles,[Security.AccessControl.AccessControlType]::Deny))
        [IO.FileSystemAclExtensions]::SetAccessControl([IO.DirectoryInfo]::new($f.Directory),$parent)
        $acl=[Security.AccessControl.FileSecurity]::new();$acl.SetAccessRuleProtection($true,$false)
        $rights=[Security.AccessControl.FileSystemRights]::ReadAndExecute -bor [Security.AccessControl.FileSystemRights]::Write -bor [Security.AccessControl.FileSystemRights]::ReadPermissions -bor [Security.AccessControl.FileSystemRights]::ChangePermissions
        $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,$rights,[Security.AccessControl.AccessControlType]::Allow))
        $context=New-TqsimDeletionContext
        try {
            [IO.FileSystemAclExtensions]::SetAccessControl([IO.FileInfo]::new($f.Source),$acl)
            {[IO.File]::Delete($f.Source)}|Should Throw
            $entry=Add-TqsimDeletionFile $context $f.Source -Target;$entry.Stream.Dispose()
            Remove-TqsimVerifiedFile $entry
            [IO.File]::Exists($f.Source)|Should Be $false
        } finally {
            Close-TqsimDeletionContext $context
            $parent.SetSecurityDescriptorSddlForm($originalParent,[Security.AccessControl.AccessControlSections]::Access)
            [IO.FileSystemAclExtensions]::SetAccessControl([IO.DirectoryInfo]::new($f.Directory),$parent)
            if([IO.File]::Exists($f.Source)){[IO.FileSystemAclExtensions]::SetAccessControl([IO.FileInfo]::new($f.Source),$originalFile)}
        }
    }
    It 'reports a real sharing violation without attempting ACL changes' {
        $f=New-TestFixture;$context=New-TqsimDeletionContext;$lock=New-TqsimStream $f.Source Open Read
        try {$entry=Add-TqsimDeletionFile $context $f.Source -Target;$entry.Stream.Dispose();$message='';try{Remove-TqsimVerifiedFile $entry}catch{$message=$_.Exception.Message};$message|Should Match 'holding.*open';[IO.File]::Exists($f.Source)|Should Be $true} finally {$lock.Dispose();Close-TqsimDeletionContext $context}
    }
    It 'preserves a real NTFS source when both Delete and owner WRITE_DAC are denied' {
        $f=New-TestFixture;$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User;$ownerRights=[Security.Principal.SecurityIdentifier]::new('S-1-3-4')
        $parent=Get-Acl -LiteralPath $f.Directory;$original=$parent.GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::Access)
        $parent.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,[Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles,[Security.AccessControl.AccessControlType]::Deny))
        $context=New-TqsimDeletionContext
        try {
            [IO.FileSystemAclExtensions]::SetAccessControl([IO.DirectoryInfo]::new($f.Directory),$parent)
            $acl=[Security.AccessControl.FileSecurity]::new();$acl.SetAccessRuleProtection($true,$false)
            $rights=[Security.AccessControl.FileSystemRights]::ReadAndExecute -bor [Security.AccessControl.FileSystemRights]::Write -bor [Security.AccessControl.FileSystemRights]::ReadPermissions
            $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,$rights,[Security.AccessControl.AccessControlType]::Allow))
            $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($ownerRights,[Security.AccessControl.FileSystemRights]::ChangePermissions,[Security.AccessControl.AccessControlType]::Deny))
            [IO.FileSystemAclExtensions]::SetAccessControl([IO.FileInfo]::new($f.Source),$acl)
            $entry=Add-TqsimDeletionFile $context $f.Source -Target;$entry.Stream.Dispose()
            $message='';try{Remove-TqsimVerifiedFile $entry}catch{$message=$_.Exception.Message}
            $message|Should Match 'not permitted|did not resolve'
            [IO.File]::Exists($f.Source)|Should Be $true
        } finally {
            Close-TqsimDeletionContext $context
            $parent.SetSecurityDescriptorSddlForm($original,[Security.AccessControl.AccessControlSections]::Access)
            [IO.FileSystemAclExtensions]::SetAccessControl([IO.DirectoryInfo]::new($f.Directory),$parent)
            # Restoring parent DELETE_CHILD permits exact deletion of our disposable
            # file even when its file DACL intentionally denies WRITE_DAC.
            if([IO.File]::Exists($f.Source)){[IO.File]::Delete($f.Source)}
        }
    }
}
