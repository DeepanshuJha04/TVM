@echo off
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0dotNET_Cleanup_SCCM_Package_Local_Copy.ps1" -Mode Install
exit /b %errorlevel%
