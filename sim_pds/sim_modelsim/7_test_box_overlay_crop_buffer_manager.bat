@echo off
cd /d "%~dp0"
set "SIM_DIR=%~dp0"
for %%I in ("%~dp0..\..") do set "ROOT_DIR=%%~fI"
set "SIM_DIR=%SIM_DIR:\=/%"
set "ROOT_DIR=%ROOT_DIR:\=/%"
vsim -c -do "set SCRIPT_DIR {%SIM_DIR%}; set ROOT_DIR {%ROOT_DIR%}; cd {%SIM_DIR%.}; do {test_box_overlay_crop_buffer_manager.tcl}; quit -f"
