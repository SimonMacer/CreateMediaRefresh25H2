@echo off
call :IsAdmin
:Home
CLS
@echo off
::Menu Section
title Windows 11, version 25H2 Disc Image File Creation (Ver 2025.11.09)!
set /P c=Set Cumulative Update KB Number:
set LCUNumber="%c%"
set LCUNumbers=%c%
set /P c=Set Feature Update for Windows 11 25H2 via Enablement Package KB Number:
set EKBNumber="%c%"
set EKBNumbers=%c%
set /P c=Set Safe OS Dynamic Update KB Number:
set SAFEOSDUNumber="%c%"
set SAFEOSDUNumbers=%c%
set /P c=Set Setup Dynamic Update KB Number:
set SETUPDUNumber="%c%"
set SETUPDUNumbers=%c%
set /P c=Set Cumulative Update for .NET Framework 3.5 and 4.8.1 KB Number:
set DoNetCUNumber="%c%"
set DoNetCUNumbers=%c%
set /P c=Set OS Build Number:
set OSNumber="%c%"
set OSNumbers=%c%
echo Specify install.wim main edition and additional edition:
echo [Index 1] Windows 11 Home
echo [Index 2] Windows 11 Pro
echo [Index 3] Windows 11 Education
echo [Index 4] Windows 11 Pro Education
echo [Index 5] Windows 11 Pro for Workstations
set /P c=Set Skip Specify install.wim, Input [Y] to use the default index of the install.wim image or [N] or No Input to use specify install.wim image:
set SkipMode=N
if /I "%c%" EQU "Y" set SkipMode=Y
CLS
echo [LCU] KB%LCUNumbers% Cumulative Update for Windows 11 Version 24H2 and 25H2
echo [Enablement] Feature Update for Windows 11 25H2 via Enablement Package (KB%EKBNumbers%)
echo [SafeOS DU] KB%SAFEOSDUNumbers% Safe OS Dynamic Update for Windows 11 Version 24H2 and 25H2
echo [Setup DU] KB%SETUPDUNumbers% Setup Dynamic Update for Windows 11 Version 24H2 and 25H2
echo [NetFx] KB%DoNetCUNumbers% Cumulative Update for .NET Framework 3.5 and 4.8.1 for Windows 11 Version 24H2 and 25H2
echo OS Build Number: %OSNumbers%
echo Skip Specify install.wim: %SkipMode%
set /P c=Confirm the above information, Input [A] to Start or [C] to Cancel:
if /I "%c%" EQU "A" goto :HomeStart
if /I "%c%" EQU "C" goto :Home
goto :Home
:HomeStart
echo Extract [24H2BootableMedia.iso] image file!
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\%username%\Desktop\Win11_24H2_Customize\Export24H2BootableMedia.ps1"
echo Update Update each main OS Windows image including the Windows Recovery Environment (WinRE)!
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\%username%\Desktop\Win11_24H2_Customize\CreateMediaRefresh25H2.ps1" -LCUNumber "%LCUNumber%" -SAFEOSDUNumber "%SAFEOSDUNumber%" -SETUPDUNumber "%SETUPDUNumber%" -DoNetCUNumber "%DoNetCUNumber%" -EKBNumber "%EKBNumber%" -OSNumber "%OSNumber%" -FocusDefaultIndex "%SkipMode%"
echo Update WinPE!
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\%username%\Desktop\Win11_24H2_Customize\UpdateBootable.ps1" -LCUNumber "%LCUNumber%" -SAFEOSDUNumber "%SAFEOSDUNumber%" -SETUPDUNumber "%SETUPDUNumber%" -DoNetCUNumber "%DoNetCUNumber%" -EKBNumber "%EKBNumber%" -OSNumber "%OSNumber%"
echo Update remaining media files!
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\%username%\Desktop\Win11_24H2_Customize\UpdateBootableMedia.ps1" -LCUNumber "%LCUNumber%" -SAFEOSDUNumber "%SAFEOSDUNumber%" -SETUPDUNumber "%SETUPDUNumber%" -DoNetCUNumber "%DoNetCUNumber%" -EKBNumber "%EKBNumber%" -OSNumber "%OSNumber%"
echo Tweak Windows Preinstallation Environment (WinPE)!
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\%username%\Desktop\Win11_24H2_Customize\TweakBootableMedia.ps1"
echo Copy [install.esd or install.wim] Image File!
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\%username%\Desktop\Win11_24H2_Customize\CopyInstallESDFile.ps1"
echo Updating Windows bootable media to use the PCA2023 signed boot manager!
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\%username%\Desktop\Win11_24H2_Customize\Make2023BootableMedia.ps1" -MediaPath "C:\Users\%username%\Desktop\Win11_24H2_Customize\24H2BootableMedia" -TargetType ISO -ISOPath "C:\Users\%username%\Desktop\Win11_24H2_Customize\Win11_25H2_Chinese_Traditional_x64_CA2023.iso"
pause
exit

:IsAdmin
Reg.exe query "HKU\S-1-5-19\Environment"
If Not %ERRORLEVEL% EQU 0 (
CLS & echo IsNotAdmin
Pause & Exit
)
CLS
goto :eof