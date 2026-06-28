@echo off
setlocal

cd /d "%~dp0"
set LOG_FILE=ddr_video_delay_sync_pds_ip_smoke.log

echo [BAT] Running PDS DDR IP co-sim smoke test...
echo [BAT] Working directory: %CD%
echo [BAT] Log file: %CD%\%LOG_FILE%
echo.

vsim -c -l "%LOG_FILE%" -do "do ./test_ddr_video_delay_sync_pds_ip.tcl"
set SIM_RC=%ERRORLEVEL%

echo.
if "%SIM_RC%"=="0" (
    echo [BAT] PASS: PDS DDR IP smoke simulation completed.
) else (
    echo [BAT] FAIL: PDS DDR IP smoke simulation returned code %SIM_RC%.
)
echo [BAT] Full transcript: %CD%\%LOG_FILE%
echo.
pause
exit /b %SIM_RC%
