transcript on

if {![info exists SCRIPT_DIR]} {
    set SCRIPT_DIR [file dirname [info script]]
}
if {![info exists ROOT_DIR]} {
    set ROOT_DIR [file join $SCRIPT_DIR ../..]
}
cd $SCRIPT_DIR

if {[file exists rtl_work_top_lprnet]} {
    vdel -lib rtl_work_top_lprnet -all
}
vlib rtl_work_top_lprnet
vmap work rtl_work_top_lprnet

set INC_HEADER_PATH [file join $ROOT_DIR rtl_pds data_process header]
set INC_RTL_PATH    [file join $ROOT_DIR rtl_pds]
set MEM_DATA_PATH   "mem_data/"
set RTL_FILES       [glob [file join $ROOT_DIR rtl_pds data_process *.sv]]

vlog -work rtl_work_top_lprnet -sv \
    +incdir+$INC_HEADER_PATH \
    +incdir+$INC_RTL_PATH \
    +define+DATA_PATH="$MEM_DATA_PATH" \
    {*}$RTL_FILES \
    [file join $ROOT_DIR rtl_pds top_lprnet.sv]

puts "top_lprnet syntax compile finished."
