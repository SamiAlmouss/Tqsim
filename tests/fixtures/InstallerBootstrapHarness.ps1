param([string]$ProjectRoot,[ValidateSet('success','failure')][string]$Scenario='success',[switch]$FileInvocation,[string]$WorkDirectory=(Join-Path $ProjectRoot '.test-work'),[string]$ResultPath)
$ErrorActionPreference='Stop'
$store=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Microsoft/WindowsApps'
if(Test-Path -LiteralPath (Join-Path $store 'pwsh.exe')) {$env:Path=$store+';'+$env:Path}
$dir=Join-Path $WorkDirectory ('bootstrap-'+$Scenario+'-'+[guid]::NewGuid())
$null=[IO.Directory]::CreateDirectory($dir)
$env:LOCALAPPDATA=Join-Path $dir "Local space ' quote 測試"
$source=[IO.File]::ReadAllText((Join-Path $ProjectRoot 'install.ps1'))
$stub=@'
function Install-TqsimRelease {
    param([string]$Repository,[string]$InstallRoot)
    $null=[IO.Directory]::CreateDirectory($InstallRoot)
    $record=@{Repository=$Repository;InstallRoot=$InstallRoot;Runtime=$PSVersionTable.PSVersion.ToString();ProcessId=$PID;OriginalScriptPath=$PSCommandPath;OriginalScriptRoot=$PSScriptRoot}
    [IO.File]::WriteAllText((Join-Path $InstallRoot 'receipt.json'),($record|ConvertTo-Json))
    if ($env:TQSIM_TEST_CHILD_FAILURE -eq '1') {throw 'DISPOSABLE CHILD FAILURE'}
    Write-Output 'DISPOSABLE INSTALL SUCCEEDED'
}
'@
$source=$source.Replace("if (`$MyInvocation.InvocationName -ne '.') {",$stub+"`nif (`$MyInvocation.InvocationName -ne '.') {")
$parent=$PID;$parentVersion=$PSVersionTable.PSVersion.ToString()
$env:TQSIM_TEST_CHILD_FAILURE=if($Scenario -eq 'failure'){'1'}else{'0'}
$caught=''
try {
    if ($FileInvocation) {
        $file=Join-Path $dir 'downloaded installer.ps1'
        [IO.File]::WriteAllText($file,$source,(New-Object Text.UTF8Encoding $true))
        & $file -Repository 'SamiAlmouss/Tqsim'
    } else {
        # Mock only the HTTP response; execute the public pipeline syntax.
        function Invoke-RestMethod {param([string]$Uri) if($Uri -cne 'https://raw.githubusercontent.com/SamiAlmouss/Tqsim/main/install.ps1'){throw 'Unexpected URL'};return $source}
        irm https://raw.githubusercontent.com/SamiAlmouss/Tqsim/main/install.ps1 | iex
    }
} catch {$caught=$_.Exception.Message}
$code=$global:LASTEXITCODE
$root=Join-Path $env:LOCALAPPDATA 'Programs/Tqsim'
$receipt=[IO.File]::ReadAllText((Join-Path $root 'receipt.json'))|ConvertFrom-Json
if($receipt.Runtime -notmatch '^7\.' -or $receipt.Repository -cne 'SamiAlmouss/Tqsim' -or $receipt.InstallRoot -cne $root){throw 'Incorrect forwarded configuration or runtime'}
if($PSVersionTable.PSVersion.Major -eq 5 -and $receipt.ProcessId -eq $parent){throw 'No separate child was started'}
if($Scenario -eq 'success' -and ($code -ne 0 -or $caught)){throw "Unexpected failure: $caught; exit $code"}
if($Scenario -eq 'failure' -and ($code -ne 1 -or !$caught)){throw 'Child failure was not propagated'}
$result=@{ParentRuntime=$parentVersion;ChildRuntime=$receipt.Runtime;ParentPid=$parent;InstallPid=$receipt.ProcessId;ExitCode=$code;ParentSurvived=$true;Scenario=$Scenario;Invocation=$(if($FileInvocation){'file'}else{'irm | iex (local HTTP fixture)'});OriginalScriptPath=$receipt.OriginalScriptPath;OriginalScriptRoot=$receipt.OriginalScriptRoot;Caught=$caught;InstallRoot=$root}
$label=if($FileInvocation){'file'}else{'piped'}
if (!$ResultPath) {$ResultPath=Join-Path $WorkDirectory "bootstrap-$parentVersion-$Scenario-$label.json"}
[IO.File]::WriteAllText($ResultPath,($result|ConvertTo-Json))
Write-Output ($result|ConvertTo-Json)
