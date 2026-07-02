set_arch -family Logos2 -device PG2L200H -speedgrade -6 -package FBB676
add_design "C:/Users/Datou21/Desktop/PDS/back1/cnn_usb_copy/prj_pds/tmp_ddr_min_top.sv"
add_design "C:/Users/Datou21/Desktop/PDS/back1/cnn_usb_copy/rtl_pds/ddr/ddr_rd_line_ram.sv"
add_design "C:/Users/Datou21/Desktop/PDS/back1/cnn_usb_copy/rtl_pds/ddr/ddr_video_delay_sync.sv"
add_design "C:/Users/Datou21/Desktop/PDS/back1/cnn_usb_copy/rtl_pds/ddr/ddr_wr_line_ram.sv"
add_design "C:/Users/Datou21/Desktop/PDS/back1/cnn_usb_copy/rtl_pds/ddr/rd_ctrl.v"
add_design "C:/Users/Datou21/Desktop/PDS/back1/cnn_usb_copy/rtl_pds/ddr/wr_cmd_trans.v"
add_design "C:/Users/Datou21/Desktop/PDS/back1/cnn_usb_copy/rtl_pds/ddr/wr_ctrl.v"
add_design "C:/Users/Datou21/Desktop/PDS/back1/cnn_usb_copy/rtl_pds/ddr/wr_rd_ctrl_top.v"
add_design "C:/Users/Datou21/Desktop/PDS/back1/cnn_usb_copy/rtl_pds/ddr/ipcore/ddr3_test/ddr3_test.idf"
compile -system_verilog -top_module tmp_ddr_min_top
