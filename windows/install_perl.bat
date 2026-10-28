@echo off
setlocal EnableExtensions

REM ##########################################################################
REM # Strawberry Perl standalone installer for EQEmu
REM #
REM # Installs Strawberry Perl 5.24.4.1 x64 (zone.exe needs perl524.dll) and
REM # adds its three folders to the system PATH:
REM #   C:\Strawberry\c\bin
REM #   C:\Strawberry\perl\site\bin
REM #   C:\Strawberry\perl\bin
REM # PATH is edited in the registry (no setx, which truncates to 1024 chars).
REM #
REM # Usage: right click - Run as Administrator
REM # Offline: put strawberry-perl-5.24.4.1-64bit.msi in .\downloads first.
REM ##########################################################################

set "SYS32=%SystemRoot%\System32"
set "PS=%SYS32%\WindowsPowerShell\v1.0\powershell.exe"
set "CURL=%SYS32%\curl.exe"

set "PERL_MSI=strawberry-perl-5.24.4.1-64bit.msi"
set "PERL_URL=https://strawberryperl.com/download/5.24.4.1/%PERL_MSI%"
set "PERL_ROOT=C:\Strawberry"
set "PERL_BIN=%PERL_ROOT%\perl\bin"

cd /d "%~dp0"
set "DL_DIR=%~dp0downloads"
set "LOG_DIR=%~dp0install_logs"
if not exist "%DL_DIR%" mkdir "%DL_DIR%"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

echo Administrative permissions required. Detecting permissions...
"%SYS32%\net.exe" session >nul 2>&1
if errorlevel 1 (
    echo Failed: Run install_perl.bat as Administrator - Right click - Run as Administrator
    goto :FAIL
)
echo Success: Administrative permissions confirmed.
echo.

REM --- 1. Install (skip when already installed) -------------------------------
if exist "%PERL_BIN%\perl.exe" if exist "%PERL_BIN%\perl524.dll" (
    echo [1/3] Strawberry Perl is already installed at %PERL_BIN%, skip install
    goto :SET_PATH
)

echo [1/3] Downloading and installing Strawberry Perl 5.24.4.1 x64...
call :CHECK_MSI
if errorlevel 1 (
    echo   Downloading %PERL_URL%
    if exist "%DL_DIR%\%PERL_MSI%" del /q "%DL_DIR%\%PERL_MSI%"
    "%CURL%" -fL --retry 3 -o "%DL_DIR%\%PERL_MSI%" "%PERL_URL%"
    call :CHECK_MSI
    if errorlevel 1 (
        echo   [FAIL] Download failed or the file is not a valid installer.
        echo          Download %PERL_MSI% manually into %DL_DIR% and run again.
        goto :FAIL
    )
)
echo   [OK] %DL_DIR%\%PERL_MSI%

echo   Installing... LOADING... PLEASE WAIT...
"%SYS32%\msiexec.exe" /i "%DL_DIR%\%PERL_MSI%" PERL_PATH=Yes /qn /norestart /l*v "%LOG_DIR%\perl_install.log"
set "RC=%errorlevel%"
if "%RC%"=="3010" set "RC=0"
if not "%RC%"=="0" (
    echo   [FAIL] Installer exited with code %RC%. Log: %LOG_DIR%\perl_install.log
    if "%RC%"=="1618" echo          Another installation is in progress. Wait for it to finish and run again.
    goto :FAIL
)
if not exist "%PERL_BIN%\perl524.dll" (
    echo   [FAIL] %PERL_BIN%\perl524.dll was not found after install. Log: %LOG_DIR%\perl_install.log
    goto :FAIL
)
echo   [OK] Strawberry Perl installed

REM --- 2. System PATH -------------------------------------------------------
:SET_PATH
echo.
echo [2/3] Adding Strawberry Perl to the system PATH...
call :ADD_MACHINE_PATH "%PERL_ROOT%\c\bin"
call :ADD_MACHINE_PATH "%PERL_ROOT%\perl\site\bin"
call :ADD_MACHINE_PATH "%PERL_BIN%"
if errorlevel 1 goto :FAIL

REM --- 3. Verify --------------------------------------------------------------
echo.
echo [3/3] Verifying...
"%PERL_BIN%\perl.exe" -e "print qq(  [OK] perl $^V\n)"
if errorlevel 1 (
    echo   [FAIL] perl.exe does not run.
    goto :FAIL
)
assoc .pl=Perl >nul
ftype Perl="%PERL_BIN%\perl.exe" "%%1" %%* >nul

echo.
echo #########################################################
echo #::: Strawberry Perl is ready.
echo #::: Open a NEW command prompt to pick up the updated PATH.
echo #########################################################
pause
exit /b 0

:FAIL
echo.
echo Perl installation stopped. See messages above.
pause
exit /b 1

REM ##########################################################################
REM # Subroutines
REM ##########################################################################

:CHECK_MSI
REM Valid when the file exists and is larger than 20 MB
if not exist "%DL_DIR%\%PERL_MSI%" exit /b 1
for %%A in ("%DL_DIR%\%PERL_MSI%") do if %%~zA LSS 20000000 exit /b 1
exit /b 0

:ADD_MACHINE_PATH
set "ADD_DIR=%~1"
"%PS%" -NoProfile -ExecutionPolicy Bypass -Command "$d=$env:ADD_DIR.TrimEnd('\'); $k=[Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment', $true); $p=$k.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames); $parts=@($p -split ';' | Where-Object { $_ -ne '' }); if ($parts | Where-Object { $_.TrimEnd('\') -ieq $d }) { Write-Host ('  System PATH already contains ' + $d); $k.Close(); exit 0 }; $k.SetValue('Path', (($parts + $d) -join ';'), [Microsoft.Win32.RegistryValueKind]::ExpandString); $k.Close(); [Environment]::SetEnvironmentVariable('EQEMU_INSTALL_PING', '1', 'Machine'); [Environment]::SetEnvironmentVariable('EQEMU_INSTALL_PING', $null, 'Machine'); Write-Host ('  Added to system PATH: ' + $d)"
if errorlevel 1 (
    echo   [FAIL] Could not update the system PATH for %ADD_DIR%
    exit /b 1
)
exit /b 0
