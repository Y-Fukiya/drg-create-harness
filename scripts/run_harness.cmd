@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
Rscript "%SCRIPT_DIR%run_harness.R" %*
exit /b %ERRORLEVEL%
