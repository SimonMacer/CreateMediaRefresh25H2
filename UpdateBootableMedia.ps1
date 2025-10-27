# Author: Macer

#
# update remaining files on media
#

param (

    [Parameter(Position=0,mandatory=$false)]
    [string] $LCUNumber,

    [Parameter(Position = 1,mandatory=$false)]
    [string] $SAFEOSDUNumber,

    [Parameter(Position = 2, Mandatory=$false)]
    [string] $SETUPDUNumber,

    [Parameter(Position = 3, Mandatory=$false)]
    [string] $DoNetCUNumber,

    [Parameter(Position = 4, Mandatory=$false)]
    [string] $EKBNumber,

    [Parameter(Position = 5, Mandatory=$false)]
    [string] $OSNumber
)

function Get-TS { return "{0:HH:mm:ss}" -f [DateTime]::Now }

# Set environment variable
$userPath = $env:username
$MEDIA_NEW_PATH = "C:\Users\$userPath\Desktop\Win11_24H2_Customize\24H2BootableMedia"
$WORKING_PATH = "C:\Users\$userPath\Desktop\Win11_24H2_Customize\WORKING_Disk"
$KBFolder = "C:\Users\$userPath\Desktop\Win11_24H2_Customize\KB"
if (Test-Path $KBFolder) {
Write-Host "[LCU] KB$LCUNumber Cumulative Update for Windows 11 Version 24H2 and 25H2" -ForegroundColor Green
$LCUFinder = Get-ChildItem -Path $KBFolder -Recurse -Filter "*windows11.0-kb$LCUNumber-x64*"
$LCUFinderCount = $LCUFinder | Measure-Object
if ($LCUFinderCount.Count -gt 0) {
switch ($LCUFinder.Extension)
{
".msu" { 
$LCU_PATH = $LCUFinder.FullName 
Write-Host "[LCU] Path: "$LCU_PATH -ForegroundColor Green
}
default { Write-Host "[LCU] The MSU update package file was not found." -ForegroundColor Red}
}
} else { Write-Host "[LCU] The MSU update package file was not found." -ForegroundColor Red }

$CHECKPOINTNumber = "5043080"
Write-Host "[Checkpoint] KB$CHECKPOINTNumber Checkpoint Cumulative Update for Windows 11 Version 24H2 and 25H2" -ForegroundColor Green
$CHECKPOINTFinder = Get-ChildItem -Path $KBFolder -Recurse -Filter "*windows11.0-kb$CHECKPOINTNumber-x64*"
$CHECKPOINTFinderCount = $CHECKPOINTFinder | Measure-Object
if ($CHECKPOINTFinderCount.Count -gt 0) {
switch ($CHECKPOINTFinder.Extension)
{
".msu" {
 $CHECKPOINT_Ge = $CHECKPOINTFinder.FullName
 Write-Host "[Checkpoint] Path: "$CHECKPOINT_Ge -ForegroundColor Green
 }
default { Write-Host "[Checkpoint] The MSU update package file was not found." -ForegroundColor Red }
}
} else { Write-Host "[Checkpoint] The MSU update package file was not found." -ForegroundColor Red }

Write-Host "[Enablement] Feature Update for Windows 11 25H2 via Enablement Package (KB$EKBNumber)" -ForegroundColor Green
$EKBFinder = Get-ChildItem -Path $KBFolder -Recurse -Filter "*windows11.0-kb$EKBNumber-x64*"
$EKBFinderCount = $EKBFinder | Measure-Object
if ($EKBFinderCount.Count -gt 0) {
switch ($EKBFinder.Extension)
{
".msu" { 
$eKB_PATH = $EKBFinder.FullName 
Write-Host "[Enablement] Path: "$eKB_PATH -ForegroundColor Green
}
".cab" {
$eKB_PATH = $EKBFinder.FullName 
Write-Host "[Enablement] Path: "$eKB_PATH -ForegroundColor Green
}
default { Write-Host "[Enablement] The MSU or CAB update package file was not found." -ForegroundColor Red}
}
} else { Write-Host "[Enablement] The MSU or CAB update package file was not found." -ForegroundColor Red }

Write-Host "[SafeOS DU] KB$SAFEOSDUNumber Safe OS Dynamic Update for Windows 11 Version 24H2 and 25H2" -ForegroundColor Green
$SafeOSFinder = Get-ChildItem -Path $KBFolder -Recurse -Filter "*windows11.0-kb$SAFEOSDUNumber-x64*"
$SafeOSFinderCount = $SafeOSFinder | Measure-Object
if ($SafeOSFinderCount.Count -gt 0) {
switch ($SafeOSFinder.Extension)
{
".msu" { 
$SAFE_OS_DU_PATH = $SafeOSFinder.FullName 
Write-Host "[SafeOS DU] Path: "$SafeOSFinder.FullName -ForegroundColor Green
}
".cab" {
$SAFE_OS_DU_PATH = $SafeOSFinder.FullName 
Write-Host "[SafeOS DU] Path: "$SAFE_OS_DU_PATH -ForegroundColor Green
}
default { Write-Host "[SafeOS DU] The MSU or CAB update package file was not found." -ForegroundColor Red}
}
} else { Write-Host "[SafeOS DU] The MSU or CAB update package file was not found." -ForegroundColor Red }

Write-Host "[Setup DU] KB$SETUPDUNumber Setup Dynamic Update for Windows 11 Version 24H2 and 25H2" -ForegroundColor Green
$SetupDUFinder = Get-ChildItem -Path $KBFolder -Recurse -Filter "*windows11.0-kb$SETUPDUNumber-x64*"
$SetupDUFinderCount = $SetupDUFinder | Measure-Object
if ($SetupDUFinderCount.Count -gt 0) {
switch ($SetupDUFinder.Extension)
{
".cab" {
$SETUP_DU_PATH = $SetupDUFinder.FullName 
Write-Host "[Setup DU] Path: "$SETUP_DU_PATH -ForegroundColor Green
}
default { Write-Host "[Setup DU] The CAB update package file was not found." -ForegroundColor Red}
}
} else { Write-Host "[Setup DU] The CAB update package file was not found." -ForegroundColor Red }

Write-Host "[NetFx] KB$DoNetCUNumber Cumulative Update for .NET Framework 3.5 and 4.8.1 for Windows 11 Version 24H2 and 25H2" -ForegroundColor Green
$NetFxFinder = Get-ChildItem -Path $KBFolder -Recurse -Filter "*windows11.0-kb$DoNetCUNumber-x64*"
$NetFxFinderCount = $NetFxFinder | Measure-Object
if ($NetFxFinderCount.Count -gt 0) {
switch ($NetFxFinder.Extension)
{
".msu" { 
$DoNet_PATH = $NetFxFinder.FullName 
Write-Host "[NetFx] Path: "$DoNet_PATH -ForegroundColor Green
}
default { Write-Host "[NetFx] The MSU update package file was not found." -ForegroundColor Red}
}
} else { Write-Host "[NetFx] The MSU update package file was not found." -ForegroundColor Red }
} else {
Write-Host "[LCU] The MSU update package file was not found." -ForegroundColor Red
Write-Host "[Checkpoint] The MSU update package file was not found." -ForegroundColor Red
Write-Host "[Enablement] The MSU update package file was not found." -ForegroundColor Red
Write-Host "[SafeOS DU] The MSU or CAB update package file was not found." -ForegroundColor Red
Write-Host "[Setup DU] The CAB update package file was not found." -ForegroundColor Red
Write-Host "[NetFx] The MSU update package file was not found." -ForegroundColor Red
}
Write-Host "OS Build Number: $OSNumber" -ForegroundColor Green

# Add latest Setup Dynamic Update for Windows for x64-based Systems by copy the files from the package into the newMedia
Write-Output "$(Get-TS): Add latest Dynamic Update for Windows for x64-based Systems: [$SETUP_DU_PATH]"
cmd.exe /c $env:SystemRoot\System32\expand.exe $SETUP_DU_PATH -F:* $MEDIA_NEW_PATH"\sources" | Out-Null
if ($LastExitCode -ne 0)
{
    throw "Error: Failed to expand $SETUP_DU_PATH. Exit code: $LastExitCode"
}

# Copy setup.exe from boot.wim, saved earlier.
Write-Output "$(Get-TS): Copying $WORKING_PATH\setup.exe to $MEDIA_NEW_PATH\sources\setup.exe"
try
{
    Copy-Item -Path $WORKING_PATH"\setup.exe" -Destination $MEDIA_NEW_PATH"\sources\setup.exe" -Force -ErrorAction stop | Out-Null
}
Catch { }

# Copy setuphost.exe from boot.wim, saved earlier.
if (Test-Path -Path $WORKING_PATH"\setuphost.exe")
{
    Write-Output "$(Get-TS): Copying $WORKING_PATH\setuphost.exe to $MEDIA_NEW_PATH\sources\setuphost.exe"
    try
    {
        Copy-Item -Path $WORKING_PATH"\setuphost.exe" -Destination $MEDIA_NEW_PATH"\sources\setuphost.exe" -Force -ErrorAction stop | Out-Null
    }
    Catch { }
}

# Copy bootmgr files from boot.wim, saved earlier.
try
{
    $MEDIA_NEW_FILES = Get-ChildItem $MEDIA_NEW_PATH -Force -Recurse -Filter b*.efi
}
Catch { }

Foreach ($File in $MEDIA_NEW_FILES)
{
    if (($File.Name -ieq "bootmgfw.efi") -or ($File.Name -ieq "bootx64.efi") -or ($File.Name -ieq "bootia32.efi") -or ($File.Name -ieq "bootaa64.efi"))
    {
        Write-Output "$(Get-TS): Copying $WORKING_PATH\bootmgfw.efi to $($File.FullName)"
        try
        {
            Copy-Item -Path $WORKING_PATH"\bootmgfw.efi" -Destination $File.FullName -Force -ErrorAction stop | Out-Null
        }
        Catch { }
    }
    elseif ($File.Name -ieq "bootmgr.efi")
    {
        Write-Output "$(Get-TS): Copying $WORKING_PATH\bootmgr.efi to $($File.FullName)"
        try
        {
            Copy-Item -Path $WORKING_PATH"\bootmgr.efi" -Destination $File.FullName -Force -ErrorAction stop | Out-Null
        }
        Catch { }
    }
}