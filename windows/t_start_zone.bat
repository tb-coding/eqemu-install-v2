:: For development purposes

@echo off
cls
cd /d "%~dp0"
REM Strawberry Perl must be on PATH: perl.exe for the scripts and perl524.dll for zone.exe
where perl >nul 2>&1 || set "PATH=C:\Strawberry\perl\bin;C:\Strawberry\perl\site\bin;C:\Strawberry\c\bin;%PATH%"
start bin/zone.exe
exit
