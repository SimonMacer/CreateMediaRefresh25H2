# Author: Macer

#
# Tweak Windows Preinstallation Environment (WinPE)
#

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

# Variable (Do not change)
$WINOS_IMAGES = ""

# Set environment variable
$userPath = $env:username
$MEDIA_NEW_PATH = "C:\Users\$userPath\Desktop\Win11_24H2_Customize\24H2BootableMedia"
$WORKING_PATH = "C:\Users\$userPath\Desktop\Win11_24H2_Customize\WORKING_Temp"
$autounattend = "C:\Users\$userPath\Desktop\Win11_24H2_Customize\autounattend"
$OEMFolder = "C:\Users\$userPath\Desktop\Win11_24H2_Customize\sources"

# Set MOUNT PATH
$WINPE_MOUNT = "C:\WinPerp2\mountPE"

$SystemPresetCount = Get-ChildItem -Recurse -File "C:\Users\$userPath\Desktop\Win11_24H2_Customize\TweakBoot\*.reg" | Measure-Object
Write-Host "HKLM (System) Offline Preset Registry Count: " $SystemPresetCount.count -ForegroundColor Green
Start-Sleep -Seconds 6

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

Foreach ($IMAGE in $WINPE_IMAGES)
{

    # Mounting WinPE
    Write-Host "$(Get-TS): Mounting WinPE, image index $($IMAGE.ImageIndex)!" -ForegroundColor Green
    try
    {
        Mount-WindowsImage -ImagePath $MEDIA_NEW_PATH"\sources\boot.wim" -Index $IMAGE.ImageIndex -Path $WINPE_MOUNT -ErrorAction stop | Out-Null
    }
    Catch { }

    # Deploy
    if ( $SystemPresetCount.count -gt 0 ) {
    Write-Host "$(Get-TS): Deploy [C:\WinPerp2\mountPE\Windows\System32\Config\System]!" -ForegroundColor Green
    $command = 'reg load HKLM\OFFLINE C:\WinPerp2\mountPE\Windows\System32\Config\System'
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c $command" -NoNewWindow -Wait
    Start-Sleep -Seconds 2
    $regFilesPath = "C:\Users\$userPath\Desktop\Win11_24H2_Customize\TweakBoot"
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

    if ($IMAGE.ImageIndex -eq "2") {
    if (Test-Path $WINPE_MOUNT"\autounattend.xml") {
            try
            {
                Remove-Item -Force -Path $WINPE_MOUNT"\autounattend.xml" -confirm:$false -recurse
            }
            Catch { }
        }
        try
        {
            Copy-Item -Path $autounattend"\autounattend.xml" -Destination $WINPE_MOUNT"\autounattend.xml" -Force -ErrorAction stop | Out-Null
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

    Write-Dbg-Host "Copying [$OEMFolder] --> [$MEDIA_NEW_PATH\sources]"

    try {
        Copy-FilesWithProgress -SourcePath $OEMFolder -DestinationPath $MEDIA_NEW_PATH"\sources"
    } catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }

try
{
    Move-Item -Path $WORKING_PATH"\boot2.wim" -Destination $MEDIA_NEW_PATH"\sources\boot.wim" -Force -ErrorAction stop | Out-Null
}
Catch { }

if (Test-Path $WORKING_PATH) {
    try
    {
        Remove-Item -Force -Path $WORKING_PATH -confirm:$false -recurse
    }
    Catch { }
}