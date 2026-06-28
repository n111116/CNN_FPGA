

////////////////////////////////////////////////////////////////     
// Copyright (c) 2019 PANGO MICROSYSTEMS, INC                        
// ALL RIGHTS REVERVED.                                              
////////////////////////////////////////////////////////////////     
//Description:                                                       
//Author:  wxxiao                                                    
//History: v1.0                                                      
////////////////////////////////////////////////////////////////     
`timescale 1ns/1ps                                                   
module   ddr3_test_slice_top_v1_10 #( 
  parameter real CLKIN_FREQ       = 50.0, 
  parameter   PPLL_BANDWIDTH      = "OPTIMIZED",
  parameter   [1:0] DDR_TYPE      = 2'b00 ,  //2'b00:DDR3  2'b01:DDR2  2'b10:LPDDR 
  parameter   GATE_MODE           = 0 ,
  parameter   TEST_DATA_PATTERN0  = 64'h55_aa_55_aa_08_f7_08_f7,  
  parameter   TEST_DATA_PATTERN1  = 64'h7f_9f_7f_9f_80_fe_80_fe,  
  parameter   TEST_DATA_PATTERN2  = 64'hf0_0f_f0_0f_01_ff_01_ff,  
  parameter   TEST_DATA_PATTERN3  = 64'hdf_aa_df_aa_55_aa_55_aa,  
  parameter   [1:0] SC_LDO_CTRL   = 2'b00,
  parameter   [0:0] SC_DLY_2X     = 1'b1 ,    //1'b0  1x delay chain, 1'b1 2x delay chain 
  parameter   PPLL_IDIV           = 2,
  parameter   PPLL_FDIV           = 64,
  parameter   PPLL_ODIVPHY        = 4,      
  parameter   MEM_ADDR_WIDTH      = 16,
  parameter   MEM_BANKADDR_WIDTH  = 3,
  parameter   MEM_DQ_WIDTH        = 16,
  parameter   MEM_DQS_WIDTH       = 2,
  parameter   MEM_DM_WIDTH        = 2
)(                          
  input [4:0]                      mc_rl                ,
  input                            force_read_clk_ctrl  ,
  input [3*MEM_DQS_WIDTH-1:0]      init_read_clk_ctrl   ,
  input [4*MEM_DQS_WIDTH-1:0]      init_slip_step       ,
  input                            force_samp_position  ,
  input                            samp_position_dyn_adj,
  input [8*MEM_DQS_WIDTH-1:0]      init_samp_position_even,
  input [8*MEM_DQS_WIDTH-1:0]      init_samp_position_odd,
  input [8*MEM_DQS_WIDTH-1:0]      init_wrlvl_step      ,
                                                        
  input                            ddrphy_sysclk        ,
  input                            ddrphy_rst_n         ,
  input                            phy_refclk           ,
  input                            phy_pll_rst          ,
  input [2:0]                      clkoutphy_gate       , 
  input                            ioclkdiv_rst         , 
  input                            dll_rstn             ,
  input                            dll_freeze           ,
  input                            dll_update_n         ,
  output reg                       dll_update_code_done ,
  output                           phy_pll_lock         ,
  output                           phy_dll_lock         ,
  output                           phy_sysclk_fb        ,
  output                           phy_ioclk_fb         ,
  input                            ddrphy_dqs_rst       ,
  input                            ddrphy_dqs_training_rstn,
  input                            ddrphy_iol_rst      ,
//wrlvl                                                  
  input                            wrlvl_dqs_req        ,
  output                           wrlvl_dqs_resp       ,
  output                           wrlvl_error          ,
  input                            ck_dly_en            ,
  input  [7:0]                     init_ck_dly_step     ,
  output                           ck_step_ov_warning   ,
  output [MEM_DQS_WIDTH-1:0]       wl_step_ov_warning   ,
                                   
//dqs                                              
  input                            gatecal_start        ,
  output                           gate_check_pass      ,
  output                           gate_adj_done        ,
  output                           gate_cal_error       ,
  input                            gate_move_en         ,
  output                           read_pattern_error   ,

                                                         
  input                            rddata_cal           ,
  output                           rddata_check_pass    ,
  input [3:0]                      read_cmd             ,

  output [2*MEM_DQS_WIDTH-1:0]     dqs_drift            ,
  input [2*MEM_DQS_WIDTH-1:0]      comp_val             ,
  input [MEM_DQS_WIDTH-1:0]        comp_dir             ,
  input                            dqs_gate_comp_en     ,
  output                           dqs_gate_comp_done   ,
                                   
///rdel                                                  
  input                            init_adj_rdel        ,
  output                           adj_rdel_done        ,
  input                            rdel_calibration     ,
  output                           rdel_calib_done      ,
  output                           rdel_calib_error     ,
  input                            rdel_move_en         ,
  output                           rdel_move_done       ,
  input                            bitslip_ctrl         ,
  
  input                            wrcal_position_dyn_adj,
  input [8*MEM_DQS_WIDTH-1:0]      init_wrcal_position  ,
  output                           wrcal_check_pass     ,
  input  [8:0]                     write_calibration    ,
  input  [8:0]                     wrcal_move_en        ,
  output                           wrcal_move_done      ,
  output                           wrcal_error          ,

  input                            eye_calibration      ,
  output                           eyecal_check_pass    ,
  output                           eyecal_move_done     ,
  input                            eyecal_move_en       ,

  output reg [7:0]                 ck_dly_set_bin       ,

//rdata                                                  
  output    	                   read_valid           ,
  output reg [8*MEM_DQ_WIDTH-1:0]  o_read_data          ,
  output                           align_error          , 
//wdata                                                  
  input [3:0]                      phy_wrdata_en        ,
  input [8*MEM_DM_WIDTH-1:0]       phy_wrdata_mask      ,
  input [8*MEM_DQ_WIDTH-1:0]       phy_wrdata           ,
  input [3:0]                      phy_cke              ,
  input [3:0]                      phy_cs_n             ,
  input [3:0]                      phy_ras_n            ,
  input [3:0]                      phy_cas_n            ,
  input [3:0]                      phy_we_n             ,
  input [4*MEM_ADDR_WIDTH-1:0]     phy_addr             ,
  input [4*MEM_BANKADDR_WIDTH-1:0] phy_ba               ,
  input [3:0]                      phy_odt              ,
  input [3:0]                      phy_ck               ,
  input                            phy_rst              ,


  output                           mem_cs_n             ,

  output                           mem_rst_n            ,
  output                           mem_ck               ,
  output                           mem_ck_n             ,
  output                           mem_cke              ,
  output                           mem_ras_n            ,
  output                           mem_cas_n            ,
  output                           mem_we_n             ,
  output                           mem_odt              ,
  output [MEM_ADDR_WIDTH-1:0]      mem_a                ,
  output [MEM_BANKADDR_WIDTH-1:0]  mem_ba               ,
  inout [MEM_DQS_WIDTH-1:0]        mem_dqs              ,
  inout [MEM_DQS_WIDTH-1:0]        mem_dqs_n            ,
  inout [MEM_DQ_WIDTH-1:0]         mem_dq               ,
  output [MEM_DM_WIDTH-1:0]        mem_dm               ,
  output [17*MEM_DQS_WIDTH -1:0]   dbg_slice_status     ,   
  output [22*MEM_DQS_WIDTH -1:0]   dbg_slice_state      ,   
  output [69*MEM_DQS_WIDTH -1:0]   debug_data   
  );                                            

  localparam  BANK_NUM = 2;

  localparam  MEM_CA_GROUP = 3;

localparam DQ0_BANK_NUM = 1;

localparam DQ8_BANK_NUM = 1;

localparam DQ16_BANK_NUM = 1;

localparam DQ24_BANK_NUM = 1;

localparam DQ32_BANK_NUM = 2;

localparam DQ40_BANK_NUM = 2;

localparam DQ48_BANK_NUM = 2;

localparam DQ56_BANK_NUM = 2;

localparam DQ64_BANK_NUM = 0;

localparam CKE_GROUP_NUM = 1;

localparam CK_GROUP_NUM = 2;

localparam CS_GROUP_NUM = 1;

localparam RAS_GROUP_NUM = 2;

localparam CAS_GROUP_NUM = 2;

localparam WE_GROUP_NUM = 2;

localparam ODT_GROUP_NUM = 0;

localparam BA0_GROUP_NUM = 1;

localparam BA1_GROUP_NUM = 1;

localparam BA2_GROUP_NUM = 2;

localparam A0_GROUP_NUM = 0;

localparam A1_GROUP_NUM = 0;

localparam A2_GROUP_NUM = 0;

localparam A3_GROUP_NUM = 1;

localparam A4_GROUP_NUM = 1;

localparam A5_GROUP_NUM = 0;

localparam A6_GROUP_NUM = 1;

localparam A7_GROUP_NUM = 0;

localparam A8_GROUP_NUM = 1;

localparam A9_GROUP_NUM = 0;

localparam A10_GROUP_NUM = 1;

localparam A11_GROUP_NUM = 1;

localparam A12_GROUP_NUM = 1;

localparam A13_GROUP_NUM = 0;

localparam A14_GROUP_NUM = 0;

localparam A15_GROUP_NUM = 0;


  wire [MEM_DQS_WIDTH-1:0]     dqs_read_valid     ;
  wire [8*MEM_DQ_WIDTH-1:0]    dqs_read_data      ;
  wire                         dqs_align_valid    ;
  wire [8*MEM_DQ_WIDTH-1:0]    dqs_align_data     ;
  
  wire                         dll_rstn_pos       ;
  reg  [7:0]                   ck_dly_set_gray    ;
  reg                          init_pls           ;
  reg                          init_pls_r1        ;
  reg                          init_pls_r2        ;
  
  integer i,j;
  reg [8*MEM_DQ_WIDTH-1:0]    phy_wrdata_reorder; 
  reg [8*MEM_DM_WIDTH-1:0]    phy_wrdata_mask_reorder; 
  reg [4*MEM_BANKADDR_WIDTH-1:0]  phy_ba_reorder ;
  reg [4*MEM_ADDR_WIDTH-1:0]  phy_addr_reorder ;
  
  wire [MEM_DQS_WIDTH-1:0]    wrlvl_error_tmp       ;
  wire [MEM_DQS_WIDTH-1:0]    wrlvl_dqs_resp_tmp    ;
  wire [MEM_DQS_WIDTH-1:0]    wrlvl_ck_dly_flag_tmp  ;
  wire [MEM_DQS_WIDTH-1:0]    ck_check_done_tmp      ;
  wire [8*MEM_DQS_WIDTH-1:0]  ck_dly_set_bin_tmp     ;
  wire [8*MEM_DQS_WIDTH-1:0]  wrlvl_step            ;
  wire [8*MEM_DQS_WIDTH-1:0]  dqs_even_bin          ;
  wire [8*MEM_DQS_WIDTH-1:0]  dqs_odd_bin           ;
  wire [3*MEM_DQS_WIDTH-1:0]  read_clk_ctrl         ;
  wire [4*MEM_DQS_WIDTH-1:0]  coarse_slip_step      ;
  wire [8*MEM_DQS_WIDTH-1:0]  wl_p_dll_bin          ;
  wire [9*MEM_DQS_WIDTH-1:0]  total_margin_even     ;
  wire [9*MEM_DQS_WIDTH-1:0]  total_margin_odd      ;
  wire [MEM_DQS_WIDTH-1:0]    adj_rdel_done_tmp     ;
  wire [MEM_DQS_WIDTH-1:0]    rdel_calib_done_tmp   ;
  wire [MEM_DQS_WIDTH-1:0]    rdel_calib_error_tmp  ;
  wire [MEM_DQS_WIDTH-1:0]    rdel_move_done_tmp    ;
  wire [MEM_DQS_WIDTH-1:0]    gate_check_pass_tmp   ;
  wire [MEM_DQS_WIDTH-1:0]    gate_adj_done_tmp     ;
  wire [MEM_DQS_WIDTH-1:0]    gate_cal_error_tmp    ;
  wire [MEM_DQS_WIDTH-1:0]    rddata_check_pass_tmp ;
  wire [MEM_DQS_WIDTH-1:0]    dqs_gate_comp_done_tmp;  
  wire [MEM_DQS_WIDTH-1:0]    dll_lock_tmp          ;
  wire [MEM_DQS_WIDTH-1:0]    wrcal_check_pass_tmp  ;
  wire [MEM_DQS_WIDTH-1:0]    wrcal_move_done_tmp   ;
  wire [MEM_DQS_WIDTH-1:0]    wrcal_error_tmp       ;
  wire [MEM_DQS_WIDTH-1:0]    eyecal_check_pass_tmp ;
  wire [MEM_DQS_WIDTH-1:0]    eyecal_move_done_tmp  ;
  wire [MEM_DQS_WIDTH-1:0]    dll_update_code_done_tmp;
  wire [2*MEM_DQS_WIDTH-1:0]  ck_dqs_diff_all       ;
  wire [MEM_DQS_WIDTH-1:0]    this_group_ca_dly_all ; 
  wire [MEM_DQS_WIDTH-1:0]    dq_rising_all         ;
  wire [MEM_DQS_WIDTH-1:0]    sample_done_all       ;
  wire [MEM_DQS_WIDTH-1:0]    read_pattern_error_tmp;
  
//  wire align_error;
  wire                        wrlvl_ck_dly_start    ;
  wire                        wrlvl_ck_dly_done     ;
  wire [7:0]                  ck_dly_set_bin_tra    ;
  wire                        all_group_dq_rising   ;
  wire                        all_group_ca_dly      ;
  wire                        all_group_sample_done ;
  
  wire [7:0]  adj_cke       ;
  wire [7:0]  adj_cs_n      ;
  wire [7:0]  adj_ras_n     ;
  wire [7:0]  adj_cas_n     ;
  wire [7:0]  adj_we_n      ;
  wire [8*MEM_ADDR_WIDTH-1:0]     adj_addr      ;
  wire [8*MEM_BANKADDR_WIDTH-1:0] adj_ba        ;
  wire [7:0]  adj_odt       ;
  wire [7:0]  adj_ck        ;
  
  wire [MEM_CA_GROUP-1:0] wclk_ca        /* pragma PAP_TIM_MASK_CLOCK_ATTR = 1 */ ;
  wire [MEM_CA_GROUP-1:0] padt_ca         ;
  wire [MEM_CA_GROUP-1:0] wclk_del_ca    /* pragma PAP_TIM_MASK_CLOCK_ATTR = 1 */ ;
  wire [MEM_CA_GROUP-1:0] padt_del_ca     ;


  wire wclk_cs_n                           ;
  wire padt_cs_n                           ;  
  wire pado_mem_cs_n                       ;
  wire padt_mem_cs_n                       ;
  wire pado_mem_cs_n_d                     ;

  wire wclk_ck                             ;
  wire padt_ck                             ;
  wire pado_mem_ck                         ;
  wire padt_mem_ck                         ;
  wire pado_mem_ck_d                       ;
  wire wclk_odt                            ;
  wire padt_odt                            ;  
  wire pado_mem_odt                        ;
  wire padt_mem_odt                        ;
  wire pado_mem_odt_d                      ;
  wire wclk_ras_n                          ;
  wire padt_ras_n                          ;  
  wire pado_mem_ras_n                      ;
  wire padt_mem_ras_n                      ;
  wire pado_mem_ras_n_d                    ;
  wire wclk_cas_n                          ;
  wire padt_cas_n                          ;  
  wire pado_mem_cas_n                      ;
  wire padt_mem_cas_n                      ;
  wire pado_mem_cas_n_d                    ;
  wire wclk_we_n                           ;
  wire padt_we_n                           ;  
  wire pado_mem_we_n                       ;
  wire padt_mem_we_n                       ;
  wire pado_mem_we_n_d                     ;
  wire wclk_cke                            ;
  wire padt_cke                            ;  
  wire pado_mem_cke                        ;
  wire padt_mem_cke                        ;
  wire pado_mem_cke_d                      ;
  wire [MEM_BANKADDR_WIDTH-1:0] wclk_ba    ;
  wire [MEM_BANKADDR_WIDTH-1:0] padt_ba    ;  
  wire [MEM_BANKADDR_WIDTH-1:0] pado_mem_ba;
  wire [MEM_BANKADDR_WIDTH-1:0] padt_mem_ba;
  wire [MEM_BANKADDR_WIDTH-1:0] pado_mem_ba_d;
  wire [MEM_ADDR_WIDTH-1:0] wclk_a         ;
  wire [MEM_ADDR_WIDTH-1:0] padt_a         ;  
  wire [MEM_ADDR_WIDTH-1:0] pado_mem_a     ;
  wire [MEM_ADDR_WIDTH-1:0] padt_mem_a     ;
  wire [MEM_ADDR_WIDTH-1:0] pado_mem_a_d   ;
  
   
  wire [BANK_NUM-1:0] pll_lock_tmp;
  wire [BANK_NUM-1:0] phy_clk_p;
  wire [BANK_NUM-1:0] phy_sysclk_p;
  wire [BANK_NUM-1:0] ppll_clkin;
  wire phy_ca_clk_p       ; 
  wire phy_ca_sysclk_p    ;
  wire [MEM_DQS_WIDTH-1:0] phy_dq_clk_p    ;
  wire [MEM_DQS_WIDTH-1:0] phy_dq_sysclk_p ;

  
//************************************************// 
 
 assign   wrlvl_error        = |wrlvl_error_tmp       ; 
 assign   wrlvl_dqs_resp     = &wrlvl_dqs_resp_tmp    ;                                                 
 assign   wrlvl_ck_dly_start = |wrlvl_ck_dly_flag_tmp ;
 assign   wrlvl_ck_dly_done  = &ck_check_done_tmp     ;
 assign   ck_dly_set_bin_tra = ck_dly_set_bin_tmp[7:0];
 assign   adj_rdel_done      = &adj_rdel_done_tmp     ;
 assign   rdel_calib_done    = &rdel_calib_done_tmp   ;
 assign   rdel_calib_error   = |rdel_calib_error_tmp  ;
 assign   rdel_move_done     = &rdel_move_done_tmp    ;
 assign   gate_check_pass    = &gate_check_pass_tmp   ;  
 assign   gate_adj_done      = &gate_adj_done_tmp     ; 
 assign   gate_cal_error     = |gate_cal_error_tmp    ;
 assign   rddata_check_pass  = &rddata_check_pass_tmp ; 
 assign   dqs_gate_comp_done = &dqs_gate_comp_done_tmp;
 assign   phy_pll_lock       = &pll_lock_tmp;
 assign   phy_dll_lock       = &dll_lock_tmp;
 assign   wrcal_check_pass   = &wrcal_check_pass_tmp  ;
 assign   wrcal_move_done    = &wrcal_move_done_tmp   ;
 assign   wrcal_error        = |wrcal_error_tmp       ;
 assign   eyecal_check_pass  = &eyecal_check_pass_tmp ;
 assign   eyecal_move_done   = &eyecal_move_done_tmp  ;
 assign   all_group_ca_dly   = |this_group_ca_dly_all ;
 assign   all_group_dq_rising = &dq_rising_all        ;
 assign   all_group_sample_done = &sample_done_all    ;
 assign   read_pattern_error = |read_pattern_error_tmp;


 assign  dll_rstn_pos = init_pls_r1 & (~init_pls_r2);

 always @(posedge ddrphy_sysclk or negedge dll_rstn) begin
     if(!dll_rstn) begin
         init_pls <= 1'b0;
         init_pls_r1 <= 1'b0;
         init_pls_r2 <= 1'b0;
     end
     else begin
         init_pls <= 1'b1;
         init_pls_r1 <= init_pls;
         init_pls_r2 <= init_pls_r1;
     end
 end

always @(posedge ddrphy_sysclk or negedge dll_rstn)
begin
    if(!dll_rstn)
      ck_dly_set_bin         <= 8'b0;
    else if (dll_rstn_pos)
      ck_dly_set_bin         <= init_ck_dly_step;
    else if (wrlvl_ck_dly_start == 1'b1) 
      ck_dly_set_bin         <= ck_dly_set_bin_tra;
    else 
        ck_dly_set_bin         <= ck_dly_set_bin;
end

always@(posedge ddrphy_sysclk or negedge dll_rstn)
begin
    if(!dll_rstn)
        dll_update_code_done <= 1'b0;
    else
        dll_update_code_done <= &dll_update_code_done_tmp;
end

assign ck_step_ov_warning = (ck_dly_set_bin > 8'd40);

assign dbg_slice_status     = {wrlvl_error_tmp,
                               wrlvl_dqs_resp_tmp,
                               adj_rdel_done_tmp,
                               rdel_calib_done_tmp,
                               rdel_calib_error_tmp,
                               rdel_move_done_tmp,
                               gate_check_pass_tmp,
                               gate_adj_done_tmp,
                               gate_cal_error_tmp,
                               rddata_check_pass_tmp,
                               dqs_gate_comp_done_tmp,
                               dll_lock_tmp,
                               wrcal_check_pass_tmp,
                               wrcal_move_done_tmp,
                               eyecal_check_pass_tmp,
                               eyecal_move_done_tmp,
                               dll_update_code_done_tmp
                               };
			       


assign phy_ca_clk_p = phy_clk_p[0];
assign phy_ca_sysclk_p = phy_sysclk_p[0];

 
assign phy_dq_clk_p[0] = phy_clk_p[DQ0_BANK_NUM];
assign phy_dq_sysclk_p[0] = phy_sysclk_p[DQ0_BANK_NUM];
 
assign phy_dq_clk_p[1] = phy_clk_p[DQ8_BANK_NUM];
assign phy_dq_sysclk_p[1] = phy_sysclk_p[DQ8_BANK_NUM];

assign phy_dq_clk_p[2] = phy_clk_p[DQ16_BANK_NUM];
assign phy_dq_sysclk_p[2] = phy_sysclk_p[DQ16_BANK_NUM];

assign phy_dq_clk_p[3] = phy_clk_p[DQ24_BANK_NUM];
assign phy_dq_sysclk_p[3] = phy_sysclk_p[DQ24_BANK_NUM];
 

assign phy_ioclk_fb  = phy_clk_p[0];
assign phy_sysclk_fb = phy_sysclk_p[0];


assign wclk_cke    = wclk_del_ca[CKE_GROUP_NUM];
assign padt_cke    = padt_del_ca[CKE_GROUP_NUM];

assign wclk_ck     = wclk_del_ca[CK_GROUP_NUM];
assign padt_ck     = padt_del_ca[CK_GROUP_NUM];

assign wclk_cs_n   = wclk_ca[CS_GROUP_NUM];
assign padt_cs_n   = padt_ca[CS_GROUP_NUM];
  
assign wclk_ras_n  = wclk_ca[RAS_GROUP_NUM];
assign padt_ras_n  = padt_ca[RAS_GROUP_NUM];    

assign wclk_cas_n  = wclk_ca[CAS_GROUP_NUM];
assign padt_cas_n  = padt_ca[CAS_GROUP_NUM]; 

assign wclk_we_n   = wclk_ca[WE_GROUP_NUM];
assign padt_we_n   = padt_ca[WE_GROUP_NUM];

assign wclk_odt    = wclk_ca[ODT_GROUP_NUM];
assign padt_odt    = padt_ca[ODT_GROUP_NUM];

assign wclk_ba[0]  = wclk_ca[BA0_GROUP_NUM];
assign padt_ba[0]  = padt_ca[BA0_GROUP_NUM];

assign wclk_ba[1]  = wclk_ca[BA1_GROUP_NUM];
assign padt_ba[1]  = padt_ca[BA1_GROUP_NUM];

assign wclk_ba[2]  = wclk_ca[BA2_GROUP_NUM];
assign padt_ba[2]  = padt_ca[BA2_GROUP_NUM];

assign wclk_a[0]  = wclk_ca[A0_GROUP_NUM];
assign padt_a[0]  = padt_ca[A0_GROUP_NUM];

assign wclk_a[1]  = wclk_ca[A1_GROUP_NUM];
assign padt_a[1]  = padt_ca[A1_GROUP_NUM];

assign wclk_a[2]  = wclk_ca[A2_GROUP_NUM];
assign padt_a[2]  = padt_ca[A2_GROUP_NUM];

assign wclk_a[3]  = wclk_ca[A3_GROUP_NUM];
assign padt_a[3]  = padt_ca[A3_GROUP_NUM];

assign wclk_a[4]  = wclk_ca[A4_GROUP_NUM];
assign padt_a[4]  = padt_ca[A4_GROUP_NUM];

assign wclk_a[5]  = wclk_del_ca[A5_GROUP_NUM];
assign padt_a[5]  = padt_del_ca[A5_GROUP_NUM];

assign wclk_a[6]  = wclk_ca[A6_GROUP_NUM];
assign padt_a[6]  = padt_ca[A6_GROUP_NUM];

assign wclk_a[7]  = wclk_ca[A7_GROUP_NUM];
assign padt_a[7]  = padt_ca[A7_GROUP_NUM];

assign wclk_a[8]  = wclk_ca[A8_GROUP_NUM];
assign padt_a[8]  = padt_ca[A8_GROUP_NUM];

assign wclk_a[9]  = wclk_ca[A9_GROUP_NUM];
assign padt_a[9]  = padt_ca[A9_GROUP_NUM];

assign wclk_a[10]  = wclk_ca[A10_GROUP_NUM];
assign padt_a[10]  = padt_ca[A10_GROUP_NUM];

assign wclk_a[11]  = wclk_del_ca[A11_GROUP_NUM];
assign padt_a[11]  = padt_del_ca[A11_GROUP_NUM];

assign wclk_a[12]  = wclk_ca[A12_GROUP_NUM];
assign padt_a[12]  = padt_ca[A12_GROUP_NUM];

assign wclk_a[13]  = wclk_ca[A13_GROUP_NUM];
assign padt_a[13]  = padt_ca[A13_GROUP_NUM];

assign wclk_a[14]  = wclk_del_ca[A14_GROUP_NUM];
assign padt_a[14]  = padt_del_ca[A14_GROUP_NUM];

////wrdata  reorder                                                                                                                   
 always @(*) begin
      for (i=0; i<8; i=i+1)
         for (j=0; j<MEM_DQ_WIDTH; j=j+1)            
           phy_wrdata_reorder[j*8 + i] = phy_wrdata[i*MEM_DQ_WIDTH+j];
 end

// write_data_mask_reorder                                                                
 always @(*) begin
     for(i=0; i<8; i=i+1)
         for(j=0; j<MEM_DM_WIDTH; j=j+1)          
             phy_wrdata_mask_reorder[j*8 + i] = phy_wrdata_mask[i*MEM_DM_WIDTH+j];
 end
 
//rddata reorder
  always @(*) begin                                                        
       for (i=0; i<8; i=i+1)                                             
          for (j=0; j<MEM_DQ_WIDTH; j=j+1)                                 
            o_read_data[i*MEM_DQ_WIDTH + j] = dqs_align_data[j*8 + 7 - i];     
  end                                                                      

  assign read_valid = dqs_align_valid ;

//bank reoder
 always @(*) begin
    for(i=0; i<4; i=i+1)
       for(j=0;j<MEM_BANKADDR_WIDTH ; j=j+1)
           phy_ba_reorder[j*4+i] = phy_ba[i*MEM_BANKADDR_WIDTH + j] ;
 end
 
//addr reoder
 always @(*) begin
    for(i=0; i<4; i=i+1)
       for(j=0;j<MEM_ADDR_WIDTH;j=j+1)
          phy_addr_reorder[j*4+i] = phy_addr[i*MEM_ADDR_WIDTH+j];
 end                                                            

genvar gen_b;
generate
for(gen_b=0; gen_b<BANK_NUM; gen_b=gen_b+1) begin   : i_dqs_bank

GTP_CLKBUFR u_clkbufr
(
 .CLKOUT(ppll_clkin[gen_b]),
 .CLKIN (phy_refclk)
);


ips2l_ddrphy_ppll_v1_0 #(
.CLKIN_FREQ      (CLKIN_FREQ     ),
.BANDWIDTH       (PPLL_BANDWIDTH ),

.CLKOUT4_SYN_EN  ("TRUE"         ),
.INTERNAL_FB     ("CLKOUT4"      ),

.IDIV            (PPLL_IDIV      ),
.FDIV            (PPLL_FDIV      ),
.ODIVPHY         (PPLL_ODIVPHY   )   
)ddrphy_ppll(
.clk_in0         (ppll_clkin[gen_b]),
.pll_rst         (phy_pll_rst   ),
.clkoutphy_gate  (clkoutphy_gate[gen_b]),
.clkout0         (),
.clkout0n        (),
.clkoutphy       (phy_clk_p[gen_b]),
.clkoutphyn      (),
.pll_lock        (pll_lock_tmp[gen_b])
);


GTP_IOCLKDIV_E3 #(
 .DIV_FACTOR    ("8"),  
 .PHASE_SHIFT   ("2")   
)u_ddrphy_ioclkdiv(
 .RST         (ioclkdiv_rst),
 .CLKIN       (phy_clk_p[gen_b]),
 .CLKDIVOUT   (phy_sysclk_p[gen_b])
);
end
endgenerate

genvar gen_d;
generate
   for(gen_d=0; gen_d<MEM_DQS_WIDTH; gen_d=gen_d+1) begin   : i_dqs_group
   ips2l_ddrphy_data_slice_v1_10 #(
      .DDR_TYPE           (DDR_TYPE),
      .TEST_DATA_PATTERN0 (TEST_DATA_PATTERN0),      
      .TEST_DATA_PATTERN1 (TEST_DATA_PATTERN1),      
      .TEST_DATA_PATTERN2 (TEST_DATA_PATTERN2),      
      .TEST_DATA_PATTERN3 (TEST_DATA_PATTERN3),       
      .GATE_MODE          (GATE_MODE),
      .SC_LDO_CTRL        (SC_LDO_CTRL),
      .SC_DLY_2X          (SC_DLY_2X),
      .WL_MAX_STEP        (8'd201  ),
      .WL_MAX_CHECK       (5'h1f  ),
      .MIN_DQSI_WIN       (9'd10  )
   )ddrphy_data_slice( 
      .mc_rl                     (mc_rl                    ), 
      .force_read_clk_ctrl       (force_read_clk_ctrl      ),                               
      .init_read_clk_ctrl        (init_read_clk_ctrl[3*gen_d+2:3*gen_d] ),
      .init_slip_step            (init_slip_step[4*gen_d+3:4*gen_d]     ), 
      .force_samp_position       (force_samp_position      ),           
      .samp_position_dyn_adj     (samp_position_dyn_adj    ),           
      .init_samp_position_even   (init_samp_position_even[8*gen_d+7:8*gen_d]),
      .init_samp_position_odd    (init_samp_position_odd[8*gen_d+7:8*gen_d] ),
      
      .ddrphy_sysclk             (ddrphy_sysclk            ),
      .ddrphy_rst_n              (ddrphy_rst_n             ),
      .phy_clk_p                 (phy_dq_clk_p[gen_d]      ), 
      .sysclk_p                  (phy_dq_sysclk_p[gen_d]   ),
      .ddrphy_dqs_rst            (ddrphy_dqs_rst           ),
      .ddrphy_dqs_training_rstn  (ddrphy_dqs_training_rstn ),
      .ddrphy_iol_rst            (ddrphy_iol_rst           ),
      
      .init_wrlvl_step           (init_wrlvl_step[8*gen_d+7:8*gen_d]),     
      .wrlvl_dqs_req             (wrlvl_dqs_req                ),
      .wrlvl_dqs_resp            (wrlvl_dqs_resp_tmp[gen_d]    ),
      .wrlvl_error               (wrlvl_error_tmp[gen_d]       ), 
      .wrlvl_ck_dly_flag         (wrlvl_ck_dly_flag_tmp[gen_d] ),
      .wrlvl_ck_dly_done         (wrlvl_ck_dly_done            ),
      .wrlvl_ck_dly_start        (wrlvl_ck_dly_start           ),
      .ck_check_done             (ck_check_done_tmp[gen_d]     ),
      .ck_dly_set_bin_tra        (ck_dly_set_bin_tmp[8*gen_d+7:8*gen_d]),
      .ck_dly_en                 (ck_dly_en                    ),
      .wrlvl_step                (wrlvl_step[8*gen_d+7:8*gen_d]),
      .read_clk_ctrl             (read_clk_ctrl[3*gen_d+2:3*gen_d]),
      .coarse_slip_step          (coarse_slip_step[4*gen_d+3:4*gen_d]),
      
      .ck_dqs_diff               (ck_dqs_diff_all[2*gen_d+1:2*gen_d]),
      .this_group_ca_dly         (this_group_ca_dly_all[gen_d] ),
      .all_group_ca_dly          (all_group_ca_dly             ),
      .all_group_dq_rising       (all_group_dq_rising          ),
      .dq_rising                 (dq_rising_all[gen_d]         ),
      .sample_done               (sample_done_all[gen_d]       ),
      .wl_step_ov_warning        (wl_step_ov_warning[gen_d]    ),
      .init_ck_dly_step          (init_ck_dly_step             ),
      .all_group_sample_done     (all_group_sample_done        ),

      .gatecal_start             (gatecal_start            ),
      .gate_check_pass           (gate_check_pass_tmp[gen_d]   ),
      .gate_adj_done             (gate_adj_done_tmp[gen_d]     ),
      .gate_cal_error            (gate_cal_error_tmp[gen_d]    ),
      .gate_move_en              (gate_move_en             ), 
      .rddata_cal                (rddata_cal               ), 
      .rddata_check_pass         (rddata_check_pass_tmp[gen_d] ),
      .dqs_even_bin              (dqs_even_bin[8*gen_d+7:8*gen_d]),                 
      .dqs_odd_bin               (dqs_odd_bin[8*gen_d+7:8*gen_d]),
      .total_margin_even         (total_margin_even[9*gen_d+8:9*gen_d]),
      .total_margin_odd          (total_margin_odd[9*gen_d+8:9*gen_d]),
      .read_pattern_error        (read_pattern_error_tmp[gen_d]  ),

      .wrcal_position_dyn_adj    (wrcal_position_dyn_adj    ),           
      .init_wrcal_position       (init_wrcal_position[8*gen_d+7:8*gen_d]),
      .wrcal_check_pass          (wrcal_check_pass_tmp[gen_d] ),
      .write_calibration         (write_calibration[gen_d]     ),
      .wrcal_move_en             (wrcal_move_en[gen_d]         ),
      .wrcal_move_done           (wrcal_move_done_tmp[gen_d]  ),
      .wrcal_error               (wrcal_error_tmp[gen_d]       ),
      .wl_p_dll_bin              (wl_p_dll_bin[8*gen_d+7:8*gen_d]),

      .eye_calibration           (eye_calibration      ),
      .eyecal_check_pass         (eyecal_check_pass_tmp[gen_d]    ),
      .eyecal_move_done          (eyecal_move_done_tmp[gen_d]     ),
      .eyecal_move_en            (eyecal_move_en       ),

      .read_cmd                  (read_cmd                 ),  
      
      .comp_val                  (comp_val[2*gen_d+1:2*gen_d]),
      .comp_dir                  (comp_dir[gen_d]            ),
      .dqs_drift                 (dqs_drift[2*gen_d+1:2*gen_d]),
      .dqs_gate_comp_en          (dqs_gate_comp_en           ),
      .dqs_gate_comp_done        (dqs_gate_comp_done_tmp[gen_d]  ),
      
      .dll_lock                  (dll_lock_tmp[gen_d]),
      .dll_rstn                  (dll_rstn           ),
      .dll_freeze                (dll_freeze         ),
      .dll_update_n              (dll_update_n       ),
      .dll_update_code_done      (dll_update_code_done_tmp[gen_d]),
      
      .init_adj_rdel             (init_adj_rdel              ),
      .adj_rdel_done             (adj_rdel_done_tmp[gen_d]       ),  
      .rdel_calibration          (rdel_calibration           ),
      .rdel_calib_done           (rdel_calib_done_tmp[gen_d]     ),
      .rdel_calib_error          (rdel_calib_error_tmp[gen_d]    ),
      .rdel_move_en              (rdel_move_en               ),
      .rdel_move_done            (rdel_move_done_tmp[gen_d]      ),
      .bitslip_ctrl              (bitslip_ctrl                   ),
      
      .read_valid                (dqs_read_valid[gen_d]               ),
      .read_data                 (dqs_read_data[64*gen_d+63:64*gen_d] ),
      
      .phy_wrdata_en             (phy_wrdata_en            ), 
      .phy_wrdata_mask           (phy_wrdata_mask_reorder[8*gen_d+7 : 8*gen_d]), 
      .phy_wrdata                (phy_wrdata_reorder[64*gen_d+63:64*gen_d]    ),
      .dqs                       (mem_dqs[gen_d]                      ),
      .dqs_n                     (mem_dqs_n[gen_d]                    ),
      .dq                        (mem_dq[8*gen_d+7 : 8*gen_d]         ), 
      .dm                        (mem_dm[gen_d]                       ),
      .dbg_slice_state           (dbg_slice_state[22*gen_d+21:22*gen_d]),
      .debug_data                (debug_data[69*gen_d+68:69*gen_d]    )
  ); 
  end     
endgenerate

   ips2l_ddrphy_slice_rddata_align_v1_0 #(
    .MEM_DQ_WIDTH       (MEM_DQ_WIDTH ),
    .MEM_DQS_WIDTH      (MEM_DQS_WIDTH)
   )ddrphy_slice_rddata_align(
    .ddrphy_sysclk     (ddrphy_sysclk   ),
    .ddrphy_rst_n      (ddrphy_rst_n    ),

    .dqs_read_valid    (dqs_read_valid  ),
    .dqs_read_data     (dqs_read_data   ),

    .dqs_align_valid   (dqs_align_valid ),
    .dqs_align_data    (dqs_align_data  ),
    .align_error       (align_error     )
    ); 
  
  ips2l_ddrphy_control_path_adj_v1_10 #(
    .DDR_TYPE            (DDR_TYPE          ),
    .MEM_ADDR_WIDTH      (MEM_ADDR_WIDTH    ),
    .MEM_BANKADDR_WIDTH  (MEM_BANKADDR_WIDTH),
    .SLIP_BIT_NUM        (2'b1              )     
  )ddrphy_control_path_adj(
    .ddrphy_sysclk (ddrphy_sysclk),
    .ddrphy_rst_n  (ddrphy_rst_n ),

    .phy_cke       (phy_cke         ),
    .phy_cs_n      (phy_cs_n        ),
    .phy_ras_n     (phy_ras_n       ),
    .phy_cas_n     (phy_cas_n       ),
    .phy_we_n      (phy_we_n        ),
    .phy_addr      (phy_addr_reorder),
    .phy_ba        (phy_ba_reorder  ),
    .phy_odt       (phy_odt         ),
    .phy_ck        (phy_ck          ),
    .adj_cke       (adj_cke         ),
    .adj_cs_n      (adj_cs_n        ),
    .adj_ras_n     (adj_ras_n       ),
    .adj_cas_n     (adj_cas_n       ),
    .adj_we_n      (adj_we_n        ),
    .adj_addr      (adj_addr        ),
    .adj_ba        (adj_ba          ),
    .adj_odt       (adj_odt         ),
    .adj_ck        (adj_ck          ),
    .all_group_ca_dly (all_group_ca_dly)
  );   

genvar gen_ca;
generate
   for(gen_ca=0; gen_ca<MEM_CA_GROUP; gen_ca=gen_ca+1) begin   : i_ca_group
GTP_DDC_E2 #(
 .CLKA_GATE_EN     ("TRUE"),         
 .WCLK_DELAY_SEL   ("FALSE"),        
 .DDC_MODE         ("QUAD_RATE"),    
 .R_EXTEND         ("FALSE"),        
 .DELAY_SEL        (SC_DLY_2X),      
 .GRS_EN           ("TRUE"),         
 .IFIFO_GENERIC    ("FALSE"),        
 .RADDR_INIT       (3'b000),         
 .DATA_RATE        (SC_LDO_CTRL)     
)u_ddc_ca(
    //output
  .WCLK                (wclk_ca[gen_ca]),
  .WCLK_DELAY          (wclk_del_ca[gen_ca]),
  .DQSI_DELAY          (),
  .DQSIB_DELAY         (),
  .DGTS                (),
  .IFIFO_WADDR         (),
  .IFIFO_RADDR         (),
  .READ_VALID          (),
  .DQS_DRIFT           (),
  .DRIFT_DETECT_ERR    (),
  .DQS_DRIFT_STATUS    (),
  .DQS_SAMPLE          (),
  .RST                 (ddrphy_dqs_rst),
  .RST_TRAINING_N      (ddrphy_dqs_training_rstn),
  .CLKA                (phy_ca_clk_p),
  .CLKB                (phy_ca_sysclk_p),
  .DQSI                (),
  .DQSIB               (),
  .DELAY_STEP0         (8'd0),
  .DELAY_STEP1         (8'd0),
  .DELAY_STEP2         (8'd0),
  .DELAY_STEP3         (8'd0),
  .DELAY_STEP4         (8'd0),
  .DQS_GATE_CTRL       (4'd0),
  .GATE_SEL            (1'b0),
  .CLK_GATE_CTRL       (2'd0),
  .CLKA_GATE           (1'b0)
 );

GTP_OSERDES_E2 #(
   .GRS_EN           ("TRUE"),               
   .OSERDES_MODE     ("HMSDR8TO1"),
   .TSERDES_EN       ("TRUE"),          
   .UPD0_SHIFT_EN    ("FALSE"),                 
   .UPD1_SHIFT_EN    ("FALSE"),                 
   .INIT_SET         (2'b00),                
   .GRS_TYPE_DQ      ("RESET"),              
   .LRS_TYPE_DQ0     ("ASYNC_RESET"),        
   .LRS_TYPE_DQ1     ("ASYNC_RESET"),        
   .LRS_TYPE_DQ2     ("ASYNC_RESET"),        
   .LRS_TYPE_DQ3     ("ASYNC_RESET"),        
   .GRS_TYPE_TQ      ("RESET"),              
   .LRS_TYPE_TQ0     ("ASYNC_RESET"),        
   .LRS_TYPE_TQ1     ("ASYNC_RESET"),        
   .LRS_TYPE_TQ2     ("ASYNC_RESET"),        
   .LRS_TYPE_TQ3     ("ASYNC_RESET"),        
   .TRI_EN           ("TRUE"),              
   .TBYTE_EN         ("FALSE"),              
   .MIPI_EN          ("FALSE"),              
   .OCASCADE_EN      ("FALSE")               
)u_tserdes_ca0(
   .RST             (ddrphy_iol_rst), 
   .OCE             (1'b1),
   .TCE             (1'b1),
   .OCLKDIV         (phy_ca_sysclk_p),                
   .SERCLK          (phy_ca_clk_p),
   .OCLK            (wclk_ca[gen_ca]),
   .MIPI_CTRL       (1'b0),
   .UPD0_SHIFT      (1'b0),
   .UPD1_SHIFT      (1'b0),
   .OSHIFTIN0       (1'b0),
   .OSHIFTIN1       (1'b0),
   .DI              (8'd0),
   .TI              (8'd0),
   .TBYTE_IN        (),
   .OSHIFTOUT0      (),
   .OSHIFTOUT1      (),
   .TQ              (),
   .DO              (padt_ca[gen_ca])
);

GTP_OSERDES_E2 #(                                       
   .GRS_EN           ("TRUE"),               
   .OSERDES_MODE     ("HMSDR8TO1"),
   .TSERDES_EN       ("TRUE"),          
   .UPD0_SHIFT_EN    ("FALSE"),                 
   .UPD1_SHIFT_EN    ("FALSE"),                 
   .INIT_SET         (2'b00),                
   .GRS_TYPE_DQ      ("RESET"),              
   .LRS_TYPE_DQ0     ("ASYNC_RESET"),        
   .LRS_TYPE_DQ1     ("ASYNC_RESET"),        
   .LRS_TYPE_DQ2     ("ASYNC_RESET"),        
   .LRS_TYPE_DQ3     ("ASYNC_RESET"),        
   .GRS_TYPE_TQ      ("RESET"),              
   .LRS_TYPE_TQ0     ("ASYNC_RESET"),        
   .LRS_TYPE_TQ1     ("ASYNC_RESET"),        
   .LRS_TYPE_TQ2     ("ASYNC_RESET"),        
   .LRS_TYPE_TQ3     ("ASYNC_RESET"),        
   .TRI_EN           ("TRUE"),              
   .TBYTE_EN         ("FALSE"),              
   .MIPI_EN          ("FALSE"),              
   .OCASCADE_EN      ("FALSE")               
)u_tserdes_ca1(
   .RST             (ddrphy_iol_rst), 
   .OCE             (1'b1),
   .TCE             (1'b1),
   .OCLKDIV         (phy_ca_sysclk_p),               
   .SERCLK          (phy_ca_clk_p),
   .OCLK            (wclk_del_ca[gen_ca]),
   .MIPI_CTRL       (1'b0),
   .UPD0_SHIFT      (1'b0),
   .UPD1_SHIFT      (1'b0),
   .OSHIFTIN0       (1'b0),
   .OSHIFTIN1       (1'b0),
   .DI              (8'd0),
   .TI              (8'd0),
   .TBYTE_IN        (),
   .OSHIFTOUT0      (),
   .OSHIFTOUT1      (),
   .TQ              (),
   .DO              (padt_del_ca[gen_ca])
);
  end     
endgenerate


GTP_OSERDES_E2 #(                             
   .GRS_EN           ("TRUE"),                
   .OSERDES_MODE     ("HMSDR8TO1"),           
   .TSERDES_EN       ("FALSE"),
   .UPD0_SHIFT_EN    ("FALSE"),                  
   .UPD1_SHIFT_EN    ("FALSE"),                  
   .INIT_SET         (2'b00),                 
   .GRS_TYPE_DQ      ("RESET"),               
   .LRS_TYPE_DQ0     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ1     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ2     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ3     ("ASYNC_RESET"),         
   .GRS_TYPE_TQ      ("RESET"),               
   .LRS_TYPE_TQ0     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ1     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ2     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ3     ("ASYNC_RESET"),         
   .TRI_EN           ("TRUE"),               
   .TBYTE_EN         ("TRUE"),               
   .MIPI_EN          ("FALSE"),               
   .OCASCADE_EN      ("FALSE")                
)u_oserdes_ck(
   .RST             (ddrphy_dqs_rst), 
   .OCE             (1'b1),
   .TCE             (1'b1),
   .OCLKDIV         (phy_ca_sysclk_p),            
   .SERCLK          (phy_ca_clk_p),
   .OCLK            (wclk_ck),
   .MIPI_CTRL       (1'b0),
   .UPD0_SHIFT      (1'b0),
   .UPD1_SHIFT      (1'b0),
   .OSHIFTIN0       (1'b0),
   .OSHIFTIN1       (1'b0),
   .DI              (adj_ck),
   .TI              (),
   .TBYTE_IN        (padt_ck),
   .OSHIFTOUT0      (),
   .OSHIFTOUT1      (),
   .TQ              (padt_mem_ck),
   .DO              (pado_mem_ck)
);


always @(posedge ddrphy_sysclk or negedge ddrphy_rst_n)
begin
    if(!ddrphy_rst_n) begin
        ck_dly_set_gray  <= 8'd0;
    end
    else begin
        ck_dly_set_gray  <= (ck_dly_set_bin>>1)^ck_dly_set_bin;
    end
end

 GTP_IODELAY_E2 #(
 .DELAY_STEP_SEL     ("PORT"), 
 .DELAY_STEP_VALUE   (8'd0)   
 )u_iodelay_dq(
 .DO                 (pado_mem_ck_d),
 .DI                 (pado_mem_ck),
 .DELAY_SEL          (1'b0),
 .DELAY_STEP         (ck_dly_set_gray)  
 );
 
 GTP_OUTBUFTCO u_outbuftco_ck
 (
 .O    (mem_ck),
 .OB   (mem_ck_n),
 .I    (pado_mem_ck_d),
 .T    (padt_mem_ck)
 );


GTP_OSERDES_E2 #(
   .GRS_EN           ("TRUE"),                
   .OSERDES_MODE     ("HMSDR8TO1"),    
   .TSERDES_EN       ("FALSE"),       
   .UPD0_SHIFT_EN    ("FALSE"),                  
   .UPD1_SHIFT_EN    ("FALSE"),                  
   .INIT_SET         (2'b00),                 
   .GRS_TYPE_DQ      ("RESET"),               
   .LRS_TYPE_DQ0     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ1     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ2     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ3     ("ASYNC_RESET"),         
   .GRS_TYPE_TQ      ("RESET"),               
   .LRS_TYPE_TQ0     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ1     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ2     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ3     ("ASYNC_RESET"),         
   .TRI_EN           ("TRUE"),               
   .TBYTE_EN         ("TRUE"),               
   .MIPI_EN          ("FALSE"),               
   .OCASCADE_EN      ("FALSE")                
)u_oserdes_odt(
   .RST             (ddrphy_dqs_rst), 
   .OCE             (1'b1),
   .TCE             (1'b1),
   .OCLKDIV         (phy_ca_sysclk_p),    
   .SERCLK          (phy_ca_clk_p),      
   .OCLK            (wclk_odt),
   .MIPI_CTRL       (1'b0),
   .UPD0_SHIFT      (1'b0),
   .UPD1_SHIFT      (1'b0),
   .OSHIFTIN0       (1'b0),
   .OSHIFTIN1       (1'b0),
   .DI              (adj_odt),
   .TI              (),
   .TBYTE_IN        (padt_odt),
   .OSHIFTOUT0      (),
   .OSHIFTOUT1      (),
   .TQ              (padt_mem_odt),
   .DO              (pado_mem_odt)
);

GTP_IODELAY_E2 #(
 .DELAY_STEP_SEL     ("PORT"),
 .DELAY_STEP_VALUE   (8'd0)
 )u_odelay_odt(
 .DO                 (pado_mem_odt_d  ),
 .DI                 (pado_mem_odt    ),
 .DELAY_SEL          (1'b0 ),
 .DELAY_STEP         (ck_dly_set_gray )
 );

GTP_OUTBUFT  u_outbuft_odt
(
    .O     (mem_odt),
    .I     (pado_mem_odt_d),
    .T     (padt_mem_odt)
);

GTP_OSERDES_E2 #(
   .GRS_EN           ("TRUE"),                
   .OSERDES_MODE     ("HMSDR8TO1"),
   .TSERDES_EN       ("FALSE"),           
   .UPD0_SHIFT_EN    ("FALSE"),                  
   .UPD1_SHIFT_EN    ("FALSE"),                  
   .INIT_SET         (2'b00),                 
   .GRS_TYPE_DQ      ("RESET"),               
   .LRS_TYPE_DQ0     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ1     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ2     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ3     ("ASYNC_RESET"),         
   .GRS_TYPE_TQ      ("RESET"),               
   .LRS_TYPE_TQ0     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ1     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ2     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ3     ("ASYNC_RESET"),         
   .TRI_EN           ("TRUE"),               
   .TBYTE_EN         ("TRUE"),               
   .MIPI_EN          ("FALSE"),               
   .OCASCADE_EN      ("FALSE")                
)u_oserdes_csn(
   .RST             (ddrphy_dqs_rst), 
   .OCE             (1'b1),
   .TCE             (1'b1),
   .OCLKDIV         (phy_ca_sysclk_p),      
   .SERCLK          (phy_ca_clk_p),      
   .OCLK            (wclk_cs_n),
   .MIPI_CTRL       (1'b0),
   .UPD0_SHIFT      (1'b0),
   .UPD1_SHIFT      (1'b0),
   .OSHIFTIN0       (1'b0),
   .OSHIFTIN1       (1'b0),
   .DI              (adj_cs_n),
   .TI              (),
   .TBYTE_IN        (padt_cs_n),
   .OSHIFTOUT0      (),
   .OSHIFTOUT1      (),
   .TQ              (padt_mem_cs_n),
   .DO              (pado_mem_cs_n)
);

GTP_IODELAY_E2 #(
 .DELAY_STEP_SEL     ("PORT"),
 .DELAY_STEP_VALUE   (8'd0)
 )u_odelay_csn(
 .DO                 (pado_mem_cs_n_d  ),
 .DI                 (pado_mem_cs_n    ),
 .DELAY_SEL          (1'b0 ),
 .DELAY_STEP         (ck_dly_set_gray  )
 );

GTP_OUTBUFT  u_outbuft_csn
(
    .O     (mem_cs_n),
    .I     (pado_mem_cs_n_d),
    .T     (padt_mem_cs_n)
);

GTP_OSERDES_E2 #(
   .GRS_EN           ("TRUE"),                
   .OSERDES_MODE     ("HMSDR8TO1"),  
   .TSERDES_EN       ("FALSE"),         
   .UPD0_SHIFT_EN    ("FALSE"),                  
   .UPD1_SHIFT_EN    ("FALSE"),                  
   .INIT_SET         (2'b00),                 
   .GRS_TYPE_DQ      ("RESET"),               
   .LRS_TYPE_DQ0     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ1     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ2     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ3     ("ASYNC_RESET"),         
   .GRS_TYPE_TQ      ("RESET"),               
   .LRS_TYPE_TQ0     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ1     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ2     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ3     ("ASYNC_RESET"),         
   .TRI_EN           ("TRUE"),               
   .TBYTE_EN         ("TRUE"),               
   .MIPI_EN          ("FALSE"),               
   .OCASCADE_EN      ("FALSE")                
)u_oserdes_rasn(
   .RST             (ddrphy_dqs_rst), 
   .OCE             (1'b1),
   .TCE             (1'b1),
   .OCLKDIV         (phy_ca_sysclk_p),      
   .SERCLK          (phy_ca_clk_p),      
   .OCLK            (wclk_ras_n),
   .MIPI_CTRL       (1'b0),
   .UPD0_SHIFT      (1'b0),
   .UPD1_SHIFT      (1'b0),
   .OSHIFTIN0       (1'b0),
   .OSHIFTIN1       (1'b0),
   .DI              (adj_ras_n),
   .TI              (),
   .TBYTE_IN        (padt_ras_n),
   .OSHIFTOUT0      (),
   .OSHIFTOUT1      (),
   .TQ              (padt_mem_ras_n),
   .DO              (pado_mem_ras_n)
);

 GTP_IODELAY_E2 #(
 .DELAY_STEP_SEL     ("PORT"),
 .DELAY_STEP_VALUE   (8'd0)
 )u_odelay_rasn(
 .DO                 (pado_mem_ras_n_d ),
 .DI                 (pado_mem_ras_n),
 .DELAY_SEL          (1'b0),
 .DELAY_STEP         (ck_dly_set_gray)
 );

GTP_OUTBUFT  u_outbuft_rasn
(
    .O     (mem_ras_n),
    .I     (pado_mem_ras_n_d),
    .T     (padt_mem_ras_n)
);


GTP_OSERDES_E2 #(
   .GRS_EN           ("TRUE"),                
   .OSERDES_MODE     ("HMSDR8TO1"),
   .TSERDES_EN       ("FALSE"),           
   .UPD0_SHIFT_EN    ("FALSE"),                  
   .UPD1_SHIFT_EN    ("FALSE"),                  
   .INIT_SET         (2'b00),                 
   .GRS_TYPE_DQ      ("RESET"),               
   .LRS_TYPE_DQ0     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ1     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ2     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ3     ("ASYNC_RESET"),         
   .GRS_TYPE_TQ      ("RESET"),               
   .LRS_TYPE_TQ0     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ1     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ2     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ3     ("ASYNC_RESET"),         
   .TRI_EN           ("TRUE"),               
   .TBYTE_EN         ("TRUE"),               
   .MIPI_EN          ("FALSE"),               
   .OCASCADE_EN      ("FALSE")                
)u_oserdes_casn(
   .RST             (ddrphy_dqs_rst), 
   .OCE             (1'b1),
   .TCE             (1'b1),
   .OCLKDIV         (phy_ca_sysclk_p), 
   .SERCLK          (phy_ca_clk_p),     
   .OCLK            (wclk_cas_n),
   .MIPI_CTRL       (1'b0),
   .UPD0_SHIFT      (1'b0),
   .UPD1_SHIFT      (1'b0),
   .OSHIFTIN0       (1'b0),
   .OSHIFTIN1       (1'b0),
   .DI              (adj_cas_n),
   .TI              (),
   .TBYTE_IN        (padt_cas_n),
   .OSHIFTOUT0      (),
   .OSHIFTOUT1      (),
   .TQ              (padt_mem_cas_n),
   .DO              (pado_mem_cas_n)
);

 GTP_IODELAY_E2 #(
 .DELAY_STEP_SEL     ("PORT"),
 .DELAY_STEP_VALUE   (8'd0)
 )u_odelay_casn(
 .DO                 (pado_mem_cas_n_d ),
 .DI                 (pado_mem_cas_n),
 .DELAY_SEL          (1'b0),
 .DELAY_STEP         (ck_dly_set_gray)
 );

GTP_OUTBUFT  u_outbuft_casn
(
    .O     (mem_cas_n),
    .I     (pado_mem_cas_n_d),
    .T     (padt_mem_cas_n)
);

GTP_OSERDES_E2 #(
   .GRS_EN           ("TRUE"),                
   .OSERDES_MODE     ("HMSDR8TO1"), 
   .TSERDES_EN       ("FALSE"),          
   .UPD0_SHIFT_EN    ("FALSE"),                  
   .UPD1_SHIFT_EN    ("FALSE"),                  
   .INIT_SET         (2'b00),                 
   .GRS_TYPE_DQ      ("RESET"),               
   .LRS_TYPE_DQ0     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ1     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ2     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ3     ("ASYNC_RESET"),         
   .GRS_TYPE_TQ      ("RESET"),               
   .LRS_TYPE_TQ0     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ1     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ2     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ3     ("ASYNC_RESET"),         
   .TRI_EN           ("TRUE"),               
   .TBYTE_EN         ("TRUE"),               
   .MIPI_EN          ("FALSE"),               
   .OCASCADE_EN      ("FALSE")                
)u_oserdes_wen(
   .RST             (ddrphy_dqs_rst), 
   .OCE             (1'b1),
   .TCE             (1'b1),
   .OCLKDIV         (phy_ca_sysclk_p),  
   .SERCLK          (phy_ca_clk_p),      
   .OCLK            (wclk_we_n),
   .MIPI_CTRL       (1'b0),
   .UPD0_SHIFT      (1'b0),
   .UPD1_SHIFT      (1'b0),
   .OSHIFTIN0       (1'b0),
   .OSHIFTIN1       (1'b0),
   .DI              (adj_we_n),
   .TI              (),
   .TBYTE_IN        (padt_we_n),
   .OSHIFTOUT0      (),
   .OSHIFTOUT1      (),
   .TQ              (padt_mem_we_n),
   .DO              (pado_mem_we_n)
);

 GTP_IODELAY_E2 #(
 .DELAY_STEP_SEL     ("PORT"),
 .DELAY_STEP_VALUE   (8'd0)
 )u_odelay_wen(
 .DO                 (pado_mem_we_n_d ),
 .DI                 (pado_mem_we_n),
 .DELAY_SEL          (1'b0),
 .DELAY_STEP         (ck_dly_set_gray)
 );

GTP_OUTBUFT  u_outbuft_wen
(
    .O     (mem_we_n),
    .I     (pado_mem_we_n_d),
    .T     (padt_mem_we_n)
);


GTP_OSERDES_E2 #(
   .GRS_EN           ("TRUE"),                
   .OSERDES_MODE     ("HMSDR8TO1"),   
   .TSERDES_EN       ("FALSE"),        
   .UPD0_SHIFT_EN    ("FALSE"),                  
   .UPD1_SHIFT_EN    ("FALSE"),                  
   .INIT_SET         (2'b00),                 
   .GRS_TYPE_DQ      ("RESET"),               
   .LRS_TYPE_DQ0     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ1     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ2     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ3     ("ASYNC_RESET"),         
   .GRS_TYPE_TQ      ("RESET"),               
   .LRS_TYPE_TQ0     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ1     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ2     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ3     ("ASYNC_RESET"),         
   .TRI_EN           ("TRUE"),               
   .TBYTE_EN         ("TRUE"),               
   .MIPI_EN          ("FALSE"),               
   .OCASCADE_EN      ("FALSE")                
)u_oserdes_cke(
   .RST             (ddrphy_dqs_rst), 
   .OCE             (1'b1),
   .TCE             (1'b1),
   .OCLKDIV         (phy_ca_sysclk_p),     
   .SERCLK          (phy_ca_clk_p),      
   .OCLK            (wclk_cke),
   .MIPI_CTRL       (1'b0),
   .UPD0_SHIFT      (1'b0),
   .UPD1_SHIFT      (1'b0),
   .OSHIFTIN0       (1'b0),
   .OSHIFTIN1       (1'b0),
   .DI              (adj_cke),
   .TI              (),
   .TBYTE_IN        (padt_cke),
   .OSHIFTOUT0      (),
   .OSHIFTOUT1      (),
   .TQ              (padt_mem_cke),
   .DO              (pado_mem_cke)
);

GTP_IODELAY_E2 #(
 .DELAY_STEP_SEL     ("PORT"),
 .DELAY_STEP_VALUE   (8'd0)
 )u_odelay_cke(
 .DO                 (pado_mem_cke_d  ),
 .DI                 (pado_mem_cke    ),
 .DELAY_SEL          (1'b0 ),
 .DELAY_STEP         (ck_dly_set_gray )
 );

GTP_OUTBUFT  u_outbuft_cke
(
    .O     (mem_cke),
    .I     (pado_mem_cke_d),
    .T     (padt_mem_cke)
);

assign mem_rst_n = phy_rst;

//address
genvar gen_i;
generate
   for(gen_i=0; gen_i<MEM_ADDR_WIDTH; gen_i=gen_i+1) begin   : i_mem_addr_0   

GTP_OSERDES_E2 #(
   .GRS_EN           ("TRUE"),                
   .OSERDES_MODE     ("HMSDR8TO1"),
   .TSERDES_EN       ("FALSE"),           
   .UPD0_SHIFT_EN    ("FALSE"),                  
   .UPD1_SHIFT_EN    ("FALSE"),                  
   .INIT_SET         (2'b00),                 
   .GRS_TYPE_DQ      ("RESET"),               
   .LRS_TYPE_DQ0     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ1     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ2     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ3     ("ASYNC_RESET"),         
   .GRS_TYPE_TQ      ("RESET"),               
   .LRS_TYPE_TQ0     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ1     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ2     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ3     ("ASYNC_RESET"),         
   .TRI_EN           ("TRUE"),               
   .TBYTE_EN         ("TRUE"),               
   .MIPI_EN          ("FALSE"),               
   .OCASCADE_EN      ("FALSE")                
)u_oserdes_addr(
   .RST             (ddrphy_dqs_rst), 
   .OCE             (1'b1),
   .TCE             (1'b1),
   .OCLKDIV         (phy_ca_sysclk_p),            
   .SERCLK          (phy_ca_clk_p),      
   .OCLK            (wclk_a[gen_i]),
   .MIPI_CTRL       (1'b0),
   .UPD0_SHIFT      (1'b0),
   .UPD1_SHIFT      (1'b0),
   .OSHIFTIN0       (1'b0),
   .OSHIFTIN1       (1'b0),
   .DI              (adj_addr[gen_i*8+7:gen_i*8]),
   .TI              (),
   .TBYTE_IN        (padt_a[gen_i]),
   .OSHIFTOUT0      (),
   .OSHIFTOUT1      (),
   .TQ              (padt_mem_a[gen_i]),
   .DO              (pado_mem_a[gen_i])
);

 GTP_IODELAY_E2 #(
 .DELAY_STEP_SEL     ("PORT"),
 .DELAY_STEP_VALUE   (8'd0)
 )u_odelay_addr(
 .DO                 (pado_mem_a_d[gen_i]),
 .DI                 (pado_mem_a[gen_i]),
 .DELAY_SEL          (1'b0),
 .DELAY_STEP         (ck_dly_set_gray  )
 );

 GTP_OUTBUFT  u_outbuft_addr0
 (
     .O     (mem_a[gen_i]),
     .I     (pado_mem_a_d[gen_i]),
     .T     (padt_mem_a[gen_i])
 );
   end
endgenerate

genvar gen_k;
generate
    for(gen_k=0; gen_k<MEM_BANKADDR_WIDTH; gen_k=gen_k+1) begin : k_mem_ba

GTP_OSERDES_E2 #(
   .GRS_EN           ("TRUE"),                
   .OSERDES_MODE     ("HMSDR8TO1"), 
   .TSERDES_EN       ("FALSE"),          
   .UPD0_SHIFT_EN    ("FALSE"),                  
   .UPD1_SHIFT_EN    ("FALSE"),                  
   .INIT_SET         (2'b00),                 
   .GRS_TYPE_DQ      ("RESET"),               
   .LRS_TYPE_DQ0     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ1     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ2     ("ASYNC_RESET"),         
   .LRS_TYPE_DQ3     ("ASYNC_RESET"),         
   .GRS_TYPE_TQ      ("RESET"),               
   .LRS_TYPE_TQ0     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ1     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ2     ("ASYNC_RESET"),         
   .LRS_TYPE_TQ3     ("ASYNC_RESET"),         
   .TRI_EN           ("TRUE"),               
   .TBYTE_EN         ("TRUE"),               
   .MIPI_EN          ("FALSE"),               
   .OCASCADE_EN      ("FALSE")                
)u_oserdes_ba(
   .RST             (ddrphy_dqs_rst), 
   .OCE             (1'b1),
   .TCE             (1'b1),
   .OCLKDIV         (phy_ca_sysclk_p),                          
   .SERCLK          (phy_ca_clk_p),      
   .OCLK            (wclk_ba[gen_k]),
   .MIPI_CTRL       (1'b0),
   .UPD0_SHIFT      (1'b0),
   .UPD1_SHIFT      (1'b0),
   .OSHIFTIN0       (1'b0),
   .OSHIFTIN1       (1'b0),
   .DI              (adj_ba[gen_k*8+7:gen_k*8]),
   .TI              (),
   .TBYTE_IN        (padt_ba[gen_k]),
   .OSHIFTOUT0      (),
   .OSHIFTOUT1      (),
   .TQ              (padt_mem_ba[gen_k]),
   .DO              (pado_mem_ba[gen_k])
);

 GTP_IODELAY_E2 #(
 .DELAY_STEP_SEL     ("PORT"),
 .DELAY_STEP_VALUE   (8'd0)
 )u_odelay_ba(
 .DO                 (pado_mem_ba_d[gen_k] ),
 .DI                 (pado_mem_ba[gen_k]),
 .DELAY_SEL          (1'b0),
 .DELAY_STEP         (ck_dly_set_gray   )
 );

GTP_OUTBUFT  u_outbuft_ba
(
    .O     (mem_ba[gen_k]),
    .I     (pado_mem_ba_d[gen_k]),
    .T     (padt_mem_ba[gen_k])
);
    end
endgenerate

endmodule   

