@echo off
cls
echo *** CLEARING OLD LOGS ***
cd /d "%~dp0"
REM Always put Strawberry Perl first on PATH: perl.exe for the scripts and perl524.dll for zone.exe
if exist "C:\Strawberry\perl\bin\perl524.dll" set "PATH=C:\Strawberry\perl\bin;C:\Strawberry\perl\site\bin;C:\Strawberry\c\bin;%PATH%"
if exist "logs\zone\" del /q "logs\zone\*"

reg add HKCU\Console /v QuickEdit /t REG_DWORD /d 0 /f

if exist bin/shared_memory.exe (
    "bin/shared_memory.exe"
) else (
    shared_memory.exe
)

start "EQEmu Server" perl win_server_launcher.pl zones="30" zone_background_start loginserver kill_all_on_start
exit
