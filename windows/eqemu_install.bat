@echo off
setlocal EnableExtensions

REM ##########################################################################
REM # EQEmu Windows installer
REM #
REM # Flow:
REM #   1. Check administrator permissions
REM #   2. Detect what is already installed
REM #   3. Download ALL required installers / files and verify them
REM #      (nothing is installed if any required download fails)
REM #   4. Install in order: VC++ Redistributable -> Perl -> MariaDB
REM #      (each step is verified; on failure the script stops, it never loops)
REM #   5. Run eqemu_server.pl new_server
REM #
REM # Installers are kept in .\downloads so a re-run does not download again.
REM # To install offline, put the files (same names as below) in .\downloads.
REM ##########################################################################

if /i not "%~1"=="max" (
    start "EQEmu Installer" /MAX "%ComSpec%" /c ""%~f0" max"
    exit /b
)

REM --- Use absolute paths for system tools so a broken PATH cannot break us ---
set "SYS32=%SystemRoot%\System32"
set "PS=%SYS32%\WindowsPowerShell\v1.0\powershell.exe"
set "PATH=%SYS32%;%SystemRoot%;%SYS32%\Wbem;%SYS32%\WindowsPowerShell\v1.0;%PATH%"
set "CURL=%SYS32%\curl.exe"

REM --- Versions / URLs (edit here to upgrade) --------------------------------
set "MARIADB_VERSION=10.11.10"
set "MARIADB_MSI=mariadb-%MARIADB_VERSION%-winx64.msi"
set "MARIADB_URL=https://archive.mariadb.org/mariadb-%MARIADB_VERSION%/winx64-packages/%MARIADB_MSI%"
set "MARIADB_DIR=%ProgramFiles%\MariaDB 10.11"
set "MARIADB_SERVICE=MySQL"
set "MARIADB_PORT=3306"
set "MARIADB_ROOT_PASSWORD=eqemu"

set "PERL_MSI=strawberry-perl-5.24.4.1-64bit.msi"
set "PERL_URL=https://strawberryperl.com/download/5.24.4.1/%PERL_MSI%"
set "PERL_BIN=C:\Strawberry\perl\bin"

set "VCREDIST_EXE=vc_redist.x64.exe"
set "VCREDIST_URL=https://aka.ms/vs/17/release/vc_redist.x64.exe"

set "EQEMU_SERVER_PL_URL=https://raw.githubusercontent.com/tb-coding/eqemu-install-v2/main/eqemu_server.pl"

REM Optional SHA256 checksums (leave empty to skip the comparison;
REM the computed hash is always printed so it can be pinned here later).
set "MARIADB_SHA256="
set "PERL_SHA256="
set "VCREDIST_SHA256="

REM --- Folders ---------------------------------------------------------------
cd /d "%~dp0"
set "INSTALL_DIR=%~dp0"
REM Server folder: this folder (e.g. C:\EQEmu prepared by eqemu_setup.bat),
REM or .\server when run from inside the repository (keeps new_server away from repo files)
if not defined EQEMU_SERVER_DIR (
    if exist "%~dp0..\eqemu_config.json" (
        set "EQEMU_SERVER_DIR=%~dp0server"
    ) else (
        set "EQEMU_SERVER_DIR=%~dp0."
    )
)
set "SERVER_DIR=%EQEMU_SERVER_DIR%\"
if not exist "%SERVER_DIR%" mkdir "%SERVER_DIR%"
set "DL_DIR=%~dp0downloads"
set "LOG_DIR=%~dp0install_logs"
if not exist "%DL_DIR%" mkdir "%DL_DIR%"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

REM ##########################################################################
REM # 1. Administrator permissions
REM ##########################################################################
echo Administrative permissions required. Detecting permissions...
"%SYS32%\net.exe" session >nul 2>&1
if errorlevel 1 (
    echo Failed: Run eqemu_install.bat as Administrator - Right click - Run as Administrator
    goto :FAIL
)
echo Success: Administrative permissions confirmed.

echo #########################################################
echo #::: EverQuest Emulator Modular Installer
echo #::: Installer Author^(s^): Akkadius, Ali
echo #:::
echo #::: EQEmulator Server Software is developed and maintained
echo #:::   by the EQEmulator Developement team
echo #:::
echo #::: Everquest is a registered trademark
echo #::: Daybreak Game Company LLC.
echo #:::
echo #::: EQEmulator is not associated or
echo #::: affiliated in any way with Daybreak Game Company LLC.
echo #########################################################
echo :
echo #########################################################
echo #::: To be installed:
echo #########################################################
echo - Server running folder - Will be installed to the folder you ran this script
echo - Visual C++ Redistributable x64 (latest)
echo - MariaDB x64 %MARIADB_VERSION% (MySQL) - Database engine
echo - Heidi SQL (Comes with MariaDB)
echo - Perl x64 5.24.4.1 :: Scripting language for quest engines
echo - LUA Configured :: Scripting language for quest engines
echo - Latest PEQ Database
echo - Latest PEQ Quests
echo - Latest Plugins repository
echo - Automatically added Firewall rules
echo - Maps (Latest V2) formats are loaded
echo - New Path files are loaded
echo - Optimized server binaries
echo #########################################################
echo Install folder : %INSTALL_DIR%
echo Server folder  : %SERVER_DIR%
echo Downloads      : %DL_DIR%
echo Logs           : %LOG_DIR%
echo #########################################################

REM ##########################################################################
REM # 2. Detect what is already installed
REM ##########################################################################
echo.
echo [1/4] Detecting installed software...

REM Always install / upgrade the VC++ runtime: an old 14.x runtime may be present
REM but too old for current binaries. The installer returns 1638 if a newer one exists.
set "NEED_VCREDIST=1"
echo   - VC++ Redistributable x64 : will install or upgrade to latest

set "NEED_PERL=1"
if exist "%PERL_BIN%\perl.exe" set "NEED_PERL="
if defined NEED_PERL (echo   - Strawberry Perl         : not installed) else (echo   - Strawberry Perl         : already installed at %PERL_BIN%, skip)

call :DETECT_MARIADB
set "NEED_MARIADB=1"
if defined MARIADB_BIN set "NEED_MARIADB="
if defined MARIADB_BIN goto :DETECT_MARIADB_DONE
"%SYS32%\sc.exe" query "%MARIADB_SERVICE%" >nul 2>&1
if errorlevel 1 goto :DETECT_MARIADB_DONE
echo.
echo [FAIL] A Windows service named "%MARIADB_SERVICE%" already exists but no MariaDB
echo        installation was found under "%ProgramFiles%\MariaDB *".
echo        It is probably MySQL or another database using the same service name / port.
echo        Uninstall it or stop and remove the service first, then run this script again.
goto :FAIL
:DETECT_MARIADB_DONE
if defined NEED_MARIADB (echo   - MariaDB                 : not installed) else (echo   - MariaDB                 : already installed at %MARIADB_BIN%, skip)

REM ##########################################################################
REM # 3. Download everything first, verify it, and only then install
REM ##########################################################################
echo.
echo [2/4] Downloading and verifying required files...

if not exist "%CURL%" echo   curl.exe not found, falling back to PowerShell downloads.

if not defined NEED_VCREDIST goto :DL_PERL
call :DOWNLOAD "VC++ Redistributable" "%VCREDIST_URL%" "%DL_DIR%\%VCREDIST_EXE%" 10000000 exe "%VCREDIST_SHA256%"
if errorlevel 1 goto :DOWNLOAD_FAILED

:DL_PERL
if not defined NEED_PERL goto :DL_MARIADB
call :DOWNLOAD "Strawberry Perl" "%PERL_URL%" "%DL_DIR%\%PERL_MSI%" 20000000 msi "%PERL_SHA256%"
if errorlevel 1 goto :DOWNLOAD_FAILED

:DL_MARIADB
if not defined NEED_MARIADB goto :DL_EQEMU_SERVER
call :DOWNLOAD "MariaDB %MARIADB_VERSION%" "%MARIADB_URL%" "%DL_DIR%\%MARIADB_MSI%" 20000000 msi "%MARIADB_SHA256%"
if errorlevel 1 goto :DOWNLOAD_FAILED

:DL_EQEMU_SERVER
set "HAVE_SERVER_PL=1"
if exist "%SERVER_DIR%eqemu_server.pl" (
    echo   [OK] eqemu_server.pl : already present
    goto :DOWNLOADS_DONE
)
call :DOWNLOAD "eqemu_server.pl" "%EQEMU_SERVER_PL_URL%" "%SERVER_DIR%eqemu_server.pl" 1000 text ""
if not errorlevel 1 goto :DOWNLOADS_DONE
set "HAVE_SERVER_PL="
echo.
echo [WARN] eqemu_server.pl could not be downloaded from:
echo        %EQEMU_SERVER_PL_URL%
echo        The server setup step ^(new_server^) will be skipped.
echo        Put eqemu_server.pl into %SERVER_DIR%, or set EQEMU_SERVER_PL_URL, and re-run later.
"%SYS32%\choice.exe" /c YN /m "Continue and install the prerequisites (VC++, Perl, MariaDB) only"
if errorlevel 2 goto :FAIL

:DOWNLOADS_DONE
echo   All required files are downloaded and verified.

REM ##########################################################################
REM # 4. Install, in order, verifying each step
REM ##########################################################################
echo.
echo [3/4] Installing...

if not defined NEED_VCREDIST goto :INSTALL_PERL
echo   Installing Visual C++ Redistributable x64...
"%DL_DIR%\%VCREDIST_EXE%" /install /passive /norestart /log "%LOG_DIR%\vc_redist.log"
set "RC=%errorlevel%"
if "%RC%"=="0" goto :VCREDIST_OK
if "%RC%"=="3010" goto :VCREDIST_OK
if "%RC%"=="1638" goto :VCREDIST_OK
echo   [FAIL] VC++ Redistributable installer exited with code %RC%. Log: %LOG_DIR%\vc_redist.log
goto :FAIL
:VCREDIST_OK
echo   [OK] Visual C++ Redistributable x64

:INSTALL_PERL
if not defined NEED_PERL goto :PERL_READY
echo   Installing Strawberry Perl... LOADING... PLEASE WAIT...
"%SYS32%\msiexec.exe" /i "%DL_DIR%\%PERL_MSI%" PERL_PATH=Yes /qn /norestart /l*v "%LOG_DIR%\perl_install.log"
set "RC=%errorlevel%"
call :CHECK_MSI_RC "Strawberry Perl" "%LOG_DIR%\perl_install.log"
if errorlevel 1 goto :FAIL
if not exist "%PERL_BIN%\perl.exe" (
    echo   [FAIL] Perl installer finished but %PERL_BIN%\perl.exe was not found. Log: %LOG_DIR%\perl_install.log
    goto :FAIL
)
echo   [OK] Strawberry Perl
:PERL_READY
set "PATH=%PATH%;C:\Strawberry\c\bin;C:\Strawberry\perl\site\bin;C:\Strawberry\perl\bin"
assoc .pl=Perl >nul
ftype Perl="%PERL_BIN%\perl.exe" "%%1" %%* >nul

if not defined NEED_MARIADB goto :MARIADB_READY
echo   Installing MariaDB %MARIADB_VERSION% (Root Password: %MARIADB_ROOT_PASSWORD%) LOADING... PLEASE WAIT...
"%SYS32%\msiexec.exe" /i "%DL_DIR%\%MARIADB_MSI%" INSTALLDIR="%MARIADB_DIR%" SERVICENAME=%MARIADB_SERVICE% PORT=%MARIADB_PORT% PASSWORD=%MARIADB_ROOT_PASSWORD% /qn /norestart /l*v "%LOG_DIR%\mariadb_install.log"
set "RC=%errorlevel%"
call :CHECK_MSI_RC "MariaDB" "%LOG_DIR%\mariadb_install.log"
if errorlevel 1 goto :FAIL
call :DETECT_MARIADB
if not defined MARIADB_BIN (
    echo   [FAIL] MariaDB installer finished but mysql.exe was not found under %MARIADB_DIR%\bin. Log: %LOG_DIR%\mariadb_install.log
    goto :FAIL
)
echo   [OK] MariaDB installed at %MARIADB_BIN%

:MARIADB_READY
REM Add MariaDB to the system PATH without setx (setx truncates to 1024 chars)
call :ADD_MACHINE_PATH "%MARIADB_BIN%"
set "PATH=%PATH%;%MARIADB_BIN%"

echo   Verifying MariaDB service and root login...
"%SYS32%\sc.exe" query "%MARIADB_SERVICE%" | "%SYS32%\find.exe" "RUNNING" >nul
if errorlevel 1 "%SYS32%\net.exe" start "%MARIADB_SERVICE%" >nul 2>&1
"%MARIADB_BIN%\mysql.exe" -uroot -p%MARIADB_ROOT_PASSWORD% -e "SELECT VERSION();" >nul 2>&1
if errorlevel 1 (
    echo   [FAIL] Cannot log in to MariaDB as root with the configured password.
    echo          If MariaDB was installed before with another root password,
    echo          update install_variables.txt / eqemu_config.json accordingly.
    goto :FAIL
)
echo   [OK] MariaDB service is running and root login works

REM ##########################################################################
REM # 5. EQEmu server setup
REM ##########################################################################
echo.
echo [4/4] EQEmu server setup...
if not defined HAVE_SERVER_PL (
    echo   [SKIP] eqemu_server.pl is not available. Prerequisites are installed.
    goto :DONE
)
REM eqemu_server.pl reads the database credentials from install_variables.txt
if not exist "%SERVER_DIR%install_variables.txt" (
    > "%SERVER_DIR%install_variables.txt" (
        echo mysql_root:%MARIADB_ROOT_PASSWORD%
        echo mysql_eqemu_db_name:peq
        echo mysql_eqemu_user:root
        echo mysql_eqemu_password:%MARIADB_ROOT_PASSWORD%
    )
)
cd /d "%SERVER_DIR%"
"%PERL_BIN%\perl.exe" eqemu_server.pl new_server
if errorlevel 1 (
    echo   [FAIL] eqemu_server.pl new_server exited with an error.
    goto :FAIL
)

:DONE
echo.
echo #########################################################
echo #::: Installation finished.
echo #::: Open a NEW command prompt to pick up the updated PATH.
echo #########################################################
pause
exit /b 0

:DOWNLOAD_FAILED
echo.
echo [FAIL] A required download failed. Nothing has been installed.
echo        Check your network, or download the file manually into:
echo        %DL_DIR%
echo        and run this script again.
goto :FAIL

:FAIL
echo.
echo Installation stopped. See messages above and logs in %LOG_DIR%
pause
exit /b 1

REM ##########################################################################
REM # Subroutines
REM ##########################################################################

REM Sets MARIADB_BIN to the bin folder of an installed MariaDB, or clears it.
:DETECT_MARIADB
set "MARIADB_BIN="
if exist "%MARIADB_DIR%\bin\mysql.exe" (
    set "MARIADB_BIN=%MARIADB_DIR%\bin"
    exit /b 0
)
for /d %%D in ("%ProgramFiles%\MariaDB *") do if exist "%%~D\bin\mysql.exe" set "MARIADB_BIN=%%~D\bin"
exit /b 0

REM :DOWNLOAD "name" "url" "target file" min_bytes kind(msi|exe|json|text) "sha256"
:DOWNLOAD
set "DL_NAME=%~1"
set "DL_URL=%~2"
set "DL_FILE=%~3"
set "DL_MIN=%~4"
set "DL_KIND=%~5"
set "DL_SHA=%~6"
if not exist "%DL_FILE%" goto :DOWNLOAD_FETCH
call :VERIFY
if errorlevel 1 goto :DOWNLOAD_STALE
echo   [OK] %DL_NAME% : using existing %DL_FILE%
exit /b 0
:DOWNLOAD_STALE
echo   [WARN] Existing %DL_FILE% failed verification, downloading again.
del /f /q "%DL_FILE%" >nul 2>&1
:DOWNLOAD_FETCH
echo   Downloading %DL_NAME% ...
echo     %DL_URL%
if exist "%DL_FILE%.part" del /f /q "%DL_FILE%.part" >nul 2>&1
if exist "%CURL%" (
    "%CURL%" -fL --retry 3 --retry-delay 5 --connect-timeout 30 -o "%DL_FILE%.part" "%DL_URL%"
) else (
    "%PS%" -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -UseBasicParsing -Uri $env:DL_URL -OutFile ($env:DL_FILE + '.part') } catch { Write-Host $_.Exception.Message; exit 1 }"
)
if errorlevel 1 goto :DOWNLOAD_ERROR
if not exist "%DL_FILE%.part" goto :DOWNLOAD_ERROR
move /y "%DL_FILE%.part" "%DL_FILE%" >nul
call :VERIFY
if errorlevel 1 (
    del /f /q "%DL_FILE%" >nul 2>&1
    echo   [FAIL] %DL_NAME% : downloaded file failed verification.
    exit /b 1
)
echo   [OK] %DL_NAME%
exit /b 0
:DOWNLOAD_ERROR
if exist "%DL_FILE%.part" del /f /q "%DL_FILE%.part" >nul 2>&1
echo   [FAIL] %DL_NAME% : download failed.
exit /b 1

REM Verifies DL_FILE: minimum size, file signature (MSI / EXE / JSON) and optional SHA256.
:VERIFY
"%PS%" -NoProfile -ExecutionPolicy Bypass -Command "$f=$env:DL_FILE; $i=Get-Item -LiteralPath $f; if ($i.Length -lt [int64]$env:DL_MIN) { Write-Host ('    too small: ' + $i.Length + ' bytes'); exit 1 }; $s=[IO.File]::OpenRead($f); $b=New-Object byte[] 8; [void]$s.Read($b,0,8); $s.Close(); $hex=($b | ForEach-Object { $_.ToString('X2') }) -join ''; if ($env:DL_KIND -eq 'msi' -and $hex -ne 'D0CF11E0A1B11AE1') { Write-Host '    not a valid MSI file'; exit 1 }; if ($env:DL_KIND -eq 'exe' -and -not $hex.StartsWith('4D5A')) { Write-Host '    not a valid EXE file'; exit 1 }; if ($env:DL_KIND -eq 'json' -and ((Get-Content -LiteralPath $f -Raw).TrimStart())[0] -ne '{') { Write-Host '    not a JSON file'; exit 1 }; $h=(Get-FileHash -Algorithm SHA256 -LiteralPath $f).Hash; Write-Host ('    SHA256 ' + $h); if ($env:DL_SHA -and $h -ne $env:DL_SHA.ToUpper()) { Write-Host ('    expected ' + $env:DL_SHA); exit 1 }; exit 0"
exit /b %errorlevel%

REM Checks RC from msiexec. 0 = OK, 3010 = OK (reboot required).
:CHECK_MSI_RC
if "%RC%"=="0" exit /b 0
if "%RC%"=="3010" (
    echo   [OK] %~1 installed ^(a reboot is required later^)
    exit /b 0
)
if "%RC%"=="1618" (
    echo   [FAIL] %~1 : another installation is in progress. Wait for it to finish and run again.
    exit /b 1
)
echo   [FAIL] %~1 installer exited with code %RC%. Log: %~2
exit /b 1

REM Appends a folder to the system (Machine) PATH if missing.
REM Reads the raw registry value so the user PATH is not merged in and
REM %%VARIABLES%% are kept, and writes it back without any length limit.
:ADD_MACHINE_PATH
set "ADD_DIR=%~1"
"%PS%" -NoProfile -ExecutionPolicy Bypass -Command "$d=$env:ADD_DIR.TrimEnd('\'); $k=[Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment', $true); $p=$k.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames); $parts=@($p -split ';' | Where-Object { $_ -ne '' }); if ($parts | Where-Object { $_.TrimEnd('\') -ieq $d }) { Write-Host ('  System PATH already contains ' + $d); $k.Close(); exit 0 }; $k.SetValue('Path', (($parts + $d) -join ';'), [Microsoft.Win32.RegistryValueKind]::ExpandString); $k.Close(); [Environment]::SetEnvironmentVariable('EQEMU_INSTALL_PING', '1', 'Machine'); [Environment]::SetEnvironmentVariable('EQEMU_INSTALL_PING', $null, 'Machine'); Write-Host ('  Added to system PATH: ' + $d)"
exit /b 0
