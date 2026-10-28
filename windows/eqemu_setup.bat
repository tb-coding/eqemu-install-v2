@echo off
setlocal EnableExtensions

REM ##########################################################################
REM # EQEmu Windows setup helper
REM #
REM # Prepares the server folder (default C:\EQEmu), copies the files the
REM # installer needs into it, then starts eqemu_install.bat from there.
REM #
REM # Usage (right click - Run as Administrator):
REM #   eqemu_setup.bat              installs to C:\EQEmu
REM #   eqemu_setup.bat D:\EQEmu     installs to another folder
REM ##########################################################################

set "SYS32=%SystemRoot%\System32"
set "SRC=%~dp0"
set "TARGET=%~1"
if "%TARGET%"=="" set "TARGET=C:\EQEmu"
if "%TARGET:~-1%"=="\" set "TARGET=%TARGET:~0,-1%"

echo Administrative permissions required. Detecting permissions...
"%SYS32%\net.exe" session >nul 2>&1
if errorlevel 1 (
    echo Failed: Run eqemu_setup.bat as Administrator - Right click - Run as Administrator
    pause
    exit /b 1
)
echo Success: Administrative permissions confirmed.
echo.
echo Server folder : %TARGET%
echo Source folder : %SRC%
echo.

if not exist "%SRC%eqemu_install.bat" (
    echo [FAIL] eqemu_install.bat not found next to this script.
    pause
    exit /b 1
)

REM new_server needs a fresh folder; refuse to reuse one that already has a server
if exist "%TARGET%\eqemu_config.json" (
    echo [FAIL] %TARGET% already contains an EQEmu server ^(eqemu_config.json^).
    echo        Use another folder: eqemu_setup.bat D:\EQEmu
    pause
    exit /b 1
)

if not exist "%TARGET%" mkdir "%TARGET%"
if not exist "%TARGET%" (
    echo [FAIL] Cannot create %TARGET%
    pause
    exit /b 1
)

echo Copying installer files...
copy /y "%SRC%eqemu_install.bat" "%TARGET%\" >nul || goto :COPY_FAILED
echo   [OK] eqemu_install.bat

REM Prefer the eqemu_server.pl from this repository so no download is needed
if exist "%SRC%..\eqemu_server.pl" (
    copy /y "%SRC%..\eqemu_server.pl" "%TARGET%\" >nul || goto :COPY_FAILED
    echo   [OK] eqemu_server.pl
) else (
    echo   [--] eqemu_server.pl not found in the repository, the installer will download it
)

REM Reuse installers already downloaded by an earlier run
if exist "%SRC%downloads\*" (
    if not exist "%TARGET%\downloads" mkdir "%TARGET%\downloads"
    copy /y "%SRC%downloads\*" "%TARGET%\downloads\" >nul || goto :COPY_FAILED
    echo   [OK] downloads\ ^(cached installers^)
)

echo.
echo Starting %TARGET%\eqemu_install.bat ...
cd /d "%TARGET%"
set "EQEMU_SERVER_DIR=%TARGET%"
call "%TARGET%\eqemu_install.bat"
exit /b 0

:COPY_FAILED
echo [FAIL] Copy to %TARGET% failed.
pause
exit /b 1
