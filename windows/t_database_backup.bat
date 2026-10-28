@echo off
cd /d "%~dp0"
REM Use perl from PATH, or Strawberry Perl when PATH has not been updated
set "PERL=perl"
where perl >nul 2>&1 || set "PERL=C:\Strawberry\perl\bin\perl.exe"
"%PERL%" eqemu_server.pl backup_database_compressed
echo Database backup should be contained in backups folder...
explorer backups
pause
