# EQEmuInstall 
- A repository for serving basic EQEmulator Server install needs

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
| 自我更新 | 下載上游 eqemu_server.pl | 停用(上游檔案已刪,wget 會存成空檔並覆蓋本檔) |

未驗證:PEQ 資料庫 `http://db.projecteq.net/api/v1/dump/latest` 與任務腳本 `codeload.github.com/ProjectEQ/projecteqquests`。

### 使用注意

- `new_server` 要求資料夾內檔案不超過 4 個(或已有 `install_variables.txt`),否則會報「must run in an empty directory」。
- 會先 DROP 再 CREATE 你輸入的資料庫名稱,請勿填既有資料庫。
- Windows 執行檔會下載上游最新 release 放到 `bin/`;若要用自己編譯的版本,裝完後以自己的建置輸出覆蓋 `bin/`。
