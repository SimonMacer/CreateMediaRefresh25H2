# https://support.microsoft.com/en-us/topic/updating-windows-bootable-media-to-use-the-pca2023-signed-boot-manager-d4064779-0e4e-43ac-b2ce-24f434fcfa0f

param (

    [Parameter(Position=0,mandatory=$true)]
	[string] $MediaPath,

	[ValidateSet("ISO", "USB", "LOCAL", IgnoreCase=$true)]
	[Parameter(Position = 1, Mandatory=$false)]
	[string] $TargetType,

	[Parameter(Position = 2,mandatory=$false)]
	[string] $ISOPath,

	[Parameter(Position = 3,mandatory=$false)]
    [string] $USBDrive,

    [Parameter(Position = 4,mandatory=$false)]
    [string] $FileSystem,

    [Parameter(Position = 5, Mandatory=$false)]
    [string] $NewMediaPath,

    [Parameter(Position = 6, Mandatory=$false)]
    [string] $StagingDir
)

function Get-TS { return "{0:HH:mm:ss}" -f [DateTime]::Now }

function Show-Usage {
    $scriptName = $global:ScriptName
    Write-Host "Usage:`r`n$scriptName -MediaPath <path> -TargetType <type> -ISOPath <path> -USBDrive <drive:> -FileSystem <type> -NewMediaPath <path> -StagingDir <path>" -ForegroundColor Blue
    Write-Host "  -MediaPath <path> The path to the media folder or ISO file to be used as baseline."
    Write-Host "  -TargetType <type> The type of media to be created (ISO, USB, or LOCAL)."
    Write-Host "        ISO: Convert media specified in -MediaPath to 2023 bootable ISO file. Targets -ISOPath."
    Write-Host "        USB: Convert media specified in -MediaPath to 2023 bootable image and writes it to -USBDrive."
    Write-Host "        LOCAL: Convert media specified in -MediaPath to 2023 bootable image copied to -NewMediaPath."
    Write-Host "  -ISOPath <path> The path to the new ISO file to be created from -MediaPath."
    Write-Host "  -USBDrive <drive:> The drive letter to a target USB drive (example E:)."
    Write-Host "  -FileSystem <type> Optional. The file system to format the USB drive with (FAT32 or ExFAT). Default is FAT32."
    Write-Host "  -NewMediaPath <path> Required for LOCAL TargetType. -MediaPath content is duplicated here and then updated."
    Write-Host "  -StagingDir (optional) <path> Overrides default temp staging path used by this script. System %TEMP% used by default with random subfolder."
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "$scriptName -MediaPath C:\Media\Win10Media -TargetType ISO -ISOPath C:\Media\Win10_Updated.iso"
    Write-Host "$scriptName -MediaPath C:\Media\Win11.iso -TargetType ISO -ISOPath C:\Media\Win11_Updated.iso"
    Write-Host "$scriptName -MediaPath \\server\share\Win11_Media -TargetType ISO -ISOPath C:\Media\Win11_Updated.iso"
    Write-Host "$scriptName -MediaPath \\server\share\Win11.iso -TargetType ISO -ISOPath C:\Media\Win11_Updated.iso"
    Write-Host "$scriptName -MediaPath C:\Media\Win1124H2 -TargetType USB -USBDrive H:"
    Write-Host "$scriptName -MediaPath C:\Media\Win11.iso -TargetType USB -USBDrive E:"
    Write-Host "$scriptName -MediaPath C:\Media\Win1124H2 -TargetType LOCAL -NewMediaPath C:\Media\Win1124H2_Updated"
    Write-Host "$scriptName -MediaPath H:\Media\Win11.iso -TargetType LOCAL -NewMediaPath R:\Win11_Updated"
    Write-Host "$scriptName -MediaPath C:\Media\Win1124H2 -TargetType ISO -ISOPath C:\Media\Win1124H2_Updated.iso -StagingDir C:\Temp\Win1124H2"
    Write-Host "`r`nIMPORTANT! You must provide this script with a media source (-MediaPath) which has the latest 2024-4B (or later) updates included!`r`n" -ForegroundColor Red
}

function Show-ADK-Req {
    Write-Host "This script requires the Windows ADK be installed on the system. Avalable at http://aka.ms/adk" -ForegroundColor Red
    Write-Host "After install, open an admin-elevated 'Deploy and Imaging Tools Environment' command prompt provided with the ADK." -ForegroundColor Red
    Write-Host "Then run PowerShell from this command prompt and you should be good to go.`r`n" -ForegroundColor Red
}

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

function Execute-Cleanup {

    # Pause here to allow the user to see the mounted WIM
    Debug-Pause

    Write-Dbg-Host "Cleaning up"

    if ($global:WIM_Mount_Path) {
        Write-Dbg-Host "`r`nDismounting $global:WIM_Mount_Path"
        try {
            Dismount-WindowsImage -Path $global:WIM_Mount_Path -Discard -ErrorAction stop | Out-Null
        } catch {
            Write-Host "Failed to dismount WIM [$global:WIM_Mount_Path]" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    }

    if ($global:ISO_Mount_Path) {
        Write-Dbg-Host "Dismounting $global:ISO_Mount_Path"

        try {
            Dismount-DiskImage -ImagePath $global:ISO_Mount_Path -ErrorAction stop | Out-Null
        } catch {
            Write-Host "Failed to dismount ISO [$global:ISO_Mount_Path]" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }

    }

    if ($global:StagingDir_Created -eq $true) {
        Write-Dbg-Host "Removing staging directory final: $global:Staging_Directory_Path"
        try {
            Remove-Item -Path $global:Staging_Directory_Path -Recurse -Force -ErrorAction stop | Out-Null
        } catch {
            Write-Host "Failed to remove $global:Staging_Directory_Path" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    }
}

function Validate-Requirements {

    Write-Host "Checking for required support tools" -ForegroundColor Blue
    # Check if the script is running with administrative privileges
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "You do not have Administrator rights to run this script.`nPlease re-run this script as an Administrator." -ForegroundColor Red
        exit
    }
    # Look for the oscdimg.exe tool in the commonly used install path for the ADK.
    $adkOsCdImgPath = "\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
    $progFilesPath = Get-ChildItem "Env:ProgramFiles(x86)"
    if ($progFilesPath -ne $null) {
        $executablePath = Join-Path -Path $progFilesPath.Value -ChildPath $adkOsCdImgPath
        if (Test-Path -Path $executablePath) {
            Write-Dbg-Host "Found oscdimg.exe in: $executablePath"
            $global:oscdimg_exe = $executablePath
            return $true
        }
        Write-Dbg-Host "oscdimg.exe not found in $executablePath"
    }
    # Final attempt to find oscdimg.exe in the system PATH
    $executablePath = (where.exe oscdimg.exe 2>$null)
    if ($null -eq $executablePath) {
        # See if oscdimg.exe exists in the current working directory
        $executablePath = Join-Path -Path $PWD.Path -ChildPath "oscdimg.exe"
        if (-not (Test-Path -Path $executablePath)) {
            Write-Host "`r`nRequired support tools not found!" -ForegroundColor Red
            Write-Dbg-Host "oscdimg.exe not found in $PWD or in the system PATH!"
            Show-ADK-Req
            return $false
        }
    }

    Write-Dbg-Host "oscdimg.exe found in: $executablePath"
    $global:oscdimg_exe = $executablePath
    return $true
}

function Initialize-MediaPaths {
    param (
         [string] $MediaPath,
         [string] $NewMediaPath
     )

    $isUNCPath = $false
    $localMediaPath = $MediaPath
    $mountResult = $null

    Write-Host "Staging media" -ForegroundColor Blue
    $global:Src_Media_Path = $MediaPath
    # See if MediaPath is a UNC path
    if ($MediaPath -match "^\\\\") {
        Write-Dbg-Host "[$MediaPath] is a UNC path"
        $isUNCPath = $true
    }

    # Now determine if this is an ISO
    if ($MediaPath -match "\.iso$") {

        Write-Dbg-Host "$MediaPath is an ISO file"
        if ($isUNCPath) {

            $localIsoPath = $global:Staging_Directory_Path + "\$((Get-Item -Path $global:Src_Media_Path).Name)"
            Write-Host "Copying [$global:Src_Media_Path] to staging directory"
            Write-Dbg-Host "Copying [$global:Src_Media_Path] --> [$localIsoPath]"
            try {
                Copy-LargeFileWithProgres -SourcePath $global:Src_Media_Path -Destination $localIsoPath -Force -ErrorAction stop | Out-Null
            } catch {
                Write-Host $_.Exception.Message -ForegroundColor Red
                return $false
            }
        } else{
            # Get full path for the ISO
            $global:Src_Media_Path = (Get-Item -Path $MediaPath).FullName
            if ($global:Src_Media_Path -eq $null) {
                Write-Host "Failed to get full path for [$MediaPath]" -ForegroundColor Red
                return $false
            }
            $localIsoPath = $global:Src_Media_Path
        }

        Write-Host "--->Mounting ISO from staged media"
        Write-Dbg-Host "Mounting ISO: $localIsoPath"
        $mountResult = Mount-DiskImage -ImagePath $localIsoPath -PassThru -ErrorAction stop
        if ($mountResult -eq $null) {
            Write-Host "Failed to mount $localIsoPath" -ForegroundColor Red
            return $false
        }

        $global:ISO_Mount_Path = $localIsoPath
        $localMediaPath = ($mountResult | Get-Volume).DriveLetter + ":"

        # Retrieve the volume label from the mounted ISO to be used later if a new ISO is created
        $global:ISO_Lable = (Get-Volume -DriveLetter ($mountResult | Get-Volume).DriveLetter).FileSystemLabel

    } else {

        Write-Dbg-Host "[$MediaPath] is a folder"
        $tmpPath = $MediaPath
        if ($MediaPath[-1] -eq "\") {
            $tmpPath = $MediaPath.Substring(0, $MediaPath.Length - 1)
            Write-Dbg-Host "tmpPath: $tmpPath"
        }

        $global:Src_Media_Path = $tmpPath
        $localMediaPath = $tmpPath
    }

    $bootWimPath = $localMediaPath + "\sources\boot.wim"
    Write-Dbg-Host "Making sure [$bootWimPath] exists"
    if (-not (Test-Path -Path $bootWimPath)) {
        Write-Host "[$localMediaPath\] does not appear to point to valid Windows media!" -ForegroundColor Red
        return $false
    }

    # Get the current working directory and add "WimMount" to it
    $global:WIM_Mount_Path = $global:Staging_Directory_Path + "\WimMount"

    # If the WIM MOUNT directory does not exist, create it
    if (-not (Test-Path -Path $global:WIM_Mount_Path)) {
        New-Item -ItemType Directory -Path $global:WIM_Mount_Path -Force | Out-Null
        Write-Dbg-Host "Creating $global:WIM_Mount_Path"
    }else{
        Write-Dbg-Host "$global:WIM_Mount_Path already exists"
    }

    # Create a new folder to stage the updated media content
    if ($NewMediaPath){
        Write-Dbg-Host "[$NewMediaPath] provided"
        $tmpPath = $NewMediaPath

        if ($NewMediaPath -match "^[a-zA-Z]:$") {
            $tmpPath = "$NewMediaPath\"
        } else {
            if ($NewMediaPath[-1] -eq "\") {
                $tmpPath = $NewMediaPath.Substring(0, $tmpPath.Length - 1)
            }
        }
        Write-Dbg-Host "tmpPath: $tmpPath"
        $global:Temp_Media_To_Update_Path = $tmpPath
    } else{
        $global:Temp_Media_To_Update_Path = $global:Staging_Directory_Path + "\MediaToUpdate"
    }

    if (-not (Test-Path -Path $global:Temp_Media_To_Update_Path)) {
        try {
            New-Item -ItemType Directory -Path $global:Temp_Media_To_Update_Path  -Force | Out-Null
            Write-Dbg-Host "[$global:Temp_Media_To_Update_Path] created"
        } catch {
            Write-Host $_.Exception.Message -ForegroundColor Red
            return $false
        }
    }

    Write-Dbg-Host "Copying [$localMediaPath] --> [$global:Temp_Media_To_Update_Path]"
    try {
        Copy-FilesWithProgress -SourcePath $localMediaPath -DestinationPath $global:Temp_Media_To_Update_Path
    } catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }

    if ($mountResult -ne $null) {
        Write-Dbg-Host "Unmounting [$global:ISO_Mount_Path]"
        try {
            Dismount-DiskImage -ImagePath $global:ISO_Mount_Path -ErrorAction stop | Out-Null
        } catch {
            Write-Host "Failed to dismount ISO [$global:ISO_Mount_Path]" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            return $false
        }
    }

    Write-Dbg-Host "Media [$global:Temp_Media_To_Update_Path] ready for update!"

    return $true
}

function Initialize-StagingDirectory {
     param (
         [string] $StagingDir
     )

    # If $StagingDir does not exist, set it to the system %TEMP%\%randomdir% directory
    Write-Host "Initializing staging directory" -ForegroundColor Blue

    if (-not $StagingDir) {
        $global:Staging_Directory_Path = [System.IO.Path]::GetTempPath() + ([System.IO.Path]::GetRandomFileName()).Replace(".", "")
        Write-Dbg-Host "Using default staging directory: $global:Staging_Directory_Path"
        New-Item -ItemType Directory -Path $global:Staging_Directory_Path -Force | Out-Null
        $global:StagingDir_Created = $true
    } else {
        Write-Dbg-Host "Using provided staging directory: $StagingDir"

        $global:Staging_Directory_Path = $StagingDir
        if ($StagingDir[-1] -eq "\") {
            $global:Staging_Directory_Path = $StagingDir.Substring(0, $StagingDir.Length - 1)
        }

        # If the provided staging directory is the root of a drive, and in the format of "D:" or "D:\", append a random subfolder to it
        if ($global:Staging_Directory_Path -match "^[a-zA-Z]:$") {
            $global:Staging_Directory_Path = "$global:Staging_Directory_Path\" + ([System.IO.Path]::GetRandomFileName()).Replace(".", "")
            Write-Dbg-Host "Appending random subfolder to staging directory: $global:Staging_Directory_Path"
            New-Item -ItemType Directory -Path $global:Staging_Directory_Path -Force | Out-Null
            $global:StagingDir_Created = $true
        } elseif (-not (Test-Path -Path $global:Staging_Directory_Path)) {
            # Provided staging directory does not exist, ask the user if they want to create it
            Write-Host "Staging directory [$global:Staging_Directory_Path] does not exist. Do you want to create it? (Y/N)" -ForegroundColor Yellow
            $response = Read-Host
            if ($response -ne "Y") {
                Write-Host "Aborting execution`r`n" -ForegroundColor Red
                return $false
            } else {
                New-Item -ItemType Directory -Path $global:Staging_Directory_Path -Force | Out-Null
                $global:StagingDir_Created = $true
                Write-Dbg-Host "[$global:Staging_Directory_Path] created"
            }
        }
    }
    $drive = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -eq $global:Staging_Directory_Path.Substring(0, 3) }
    Write-Dbg-Host "Drive [$drive] free disk space: $($drive.Free / 1GB)GB"
    if ($drive.Free -lt 10GB) {
        Write-Host "Drive [$drive] used for temp file staging does not not have enough free disk space! (10GB required)" -ForegroundColor Red
        return $false
    }

    return $true
}
function Validate-Parameters {
    param (
        [string] $TargetType,
        [string] $ISOPath,
        [string] $USBDrive,
        [string] $NewMediaPath,
        [string] $FileSystem,
        [string] $StagingDir
     )


    if ($StagingDir){
        $driveLetter = $StagingDir.SubString(0,1)
        $fs = (Get-Volume -DriveLetter $driveLetter).FileSystem

        if ($fs -ne "NTFS" -and $fs -ne "ReFS") {
            Write-Host "`r`n-StagingDir [$StagingDir] must target an NTFS or ReFS based file system`r`n" -ForegroundColor Red
            return $false
        }
    }

    if (-not $TargetType) {
        Write-Host "`r`n-TargetType parameter required`r`n" -ForegroundColor Red
        return $false
    }

    switch ($TargetType) {
        "ISO" {

            if ($NewMediaPath){
                Write-Host "`r`n-NewMediaPath parameter invalid for TargetType ISO.`r`n" -ForegroundColor Red
                return $false
            }

            if ($USBDrive) {
                Write-Host "`r`n-USBDrive parameter invalid for TargetType ISO.`r`n" -ForegroundColor Red
                return $false
            }

            if ($FileSystem) {
                Write-Host "`r`n-FileSystem parameter invalid for TargetType ISO.`r`n" -ForegroundColor Red
                return $false
            }

            if (-not $ISOPath) {
                Write-Host "`r`n-ISOPath parameter required for TargetType ISO.`r`n" -ForegroundColor Red
                return $false
            }

            if (-not ($ISOPath -match "\.iso$")) {
                Write-Host "`r`n-ISOPath must specify a *.ISO file.`r`n" -ForegroundColor Red
                Write-Dbg-Host "Invalid ISOPath: $ISOPath"
                return $false
            }
            # if $ISOPath exists, ask the user if they want to overwrite it, otherwise abort
            if (Test-Path -Path $ISOPath) {
                Write-Host "ISO [$ISOPath] already exists. Do you want to overwrite it? (Y/N)" -ForegroundColor Yellow
                $response = Read-Host
                if ($response -ne "Y") {
                    Write-Host "Aborting execution`r`n" -ForegroundColor Red
                    exit
                } else {
                    Write-Dbg-Host "Deleting [$ISOPath]"
                    Remove-Item -Path $ISOPath -Force
                }
            }

            Write-Dbg-Host "ISOPath: $ISOPath"
        }
        "USB" {

            if ($NewMediaPath){
                Write-Host "`r`n-NewMediaPath parameter invalid for TargetType USB.`r`n" -ForegroundColor Red
                return $false
            }

            if ($ISOPath) {
                Write-Host "`r`n-ISOPath parameter invalid for TargetType USB.`r`n" -ForegroundColor Red
                return $false
            }

            if ($FileSystem -and
                ($FileSystem -ne "FAT32" -and $FileSystem -ne "ExFAT")) {
                Write-Host "`r`n-FileSystem must be FAT32 or ExFAT to boot on most UEFI systems." -ForegroundColor Red
                Write-Host "`r`nNOTE: FAT32 does not support files larger than 4GB and may cause media creation failures on newer OS media.`r`n" -ForegroundColor Red
                return $false
            }

            if (-not $USBDrive) {
                Write-Host "`r`n-USBDrive parameter required for TargetType USB.`r`n" -ForegroundColor Red
                return $false
            }

            if (-not ($USBDrive -match "^[a-zA-Z]:$")) {
                Write-Host "`r`n-USBDrive must specify a valid drive letter. ($USBDrive invalid!)`r`n" -ForegroundColor Red
                return $false
            } else {
                Write-Host "`r`nWARNING: Contents on drive [$USBDrive] will be erased! Continue? (Y/N) " -ForegroundColor Yellow
                $response = Read-Host
                if ($response -ne "Y") {
                    Write-Host "Aborting execution`r`n" -ForegroundColor Red
                    exit
                }
            }
        }
        "LOCAL" {

            if ($USBDrive) {
                Write-Host "`r`n-USBDrive parameter invalid for TargetType LOCAL.`r`n" -ForegroundColor Red
                return $false
            }

            if ($ISOPath) {
                Write-Host "`r`n-ISOPath parameter invalid for TargetType LOCAL.`r`n" -ForegroundColor Red
                return $false
            }

            if ($FileSystem) {
                Write-Host "`r`n-FileSystem parameter invalid for TargetType LOCAL.`r`n" -ForegroundColor Red
                return $false
            }

            if (-not $NewMediaPath) {
                Write-Host "`r`n-NewMediaPath parameter required for TargetType LOCAL.`r`n" -ForegroundColor Red
                return $false
            }

            $tmpPath = $NewMediaPath
            if ($NewMediaPath -match "^[a-zA-Z]:$" -or $NewMediaPath -match "^[a-zA-Z]:\\$") {
                $isRoot = $true
                $tmpPath = "$($NewMediaPath.Substring(0, 2))\"
            }

            $driveLetter = $tmpPath.SubString(0,1)
            $fs = (Get-Volume -DriveLetter $driveLetter).FileSystem

            if ($fs -ne "NTFS" -and $fs -ne "ReFS") {
                Write-Host "`r`n-NewMediaPath [$tmpPath] must target an NTFS or ReFS based file system`r`n" -ForegroundColor Red
                return $false
            }

            $drive = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -eq $tmpPath.Substring(0, 3) }
            if ($drive.Free -lt 10GB) {
                Write-Host "$NewMediaPath does not have enough free space! (10GB required)" -ForegroundColor Red
                return $false
            }

            if ($isRoot){
                return $true
            }

            if (-not (Test-Path -Path $NewMediaPath)) {
                Write-Host "NewMediaPath [$NewMediaPath] does not exist! Create it? (Y/N)" -ForegroundColor Yellow
                $response = Read-Host
                if ($response -ne "Y") {
                    Write-Host "Aborting execution`r`n" -ForegroundColor Red
                    exit
                } else {
                    New-Item -ItemType Directory -Path $NewMediaPath -Force | Out-Null
                }
            } else {
                Write-Host "NewMediaPath [$NewMediaPath] already exists. Do you want to overwrite it? (Y/N)" -ForegroundColor Yellow
                $response = Read-Host
                if ($response -ne "Y") {
                    Write-Host "Aborting execution`r`n" -ForegroundColor Red
                    exit
                } else {
                    Write-Dbg-Host "Deleting [$NewMediaPath]"
                    Remove-Item -Path $NewMediaPath -Recurse -Force
                }
            }
        }
        default {
            Write-Host "Invalid TargetType: $TargetType" -ForegroundColor Red
            return $false
        }
    }

    return $true
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

function Copy-2023BootBins {

    $bootWimPath = $global:Temp_Media_To_Update_Path + "\sources\boot.wim"
    # Make sure we have a boot.wim file
    if (-not (Test-Path -Path $bootWimPath)) {
        Write-Host "[$global:Src_Media_Path] does not appear to point to valid Windows media!" -ForegroundColor Red
        return $false
    }
    $bootWimMount = $global:WIM_Mount_Path
    Write-Dbg-Host "Mounting [$bootWimPath]"
    Write-Host "--->Mounting boot.wim from staged media"
    try {
        $mountedImage = Mount-WindowsImage -ImagePath $bootWimPath -Index 1 -Path $bootWimMount -ReadOnly -ErrorAction stop | Out-Null
        Write-Dbg-Host "Mounted [$bootWimPath] --> [$bootWimMount]"
    } catch {
        Write-Host "Failed to mount boot.wim of the source media!`r`nMake sure -StagingDir and -NewMediaPath are targetting an NTFS or ReFS based filesystem." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }

    $ex_bins_path = $bootWimMount + "\Windows\Boot\EFI_EX"
    $ex_fonts_path = $bootWimMount + "\Windows\Boot\FONTS_EX"
    $ex_dvd_path = $bootWimMount + "\Windows\Boot\DVD_EX"

    # Make sure the directories exist
    if (-not (Test-Path -Path $ex_dvd_path) -or
        -not (Test-Path -Path $ex_fonts_path) -or
        -not (Test-Path -Path $ex_bins_path)) {
        Write-Host "-MediaPath [$((Get-Item -Path $global:Src_Media_Path).Name)] does not have required binaries." -ForegroundColor Red
        Write-Host "Make sure all required updates (2024-4B or later) have been applied." -ForegroundColor Red
        Write-Host "[$global:Temp_Media_To_Update_Path] staged but was not updated!" -ForegroundColor Red
        return $false
    }

    Write-Host "Updating staged media to use boot binaries signed with 'Windows UEFI CA 2023' certificate" -ForegroundColor Blue

    try {
        #Copy  $ex_bins_path\bootmgr_EX.efi to $global:Temp_Media_To_Update_Path\bootmgr.efi
        Write-Dbg-Host "Copying $ex_bins_path\bootmgr_EX.efi to $global:Temp_Media_To_Update_Path\bootmgr.efi"
        Copy-Item -Path $ex_bins_path"\bootmgr_EX.efi" -Destination $global:Temp_Media_To_Update_Path"\bootmgr.efi" -Force -ErrorAction stop | Out-Null

        # Copy $ex_bins_path\bootmgrfw_EX.efi to $global:Temp_Media_To_Update_Path\efi\boot\bootx64.efi
        Write-Dbg-Host "Copying $ex_bins_path\bootmgfw_EX.efi to $global:Temp_Media_To_Update_Path\efi\boot\bootx64.efi"
        Copy-Item -Path $ex_bins_path"\bootmgfw_EX.efi" -Destination $global:Temp_Media_To_Update_Path"\efi\boot\bootx64.efi" -Force -ErrorAction stop | Out-Null

        # Copy $ex_dvd_path\EFI\en-US\efisys_EX.bin to $global:Temp_Media_To_Update_Path\efi\microsoft\boot\
        Write-Dbg-Host "Copying $ex_dvd_path\EFI\en-US\efisys_EX.bin to $global:Temp_Media_To_Update_Path\efi\microsoft\boot\efisys_ex.bin"
        Copy-Item -Path $ex_dvd_path"\EFI\en-US\efisys_EX.bin" -Destination $global:Temp_Media_To_Update_Path"\efi\microsoft\boot\efisys_ex.bin" -Force -ErrorAction stop | Out-Null

        # Copy $ex_fonts_path\* to $global:Temp_Media_To_Update_Path\efi\microsoft\boot\fonts_ex
        Write-Dbg-Host "Copying $ex_fonts_path\* to $global:Temp_Media_To_Update_Path\efi\microsoft\boot\fonts_ex"
        New-Item -ItemType Directory -Path $global:Temp_Media_To_Update_Path"\efi\microsoft\boot\fonts_ex" -Force | Out-Null
        Copy-Item -Path $ex_fonts_path"\*" -Destination $global:Temp_Media_To_Update_Path"\efi\microsoft\boot\fonts_ex\" -Force -ErrorAction stop | Out-Null

        # rename $global:Temp_Media_To_Update_Path\efi\microsoft\boot\fonts_ex\*_EX.ttf to *.ttf
        Write-Dbg-Host "Renaming $global:Temp_Media_To_Update_Path\efi\microsoft\boot\fonts_ex\*_EX.ttf to *.ttf"
        Get-ChildItem -Path $global:Temp_Media_To_Update_Path"\efi\microsoft\boot\fonts_ex" -Filter "*_EX.ttf" | Rename-Item -NewName { $_.Name -replace '_EX', '' } -Force -ErrorAction stop

        # Copy $global:Temp_Media_To_Update_Path\efi\microsoft\boot\fonts_ex\* to $global:Temp_Media_To_Update_Path\efi\microsoft\boot\fonts
        Write-Dbg-Host "Copying $global:Temp_Media_To_Update_Path\efi\microsoft\boot\fonts_ex\* to $global:Temp_Media_To_Update_Path\efi\microsoft\boot\fonts"
        Copy-Item -Path $global:Temp_Media_To_Update_Path"\efi\microsoft\boot\fonts_ex\*" -Destination $global:Temp_Media_To_Update_Path"\efi\microsoft\boot\fonts" -Force -ErrorAction stop | Out-Null

        # remove $global:Temp_Media_To_Update_Path\efi\microsoft\boot\fonts_ex
        Write-Dbg-Host "Removing $global:Temp_Media_To_Update_Path\efi\microsoft\boot\fonts_ex"
        Remove-Item -Path $global:Temp_Media_To_Update_Path"\efi\microsoft\boot\fonts_ex" -Recurse -Force -ErrorAction stop | Out-Null

    } catch {
        Write-Host "$_" -ForegroundColor Red
        return $false
    }

    if ($global:WIM_Mount_Path) {
        Write-Dbg-Host "`r`nDismounting $global:WIM_Mount_Path"
        try {
            Dismount-WindowsImage -Path $global:WIM_Mount_Path -Discard -ErrorAction stop | Out-Null
            $global:WIM_Mount_Path = $null
        } catch {
            Write-Host "Failed to dismount WIM [$global:WIM_Mount_Path]" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    }
    return $true
}

function Create-ISOMedia {
    param (
         [string] $ISOPath
     )

     Write-Host "Writing 'Windows UEFI CA 2023' bootable ISO media at location [$ISOPath]" -ForegroundColor Blue

     # If $ISOLable is not set, then defualt to "WINDOWS2023PCAISO"
    if (-not $global:ISO_Lable) {
        $global:ISO_Lable = "WINDOWS2023PCAISO"
    }

    # Generate a timestamp string in the following format: mm/dd/yyyy,hh:mm:ss
    $timestamp = Get-Date -Format "MM/dd/yyyy,HH:mm:ss"

    $runCommand = "-l$global:ISO_Lable -t$timestamp -bootdata:2#p0,e,b$global:Temp_Media_To_Update_Path\boot\etfsboot.com#pEF,e,b$global:Temp_Media_To_Update_Path\efi\microsoft\boot\efisys_ex.bin -u2 -udfver102 -o $global:Temp_Media_To_Update_Path $ISOPath"

    Write-Dbg-Host "Running: $global:oscdimg_exe $runCommand"
    try {

        # strip the file name from $ISOPath
        $isoDirPath = $ISOPath.Substring(0, $ISOPath.LastIndexOf("\"))

        # Make sure ISO path is valid or the call to oscdimg.exe will fail
        if (-not (Test-Path $isoDirPath)) {
            Write-Dbg-Host "ISOPath: $isoDirPath not valid, creating it" -ForegroundColor Red
            New-Item -ItemType Directory -Path $isoDirPath -Force | Out-Null
        }

        # $stdoutFile = "$Staging_Directory_Path\" + ([System.IO.Path]::GetRandomFileName()).Replace(".", "")
        # $stderrFile = "$Staging_Directory_Path\" + ([System.IO.Path]::GetRandomFileName()).Replace(".", "")
        Write-Dbg-Host "Writing [$ISOPath]"
        # Start-Process -FilePath $global:oscdimg_exe -ArgumentList $runCommand -Wait -NoNewWindow -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile -ErrorAction Stop | Out-Null
        Start-Process -FilePath $global:oscdimg_exe -ArgumentList $runCommand -Wait -NoNewWindow -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "Failed to create ISO: $ISOPath" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
    return $true
}

function Create-USBMedia {
    param (
         [string] $USBDrive,
         [string] $FileSystem
     )

    Write-Host "Creating 'Windows UEFI CA 2023' bootable USB media on drive [$USBDrive]" -ForegroundColor Blue

    $volume = Get-Volume -DriveLetter $USBDrive.TrimEnd(':')
    $currentLabel = $volume.FileSystemLabel

    if (-not $currentLabel) {
        $currentLabel = "BOOT2023PCA"
    }

    $fileSystem = $FileSystem
    if (-not $FileSystem) {
        $fileSystem = "FAT32"
    }

    # Format the drive using the existing label
    try {
        Format-Volume -DriveLetter $USBDrive.TrimEnd(':') -FileSystem $fileSystem -NewFileSystemLabel $currentLabel -Force
    } catch {
        Write-Host "Failed to format drive [$USBDrive] as $fileSystem" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }

    try {
        Write-Dbg-Host "Copying media to USB drive [$USBDrive\]"
        Copy-FilesWithProgress -SourcePath "$global:Temp_Media_To_Update_Path" -DestinationPath "$USBDrive\"
    } catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }

    return $true
}
function Update-LocalMedia {

    # Work here was already done during staging and CopyBins
    Write-Host "Creating 'Windows UEFI CA 2023' bootable local media at location [$global:Temp_Media_To_Update_Path]" -ForegroundColor Blue
    return $true
}

# Global variables
$global:ScriptName = Split-Path -Leaf $PSCommandPath
$global:Src_Media_Path = $null
$global:Staging_Directory_Path = $null
$global:StagingDir_Created = $false
$global:Temp_Media_To_Update_Path = $null
$global:WIM_Mount_Path = $null
$global:ISO_Mount_Path = $null
$global:ISO_Label = $null
$global:oscdimg_exe = $null
$global:Dbg_Pause = $false
$global:Dbg_Ouput = $false

Write-Host "`r`n`r`nMicrosoft 'Windows UEFI CA 2023' Media Update Script - Version 1.2`r`n" -ForegroundColor DarkYellow

# First validate that the required tools/environment exist
$result = Validate-Parameters -TargetType $TargetType -ISOPath $ISOPath -USBDrive $USBDrive -NewMediaPath $NewMediaPath -FileSystem $FileSystem -StagingDir $StagingDir
if (-not $result) {
    Write-Dbg-Host "Validate-Parameters failed"
    Show-Usage
    exit
}

# validate params
$result = Validate-Requirements
if (-not $result) {
    Write-Dbg-Host "Validate-Requirements failed"
    exit
}

# Now setup the staging infra
$result = Initialize-StagingDirectory -StagingDir $StagingDir
if (-not $result) {
    Write-Dbg-Host "Initialize-StagingDirectory failed"
    Execute-Cleanup
    exit
}

# Now initialize media path requirements
$result = Initialize-MediaPaths -MediaPath $MediaPath -NewMediaPath $NewMediaPath
if (-not $result) {
    Write-Dbg-Host "Initialize-MediaPath failed"
    Execute-Cleanup
    exit
}

$result = Copy-2023BootBins
if (-not $result) {
    Write-Dbg-Host "Copy-2023BootBins failed"
    Execute-Cleanup
    exit
}

switch ($TargetType) {
    "ISO" {
        $result = Create-ISOMedia -ISOPath $ISOPath
        if (-not $result) {
            Write-Host "ISO media creation failed" -ForegroundColor Red
        } else {
            if (Test-Path -Path $ISOPath){
                Write-Host "Successfully created ISO [$ISOPath]" -ForegroundColor Green
            }
        }
    }
    "USB" {
        $result = Create-USBMedia -USBDrive $USBDrive -FileSystem $FileSystem
        if (-not $result) {
            Write-Host "USB media creation failed!" -ForegroundColor Red
            break
        }
        Write-Host "Successfully created media on USB drive [$USBDrive]" -ForegroundColor Green
        break
    }
    "LOCAL" {

        $result = Update-LocalMedia
        if (-not $result) {
            Write-Host "Local media update failed!" -ForegroundColor Red
            break
        }
        Write-Host "Local media updated successfully at location [$global:Temp_Media_To_Update_Path]" -ForegroundColor Green
        break
    }
    default {
        Write-Host "Invalid TargetType: $TargetType" -ForegroundColor Red
        Show-Usage
        break
    }
}

Execute-Cleanup
exit
# SIG # Begin signature block
# MIIlrwYJKoZIhvcNAQcCoIIloDCCJZwCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCByZXaVuh0R0FMP
# psduKzOQj+g3KXiiyFX1DcYidYBwtaCCCtkwggT6MIID4qADAgECAhMzAAAEqILm
# uKwcXV/wAAAAAASoMA0GCSqGSIb3DQEBCwUAMIGEMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMS4wLAYDVQQDEyVNaWNyb3NvZnQgV2luZG93cyBQ
# cm9kdWN0aW9uIFBDQSAyMDExMB4XDTI0MDkxMjIwMDQwN1oXDTI1MDkxMTIwMDQw
# N1owcDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcT
# B1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEaMBgGA1UE
# AxMRTWljcm9zb2Z0IFdpbmRvd3MwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
# AoIBAQDliiA2nsvDibvZwdp6WaqHm4sM0FcA6wPCxkNkFP70YMrZwPWIAHGPpJbZ
# C8gtOaaqMtfMVQa0Gb8YRiloLrUptSNGjgAo5M3wYj3ChWW/SYWIw0+wNvssyNdd
# UsKrixU+cNs8zGN+tKTtPTWXz/cmMPvqJFtvRvMOaG+n/4pXoccJVk7Xy563xhQl
# recMXGhyodzJMXP0jMHxXSFeUy2IjZN7vkzEJM9IbzPRfj2GkKy5qWFZ3GDH7PJX
# pHpcUVdA79fqwFQGJBxwo5mZaWtoFRo3wfWwjuft6P1UIQTM4EgkZ07SIrRdBDfI
# NsyLhr4RTBGKKrdS8iuNIHIw+UL5AgMBAAGjggF2MIIBcjAfBgNVHSUEGDAWBgor
# BgEEAYI3CgMGBggrBgEFBQcDAzAdBgNVHQ4EFgQU8nJKLNX1/bGcEvXjHu9nuZj9
# hcYwRQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEWMBQGA1UEBRMNMjI5ODc5KzUwMjk1NzAfBgNVHSMEGDAWgBSpKQI5jhbEl3jN
# kPmeT5rhfFWvUzBXBgNVHR8EUDBOMEygSqBIhkZodHRwOi8vd3d3Lm1pY3Jvc29m
# dC5jb20vcGtpb3BzL2NybC9NaWNXaW5Qcm9QQ0EyMDExXzIwMTEtMTAtMTkuY3Js
# JTIwMGEGCCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDovL3d3dy5taWNy
# b3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNXaW5Qcm9QQ0EyMDExXzIwMTEtMTAt
# MTkuY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggEBAMdVC2g+Ccpe
# qEMRygbEfPhNJDU31uGk8AHdo9Q7tCKAD5sAvvelHdbTFbguEuJwtPJbjIH4w9Zc
# 7OY3QVeolhAFrfByH+5glDg08IOobRIPhCPTmS26e6aSZqis1FL4NlVg7N+3H+T+
# tHKWR9R4yeUD0j7MJQZjarJROckKeBqxk96j6UN7pDJEh7YGvc9XanVPoy1bB81A
# askt5/wU9JOsUi7wa9VbA81VUeAlxBJ8KAaipSbC1c6q6AMljuRUBoi6qb1B4P2f
# 5OZq1aaUJ11n0jcXovqw/S86MYlIgzoZsL8Oq+e6+emwbnEe68HCiVGVRfrxbNgR
# zXA8v5/hMuswggXXMIIDv6ADAgECAgphB3ZWAAAAAAAIMA0GCSqGSIb3DQEBCwUA
# MIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQD
# EylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAxMDAeFw0x
# MTEwMTkxODQxNDJaFw0yNjEwMTkxODUxNDJaMIGEMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMS4wLAYDVQQDEyVNaWNyb3NvZnQgV2luZG93cyBQ
# cm9kdWN0aW9uIFBDQSAyMDExMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKC
# AQEA3Qy7ouQuCePnxfeWabwAIb1pMzPvrQTLVIDuBoO7xSCE2ffSi/M4sKukrS18
# YnkF/+NKPwQ1IHDjxOdr4JzANnXpijHdjXDl3De1dEaWKFuHYCMsv9xHpWf3USee
# cusHpsm5HjtTNXzl0+wnuYcc/rnJIwlvqEaRwW6WPEHTy6M/XQJqTexpHyUoXDb/
# /UMVCpTgGbTP38IS4sJbJ+4neDCLWyoJayKJU2AWLMBoHVO67EnznWGMhWgJc0Rd
# faJUK9159xXPNV1sHCtczrycI4tvbrUm2TYTw0/WJ665MjtBkizhx8136KpUTvdc
# CwSHZbRDGKiy4G0Zd+xaJPpIAwIDAQABo4IBQzCCAT8wEAYJKwYBBAGCNxUBBAMC
# AQAwHQYDVR0OBBYEFKkpAjmOFsSXeM2Q+Z5PmuF8Va9TMBkGCSsGAQQBgjcUAgQM
# HgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1Ud
# IwQYMBaAFNX2VsuP6KJcYmjRPZSQW9fOmhjEMFYGA1UdHwRPME0wS6BJoEeGRWh0
# dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0Nl
# ckF1dF8yMDEwLTA2LTIzLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUHMAKG
# Pmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9vQ2VyQXV0
# XzIwMTAtMDYtMjMuY3J0MA0GCSqGSIb3DQEBCwUAA4ICAQAU/HxxUaV5wm6y7zk+
# vDxSD24rPxATc/6oaNBIpjRNipYFJu4xRpBhedb/OC5Fa/TA5Si42h2PitsJ1xrH
# TAo2ZmqM7BvXBJCoGBekm7niQDI2dsTBWsa/5ATA6hbTrMNo72Ks3VRsUDBYput8
# /pSnTo707HyGc1fCUiFzNFrzo4pWyATaBwnt+IvjzvR+jq7w9guKCPs/yR1yf1O4
# 675j4OM9MWWwgeXyrM0WpJ89qLGbwkLQkIRfVB3/ieq6HUeQb7BzTkGfQJ9f5aEq
# shGRc4ohKPDO3nM5Xz6rXGDs3wMQqNMJ6fT2loW2f1GIZkcZjaKwEj2BKmgFd7uR
# TGJ7tsEHx7p6hzQDDktiepnpyvzOSjfJLaRXfBz+Pdy4D1r61sSzAoUCOuqz2W7k
# aSE33oHR9nUZBWfTk1deKRs5yO4t4c3kRXNb0NLOeqsWGYJGWNBenYGzZ69sNfK8
# 5T8k4jWiCnUG9hhWmdR4LNEFG+vQiAGdqhDxBd+6fixjtwabIyHE+Xhs4lgXBjYr
# kRIDzKTZ8i26+ZSdQO0YRfHOilxrPqsD03AYKgpq4F9H0dVjCjLyr9c2HypwWuVC
# WQhxS1e6foOB8CE89BzBxbmQkw6IRZOG6bEgmb6Yy8WVpF1i1qBjCCC9dRB3fT3z
# Rbmfl5/LV4BvM6kEz3ekYhxZfjGCGiwwghooAgEBMIGcMIGEMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS4wLAYDVQQDEyVNaWNyb3NvZnQgV2lu
# ZG93cyBQcm9kdWN0aW9uIFBDQSAyMDExAhMzAAAEqILmuKwcXV/wAAAAAASoMA0G
# CWCGSAFlAwQCAQUAoIGwMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisG
# AQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCAsFlM+tDbR
# W+i/XZ15O0sFm1q7wUhwWsCEtsMksC12pTBEBgorBgEEAYI3AgEMMTYwNKAUgBIA
# TQBpAGMAcgBvAHMAbwBmAHShHIAaaHR0cHM6Ly93d3cubWljcm9zb2Z0LmNvbSAw
# DQYJKoZIhvcNAQEBBQAEggEAmgAycphxKKbO0Sed8HgpNSzaVz/2Tgz1F0Mg6/5P
# p0/oukoAGVKjfbQoeJTA6mcTugfd1YBGguwDomGsF5lDrQ2Ha8oJ76QBZjnVtSih
# x2B1Yxo63SobL+wAH/hw62UT16JL7I7NVG3OHKG4SPNiduUhzo1VP/bB2PsIEJlt
# 9s3VAbbjMjLwnyG9PDUfbg1GgiMkjr7Od7sEGL01vLJqncWDqzxhyXovQ6rLl1uD
# XktZLJDDjzdPMM9pCi+NtVRUHOAJRnMZH6hIpAyF8zWRDRpX7KXwwaIfjQyi925j
# HNwsJxGtbotNXIQc1JQq+n1U6D2g4eoB6akq5iTCgWhDq6GCF60wghepBgorBgEE
# AYI3AwMBMYIXmTCCF5UGCSqGSIb3DQEHAqCCF4YwgheCAgEDMQ8wDQYJYIZIAWUD
# BAIBBQAwggFaBgsqhkiG9w0BCRABBKCCAUkEggFFMIIBQQIBAQYKKwYBBAGEWQoD
# ATAxMA0GCWCGSAFlAwQCAQUABCCR+WGP+9Tlwf7oT/VrI/TpbrPRLDxreG0Ru/Of
# PjNRGQIGZ7Y1nZ4dGBMyMDI1MDMxMTE5MjUwOS4wMzVaMASAAgH0oIHZpIHWMIHT
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRN
# aWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJzAlBgNVBAsTHm5T
# aGllbGQgVFNTIEVTTjoyQTFBLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgU2VydmljZaCCEfswggcoMIIFEKADAgECAhMzAAAB+R9njXWr
# pPGxAAEAAAH5MA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBD
# QSAyMDEwMB4XDTI0MDcyNTE4MzEwOVoXDTI1MTAyMjE4MzEwOVowgdMxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1pY3Jvc29m
# dCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNoaWVsZCBU
# U1MgRVNOOjJBMUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1T
# dGFtcCBTZXJ2aWNlMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAtD1M
# H3yAHWHNVslC+CBTj/Mpd55LDPtQrhN7WeqFhReC9xKXSjobW1ZHzHU8V2BOJUiY
# g7fDJ2AxGVGyovUtgGZg2+GauFKk3ZjjsLSsqehYIsUQrgX+r/VATaW8/ONWy6lO
# yGZwZpxfV2EX4qAh6mb2hadAuvdbRl1QK1tfBlR3fdeCBQG+ybz9JFZ45LN2ps8N
# c1xr41N8Qi3KVJLYX0ibEbAkksR4bbszCzvY+vdSrjWyKAjR6YgYhaBaDxE2KDJ2
# sQRFFF/egCxKgogdF3VIJoCE/Wuy9MuEgypea1Hei7lFGvdLQZH5Jo2QR5uN8hiM
# c8Z47RRJuIWCOeyIJ1YnRiiibpUZ72+wpv8LTov0yH6C5HR/D8+AT4vqtP57ITXs
# D9DPOob8tjtsefPcQJebUNiqyfyTL5j5/J+2d+GPCcXEYoeWZ+nrsZSfrd5DHM4o
# vCmD3lifgYnzjOry4ghQT/cvmdHwFr6yJGphW/HG8GQd+cB4w7wGpOhHVJby44kG
# VK8MzY9s32Dy1THnJg8p7y1sEGz/A1y84Zt6gIsITYaccHhBKp4cOVNrfoRVUx2G
# /0Tr7Dk3fpCU8u+5olqPPwKgZs57jl+lOrRVsX1AYEmAnyCyGrqRAzpGXyk1HvNI
# BpSNNuTBQk7FBvu+Ypi6A7S2V2Tj6lzYWVBvuGECAwEAAaOCAUkwggFFMB0GA1Ud
# DgQWBBSJ7aO6nJXJI9eijzS5QkR2RlngADAfBgNVHSMEGDAWgBSfpxVdAF5iXYP0
# 5dJlpxtTNRnpcjBfBgNVHR8EWDBWMFSgUqBQhk5odHRwOi8vd3d3Lm1pY3Jvc29m
# dC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIw
# MjAxMCgxKS5jcmwwbAYIKwYBBQUHAQEEYDBeMFwGCCsGAQUFBzAChlBodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFRpbWUt
# U3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNydDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB
# /wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIHgDANBgkqhkiG9w0BAQsFAAOC
# AgEAZiAJgFbkf7jfhx/mmZlnGZrpae+HGpxWxs8I79vUb8GQou50M1ns7iwG2Ccd
# oXaq7VgpVkNf1uvIhrGYpKCBXQ+SaJ2O0BvwuJR7UsgTaKN0j/yf3fpHD0ktH+Ek
# EuGXs9DBLyt71iutVkwow9iQmSk4oIK8S8ArNGpSOzeuu9TdJjBjsasmuJ+2q5Tj
# mrgEKyPe3TApAio8cdw/b1cBAmjtI7tpNYV5PyRI3K1NhuDgfEj5kynGF/uizP1N
# uHSxF/V1ks/2tCEoriicM4k1PJTTA0TCjNbkpmBcsAMlxTzBnWsqnBCt9d+Ud9Va
# 3Iw9Bs4ccrkgBjLtg3vYGYar615ofYtU+dup+LuU0d2wBDEG1nhSWHaO+u2y6Si3
# AaNINt/pOMKU6l4AW0uDWUH39OHH3EqFHtTssZXaDOjtyRgbqMGmkf8KI3qIVBZJ
# 2XQpnhEuRbh+AgpmRn/a410Dk7VtPg2uC422WLC8H8IVk/FeoiSS4vFodhncFetJ
# 0ZK36wxAa3FiPgBebRWyVtZ763qDDzxDb0mB6HL9HEfTbN+4oHCkZa1HKl8B0s8R
# iFBMf/W7+O7EPZ+wMH8wdkjZ7SbsddtdRgRARqR8IFPWurQ+sn7ftEifaojzuCEa
# hSAcq86yjwQeTPN9YG9b34RTurnkpD+wPGTB1WccMpsLlM0wggdxMIIFWaADAgEC
# AhMzAAAAFcXna54Cm0mZAAAAAAAVMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQg
# Um9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAxMDAeFw0yMTA5MzAxODIyMjVa
# Fw0zMDA5MzAxODMyMjVaMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMIIC
# IjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA5OGmTOe0ciELeaLL1yR5vQ7V
# gtP97pwHB9KpbE51yMo1V/YBf2xK4OK9uT4XYDP/XE/HZveVU3Fa4n5KWv64NmeF
# RiMMtY0Tz3cywBAY6GB9alKDRLemjkZrBxTzxXb1hlDcwUTIcVxRMTegCjhuje3X
# D9gmU3w5YQJ6xKr9cmmvHaus9ja+NSZk2pg7uhp7M62AW36MEBydUv626GIl3GoP
# z130/o5Tz9bshVZN7928jaTjkY+yOSxRnOlwaQ3KNi1wjjHINSi947SHJMPgyY9+
# tVSP3PoFVZhtaDuaRr3tpK56KTesy+uDRedGbsoy1cCGMFxPLOJiss254o2I5Jas
# AUq7vnGpF1tnYN74kpEeHT39IM9zfUGaRnXNxF803RKJ1v2lIH1+/NmeRd+2ci/b
# fV+AutuqfjbsNkz2K26oElHovwUDo9Fzpk03dJQcNIIP8BDyt0cY7afomXw/TNuv
# XsLz1dhzPUNOwTM5TI4CvEJoLhDqhFFG4tG9ahhaYQFzymeiXtcodgLiMxhy16cg
# 8ML6EgrXY28MyTZki1ugpoMhXV8wdJGUlNi5UPkLiWHzNgY1GIRH29wb0f2y1BzF
# a/ZcUlFdEtsluq9QBXpsxREdcu+N+VLEhReTwDwV2xo3xwgVGD94q0W29R6HXtqP
# nhZyacaue7e3PmriLq0CAwEAAaOCAd0wggHZMBIGCSsGAQQBgjcVAQQFAgMBAAEw
# IwYJKwYBBAGCNxUCBBYEFCqnUv5kxJq+gpE8RjUpzxD/LwTuMB0GA1UdDgQWBBSf
# pxVdAF5iXYP05dJlpxtTNRnpcjBcBgNVHSAEVTBTMFEGDCsGAQQBgjdMg30BATBB
# MD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0Rv
# Y3MvUmVwb3NpdG9yeS5odG0wEwYDVR0lBAwwCgYIKwYBBQUHAwgwGQYJKwYBBAGC
# NxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8w
# HwYDVR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186aGMQwVgYDVR0fBE8wTTBLoEmg
# R4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWlj
# Um9vQ2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEF
# BQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29D
# ZXJBdXRfMjAxMC0wNi0yMy5jcnQwDQYJKoZIhvcNAQELBQADggIBAJ1VffwqreEs
# H2cBMSRb4Z5yS/ypb+pcFLY+TkdkeLEGk5c9MTO1OdfCcTY/2mRsfNB1OW27DzHk
# wo/7bNGhlBgi7ulmZzpTTd2YurYeeNg2LpypglYAA7AFvonoaeC6Ce5732pvvinL
# btg/SHUB2RjebYIM9W0jVOR4U3UkV7ndn/OOPcbzaN9l9qRWqveVtihVJ9AkvUCg
# vxm2EhIRXT0n4ECWOKz3+SmJw7wXsFSFQrP8DJ6LGYnn8AtqgcKBGUIZUnWKNsId
# w2FzLixre24/LAl4FOmRsqlb30mjdAy87JGA0j3mSj5mO0+7hvoyGtmW9I/2kQH2
# zsZ0/fZMcm8Qq3UwxTSwethQ/gpY3UA8x1RtnWN0SCyxTkctwRQEcb9k+SS+c23K
# jgm9swFXSVRk2XPXfx5bRAGOWhmRaw2fpCjcZxkoJLo4S5pu+yFUa2pFEUep8beu
# yOiJXk+d0tBMdrVXVAmxaQFEfnyhYWxz/gq77EFmPWn9y8FBSX5+k77L+DvktxW/
# tM4+pTFRhLy/AsGConsXHRWJjXD+57XQKBqJC4822rpM+Zv/Cuk0+CQ1ZyvgDbjm
# jJnW4SLq8CdCPSWU5nR0W2rRnj7tfqAxM328y+l7vzhwRNGQ8cirOoo6CGJ/2XBj
# U02N7oJtpQUQwXEGahC0HVUzWLOhcGbyoYIDVjCCAj4CAQEwggEBoYHZpIHWMIHT
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRN
# aWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJzAlBgNVBAsTHm5T
# aGllbGQgVFNTIEVTTjoyQTFBLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcGBSsOAwIaAxUAqs5WjWO7zVAKmIcd
# whqgZvyp6UaggYMwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAN
# BgkqhkiG9w0BAQsFAAIFAOt6Z7swIhgPMjAyNTAzMTEwNzQxNDdaGA8yMDI1MDMx
# MjA3NDE0N1owdDA6BgorBgEEAYRZCgQBMSwwKjAKAgUA63pnuwIBADAHAgEAAgII
# UjAHAgEAAgITCTAKAgUA63u5OwIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEE
# AYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBCwUAA4IB
# AQCrk0K7hxJgzTIFkasihyOcwb6n1BBFcmkIdRBdr7lxi3+A+3UzK1xQoaHIL3Mg
# kEqLK81SRl43iqF4rtTZI8WMW7SvSCdUEzWHJvtE+KsvZVgW++S2gy+iS9/46UV9
# YNqz5gEWHvfso+ldhmLoEHAUD65ZD0XQfbPV9ItpGRFqgPc89NxpLs8PZGr0nq4Z
# Ouj6ELUhFHcUQYt7c90v6m8WJi6iTHKLDzg5MQYysjJn0Q3sPJh7uyBmPXC7pPAL
# AbWZLP/BEYw+AmTo2+5QQn7vrjf4YimkMCtsRySYHTZZU+jefWqvJzyQfp6NSGF9
# Wv0X5WuwPYeXw3xZODrnDd1OMYIEDTCCBAkCAQEwgZMwfDELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgUENBIDIwMTACEzMAAAH5H2eNdauk8bEAAQAAAfkwDQYJYIZIAWUDBAIB
# BQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0BCQQx
# IgQgXpKzSvncV21QxUSfCKLDQrKLuIIubLBxAWVDtIbrSzAwgfoGCyqGSIb3DQEJ
# EAIvMYHqMIHnMIHkMIG9BCA5I4zIHvCN+2T66RUOLCZrUEVdoKlKl8VeCO5SbGLY
# EDCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB+R9n
# jXWrpPGxAAEAAAH5MCIEIJ4UtdAF3wp4raeL0IRHMxULFwajeUWpNW9qjbJY3CrV
# MA0GCSqGSIb3DQEBCwUABIICACQeSEE2jIoY3hSAE3YIgwqqH1RJ1HT7AgzIclLK
# KNFppT3xE+ec9zeB9FArv37hwi+7jvn7hvCbD/JpPqbRUCYaz3ydbmOgkyWNdvcu
# ewCs175tyae3FN6UL26dRJrqz+MxdwfgNSs5Awl+TppiNQ3nFSmonj6wqJJWd1+t
# qg2Kgvl2b5K1Cizvaec35m88kqFoIleZCO7Olv+Wu++FO9+PqwkJ7wz3HQ+GgFsi
# mgQQxcraJaaee42nZkwyb1uzJXiSnARkRuQkIVsh25V/IqMxNJtSGnEydWTmD3hK
# iIs4nW3idtVF2xK3+7J/Y14OBwZmZq5qLi7wVCmEclRzLbkLxOVSQRvq+UIUbRSL
# Cp3Ri0DAEuNMV6C0+TjeyFVwF+YY4GSxHCe9h5cl5ZnvWKrecdc+2hgN5+MZifMh
# FWENUoz/48DKdB75wV5bTb3eZ8fwMKx/tZSjT/91YZVpaC9Tpb7Zhm3Civc7VIyT
# BRLDjoKtVRFuqSFU+nbdGGu6qE4WnWtMuhfhKi7IngyJgaro5DPBz1BUnhctYtdo
# myB0feKpVySrdrEjWx2uwJkr8ffyJLyQ4+YvzwzZytisSbyRO5cNk7cy+e8IGKAX
# rAis8V0clYvYS4ePViNG/ddQTIrmUi0LUXFJ/nXWO2TYphfOC630NFnXBvuDGStc
# XPYB
# SIG # End signature block
