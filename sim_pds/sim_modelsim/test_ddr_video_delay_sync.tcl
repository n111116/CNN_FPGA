transcript on

set WORK_LIB rtl_work_ddr_video_delay_sync

if {[file exists $WORK_LIB]} {
    vdel -lib $WORK_LIB -all
}
vlib $WORK_LIB
vmap work $WORK_LIB

vlog -work $WORK_LIB -sv \
    ../ddr3_test_axi_model.sv \
    ../../rtl_pds/ddr/wr_cmd_trans.v \
    ../../rtl_pds/ddr/wr_ctrl.v \
    ../../rtl_pds/ddr/rd_ctrl.v \
    ../../rtl_pds/ddr/wr_rd_ctrl_top.v \
    ../../rtl_pds/ddr/ddr_wr_line_ram.sv \
    ../../rtl_pds/ddr/ddr_rd_line_ram.sv \
    ../../rtl_pds/ddr/ddr_video_delay_sync.sv \
    ../tb_ddr_video_delay_sync.sv

vsim -t 1ns -L $WORK_LIB -L work -voptargs="+acc" tb_ddr_video_delay_sync
run -all
