. "$PSScriptRoot/TestSupport.ps1"
$boundaries=@(
    @{Size='500MB';Expected=524288000L}
    @{Size='1GB';Expected=1073741824L}
    @{Size='2GB';Expected=2147483648L}
    @{Size='4GB';Expected=4294967296L}
    @{Size='2147483647';Expected=2147483647L}
    @{Size='2147483648';Expected=2147483648L}
    @{Size='200GB';Expected=214748364800L}
    @{Size='1TB';Expected=1099511627776L}
)
Describe 'Int64 file and chunk boundaries' {
    It 'parses <Size> and bounds reads without Int32 overflow' -TestCases $boundaries {
        param($Size,$Expected)
        $bytes=ConvertTo-TqsimSize $Size
        $bytes | Should BeOfType ([long])
        $bytes | Should Be $Expected
        # This is the production split/verify/merge read-count calculation.
        # The old Min(buffer.Length, remaining) throws here at 2 GiB and above.
        $readCount=Get-TqsimReadCount 4194304 $bytes
        $readCount | Should BeOfType ([int])
        $readCount | Should Be 4194304
        [long]$remaining=$bytes-$readCount
        $remaining | Should Be ($Expected-4194304L)
        (Get-TqsimReadCount 4194304 $remaining) | Should Be 4194304
    }
    It 'round trips binary data with <Size> configured parts' -TestCases $boundaries {
        param($Size,$Expected)
        $f=New-TestFixture 10003 'boundary 測試.bin'
        $originalHash=(Get-FileHash -LiteralPath $f.Source).Hash
        Split-Tqsim -File $f.Source -Size $Size -Output $f.Parts -BufferSize 4096 -Quiet
        $manifest=Read-TqsimManifest (Join-Path $f.Parts 'boundary 測試.bin.tqsim.json')
        $manifest.partSize | Should Be $Expected
        $manifest.totalParts | Should Be 1
        $manifest.originalSHA256 | Should Be $originalHash
        Test-Tqsim -PartsPath $f.Parts -BufferSize 4096 -Quiet
        Merge-Tqsim -PartsPath $f.Parts -Output $f.Restored -BufferSize 4096 -Quiet
        (Get-FileHash -LiteralPath (Join-Path $f.Restored 'boundary 測試.bin')).Hash | Should Be $originalHash
        (Get-FileHash -LiteralPath $f.Source).Hash | Should Be $originalHash
    }
    It 'only narrows after bounding a read and handles a short final read' {
        (Get-TqsimReadCount 4194304 ([long]::MaxValue)) | Should Be 4194304
        (Get-TqsimReadCount 4194304 17L) | Should Be 17
        (Get-TqsimReadCount 4194304 0L) | Should Be 0
    }
    It 'preserves v1.0.0 manifest compatibility' {
        $f=New-SplitFixture
        $path=Change-TestManifest $f {param($m)$m.applicationVersion='1.0.0'}
        (Read-TqsimManifest $path).applicationVersion | Should Be '1.0.0'
        Test-Tqsim -Manifest $path -Quiet
        Merge-Tqsim -Manifest $path -Output $f.Restored -Quiet
        (Get-FileHash -LiteralPath (Join-Path $f.Restored 'data.bin')).Hash | Should Be (Get-FileHash -LiteralPath $f.Source).Hash
    }
}
