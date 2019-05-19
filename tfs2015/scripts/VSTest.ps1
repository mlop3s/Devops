param(
    [string]$vsTestVersion, 
    [string]$testAssembly,
    [string]$testFiltercriteria,
    [string]$runSettingsFile,
    [string]$codeCoverageEnabled,
    [string]$pathtoCustomTestAdapters,
    [string]$overrideTestrunParameters,
    [string]$otherConsoleOptions,
    [string]$platform,
    [string]$configuration
)

Write-Verbose "Entering script VSTestConsole.ps1"

# Import the Task.Common and Task.Internal dll that has all the cmdlets we need for Build
import-module "Microsoft.TeamFoundation.DistributedTask.Task.Internal"
import-module "Microsoft.TeamFoundation.DistributedTask.Task.Common"
# Import the Task.TestResults dll that has the cmdlet we need for publishing results
import-module "Microsoft.TeamFoundation.DistributedTask.Task.TestResults"

if (!$testAssembly)
{
    throw (Get-LocalizedString -Key "Test assembly parameter not set on script")
}

# check for solution pattern
if ($testAssembly.Contains("*") -or $testAssembly.Contains("?"))
{
    Write-Verbose "Pattern found in solution parameter. Calling Find-Files."
    Write-Verbose "Calling Find-Files with pattern: $testAssembly"
    $testAssemblyFiles = Find-Files -SearchPattern $testAssembly  | Where-Object {($_ -notlike '*Nexus\MF\libs*') -and ($_ -notlike '*packages*') -and ($_ -notlike '*Microsoft.VisualStudio*') -and ($_ -notlike '*TESTADAPTER*' ) -and ($_ -notlike '*TESTCONTAINER*' ) }  | Resolve-Path | Where-Object {[System.IO.Path]::GetFileName($_).Contains('Test')} | Select-Object -Property Path | convert-path
    Write-Verbose "Found files: $testAssemblyFiles"
}
else
{
    Write-Verbose "No Pattern found in solution parameter."
    $testAssemblyFiles = ,$testAssembly
}

if (!$testFiltercriteria)
{
	$testFiltercriteria = 'TestCategory!=Integration'
}

$diagFile = $workingDirectory + "\" + "diagnostic.txt"

if (!$otherConsoleOptions)
{
	$otherConsoleOptions = "/Blame"
}

#$codeCoverage = Convert-String $codeCoverageEnabled Boolean
$codeCoverage = Convert-String "false" Boolean
if($testAssemblyFiles)
{
	Write-Warning "testAssemblyFiles = $testAssemblyFiles"
	Write-Warning "Calling Invoke-VSTest for version 16.0 for all listed test assemblies"
    $vsTestVersion = "16.0"
    $artifactsDirectory = Get-TaskVariable -Context $distributedTaskContext -Name "System.ArtifactsDirectory" -Global $FALSE

    $workingDirectory = $artifactsDirectory
    $testResultsDirectory = $workingDirectory + "\" + "TestResults"
	$env:Path += "$workingDirectory\DEV\DEVMAIN\SDKs\misc;$workingDirectory\DEV\DEVMAIN\SDKs\Ssce5532_02\dll;$workingDirectory\DEV\DEVMAIN\SDKs\Fingerprint SDK 2009\Bin;$workingDirectory\DEV\DEVMAIN\SDKs\LTWIN90X\REDIST;$workingDirectory\DEV\DEVMAIN\SDKs\CxImage90\bin;$workingDirectory\DEV\DEVMAIN\SDKs\Xtreme ToolkitPro v16.3.1\Bin\vc140;$workingDirectory\DEV\DEVMAIN\SDKs\OpenSSL\bin;$workingDirectory\DEV\DEVMAIN\SDKs\ObjG601_6080\Bin\vc140;$workingDirectory\DEV\DEVMAIN\Nexus\MF\libs\Oracle-11.2.0.3.20_x86\instantclient_11_2;$workingDirectory\DEV\DEVMAIN\SDKs\ocilib-4.5.1-windows\lib32;"

    Write-Warning "Using environment path= $env:Path"
	$pathtoCustomTestAdapters = "C:\TestAdapters"
    Invoke-VSTest -TestAssemblies $testAssemblyFiles -VSTestVersion $vsTestVersion -TestFiltercriteria $testFiltercriteria -RunSettingsFile $runSettingsFile -PathtoCustomTestAdapters $pathtoCustomTestAdapters -CodeCoverageEnabled $codeCoverage -OverrideTestrunParameters $overrideTestrunParameters -OtherConsoleOptions $otherConsoleOptions -WorkingFolder $workingDirectory -TestResultsFolder $testResultsDirectory

    $resultFiles = Find-Files -SearchPattern "*.trx" -RootFolder $testResultsDirectory 

    if($resultFiles) 
    {
        Publish-TestResults -Context $distributedTaskContext -TestResultsFiles $resultFiles -TestRunner "VSTest" -Platform $platform -Configuration $configuration
    }
    else
    {
        Write-Warning "No results found to publish."
    }
}
else
{
    Write-Warning "No test assemblies found matching the pattern: $testAssembly"
}
Write-Verbose "Leaving script VSTestConsole.ps1"