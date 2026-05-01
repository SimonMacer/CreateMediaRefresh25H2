@echo off
title BypassNRO
echo Add registry, Skip Microsoft account, internet in OOBE (Out-of-Box Experience).
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v "BypassNRO" /t REG_DWORD /d 1 /f
echo Specifies that the Microsoft Software License Terms page of Windows Welcome is not displayed.
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v "HideEULAPage" /t REG_DWORD /d 1 /f
echo Hides the Network screen during Windows Welcome.
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v "HideWirelessSetupInOOBE" /t REG_DWORD /d 1 /f
echo Hides the sign-in page during OOBE (Out-of-Box Experience).
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v "HideOnlineAccountScreens" /t REG_DWORD /d 1 /f
echo Restart the system.
shutdown -r -t 0
Exit
