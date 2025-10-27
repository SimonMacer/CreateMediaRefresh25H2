# Author: Macer

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

# Set environment variable
$userPath = $env:username
$MediaPath = "C:\Users\$userPath\Desktop\Win11_24H2_Customize\24H2BootableMedia.iso"
$global:Temp_Media_To_Update_Path = "C:\Users\$userPath\Desktop\Win11_24H2_Customize"
    if ($MediaPath -match "\.iso$") {

        Write-Dbg-Host "$MediaPath is an ISO file"
            # Get full path for the ISO
            $global:Src_Media_Path = (Get-Item -Path $MediaPath).FullName
            if ($global:Src_Media_Path -eq $null) {
                Write-Host "Failed to get full path for [$MediaPath]" -ForegroundColor Red
                return $false
            }
            $localIsoPath = $global:Src_Media_Path

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

    }

$MediaDestinationPath = "C:\Users\$userPath\Desktop\Win11_24H2_Customize\" + (Get-Item $global:Src_Media_Path ).Basename

    if (Test-Path $MediaDestinationPath) {
        try
        {
            Remove-Item -Force -Path $MediaDestinationPath -confirm:$false -recurse
        }
        Catch { }
    }

    try
    {
        New-Item -Force -Path $MediaDestinationPath -ItemType Directory
    }
    Catch { }

    Write-Dbg-Host "Copying [$localMediaPath] --> [$MediaDestinationPath]"

    try {
        Copy-FilesWithProgress -SourcePath $localMediaPath -DestinationPath $MediaDestinationPath
    } catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
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