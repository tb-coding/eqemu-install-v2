@echo off
cls
cd /d "%~dp0"
REM Strawberry Perl must be on PATH: perl.exe for the scripts and perl524.dll for zone.exe
where perl >nul 2>&1 || set "PATH=C:\Strawberry\perl\bin;C:\Strawberry\perl\site\bin;C:\Strawberry\c\bin;%PATH%"
if exist "logs\zone\" del /q "logs\zone\*"

reg add HKCU\Console /v QuickEdit /t REG_DWORD /d 0 /f

if exist bin/shared_memory.exe (
    "bin/shared_memory.exe"
) else (
    shared_memory.exe
)

start "EQEmu Server" perl win_server_launcher.pl zones="30" zone_background_start kill_all_on_start
exit
