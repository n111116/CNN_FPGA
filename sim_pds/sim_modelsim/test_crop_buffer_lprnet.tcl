transcript on

if {![info exists SCRIPT_DIR]} {
    set SCRIPT_DIR [file dirname [info script]]
}
if {![info exists ROOT_DIR]} {
    set ROOT_DIR [file join $SCRIPT_DIR ../..]
}
cd $SCRIPT_DIR

if {[file exists rtl_work_crop_lprnet]} {
    vdel -lib rtl_work_crop_lprnet -all
}
vlib rtl_work_crop_lprnet
vmap work rtl_work_crop_lprnet

set INC_HEADER_PATH [file join $ROOT_DIR rtl_pds data_process header]
set INC_RTL_PATH    [file join $ROOT_DIR rtl_pds]
set MEM_DATA_PATH   "mem_data/"
set RTL_DATA_FILES  [glob [file join $ROOT_DIR rtl_pds data_process *.sv]]

vlog -work rtl_work_crop_lprnet -sv \
    +incdir+$INC_HEADER_PATH \
    +incdir+$INC_RTL_PATH \
    +define+DATA_PATH="$MEM_DATA_PATH" \
    {*}$RTL_DATA_FILES \
    [file join $ROOT_DIR rtl_pds my_fifo.sv] \
    [file join $ROOT_DIR rtl_pds overlay crop_buffer_manager.sv] \
    [file join $ROOT_DIR rtl_pds top_lprnet.sv] \
    [file join $ROOT_DIR sim_pds tb_crop_buffer_lprnet.sv]

vsim -t 1ns -L rtl_work_crop_lprnet -L work -voptargs="+acc" tb_crop_buffer_lprnet
run -all
