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
        $InstallESDName = (Get-Item $file.FullName ).Name
        if (($InstallESDName -eq "install.esd") -or ($InstallESDName -eq "install.wim")) {
        if ($InstallESDName -eq "install.esd") {
        if ($file.Length -gt 5MB) {
            Copy-LargeFileWithProgres -SourcePath $file.FullName -DestinationPath $destinationFile
            continue
        } else{
            Copy-Item -Path $file.FullName -Destination $destinationFile -Force
        }
        } else {
        if (!$ESDFound) {
            if ($InstallESDName -eq "install.wim") {
                if ($file.Length -gt 5MB) {
                    Copy-LargeFileWithProgres -SourcePath $file.FullName -DestinationPath $destinationFile
                    continue
                } else{
                    Copy-Item -Path $file.FullName -Destination $destinationFile -Force
                }
            }
            }
            }
                Write-Progress -Activity "Copying files" -Status "copying [$file]" -PercentComplete $percentComplete
                break
        }
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
$ESDFound = $false
$userPath = $env:username
$InstallESD = "C:\Users\$userPath\Desktop\Win11_24H2_Customize\WORKING_WIM"
$MediaDestinationPath = "C:\Users\$userPath\Desktop\Win11_24H2_Customize\24H2BootableMedia\sources"

if (Test-Path $InstallESD"\install.esd") {
        $ESDFound = $true
    if (Test-Path $MediaDestinationPath"\install.esd") {
        try
        {
            Remove-Item -Force -Path $MediaDestinationPath"\install.esd" -confirm:$false -recurse
        }
        Catch { }
    }

    if (Test-Path $MediaDestinationPath"\install.wim") {
        try
        {
            Remove-Item -Force -Path $MediaDestinationPath"\install.wim" -confirm:$false -recurse
        }
        Catch { }
    }

        Write-Dbg-Host "Copying [$InstallESD] --> [$MediaDestinationPath]"

        try 
        {
            Copy-FilesWithProgress -SourcePath $InstallESD -DestinationPath $MediaDestinationPath
        }
        Catch
        {
            Write-Host $_.Exception.Message -ForegroundColor Red
            return $false
        }
    } else {
    if (Test-Path $InstallESD"\install.wim") {
        $ESDFound = $false
    if (Test-Path $MediaDestinationPath"\install.wim") {
        try
        {
            Remove-Item -Force -Path $MediaDestinationPath"\install.wim" -confirm:$false -recurse
        }
        Catch { }
    }

    if (Test-Path $MediaDestinationPath"\install.esd") {
        try
        {
            Remove-Item -Force -Path $MediaDestinationPath"\install.esd" -confirm:$false -recurse
        }
        Catch { }
    }

        Write-Dbg-Host "Copying [$InstallESD] --> [$MediaDestinationPath]"

        try 
        {
            Copy-FilesWithProgress -SourcePath $InstallESD -DestinationPath $MediaDestinationPath
        }
        Catch
        {
            Write-Host $_.Exception.Message -ForegroundColor Red
            return $false
        }
    }
    }