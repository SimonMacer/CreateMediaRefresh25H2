# CreateMediaRefresh25H2
Windows 11, version 25H2 Disc Image File Creation.

# 建立與部屬 Windows 11, version 25H2 光碟映像檔 ISO
## 栽要
* 基於 [Update Windows installation media with Dynamic Update - Microsoft Learn](https://learn.microsoft.com/en-us/windows/deployment/update/media-dynamic-update) 改進製作流程。
* 適用於 Windows 11, version 25H2 製作。
* 適用於繁體中文語系 OS。

## 準備工作
* [下載及安裝 Windows ADK](https://learn.microsoft.com/zh-tw/windows-hardware/get-started/adk-install)。
* Windows 11, version 24H2 Build 26100.1742 或最新 Windows 11, version 25H2 光碟映像檔 ISO。
建議使用 Windows 11, version 24H2 Build 26100.1742 做為基底，General Availability Channel/Release Preview Channel 及 Dev/Beta Channel 皆是在 (Checkpoint) Build 26100.1742 為基礎。我們可以從 [Windows 11, version 24H2 (26100.1742) amd64 - UUP dump](https://uupdump.net/selectlang.php?id=e1d5e11a-7054-49cf-b9c9-ba54258d5cc6) 下載並製作此版本。

## Win11_24H2_Customize 環境建置
* 在 [桌面] 上建立一個 Win11_24H2_Customize 目錄並 Download ZIP 將 .\CreateMediaRefresh25H2-main.zip\CreateMediaRefresh25H2-main 中的所有文件解壓縮至 Win11_24H2_Customize 目錄中。

![Download ZIP](https://i.meee.com.tw/0x1R3nZ.png)
* 下載 24H2BootableMedia.iso Build 26100.1742 安裝媒體。[Google Drive 空間下載](https://drive.google.com/file/d/1J0VpkozUZ5TG_ynje5890LzF8GwDt9gW/view?usp=sharing)
* 請將下載的 24H2BootableMedia.7z 中的 24H2BootableMedia.iso 文件解壓縮至 Win11_24H2_Customize 目錄中。

### Win11_24H2_Customize\KB
* 將 MSU 及 CAB 更新套件放置於此。
* 從 [UUP dump](https://uupdump.net/) 或 [Microsoft®Update Catalog](https://www.catalog.update.microsoft.com/home.aspx) 下載 Cumulative Update、Safe OS Dynamic Update、Setup Dynamic Update、Cumulative Update for .NET Framework、Enablement Package 及 Checkpoint Cumulative Update 更新套件。
* 下載副檔名 *.MSU 的 Cumulative Update 更新套件。
* 下載副檔名 *.MSU 或 *.CAB 的 Safe OS Dynamic Update 更新套件。
* 下載副檔名 *.CAB 的 Setup Dynamic Update 更新套件。
* 下載副檔名 *.MSU 的 Cumulative Update for .NET Framework 更新套件。
* 下載副檔名 *.MSU 或 *.CAB 的 Enablement Package 更新套件。
* 下載副檔名 *.MSU 的 KB5043080 Checkpoint Cumulative Update for Windows 11 Version 24H2 and 25H2 更新套件。

### Win11_24H2_Customize\autounattend
* 放置 autounattend.xml 回應檔案。

### Win11_24H2_Customize\CustomAppsList
* 編輯 CustomAppsList.txt 文件選擇想要刪除的商店應用程式，刪除 # 開頭字串將移除商店應用程式。

### Win11_24H2_Customize\Drivers
* 放置想要整合的驅動程式 *inf 文件。

### Win11_24H2_Customize\GAC-WIM
* 放置來源 install.wim 文件。

### Win11_24H2_Customize\MSEDGE
* 放置 Microsoft Edge 更新套件。Edge 更新套件需要特別處理才能正確更新 install.wim 文件。

[下載 Microsoft Edge Stable Channel Version 141.0.3537.99: October 23, 2025 更新套件](https://drive.google.com/file/d/1F6_FFSURA2lGqPrzJrdzsZm79ovXaEgE/view?usp=sharing)
* 請將 MSEDGE_141.0.3537.99.7z 解壓縮至 .\MSEDGE 目錄中。

### Win11_24H2_Customize\sources
* 請將 $OEM$.7z 解壓縮至同目錄並刪除。

### Win11_24H2_Customize\System
* 放置 *.REG 註冊表文件。
* 對應註冊表路徑 HKLM\System。

### Win11_24H2_Customize\SystemMain
* 放置 *.REG 註冊表文件。
* 對應註冊表路徑 HKLM\System。

### Win11_24H2_Customize\Tweak
* 放置 *.REG 註冊表文件。
* 對應註冊表路徑 HKLM\SOFTWARE。

### Win11_24H2_Customize\User
* 放置 *.REG 註冊表文件。
* 對應註冊表路徑 HKCU。

### Win11_24H2_Customize\TweakBoot
* 放置 *.REG 註冊表文件。
* 對應註冊表路徑 HKLM\SYSTEM。
* 適用於 boot.wim 文件。

## 開始
* 請將基底或您想要更新的 install.wim 文件放置於 Win11_24H2_Customize\GAC-WIM 目錄中。
* 請將 Win11_24H2_Customize\sources\\$OEM$.7z 解壓縮至 .\sources 同目錄並刪除。
* 以系統管理員身分執行 StartGenerateInstallationMedia25H2.cmd 文件。
* 依照詢問的問題輸入正確的資料，在輸入更新套件 KB 時不需要輸入 KB 字串。如果想跳過某個更新僅需要輸入 -1 即可。
* 如果啟用 Test Mode 測試模式僅會輸出 Index 1 並使用 Fast 壓縮模式匯出 install.wim 文件。
