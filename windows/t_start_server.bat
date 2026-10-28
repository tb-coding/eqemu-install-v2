@echo off
cls
cd /d "%~dp0"
if exist "logs\zone\" del /q "logs\zone\*"

reg add HKCU\Console /v QuickEdit /t REG_DWORD /d 0 /f

if exist bin/shared_memory.exe (
    "bin/shared_memory.exe"
) else (
    shared_memory.exe
)

REM Use perl from PATH, or Strawberry Perl when PATH has not been updated
set "PERL=perl"
where perl >nul 2>&1 || set "PERL=C:\Strawberry\perl\bin\perl.exe"
start "EQEmu Server" "%PERL%" win_server_launcher.pl zones="30" zone_background_start kill_all_on_start
exit
