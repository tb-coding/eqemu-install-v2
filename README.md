# EQEmuInstall 
- A repository for serving basic EQEmulator Server install needs

## Windows 安裝(已驗證)

2026-10-28 在 Windows 11 上依下列步驟安裝並成功啟動伺服器(MariaDB 10.11.10、Strawberry Perl 5.24.4.1 x64、EQEmu/EQEmu 最新 release 執行檔)。

### 步驟

1. 取得本 repo(`git clone` 或下載 zip),進入 `windows\` 資料夾。
2. 以**系統管理員身分**執行 `eqemu_setup.bat`。
   - 會建立 `C:\EQEmu`(可用第一個參數指定其他資料夾,例如 `eqemu_setup.bat D:\EQEmu`),複製 `eqemu_install.bat`、`eqemu_server.pl` 與 `downloads\` 內已下載的安裝檔,再從該資料夾啟動 `eqemu_install.bat`。
   - 目標資料夾已有 `eqemu_config.json` 時會停止,避免覆蓋既有伺服器。
3. `eqemu_install.bat` 依序完成:
   - 安裝 VC++ Redistributable、Strawberry Perl、MariaDB(root 密碼 `eqemu`、連接埠 3306、服務名稱 `MySQL`),已安裝者略過,並把路徑寫入系統 PATH(不使用 setx)。
   - 產生 `install_variables.txt`,執行 `perl eqemu_server.pl new_server`:下載執行檔、地圖、opcodes、任務腳本、plugins、lua modules,建立 `peq` 資料庫並匯入 PEQ 資料,加入防火牆規則,安裝 loginserver 資料表與設定。
   - 最後顯示安裝摘要(資料庫帳密等),按任意鍵結束,看到 `Installation finished.` 即完成。
4. 開一個**新的**命令提示字元(才會套用新的 PATH),執行 `C:\EQEmu\t_start_server.bat` 啟動伺服器。world 第一次啟動會自動執行資料庫 migration。
5. 停止伺服器:`C:\EQEmu\t_stop_server.bat`。

### 疑難排解

| 狀況 | 處理方式 |
|---|---|
| 「Windows 找不到 'perl'」或 zone.exe「找不到 perl524.dll」 | 以系統管理員身分執行 `windows\install_perl.bat`:安裝 Strawberry Perl 5.24.4.1 x64 並把 `C:\Strawberry\c\bin`、`C:\Strawberry\perl\site\bin`、`C:\Strawberry\perl\bin` 寫入系統 PATH。舊的 `t_*.bat` 請改用本 repo 最新版(會自動把 Strawberry Perl 放到 PATH 最前面)。 |
| PEQ 資料庫下載失敗 | 腳本會依序嘗試多個來源(見下方說明);全部失敗時,手動下載 `peq-latest.zip` 放到 `C:\EQEmu` 再重跑。 |
| 安裝中途失敗後重跑 | 刪除 `C:\EQEmu\eqemu_server.pl`(會重新下載最新版);想跳過約 1 GB 的地圖下載可建立空檔 `C:\EQEmu\eqemu_server_skip_maps_update.txt`;再以系統管理員身分執行 `C:\EQEmu\eqemu_install.bat`。 |
| 防火牆步驟顯示亂碼 | 是 `netsh` 中文輸出「確定。」的編碼問題,規則已成功加入。 |
| 啟動時「系統找不到指定的路徑」 | 舊版 `t_start_server.bat` 清除不存在的 `logs/zone` 所致,不影響啟動;新版已修正。 |

> 安全提醒:MariaDB root 預設密碼為 `eqemu`,伺服器若對外開放請更改;伺服器名稱等設定在 `C:\EQEmu\eqemu_config.json`。

## eqemu_server.pl

上游已刪除 `eqemu_server.pl`(EQEmu/EQEmu 2024-02-10, #4049),此 repo 保留刪除前最後一版(最後修改 2023-06-19),並修正已失效的下載網址。
`windows/eqemu_install.bat` 會從本 repo 下載它並執行 `perl eqemu_server.pl new_server`。

### 相對上游原檔的修改(皆標註 `# tb-coding:`)

| 項目 | 原網址 | 改為 |
|---|---|---|
| 安裝範本(eqemu_config.json、t_*.bat、wget.exe) | Akkadius/eqemu-install-v2 master(已刪) | tb-coding/eqemu-install-v2 main |
| opcodes、loginserver 檔案 | EQEmu/Server master | EQEmu/EQEmu master(改名後) |
| Windows 執行檔 zip | eqemu/server releases | EQEmu/EQEmu releases latest |
| 地圖 maps.zip | Akkadius/eqemu-maps(已刪) | EQEmu/maps releases latest(約 1 GB,結構相同) |
| 上層設定檔切換 | 上層有 eqemu_config.json 就切到上層 | `new_server` 或目前資料夾已有設定檔時不切換 |
| 等待按鍵 | `<>`(會把參數 new_server 當檔案開啟) | `<STDIN>`;空資料夾檢查失敗改回傳 exit 1 |
| 自我更新 | 下載上游 eqemu_server.pl | 停用(上游檔案已刪,wget 會存成空檔並覆蓋本檔) |

PEQ 資料庫依序嘗試 `db.eqemu.dev`、`db.projecteq.net`、`peqarchive/peqdatabase`(2025-09-28 封存),並檢查下載結果是否為有效 zip;也可把自行下載的 `peq-latest.zip` 放在伺服器資料夾優先使用。

### 使用注意

- 直接在 repo 的 `windows\` 執行 `eqemu_install.bat` 時,伺服器會裝在 `windows\server\`;放在其他資料夾執行時就裝在該資料夾。可用環境變數 `EQEMU_SERVER_DIR` 指定位置。批次檔會依 MariaDB 密碼產生 `install_variables.txt`。
- 手動執行 `new_server` 時,資料夾內檔案不可超過 4 個(或已有 `install_variables.txt`),否則會報「must run in an empty directory」。
- 會先 DROP 再 CREATE 你輸入的資料庫名稱,請勿填既有資料庫。
- Windows 執行檔會下載上游最新 release 放到 `bin/`;若要用自己編譯的版本,裝完後以自己的建置輸出覆蓋 `bin/`。
