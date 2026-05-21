@echo off
REM Wrapper to fix PATH so flutter.bat finds where.exe/git/powershell when invoked from non-Windows shells.
set "PATH=C:\Windows\System32;C:\Windows\System32\WindowsPowerShell\v1.0;C:\tools\flutter\bin;C:\Program Files\Git\cmd;%PATH%"
flutter %*
