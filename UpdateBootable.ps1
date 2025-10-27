# Author: Macer

#
# update Windows Preinstallation Environment (WinPE)
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

# Variable (Do not change)
$WINOS_IMAGES = ""

# Set environment variable
$userPath = $env:username
$MEDIA_NEW_PATH = "C:\Users\$userPath\Desktop\Win11_24H2_Customize\24H2BootableMedia"
$WORKING_PATH = "C:\Users\$userPath\Desktop\Win11_24H2_Customize\WORKING_Disk"

# Set MOUNT PATH
$WINPE_MOUNT = "C:\WinPerp2\mountPE"

# Get the list of images contained within WinPE
try
{
    $WINPE_IMAGES = Get-WindowsImage -ImagePath $MEDIA_NEW_PATH"\sources\boot.wim"
}
Catch { }
try
{
    Remove-Item -Force -Path $WINPE_MOUNT -confirm:$false -recurse
}
Catch { }
try
{
    Remove-Item -Force -Path $WORKING_PATH -confirm:$false -recurse
}
Catch { }
try
{
    New-Item -Force -Path $WINPE_MOUNT -ItemType Directory
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

Foreach ($IMAGE in $WINPE_IMAGES)
{

    # update WinPE
    Write-Host "$(Get-TS): Mounting WinPE, image index $($IMAGE.ImageIndex)!" -ForegroundColor Green
    try
    {
        Mount-WindowsImage -ImagePath $MEDIA_NEW_PATH"\sources\boot.wim" -Index $IMAGE.ImageIndex -Path $WINPE_MOUNT -ErrorAction stop | Out-Null
    }
    Catch { }

    if (Test-Path $LCU_PATH) {
    # Add latest Cumulative Update for Windows for x64-based Systems
    Write-Host "$(Get-TS): Add latest Cumulative Update [$LCU_PATH] to WinPE, image index $($IMAGE.ImageIndex)!" -ForegroundColor Green
    try
    {
        Add-WindowsPackage -Path $WINPE_MOUNT -PackagePath $LCU_PATH -ErrorAction stop | Out-Null
    }
    Catch { }
    }

    if (Test-Path $SAFE_OS_DU_PATH) {
    # Add latest Safe OS Dynamic Update for Windows for x64-based Systems
    Write-Host "$(Get-TS): Add latest Safe OS Dynamic Update [$SAFE_OS_DU_PATH] to WinPE, image index $($IMAGE.ImageIndex)!" -ForegroundColor Green
    try
    {
        Add-WindowsPackage -Path $WINPE_MOUNT -PackagePath $SAFE_OS_DU_PATH | Out-Null
    }
    Catch { }
    }

    if (Test-Path $LCU_PATH) {
    # Perform image cleanup.
    Write-Host "$(Get-TS): Performing image cleanup on WinPE, image index $($IMAGE.ImageIndex)!" -ForegroundColor Green
    try
    {
        DISM /image:$WINPE_MOUNT /cleanup-image /StartComponentCleanup /ResetBase /Defer | Out-Null
        if ($LastExitCode -ne 0)
        {
            throw "Error: Failed to perform image cleanup on WinPE, image index $($IMAGE.ImageIndex). Exit code: $LastExitCode"
        }

        if ($IMAGE.ImageIndex -eq "2")
        {
            # Save setup.exe for later use. This will address possible binary mismatch with the version in the main OS \sources folder
            Copy-Item -Path $WINPE_MOUNT"\sources\setup.exe" -Destination $WORKING_PATH"\setup.exe" -Force -ErrorAction stop | Out-Null

            # Save setuphost.exe for later use. This will address possible binary mismatch with the version in the main OS \sources folder
            # This is only required starting with Windows 11 version 24H2
            $TEMP = Get-WindowsImage -ImagePath $MEDIA_NEW_PATH"\sources\boot.wim" -Index $IMAGE.ImageIndex
            if ([System.Version]$TEMP.Version -ge [System.Version]"10.0.26100")
            {
                Copy-Item -Path $WINPE_MOUNT"\sources\setuphost.exe" -Destination $WORKING_PATH"\setuphost.exe" -Force -ErrorAction stop | Out-Null
            }
            else
            {
                Write-Output "$(Get-TS): Skipping copy of setuphost.exe; image version $($TEMP.Version)"
            }

            # Save serviced boot manager files later copy to the root media.
            Copy-Item -Path $WINPE_MOUNT"\Windows\boot\efi\bootmgfw.efi" -Destination $WORKING_PATH"\bootmgfw.efi" -Force -ErrorAction stop | Out-Null
            Copy-Item -Path $WINPE_MOUNT"\Windows\boot\efi\bootmgr.efi" -Destination $WORKING_PATH"\bootmgr.efi" -Force -ErrorAction stop | Out-Null
        }
    }
    Catch { }
    }

    # Dismount
    Write-Host "$(Get-TS): Dismount [$WINPE_MOUNT]!" -ForegroundColor Green
    try
    {
        Dismount-WindowsImage -Path $WINPE_MOUNT -Save -ErrorAction stop | Out-Null
    }
    Catch { }

    # Export
    Write-Host "$(Get-TS): Export [$WORKING_PATH\boot2.wim]!" -ForegroundColor Green
    Export-WindowsImage -SourceImagePath $MEDIA_NEW_PATH"\sources\boot.wim" -SourceIndex $IMAGE.ImageIndex -DestinationImagePath $WORKING_PATH"\boot2.wim" -ErrorAction stop | Out-Null
}

try
{
    Move-Item -Path $WORKING_PATH"\boot2.wim" -Destination $MEDIA_NEW_PATH"\sources\boot.wim" -Force -ErrorAction stop | Out-Null
}
Catch { }