@echo off
cd /d "%~dp0"
set "SIM_DIR=%~dp0"
for %%I in ("%~dp0..\..") do set "ROOT_DIR=%%~fI"
if not exist "mem_data" mkdir "mem_data"
copy /Y "%ROOT_DIR%\rtl_pds\data_process\mem_data\*.mem" "mem_data\" >nul
set "SIM_DIR=%SIM_DIR:\=/%"
set "ROOT_DIR=%ROOT_DIR:\=/%"
vsim -c -do "set SCRIPT_DIR {%SIM_DIR%}; set ROOT_DIR {%ROOT_DIR%}; cd {%SIM_DIR%.}; do {test_top_lprnet_syntax.tcl}; quit -f"
