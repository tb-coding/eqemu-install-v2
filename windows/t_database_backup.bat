@echo off
cd /d "%~dp0"
REM Always put Strawberry Perl first on PATH: perl.exe for the scripts and perl524.dll for zone.exe
if exist "C:\Strawberry\perl\bin\perl524.dll" set "PATH=C:\Strawberry\perl\bin;C:\Strawberry\perl\site\bin;C:\Strawberry\c\bin;%PATH%"
perl eqemu_server.pl backup_database_compressed
echo Database backup should be contained in backups folder...
explorer backups
pause
