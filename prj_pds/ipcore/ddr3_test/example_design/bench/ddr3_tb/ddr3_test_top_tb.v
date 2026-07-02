

////////////////////////////////////////////////////////////////
// Copyright (c) 2019 PANGO MICROSYSTEMS, INC
// ALL RIGHTS REVERVED.
////////////////////////////////////////////////////////////////
//Description:
//Author:  wxxiao
//History: v1.0
////////////////////////////////////////////////////////////////
`timescale 1 ns / 10 fs 
module ddr3_test_top_tb;

`include "../../example_design/bench/mem/ddr3_parameters.vh"

///////////////////////////test WRLVL case///////////////////////////
   
parameter CA_FIRST_DLY          = 0.15;
parameter CA_GROUP_TO_GROUP_DLY = 0.05;

////////////////////////////////////////////////////////////////////


localparam real CLKIN_FREQ  =  125.0   ; 


parameter PLL_REFCLK_IN_PERIOD = 1000 / CLKIN_FREQ;

  
parameter MEM_DQ_WIDTH = 32;
 
parameter MEM_DQS_WIDTH = MEM_DQ_WIDTH/8;
 
parameter MEM_ROW_WIDTH = 15;

reg pll_refclk_in;
reg free_clk;
reg ddr_rstn;
reg grs_n;
wire mem_rst_n      ; 
wire mem_ck         ;
wire mem_ck_n       ;
wire mem_cke        ;

wire mem_cs_n       ;

wire mem_ras_n      ;
wire mem_cas_n      ;
wire mem_we_n       ;
wire mem_odt        ;
wire [MEM_ROW_WIDTH-1:0] mem_a   ;  
wire [2:0]  mem_ba  ;  
wire [MEM_DQS_WIDTH-1:0]  mem_dqs ;  
wire [MEM_DQS_WIDTH-1:0]  mem_dqs_n;  
wire [MEM_DQ_WIDTH-1:0] mem_dq  ;  
wire [MEM_DQS_WIDTH-1:0]  mem_dm  ;
wire [ADDR_BITS-1:0] mem_addr;
wire dfi_init_complete;
reg  uart_rxd ;
wire uart_txd ;
reg  uart_clk ;


test_ddr u_ddr(
.ref_clk_p         (pll_refclk_in   ),
.ref_clk_n         (~pll_refclk_in  ),
.free_clk          (free_clk        ),
.rst_board         (ddr_rstn        ),
.pll_lock          (         ),
.ddrphy_cpd_lock   (         ),        
.ddr_init_done     (dfi_init_complete),
//uart
.uart_rxd          (uart_rxd         ),
.uart_txd          (uart_txd         ),

.mem_rst_n         (mem_rst_n        ),                       
.mem_ck            (mem_ck           ),
.mem_ck_n          (mem_ck_n         ),
.mem_cke           (mem_cke          ),

.mem_cs_n          (mem_cs_n         ),

.mem_ras_n         (mem_ras_n        ),
.mem_cas_n         (mem_cas_n        ),
.mem_we_n          (mem_we_n         ), 
.mem_odt           (mem_odt          ),
.mem_a             (mem_a            ),   
.mem_ba            (mem_ba           ),   
.mem_dqs           (mem_dqs          ),
.mem_dqs_n         (mem_dqs_n        ),
.mem_dq            (mem_dq           ),
.mem_dm            (mem_dm           ),
.heart_beat_led    (                 ),
.err_flag_led      (                 )

);

wire [MEM_DQS_WIDTH+1:0] mem_ck_dly;
wire [MEM_DQS_WIDTH+1:0] mem_ck_n_dly;
wire [(MEM_DQS_WIDTH+2)*ADDR_BITS:0] mem_addr_dly;
wire [MEM_DQS_WIDTH+1:0] mem_cke_dly;
wire [MEM_DQS_WIDTH+1:0] mem_odt_dly;
wire [MEM_DQS_WIDTH+1:0] mem_ras_n_dly;
wire [MEM_DQS_WIDTH+1:0] mem_cas_n_dly;
wire [MEM_DQS_WIDTH+1:0] mem_we_n_dly;
wire [MEM_DQS_WIDTH*3+6:0] mem_ba_dly;
wire [MEM_DQS_WIDTH+1:0] mem_cs_n_dly;
wire [MEM_DQS_WIDTH+1:0] mem_rst_n_dly;


assign #CA_FIRST_DLY   mem_ck_dly[1:0]               =  {mem_ck,mem_ck}    ;
assign #CA_FIRST_DLY   mem_ck_n_dly[1:0]             =  {mem_ck_n,mem_ck_n}  ;
assign #CA_FIRST_DLY   mem_addr_dly[ADDR_BITS*2-1:0] =  {mem_addr,mem_addr}  ;
assign #CA_FIRST_DLY   mem_cke_dly[1:0]              =  {mem_cke,mem_cke}   ;
assign #CA_FIRST_DLY   mem_odt_dly[1:0]              =  {mem_odt,mem_odt}   ;
assign #CA_FIRST_DLY   mem_ras_n_dly[1:0]            =  {mem_ras_n,mem_ras_n} ;
assign #CA_FIRST_DLY   mem_cas_n_dly[1:0]            =  {mem_cas_n,mem_cas_n} ;
assign #CA_FIRST_DLY   mem_we_n_dly[1:0]             =  {mem_we_n,mem_we_n}  ;
assign #CA_FIRST_DLY   mem_ba_dly[5:0]               =  {mem_ba,mem_ba}    ;
assign #CA_FIRST_DLY   mem_cs_n_dly[1:0]             =  {mem_cs_n,mem_cs_n}  ;
assign #CA_FIRST_DLY   mem_rst_n_dly[1:0]            =  {mem_rst_n,mem_rst_n} ;


assign mem_addr = {{(ADDR_BITS-MEM_ROW_WIDTH){1'b0}},{mem_a}};

genvar gen_mem;                                                    
generate                                                         
for(gen_mem=0; gen_mem<(MEM_DQS_WIDTH/2); gen_mem=gen_mem+1) begin   : i_mem 
    

assign #CA_GROUP_TO_GROUP_DLY   mem_addr_dly[(ADDR_BITS*(gen_mem+1)+ADDR_BITS)*2-1:(ADDR_BITS*(gen_mem+1))*2] =  mem_addr_dly[(ADDR_BITS*gen_mem+ADDR_BITS)*2-1:(ADDR_BITS*gen_mem)*2];
assign #CA_GROUP_TO_GROUP_DLY   mem_cke_dly[2*gen_mem+3:2*gen_mem+2] =  mem_cke_dly[2*gen_mem+1:2*gen_mem];
assign #CA_GROUP_TO_GROUP_DLY   mem_odt_dly[2*gen_mem+3:2*gen_mem+2] =  mem_odt_dly[2*gen_mem+1:2*gen_mem];
assign #CA_GROUP_TO_GROUP_DLY   mem_ras_n_dly[2*gen_mem+3:2*gen_mem+2] =  mem_ras_n_dly[2*gen_mem+1:2*gen_mem];
assign #CA_GROUP_TO_GROUP_DLY   mem_cas_n_dly[2*gen_mem+3:2*gen_mem+2] =  mem_cas_n_dly[2*gen_mem+1:2*gen_mem];
assign #CA_GROUP_TO_GROUP_DLY   mem_we_n_dly[2*gen_mem+3:2*gen_mem+2] =  mem_we_n_dly[2*gen_mem+1:2*gen_mem];
assign #CA_GROUP_TO_GROUP_DLY   mem_ba_dly[(gen_mem+1)*6+5:(gen_mem+1)*6] =  mem_ba_dly[gen_mem*6+5:gen_mem*6];
assign #CA_GROUP_TO_GROUP_DLY   mem_cs_n_dly[2*gen_mem+3:2*gen_mem+2] =  mem_cs_n_dly[2*gen_mem+1:2*gen_mem];
assign #CA_GROUP_TO_GROUP_DLY   mem_rst_n_dly[2*gen_mem+3:2*gen_mem+2] =  mem_rst_n_dly[2*gen_mem+1:2*gen_mem];
assign #CA_GROUP_TO_GROUP_DLY   mem_ck_dly[2*gen_mem+3:2*gen_mem+2] =  mem_ck_dly[2*gen_mem+1:2*gen_mem];
assign #CA_GROUP_TO_GROUP_DLY   mem_ck_n_dly[2*gen_mem+3:2*gen_mem+2] =  mem_ck_n_dly[2*gen_mem+1:2*gen_mem];


ddr3     mem_core (
    .rst_n                           (mem_rst_n_dly[2*gen_mem+1:2*gen_mem]  ),

    .ck                              (mem_ck_dly[2*gen_mem+1:2*gen_mem] ),
    .ck_n                            (mem_ck_n_dly[2*gen_mem+1:2*gen_mem] ),

    
    .cs_n                            (mem_cs_n_dly[2*gen_mem+1:2*gen_mem]  ),
    
    .ras_n                           (mem_ras_n_dly[2*gen_mem+1:2*gen_mem]  ),
    .cas_n                           (mem_cas_n_dly[2*gen_mem+1:2*gen_mem]  ),
    .we_n                            (mem_we_n_dly[2*gen_mem+1:2*gen_mem] ),
    .addr                            (mem_addr_dly[(ADDR_BITS*gen_mem+ADDR_BITS)*2-1:ADDR_BITS*gen_mem*2]  ),
    .ba                              (mem_ba_dly[gen_mem*6+5:gen_mem*6]  ),
    .odt                             (mem_odt_dly[2*gen_mem+1:2*gen_mem]  ),
    .cke                             (mem_cke_dly[2*gen_mem+1:2*gen_mem]  ),

    .dq                              (mem_dq[16*gen_mem+15:16*gen_mem]),
    .dqs                             (mem_dqs[2*gen_mem+1:2*gen_mem]  ),
    .dqs_n                           (mem_dqs_n[2*gen_mem+1:2*gen_mem] ),
    .dm_tdqs                         (mem_dm[2*gen_mem+1:2*gen_mem] ),
    .tdqs_n                          (  )
);
end     
endgenerate

/********************clk and init******************/

always #(PLL_REFCLK_IN_PERIOD / 2)  pll_refclk_in = ~pll_refclk_in;

always #(20 / 2)  free_clk = ~free_clk;

initial begin

#1 
pll_refclk_in = 0;
free_clk = 0;

//default input from keyboard
ddr_rstn = 1'b1;

end
/*******************end of clk and init*******************/


//GTP_GRS I_GTP_GRS(
GTP_GRS GRS_INST(
		.GRS_N (grs_n)
	);
initial begin
grs_n = 1'b0;
#5 grs_n = 1'b1;
end

initial begin

//reset the bu_top
uart_rxd = 1'b1;
#10 ddr_rstn = 1'b0;
#50 ddr_rstn = 1'b1;
$display("%t simulation start... ",$time);
$display("%t Reset sequence start... ",$time);

@ (posedge dfi_init_complete);
$display("%t simulation finish... ",$time);
#200000;
$finish;
end


initial begin
    @(posedge u_ddr.I_ips_ddr_top.u_ddrphy_top.ddrphy_reset_ctrl.ddrphy_rst_n)
    $display("%t Reset sequence complete ... ",$time);
    $display("%t Mem ddrphy training start ... ",$time);
    @(posedge u_ddr.I_ips_ddr_top.u_ddrphy_top.ddrphy_calib_top.ddrphy_main_ctrl.init_done)
    $display("%t Initialiation done ... ",$time);
    @(posedge u_ddr.I_ips_ddr_top.u_ddrphy_top.ddrphy_calib_top.ddrphy_main_ctrl.wrlvl_done)
    $display("%t Write Leveling done ... ",$time);
    $display("%t The Phy wrlvl_step is %h",$time,u_ddr.I_ips_ddr_top.u_ddrphy_top.ddrphy_slice_top.wrlvl_step);
    $display("%t The Phy ck_dly_step is %h",$time,u_ddr.I_ips_ddr_top.u_ddrphy_top.ddrphy_slice_top.ck_dly_set_bin);

    @(posedge u_ddr.I_ips_ddr_top.u_ddrphy_top.ddrphy_calib_top.ddrphy_main_ctrl.rdcal_done)
    $display("%t Read calibration and Gate calibration done ... ",$time);
    $display("%t The Phy dqs_even_bin is %h",$time,u_ddr.I_ips_ddr_top.u_ddrphy_top.ddrphy_slice_top.dqs_even_bin);
    $display("%t The Phy dqs_odd_bin is %h",$time,u_ddr.I_ips_ddr_top.u_ddrphy_top.ddrphy_slice_top.dqs_odd_bin);
    $display("%t The Phy coarse_slip_step is %h",$time,u_ddr.I_ips_ddr_top.u_ddrphy_top.ddrphy_slice_top.coarse_slip_step);
    $display("%t The Phy read_clk_ctrl is %h",$time,u_ddr.I_ips_ddr_top.u_ddrphy_top.ddrphy_slice_top.read_clk_ctrl);
    $display("%t The Phy ca_dly is %h",$time,u_ddr.I_ips_ddr_top.u_ddrphy_top.ddrphy_slice_top.all_group_ca_dly);
    $display("%t The Phy dq_dly is %h",$time,u_ddr.I_ips_ddr_top.u_ddrphy_top.ddrphy_slice_top.ck_dqs_diff_all);
    $display("%t The Phy total_margin_even is %h",$time,u_ddr.I_ips_ddr_top.u_ddrphy_top.ddrphy_slice_top.total_margin_even);
    $display("%t The Phy total_margin_odd is %h",$time,u_ddr.I_ips_ddr_top.u_ddrphy_top.ddrphy_slice_top.total_margin_odd);   

    @(posedge u_ddr.I_ips_ddr_top.u_ddrphy_top.ddrphy_calib_top.ddrphy_main_ctrl.wrcal_done)
    $display("%t Write calibration done ... ",$time);
    $display("%t The Phy dq_dly_bin is %h",$time,u_ddr.I_ips_ddr_top.u_ddrphy_top.ddrphy_slice_top.wl_p_dll_bin);

    @(posedge u_ddr.I_ips_ddr_top.u_ddrphy_top.ddrphy_calib_top.ddrphy_main_ctrl.eyecal_done)
    $display("%t Eye calibration done ... ",$time);
    $display("%t The Phy dqs_even_bin is %h",$time,u_ddr.I_ips_ddr_top.u_ddrphy_top.ddrphy_slice_top.dqs_even_bin);
    $display("%t The Phy dqs_odd_bin is %h",$time,u_ddr.I_ips_ddr_top.u_ddrphy_top.ddrphy_slice_top.dqs_odd_bin);
    $display("%t Mem training complete ... ",$time);

end




initial 
begin
 $fsdbDumpfile("ddr3_test_top_tb.fsdb");
 $fsdbDumpvars(0,"ddr3_test_top_tb");
end

wire error_state ; 
assign error_state = | u_ddr.I_ips_ddr_top.u_ddrphy_top.ddrphy_calib_top.ddrphy_main_ctrl.error_status ;
 
initial
begin
      @(posedge error_state)
        $display("%t TRAINING ERROR, error_state is %h ",$time,u_ddr.I_ips_ddr_top.u_ddrphy_top.ddrphy_calib_top.ddrphy_main_ctrl.error_status);
    #10000;
    $finish;
end






endmodule 
