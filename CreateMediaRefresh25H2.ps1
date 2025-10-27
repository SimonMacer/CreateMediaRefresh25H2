# Author: Macer
# Version 2025.10.28
# Based on Microsoft PowerShell
# https://learn.microsoft.com/en-us/windows/deployment/update/media-dynamic-update

#
# Update each main OS Windows image including the Windows Recovery Environment (WinRE)
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
    [string] $OSNumber,

    [Parameter(Position = 6, Mandatory=$false)]
    [string] $FocusDefaultIndex
)

function Get-TS { return "{0:HH:mm:ss}" -f [DateTime]::Now }

function Debug-Pause {

    if ($global:Dbg_Pause) {
        Write-Host "Press any key to continue"
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    return
}

# Routine to help with script debugging
function Write-Dbg-Host {
    if ($global:Dbg_Ouput) {
        Write-Host "$(Get-TS): [DBG] $args" -ForegroundColor DarkMagenta
    }
}

function Copy-FilesWithProgress {
    param (
        [string] $SourcePath,
        [string] $DestinationPath
    )

    $files = Get-ChildItem -Path $SourcePath -Recurse
    $totalFiles = $files.Count
    $currentFile = 0

    foreach ($file in $files) {
        $currentFile++
        $percentComplete = [math]::Round(($currentFile / $totalFiles) * 100, 2)
        $destinationFile = $file.FullName -replace [regex]::Escape($SourcePath), $DestinationPath

        $destinationDir = [System.IO.Path]::GetDirectoryName($destinationFile)
        if (-not (Test-Path -Path $destinationDir)) {
            New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
        }

        # if the file is larger than 5MB, use the Copy-LargeFileWithProgres function
        if ($file.Length -gt 5MB) {
            Copy-LargeFileWithProgres -SourcePath $file.FullName -DestinationPath $destinationFile
            continue
        } else{
            Copy-Item -Path $file.FullName -Destination $destinationFile -Force
        }
        Write-Progress -Activity "Copying files" -Status "copying [$file]" -PercentComplete $percentComplete
    }
    Write-Progress -Activity "Copying files" -Completed
}

function Copy-LargeFileWithProgres {
    param (
        [string] $SourcePath,
        [string] $DestinationPath
    )

    # Define source and destination files
    $sourceFile = $SourcePath
    $destinationFile = $DestinationPath
    $fileName = [System.IO.Path]::GetFileName($sourceFile)

    # Get the total size of the source file
    $totalSize = (Get-Item $sourceFile).Length

    # Open file streams
    $sourceStream = [System.IO.File]::OpenRead($sourceFile)
    $destinationStream = [System.IO.File]::Create($destinationFile)

    # Define buffer size (e.g., 1 MB)
    $bufferSize = 10MB
    $buffer = New-Object byte[] $bufferSize
    $totalRead = 0

    # Copy in chunks
    try {
        while (($bytesRead = $sourceStream.Read($buffer, 0, $bufferSize)) -gt 0) {
            # Write to destination
            $destinationStream.Write($buffer, 0, $bytesRead)

            # Update total read
            $totalRead += $bytesRead

            # Calculate progress
            $percentComplete = [math]::Round(($totalRead / $totalSize) * 100, 2)

            # Display progress
            Write-Progress -Activity "Copying files" -Status "copying [$fileName] $percentComplete% complete" -PercentComplete $percentComplete
        }
        Write-Progress -Activity "Copying file" -Completed
    }
    finally {
        # Close streams
        $sourceStream.Close()
        $destinationStream.Close()
    }
}

# Set OS Build Number
$WINVER_OS = $OSNumber

# Variable (Do not change)
$WIN_NAME = ""
$WINOS_IMAGES = ""
$WimIndex = ""

# Set MOUNT PATH
$MAIN_OS_MOUNT = "C:\WinPerp2\mount"
$WINRE_MOUNT = "C:\WinPerp2\mountRE"

# Set environment variable
$userPath = $env:username
$MEDIA_NEW_PATH = "C:\Users\$userPath\Desktop\Win11_24H2_Customize\GAC-WIM"
$WORKING_PATH = "C:\Users\$userPath\Desktop\Win11_24H2_Customize\WORKING_WIM"
$EdgeInstalled = "$MAIN_OS_MOUNT\Program Files (x86)\Microsoft"
$EdgeUpgradePath = "C:\Users\$userPath\Desktop\Win11_24H2_Customize\MSEDGE"
$AppListFile = "C:\Users\$userPath\Desktop\Win11_24H2_Customize\CustomAppsList\CustomAppsList.txt"
$DelApps = $null
$AppContains = $null
$RemovedContains = $null

try
{
    $WINOS_IMAGES = Get-WindowsImage -ImagePath $MEDIA_NEW_PATH"\install.wim"
}
Catch { }
try
{
    Remove-Item -Force -Path $MAIN_OS_MOUNT -confirm:$false -recurse
}
Catch { }
try
{
    Remove-Item -Force -Path $WINRE_MOUNT -confirm:$false -recurse
}
Catch { }
try
{
    Remove-Item -Force -Path $WORKING_PATH -confirm:$false -recurse
}
Catch { }
try
{
    New-Item -Force -Path $MAIN_OS_MOUNT -ItemType Directory
}
Catch { }
try
{
    New-Item -Force -Path $WINRE_MOUNT -ItemType Directory
}
Catch { }
try
{
    New-Item -Force -Path $WORKING_PATH -ItemType Directory
}
Catch { }
CLS
Write-Host "$(Get-TS): Starting media refresh" -ForegroundColor Green
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
$UserPresetCount = Get-ChildItem -Recurse -File "C:\Users\$userPath\Desktop\Win11_24H2_Customize\User\*.reg" | Measure-Object
Write-Host "HKCU Offline Preset Registry Count: " $UserPresetCount.count -ForegroundColor Green
$SystemPresetCount = Get-ChildItem -Recurse -File "C:\Users\$userPath\Desktop\Win11_24H2_Customize\System\*.reg" | Measure-Object
Write-Host "HKLM (System) Offline Preset Registry Count: " $SystemPresetCount.count -ForegroundColor Green
$SystemMainPresetCount = Get-ChildItem -Recurse -File "C:\Users\$userPath\Desktop\Win11_24H2_Customize\SystemMain\*.reg" | Measure-Object
Write-Host "HKLM (SystemMain) Offline Preset Registry Count: " $SystemMainPresetCount.count -ForegroundColor Green
$SoftwarePresetCount = Get-ChildItem -Recurse -File "C:\Users\$userPath\Desktop\Win11_24H2_Customize\Tweak\*.reg" | Measure-Object
Write-Host "HKLM (Software) Offline Preset Registry Count: " $SoftwarePresetCount.count -ForegroundColor Green

$DriversCount = Get-ChildItem -Recurse -File "C:\Users\$userPath\Desktop\Win11_24H2_Customize\Drivers\*.inf" | Measure-Object
Write-Host "Add Drivers Count: " $DriversCount.count -ForegroundColor Green

$EnablePrivateMode = $false
if ( $FocusDefaultIndex -eq "y") {
$EnablePrivateMode = $false
} else {
Write-Host "$(Get-TS): Check the source install.wim index!" -ForegroundColor Green
$ImageStageMedia = "$MEDIA_NEW_PATH\install.wim"
try {
$HomeLabel = Get-WindowsImage -ImagePath $ImageStageMedia -Index 1 | where {$_.EditionId -eq "Core"}
} catch { }
try {
$ProLabel = Get-WindowsImage -ImagePath $ImageStageMedia -Index 2 | where {$_.EditionId -eq "Professional"}
} catch { }
try {
$EduLabel = Get-WindowsImage -ImagePath $ImageStageMedia -Index 3 | where {$_.EditionId -eq "Education"}
} catch { }
try {
$ProEduLabel = Get-WindowsImage -ImagePath $ImageStageMedia -Index 4 | where {$_.EditionId -eq "ProfessionalEducation"}
} catch { }
try {
$ProWorkLabel = Get-WindowsImage -ImagePath $ImageStageMedia -Index 5 | where {$_.EditionId -eq "ProfessionalWorkstation"}
} catch { }
try {
$EntLTSCLabel = Get-WindowsImage -ImagePath $ImageStageMedia -Index 6 | where {$_.EditionId -eq "EnterpriseS"}
} catch { }
if ( ($HomeLabel.Count -eq 1) -and ($ProLabel.Count -eq 1) -and ($EduLabel.Count -eq 1) -and ($ProEduLabel.Count -eq 1) -and ($ProWorkLabel.Count -eq 1) -and ($EntLTSCLabel.Count -eq 1) ) {
Write-Host "[install.wim] Index 1 > Core (Matched)" -ForegroundColor Green
Write-Host "[install.wim] Index 2 > Professional (Matched)" -ForegroundColor Green
Write-Host "[install.wim] Index 3 > Education (Matched)" -ForegroundColor Green
Write-Host "[install.wim] Index 4 > ProfessionalEducation (Matched)" -ForegroundColor Green
Write-Host "[install.wim] Index 5 > ProfessionalWorkstation (Matched)" -ForegroundColor Green
Write-Host "[install.wim] Index 6 > EnterpriseS (Matched)" -ForegroundColor Green
$EnablePrivateMode = $true
} else {
if ($HomeLabel.Count -eq 1) {
Write-Host "[install.wim] Index 1 > Core (Matched)" -ForegroundColor Green
} else {
Write-Host "[install.wim] Index 1 > Core (Does not match)" -ForegroundColor Red
}
if ($ProLabel.Count -eq 1) {
Write-Host "[install.wim] Index 2 > Professional (Matched)" -ForegroundColor Green
} else {
Write-Host "[install.wim] Index 2 > Professional (Does not match)" -ForegroundColor Red
}
if ($EduLabel.Count -eq 1) {
Write-Host "[install.wim] Index 3 > Education (Matched)" -ForegroundColor Green
} else {
Write-Host "[install.wim] Index 3 > Education (Does not match)" -ForegroundColor Red
}
if ($ProEduLabel.Count -eq 1) {
Write-Host "[install.wim] Index 4 > ProfessionalEducation (Matched)" -ForegroundColor Green
} else {
Write-Host "[install.wim] Index 4 > ProfessionalEducation (Does not match)" -ForegroundColor Red
}
if ($ProWorkLabel.Count -eq 1) {
Write-Host "[install.wim] Index 5 > ProfessionalWorkstation (Matched)" -ForegroundColor Green
} else {
Write-Host "[install.wim] Index 5 > ProfessionalWorkstation (Does not match)" -ForegroundColor Red
}
if ($EntLTSCLabel.Count -eq 1) {
Write-Host "[install.wim] Index 6 > EnterpriseS (Matched)" -ForegroundColor Green
} else {
Write-Host "[install.wim] Index 6 > EnterpriseS (Does not match)" -ForegroundColor Red
}
$EnablePrivateMode = $false
}
}
Write-Host "$(Get-TS): [Specify install.wim] Use the specified install.wim image > $EnablePrivateMode" -ForegroundColor Green

    try {
$MSEDGEUpgradeCount = Get-ChildItem -Recurse -File $EdgeUpgradePath"\Microsoft" | Measure-Object
} catch { }

$AskWUEdge = $false
if ($MSEDGEUpgradeCount.Count -gt 0) {
$AskWUEdge = Read-Host "Would you like to update the Microsoft Edge within this OS image? (Y = Yes, Update;N = No, Keep default;No input = Keep default)" -WarningAction Inquire
if ($AskWUEdge -eq 'y') {
$AskWUEdge = $true
} else {
$AskWUEdge = $false
}
} else {
$AskWUEdge = $false
}
Write-Host "$(Get-TS): [Microsoft Edge] Update the Microsoft Edge within this OS image > $AskWUEdge" -ForegroundColor Green

$AskAppCutom = $false
if (Test-Path $AppListFile) {
$AskAppCutom = Read-Host "Would you like to customize which Microsoft Store Apps are removed within this OS image? (Y = Yes;N = No;No input = No)" -WarningAction Inquire
if ($AskAppCutom -eq 'y') {
$AskAppCutom = $true
} else {
$AskAppCutom = $false
}
} else {
$AskAppCutom = $false
}
Write-Host "$(Get-TS): [Microsoft Store Apps] Customize which Microsoft Store Apps are removed within this OS image > $AskAppCutom" -ForegroundColor Green

$TestModeEnabled = $false
$AskTESTMode = Read-Host "Would you like to enable test mode to create the Index 1 image? (Y = Yes, Enable Test Mode;N = No, Normal Mode;No input = Normal Mode)" -WarningAction Inquire
if ($AskTESTMode -eq 'y') {
$TestModeEnabled = $true
}
Write-Host "$(Get-TS): [Test Mode] Test Mode > $TestModeEnabled" -ForegroundColor Green

Foreach ($IMAGE in $WINOS_IMAGES)
{

    # first mount the main OS image
    Write-Host "$(Get-TS): Mounting [$MEDIA_NEW_PATH\install.wim] image!" -ForegroundColor Green
    try
    {
        Mount-WindowsImage -ImagePath $MEDIA_NEW_PATH"\install.wim" -Index $IMAGE.ImageIndex -Path $MAIN_OS_MOUNT -ErrorAction stop| Out-Null
    }
    Catch { }

    if ($IMAGE.ImageIndex -eq "1")
    {

        #
        # update Windows Recovery Environment (WinRE) within this OS image
        #
        Write-Host "$(Get-TS): Copying winre.wim image to [$WORKING_PATH\winre.wim]!" -ForegroundColor Green
        try
        {
            Copy-Item -Path $MAIN_OS_MOUNT"\windows\system32\recovery\winre.wim" -Destination $WORKING_PATH"\winre.wim" -Force -ErrorAction stop | Out-Null
        }
        Catch { }
        Write-Host "$(Get-TS): Mounting winre.wim image!" -ForegroundColor Green
        try
        {
            Mount-WindowsImage -ImagePath $WORKING_PATH"\winre.wim" -Index 1 -Path $WINRE_MOUNT -ErrorAction stop | Out-Null
        }
        Catch { }

        try {
        if (Test-Path $LCU_PATH) {
        # update Windows Recovery Environment (WinRE) within this OS image
        Write-Host "$(Get-TS): update Windows Recovery Environment (WinRE) within this OS image!" -ForegroundColor Green
        try
        {
            Add-WindowsPackage -Path $WINRE_MOUNT -PackagePath $LCU_PATH | Out-Null
        }
        Catch { }
        }
        } catch { }

        try {
        if (Test-Path $SAFE_OS_DU_PATH) {
        # Add latest Safe OS Dynamic Update for Windows (Ge) Version 25H2 for x64-based Systems
        Write-Host "$(Get-TS): Add latest Safe OS Dynamic Update for Windows (Ge) Version 25H2 for x64-based Systems!" -ForegroundColor Green
        try
        {
            Add-WindowsPackage -Path $WINRE_MOUNT -PackagePath $SAFE_OS_DU_PATH -ErrorAction stop | Out-Null
        }
        Catch { }
        }
        } catch { }

        try {
        if (Test-Path $LCU_PATH) {
        # Perform image cleanup
        Write-Host "$(Get-TS): Perform image cleanup!" -ForegroundColor Green
        try
        {
            DISM /image:$WINRE_MOUNT /cleanup-image /StartComponentCleanup /ResetBase /Defer | Out-Null
        }
        Catch { }
        }
        } catch { }

        # Dismount
        Write-Host "$(Get-TS): Dismount [$WINRE_MOUNT]!" -ForegroundColor Green
        try
        {
            Dismount-WindowsImage -Path $WINRE_MOUNT  -Save -ErrorAction stop | Out-Null
        }
        Catch { }

        # Export
        Write-Host "$(Get-TS): Export [$WORKING_PATH\winre2.wim]!" -ForegroundColor Green
        try
        {
            Export-WindowsImage -SourceImagePath $WORKING_PATH"\winre.wim" -SourceIndex 1 -DestinationImagePath $WORKING_PATH"\winre2.wim" -ErrorAction stop | Out-Null
        }
        Catch { }

    }

    if ($EnablePrivateMode) {
    if ($IMAGE.ImageIndex -eq "6")
    {

        #
        # update Windows Recovery Environment (WinRE) within this OS image
        #
        try
        {
            Remove-Item -Force -Path $WORKING_PATH"\winre.wim" -confirm:$false -recurse
        }
        Catch { }
        try
        {
            Remove-Item -Force -Path $WORKING_PATH"\winre2.wim" -confirm:$false -recurse
        }
        Catch { }
        Write-Host "$(Get-TS): Copying winre.wim image to [$WORKING_PATH\winre.wim]!" -ForegroundColor Green
        try
        {
            Copy-Item -Path $MAIN_OS_MOUNT"\windows\system32\recovery\winre.wim" -Destination $WORKING_PATH"\winre.wim" -Force -ErrorAction stop | Out-Null
        }
        Catch { }
        Write-Host "$(Get-TS): Mounting winre.wim image!" -ForegroundColor Green
        try
        {
            Mount-WindowsImage -ImagePath $WORKING_PATH"\winre.wim" -Index 1 -Path $WINRE_MOUNT -ErrorAction stop | Out-Null
        }
        Catch { }

        try {
        if (Test-Path $LCU_PATH) {
        # update Windows Recovery Environment (WinRE) within this OS image
        Write-Host "$(Get-TS): update Windows Recovery Environment (WinRE) within this OS image!" -ForegroundColor Green
        try
        {
            Add-WindowsPackage -Path $WINRE_MOUNT -PackagePath $LCU_PATH | Out-Null
        }
        Catch { }
        }
        } catch { }

        try {
        if (Test-Path $SAFE_OS_DU_PATH) {
        # Add latest Safe OS Dynamic Update for Windows (Ge) Version 25H2 for x64-based Systems
        Write-Host "$(Get-TS): Add latest Safe OS Dynamic Update for Windows (Ge) Version 25H2 for x64-based Systems!" -ForegroundColor Green
        try
        {
            Add-WindowsPackage -Path $WINRE_MOUNT -PackagePath $SAFE_OS_DU_PATH -ErrorAction stop | Out-Null
        }
        Catch { }
        }
        } catch { }

        try {
        if (Test-Path $LCU_PATH) {
        # Perform image cleanup
        Write-Host "$(Get-TS): Perform image cleanup!" -ForegroundColor Green
        try
        {
            DISM /image:$WINRE_MOUNT /cleanup-image /StartComponentCleanup /ResetBase /Defer | Out-Null
        }
        Catch { }
        }
        } catch { }

        # Dismount
        Write-Host "$(Get-TS): Dismount [$WINRE_MOUNT]!" -ForegroundColor Green
        try
        {
            Dismount-WindowsImage -Path $WINRE_MOUNT  -Save -ErrorAction stop | Out-Null
        }
        Catch { }

        # Export
        Write-Host "$(Get-TS): Export [$WORKING_PATH\winre2.wim]!" -ForegroundColor Green
        try
        {
            Export-WindowsImage -SourceImagePath $WORKING_PATH"\winre.wim" -SourceIndex 1 -DestinationImagePath $WORKING_PATH"\winre2.wim" -ErrorAction stop | Out-Null
        }
        Catch { }

    }
    }

    #
    # Customize which Microsoft Store Apps are removed
    #

    if ($AskAppCutom) {
$DelApps = $null
$AppContains = $null
$RemovedContains = $null
try {
if (Test-Path $AppListFile) {
try {
$AppContains = Get-AppProvisionedPackage -Path $MAIN_OS_MOUNT | Select -ExpandProperty "PackageName" -ErrorAction SilentlyContinue
} catch { }
try {
$RemovedContains = Get-Content -Path $AppListFile -Filter "#"
} catch { }

if (($RemovedContains -ne $null) -and ($AppContains -ne $null)) {
Foreach ($AppBox in $AppContains)
{
Foreach ($AppBoxOutput in $RemovedContains)
{
$AppBoxFilter = "*$AppBoxOutput*"
if (($AppBox -like $AppBoxFilter) -and ($AppBox -notlike "*Microsoft.SecHealthUI*") -and ($AppBox -notlike "*Microsoft.DesktopAppInstaller*")) {
[array]$DelApps += $AppBox
}
}
}
}
if ($DelApps -ne $null) {
Write-Host "Remove App Package List {" -ForegroundColor Red
$DelApps
Write-Host "}" -ForegroundColor Red
Foreach ($DelAppsName in $DelApps)
{
$AppNameKilled = $DelAppsName
Write-Host "$(Get-TS): Starting to remove [$AppNameKilled] app package!" -ForegroundColor Green
$ErrorStop = $false
try {
Remove-AppProvisionedPackage -Path $MAIN_OS_MOUNT -PackageName $AppNameKilled -ErrorAction Stop
} catch { $ErrorStop = $true }
if ($ErrorStop) {
Write-Host "$(Get-TS): Failed to remove [$AppNameKilled] app package!" -ForegroundColor Red
} else { Write-Host "$(Get-TS): Successfully removed the [$AppNameKilled] app package!" -ForegroundColor Green }
}
}
}
} catch { }
}

    #
    # update Main OS
    #

    try {
    if (Test-Path $eKB_PATH) {
    # Add Feature Update for Windows 11 25H2 via Enablement Package
    Write-Host "$(Get-TS): Add Feature Update for Windows 11 25H2 via Enablement Package (KB$EKBNumber)!" -ForegroundColor Green
    try
    {
        Add-WindowsPackage -Path $MAIN_OS_MOUNT -PackagePath $eKB_PATH -ErrorAction stop | Out-Null
    }
    Catch { }
    }
    } catch { }

    try {
    if (Test-Path $LCU_PATH) {
    # Add latest Cumulative Update for Windows 11, version 25H2 for x64-based Systems
    Write-Host "$(Get-TS): Add latest Cumulative Update for Windows 11, version 25H2 for x64-based Systems!" -ForegroundColor Green
    try
    {
        Add-WindowsPackage -Path $MAIN_OS_MOUNT -PackagePath $LCU_PATH -ErrorAction stop | Out-Null
    }
    Catch { }
    }
    } catch { }

    try {
    if (Test-Path $LCU_PATH) {
    # Perform image cleanup.
    Write-Host "$(Get-TS): Perform image cleanup. Some Optional Components might require the image to be booted, and thus image cleanup may fail. We'll catch and handle as a warning." -ForegroundColor Green
    try
    {
        DISM /image:$MAIN_OS_MOUNT /cleanup-image /StartComponentCleanup | Out-Null
        if ($LastExitCode -ne 0)
        {
            if ($LastExitCode -eq -2146498554)
            {
                # We hit 0x800F0806 CBS_E_PENDING. We will ignore this with a warning
                # This is likely due to legacy components being added that require online operations.
                Write-Warning "$(Get-TS): Failed to perform image cleanup on main OS, index $($IMAGE.ImageIndex). Exit code: $LastExitCode. The operation cannot be performed until pending servicing operations are completed. The image must be booted to complete the pending servicing operation."
            }
            else
            {
                throw "Error: Failed to perform image cleanup on main OS, index $($IMAGE.ImageIndex). Exit code: $LastExitCode"
            }
        }
    }
    Catch { }
    }
    } catch { }

    try {
    if (Test-Path $DoNet_PATH) {
    # Add latest Cumulative Update for .NET Framework 3.5 and 4.8.1 for Windows 11, version 25H2 for x64
    Write-Host "$(Get-TS): Add latest Cumulative Update for .NET Framework 3.5 and 4.8.1 for Windows 11, version 25H2 for x64!" -ForegroundColor Green
    try
    {
        Add-WindowsPackage -Path $MAIN_OS_MOUNT -PackagePath $DoNet_PATH -ErrorAction stop | Out-Null
    }
    Catch { }
    }
    } catch { }

    try {
    if (Test-Path $SAFE_OS_DU_PATH) {
    # Add latest Safe OS Dynamic Update for Windows (Ge) Version 25H2 for x64-based Systems
    Write-Host "$(Get-TS): Add latest Safe OS Dynamic Update for Windows (Ge) Version 25H2 for x64-based Systems!" -ForegroundColor Green
    try
    {
        Add-WindowsPackage -Path $MAIN_OS_MOUNT -PackagePath $SAFE_OS_DU_PATH -ErrorAction stop | Out-Null
    }
    Catch { }
    }
    } catch { }

    try
    {
        Remove-Item -Force -Path $MAIN_OS_MOUNT"\windows\system32\recovery\winre.wim" -confirm:$false -recurse
    }
    Catch { }
    try
    {
        Copy-Item -Path $WORKING_PATH"\winre2.wim" -Destination $MAIN_OS_MOUNT"\windows\system32\recovery\winre.wim" -Force -ErrorAction stop | Out-Null
    }
    Catch { }

    # Update Microsoft Edge
    if ($AskWUEdge) {
    try {
if ((Test-Path $EdgeUpgradePath"\Microsoft") -and ($MSEDGEUpgradeCount.Count -gt 0)) {
$MSEDGEInstalledCount = Get-ChildItem -Recurse -File $EdgeInstalled"\Edge" | Measure-Object
if ( $MSEDGEInstalledCount.Count -gt 0 ) {

    Write-Host "$(Get-TS): Update the Microsoft Edge within this OS image!" -ForegroundColor Green

    if (Test-Path $EdgeInstalled"\Edge") {
        try
        {
            Remove-Item -Force -Path $EdgeInstalled"\Edge" -confirm:$false -recurse
        }
        Catch { }
    }

    if (Test-Path $EdgeInstalled"\EdgeCore") {
        try
        {
            Remove-Item -Force -Path $EdgeInstalled"\EdgeCore" -confirm:$false -recurse
        }
        Catch { }
    }

    if (Test-Path $EdgeInstalled"\EdgeWebView") {
        try
        {
            Remove-Item -Force -Path $EdgeInstalled"\EdgeWebView" -confirm:$false -recurse
        }
        Catch { }
    }

    if (Test-Path $EdgeInstalled"\EdgeUpdate") {
        try
        {
            Remove-Item -Force -Path $EdgeInstalled"\EdgeUpdate" -confirm:$false -recurse
        }
        Catch { }
    }

    Write-Dbg-Host "Copying [$EdgeUpgradePath\Microsoft] --> [$EdgeInstalled]"

    try 
    {
        Copy-FilesWithProgress -SourcePath $EdgeUpgradePath"\Microsoft" -DestinationPath $EdgeInstalled
    }
    Catch
    {
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }

    $MSEDGECount = Get-ChildItem -Recurse -File "$EdgeUpgradePath\PreMsEdge\*.reg" | Measure-Object

    if ( $MSEDGECount.count -gt 0 ) {
        Write-Host "$(Get-TS): Deploy [C:\WinPerp2\mount\Windows\System32\Config\Software]!" -ForegroundColor Green
        $command = 'reg load HKLM\OFFLINE C:\WinPerp2\mount\Windows\System32\Config\Software'
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c $command" -NoNewWindow -Wait
        Start-Sleep -Seconds 2
        $regFilesPath = "$EdgeUpgradePath\PreMsEdge"
        $regFiles = Get-ChildItem -Path $regFilesPath -Filter "*.reg"
        foreach ($file in $regFiles) {
            Write-Host "$(Get-TS): Importing registry file: $($file.FullName)" -ForegroundColor Green
            Start-Process -FilePath "C:\Users\$userPath\Desktop\Win11_24H2_Customize\PowerRun.exe" -ArgumentList "regedit.exe /s ", "`"$($file.FullName)`"" -Wait -NoNewWindow
            Write-Host "$(Get-TS): Finished importing $($file.Name)"
        }
        Start-Sleep -Seconds 2
        Write-Host "$(Get-TS): Unload HKLM\OFFLINE" -ForegroundColor Green
        $command = 'reg unload HKLM\OFFLINE'
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c $command" -NoNewWindow -Wait
        Start-Sleep -Seconds 1
    }
    }
    }
    } catch { }
    }

    # Deploy
    Write-Host "$(Get-TS): Deploy personal preference settings and local policy settings management!" -ForegroundColor Green
    if ( $UserPresetCount.count -gt 0 ) {
    Write-Host "$(Get-TS): Deploy [C:\WinPerp2\mount\Users\Default\NTUSER.DAT]!" -ForegroundColor Green
    $command = 'reg load HKLM\OFFLINE C:\WinPerp2\mount\Users\Default\NTUSER.DAT'
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c $command" -NoNewWindow -Wait
    Start-Sleep -Seconds 2
    $regFilesPath = "C:\Users\$userPath\Desktop\Win11_24H2_Customize\User"
    $regFiles = Get-ChildItem -Path $regFilesPath -Filter "*.reg"
    foreach ($file in $regFiles) {
        Write-Host "$(Get-TS): Importing registry file: $($file.FullName)" -ForegroundColor Green
        Start-Process -FilePath "C:\Users\$userPath\Desktop\Win11_24H2_Customize\PowerRun.exe" -ArgumentList "regedit.exe /s ", "`"$($file.FullName)`"" -Wait -NoNewWindow
        Write-Host "$(Get-TS): Finished importing $($file.Name)"
    }
    Start-Sleep -Seconds 2
    Write-Host "$(Get-TS): Unload HKLM\OFFLINE" -ForegroundColor Green
    $command = 'reg unload HKLM\OFFLINE'
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c $command" -NoNewWindow -Wait
    Start-Sleep -Seconds 1
    }

    if ( ( $SystemPresetCount.count -gt 0 ) -or ( $SystemMainPresetCount.count -gt 0 ) ) {
    Write-Host "$(Get-TS): Deploy [C:\WinPerp2\mount\Windows\System32\Config\System]!" -ForegroundColor Green
    $command = 'reg load HKLM\OFFLINE C:\WinPerp2\mount\Windows\System32\Config\System'
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c $command" -NoNewWindow -Wait
    Start-Sleep -Seconds 2
    
    if ( $SystemPresetCount.count -gt 0 ) {
    $regFilesPath = "C:\Users\$userPath\Desktop\Win11_24H2_Customize\System"
    $regFiles = Get-ChildItem -Path $regFilesPath -Filter "*.reg"
    foreach ($file in $regFiles) {
        Write-Host "$(Get-TS): Importing registry file: $($file.FullName)" -ForegroundColor Green
        Start-Process -FilePath "C:\Users\$userPath\Desktop\Win11_24H2_Customize\PowerRun.exe" -ArgumentList "regedit.exe /s ", "`"$($file.FullName)`"" -Wait -NoNewWindow
        Write-Host "$(Get-TS): Finished importing $($file.Name)"
    }
    }

    if ( $SystemMainPresetCount.count -gt 0 ) {
    $regFilesPath = "C:\Users\$userPath\Desktop\Win11_24H2_Customize\SystemMain"
    $regFiles = Get-ChildItem -Path $regFilesPath -Filter "*.reg"
    foreach ($file in $regFiles) {
        Write-Host "$(Get-TS): Importing registry file: $($file.FullName)" -ForegroundColor Green
        Start-Process -FilePath "C:\Users\$userPath\Desktop\Win11_24H2_Customize\PowerRun.exe" -ArgumentList "regedit.exe /s ", "`"$($file.FullName)`"" -Wait -NoNewWindow
        Write-Host "$(Get-TS): Finished importing $($file.Name)"
    }
    }

    Start-Sleep -Seconds 2
    Write-Host "$(Get-TS): Unload HKLM\OFFLINE" -ForegroundColor Green
    $command = 'reg unload HKLM\OFFLINE'
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c $command" -NoNewWindow -Wait
    Start-Sleep -Seconds 1
    }

    if ( $SoftwarePresetCount.count -gt 0 ) {
    Write-Host "$(Get-TS): Deploy [C:\WinPerp2\mount\Windows\System32\Config\Software]!" -ForegroundColor Green
    $command = 'reg load HKLM\OFFLINE C:\WinPerp2\mount\Windows\System32\Config\Software'
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c $command" -NoNewWindow -Wait
    Start-Sleep -Seconds 2
    $regFilesPath = "C:\Users\$userPath\Desktop\Win11_24H2_Customize\Tweak"
    $regFiles = Get-ChildItem -Path $regFilesPath -Filter "*.reg"
    foreach ($file in $regFiles) {
        Write-Host "$(Get-TS): Importing registry file: $($file.FullName)" -ForegroundColor Green
        Start-Process -FilePath "C:\Users\$userPath\Desktop\Win11_24H2_Customize\PowerRun.exe" -ArgumentList "regedit.exe /s ", "`"$($file.FullName)`"" -Wait -NoNewWindow
        Write-Host "$(Get-TS): Finished importing $($file.Name)"
    }
    Start-Sleep -Seconds 2
    Write-Host "$(Get-TS): Unload HKLM\OFFLINE" -ForegroundColor Green
    $command = 'reg unload HKLM\OFFLINE'
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c $command" -NoNewWindow -Wait
    Start-Sleep -Seconds 1
    }

    # Add Drivers
    if ( $DriversCount.count -gt 0 ) {
    Write-Host "$(Get-TS): Add driver: C:\Users\%username%\Desktop\Win11_24H2_Customize\Drivers" -ForegroundColor Green
    $command = 'dism /Image:C:\WinPerp2\mount /Add-Driver /Driver:"C:\Users\%username%\Desktop\Win11_24H2_Customize\Drivers" /Recurse'
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c $command" -NoNewWindow -Wait
    }

    # Dismount
    Write-Host "$(Get-TS): Dismount [$MAIN_OS_MOUNT]!" -ForegroundColor Green
    try
    {
        Dismount-WindowsImage -Path $MAIN_OS_MOUNT -Save -ErrorAction stop | Out-Null
    }
    Catch { }

    # Export

    if ($EnablePrivateMode) {
    if ($IMAGE.ImageIndex -eq "1")
    {
       $WimIndex = '1'
       $WIN_NAME = "Windows 11 Home Edition, version 25H2 ($WINVER_OS)"
    }
    if ($IMAGE.ImageIndex -eq "2")
    {
       $WimIndex = '2'
       $WIN_NAME = "Windows 11 Pro Edition, version 25H2 ($WINVER_OS)"
    }
    if ($IMAGE.ImageIndex -eq "3")
    {
       $WimIndex = '3'
       $WIN_NAME = "Windows 11 Education, version 25H2 ($WINVER_OS)"
    }
    if ($IMAGE.ImageIndex -eq "4")
    {
       $WimIndex = '4'
       $WIN_NAME = "Windows 11 Pro Education, version 25H2 ($WINVER_OS)"
    }
    if ($IMAGE.ImageIndex -eq "5")
    {
       $WimIndex = '5'
       $WIN_NAME = "Windows 11 Pro for Workstations, version 25H2 ($WINVER_OS)"
    }
    if ($IMAGE.ImageIndex -eq "6")
    {
       $WimIndex = '6'
       $WIN_NAME = "Windows 11 Enterprise LTSC 2024, version 25H2 ($WINVER_OS)"
    }
    if ($TestModeEnabled) {
    Write-Host "$(Get-TS): Export [$WORKING_PATH\install.wim] - $WIN_NAME!" -ForegroundColor Green
    DISM /export-image /SourceImageFile:$MEDIA_NEW_PATH"\install.wim" /SourceIndex:$WimIndex /DestinationImageFile:$WORKING_PATH"\install.wim" /DestinationName:"$WIN_NAME" /Compress:fast
    } else {
    Write-Host "$(Get-TS): Export [$WORKING_PATH\install.esd] - $WIN_NAME!" -ForegroundColor Green
    DISM /export-image /SourceImageFile:$MEDIA_NEW_PATH"\install.wim" /SourceIndex:$WimIndex /DestinationImageFile:$WORKING_PATH"\install.esd" /DestinationName:"$WIN_NAME" /Compress:recovery
    }
    } else {
    $WimIndex = $IMAGE.ImageIndex
    if ($TestModeEnabled) {
    Write-Host "$(Get-TS): Export [$WORKING_PATH\install.wim] - Index ($WimIndex)!" -ForegroundColor Green
    DISM /export-image /SourceImageFile:$MEDIA_NEW_PATH"\install.wim" /SourceIndex:$WimIndex /DestinationImageFile:$WORKING_PATH"\install.wim" /Compress:fast
    } else {
    Write-Host "$(Get-TS): Export [$WORKING_PATH\install.esd] - Index ($WimIndex)!" -ForegroundColor Green
    DISM /export-image /SourceImageFile:$MEDIA_NEW_PATH"\install.wim" /SourceIndex:$WimIndex /DestinationImageFile:$WORKING_PATH"\install.esd" /Compress:recovery
    }
    }
    if ($TestModeEnabled) {
    DISM /Get-WimInfo /WimFile:$WORKING_PATH"\install.wim" /index:$WimIndex
    } else {
    DISM /Get-WimInfo /WimFile:$WORKING_PATH"\install.esd" /index:$WimIndex
    }

    if ($TestModeEnabled) {
    break
    }
}