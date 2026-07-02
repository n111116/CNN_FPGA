
    
////////////////////////////////////////////////////////////////
// Copyright (c) 2019 PANGO MICROSYSTEMS, INC
// ALL RIGHTS REVERVED.
////////////////////////////////////////////////////////////////
//Description:
//Author:  wxxiao
//History: v1.0
////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
module  ddr3_test_ddrphy_top  #(

  parameter         MEM_TYPE     =  "DDR3"   ,
 
  parameter [7:0]   TMRD         =  4/4   ,

  parameter [7:0]   TMOD         =  12/4   ,
  
  parameter [7:0]   TXPR         =  39     ,
  
  parameter [7:0]   TRP          =  2     ,
  
  parameter [7:0]   TRFC         =  38     ,
    
  parameter [7:0]   TRCD         =  2     ,
  
  parameter MEM_ROW_WIDTH        =  15     ,

  parameter MEM_BANK_WIDTH       =  3     ,
  
  parameter MEM_DQ_WIDTH         =  32     ,
  
  parameter MEM_DM_WIDTH         =  4     ,
  
  parameter MEM_DQS_WIDTH        =  4 
           
)(
//clk
  input                              ref_clk              ,
  input                              ddr_rstn             ,
  output                             pll_lock             ,
  output                             phy_pll_lock         ,
  output                             gpll_lock            ,
  output                             rst_gpll_lock        ,
  output                             ddrphy_cpd_lock      ,
  output                             ddrphy_sysclk        ,
 
//dfi                                           
  input  [4*MEM_ROW_WIDTH-1:0]       dfi_address          ,
  input  [4*MEM_BANK_WIDTH-1:0]      dfi_bank             ,
  input  [3:0]                       dfi_cs_n             ,
  input  [3:0]                       dfi_cas_n            ,
  input  [3:0]                       dfi_ras_n            ,
  input  [3:0]                       dfi_we_n             ,
  input  [3:0]                       dfi_cke              ,
  input  [3:0]                       dfi_odt              ,
  input  [3:0]                       dfi_wrdata_en        ,
  input  [8*MEM_DQ_WIDTH-1:0]        dfi_wrdata           ,
  input  [8*MEM_DM_WIDTH-1:0]        dfi_wrdata_mask      ,
  output [8*MEM_DQ_WIDTH-1:0]        dfi_rddata           ,
  output                             dfi_rddata_valid     ,
  input                              dfi_reset_n          ,
  output                             dfi_phyupd_req       ,
  input                              dfi_phyupd_ack       ,
  output                             dfi_init_complete    ,
  output                             dfi_error            ,


  output                             mem_cs_n             ,

  output                             mem_rst_n            ,
  output                             mem_ck               ,
  output                             mem_ck_n             ,
  output                             mem_cke              ,
  output                             mem_ras_n            ,
  output                             mem_cas_n            ,
  output                             mem_we_n             , 
  output                             mem_odt              ,
  output [MEM_ROW_WIDTH-1:0]         mem_a                ,
  output [MEM_BANK_WIDTH-1:0]        mem_ba               ,
  inout [MEM_DQS_WIDTH-1:0]          mem_dqs              ,
  inout [MEM_DQS_WIDTH-1:0]          mem_dqs_n            ,
  inout [MEM_DQ_WIDTH-1:0]           mem_dq               ,
  output [MEM_DM_WIDTH-1:0]          mem_dm               ,

  //debug
  input                              dbg_gate_start      ,
  input                              dbg_cpd_start       ,
  input                              dbg_ddrphy_rst_n    ,
  input                              dbg_gpll_scan_rst   ,
  //input                              dbg_dll_update_en   ,
  
  input                              force_samp_position  ,  
  input                              samp_position_dyn_adj,  
  input [8*MEM_DQS_WIDTH-1:0]        init_samp_position_even,
  input [8*MEM_DQS_WIDTH-1:0]        init_samp_position_odd, 

  input                              wrlvl_en             ,  
  input [8*MEM_DQS_WIDTH-1:0]        init_wrlvl_step      ,  
  input                              ck_dly_en            ,
  input [7:0]                        init_ck_dly_step     ,

  input                              wrcal_position_dyn_adj,
  input [8*MEM_DQS_WIDTH-1:0]        init_wrcal_position  , 

  input                              force_read_clk_ctrl  ,  
  input [3*MEM_DQS_WIDTH-1:0]        init_read_clk_ctrl   ,  
  input [4*MEM_DQS_WIDTH-1:0]        init_slip_step       ,  

  output [33:0]                      debug_calib_ctrl     ,
  output [17*MEM_DQS_WIDTH -1:0]     dbg_slice_status     ,
  output [22*MEM_DQS_WIDTH -1:0]     dbg_slice_state      ,
  output [69*MEM_DQS_WIDTH -1:0]     debug_data           ,
  output [1:0]                       dbg_dll_upd_state    ,
  output [8:0]                       debug_gpll_dps_phase ,
 
  output [2:0]                       dbg_rst_dps_state   ,
  output [5:0]                       dbg_tran_err_rst_cnt,
  output                             dbg_ddrphy_init_fail,
  
  input                              debug_cpd_offset_adj,
  input                              debug_cpd_offset_dir,
  input [9:0]                        debug_cpd_offset    ,
  output [9:0]                       debug_dps_cnt_dir0  , 
  output [9:0]                       debug_dps_cnt_dir1  ,

  output [7:0]                       ck_dly_set_bin      ,
  output                             ck_step_ov_warning  ,
  output [MEM_DQS_WIDTH-1:0]         wl_step_ov_warning  ,
 
  output                             align_error         ,
  output [3:0]                       debug_rst_state     ,
  output [3:0]                       debug_cpd_state     

);

localparam real CLKIN_FREQ  =  125.0   ; 

localparam GPLL_BANDWIDTH = "HIGH";

localparam PPLL_BANDWIDTH = "HIGH";


localparam DDR_TYPE = (MEM_TYPE == "DDR3") ? 2'b00 : (MEM_TYPE == "DDR2") ? 2'b01 : (MEM_TYPE == "LPDDR") ? 2'b10 : 2'b00;
localparam SC_LDO_CTRL  =  2'b00     ;
localparam SC_DLY_2X    =  1'b1      ;  //1'b0  1x delay chain, 1'b1 2x delay chain 
localparam REF_CNT   = (DDR_TYPE == 2'b10) ? 8'd2 : 8'd9;
localparam EYECAL_EN    =  1         ; 

localparam PPLL_IDIV    =  1         ;

localparam PPLL_FDIV    =  16         ;

localparam PPLL_ODIVPHY =  2         ;


localparam TEST_DATA_PATTERN0  = 64'h55_aa_55_aa_08_f7_08_f7;
localparam TEST_DATA_PATTERN1  = 64'h7f_9f_7f_9f_80_fe_80_fe;
localparam TEST_DATA_PATTERN2  = 64'hf0_0f_f0_0f_01_ff_01_ff;
localparam TEST_DATA_PATTERN3  = 64'hdf_aa_df_aa_55_aa_55_aa;

localparam      RST_GPLL_IDIV  = PPLL_IDIV;
localparam real RST_GPLL_FDIV  = PPLL_FDIV/2.0;
localparam      RST_GPLL_DUTYF = PPLL_FDIV/(PPLL_IDIV * 2);
localparam real RST_GPLL_ODIV0 = PPLL_FDIV/(PPLL_IDIV * 2);
localparam      RST_GPLL_DUTY0 = PPLL_FDIV/(PPLL_IDIV * 2);
localparam      RST_GPLL_ODIV1 = PPLL_FDIV/PPLL_IDIV;
localparam      RST_GPLL_INTERNAL_FB = "CLKOUTF" ;

localparam      GPLL_IDIV  = PPLL_IDIV;
localparam real GPLL_FDIV  = PPLL_FDIV/2.0;
localparam      GPLL_DUTYF = PPLL_FDIV/2;
localparam real GPLL_ODIV0 = PPLL_ODIVPHY*4.0;
localparam      GPLL_DUTY0 = PPLL_ODIVPHY*4; 
localparam      GPLL_ODIV1 = PPLL_ODIVPHY*8;
localparam      GPLL_INTERNAL_FB = "CLKOUTF" ;

//MR0_DDR3
localparam [0:0] DDR3_PPD      = 1'b1;

localparam [2:0] DDR3_WR       = 3'd4; 

localparam [0:0] DDR3_DLL      = 1'b1;
localparam [0:0] DDR3_TM       = 1'b0;
localparam [0:0] DDR3_RBT      = 1'b0;

localparam [3:0] DDR3_CL       = 4'd6;

localparam [1:0] DDR3_BL       = 2'b00;
localparam [15:0] MR0_DDR3     = {3'b000, DDR3_PPD, DDR3_WR, DDR3_DLL, DDR3_TM, DDR3_CL[3:1], DDR3_RBT, DDR3_CL[0], DDR3_BL};
//MR1_DDR3
localparam [0:0] DDR3_QOFF     = 1'b0;
localparam [0:0] DDR3_TDQS     = 1'b0;

localparam [2:0] DDR3_RTT_NOM  = 3'b001;       

localparam [0:0] DDR3_LEVEL    = 1'b0;

localparam [1:0] DDR3_DIC      = 2'b00;

localparam [1:0] DDR3_AL       = 2'd2;

localparam [0:0] DDR3_DLL_EN   = 1'b0;
localparam [15:0] MR1_DDR3 = {1'b0, DDR3_QOFF, DDR3_TDQS, 1'b0, DDR3_RTT_NOM[2], 1'b0, DDR3_LEVEL, DDR3_RTT_NOM[1], DDR3_DIC[1], DDR3_AL, DDR3_RTT_NOM[0], DDR3_DIC[0], DDR3_DLL_EN};
//MR2_DDR3
localparam [1:0] DDR3_RTT_WR   = 2'b00;
localparam [0:0] DDR3_SRT      = 1'b0;
localparam [0:0] DDR3_ASR      = 1'b0;

localparam [2:0] DDR3_CWL      = 6 - 5;

localparam [2:0] DDR3_PASR     = 3'b000;
localparam [15:0] MR2_DDR3     = {5'b00000, DDR3_RTT_WR, 1'b0, DDR3_SRT, DDR3_ASR, DDR3_CWL, DDR3_PASR};
//MR3_DDR3
localparam [0:0] DDR3_MPR      = 1'b0;
localparam [1:0] DDR3_MPR_LOC  = 2'b00;
localparam [15:0] MR3_DDR3     = {13'b0, DDR3_MPR, DDR3_MPR_LOC};

//MR_DDR2
localparam [2:0] DDR2_BL       = 3'b011;
localparam [0:0] DDR2_BT       = 1'b0; //Sequential

localparam [2:0] DDR2_CL       = 3'd4;

localparam [0:0] DDR2_TM       = 1'b0;
localparam [0:0] DDR2_DLL      = 1'b1;

localparam [2:0] DDR2_WR       = 3'd5; 

localparam [0:0] DDR2_PD       = 1'b0;
localparam [15:0]  MR_DDR2     = {3'b000,DDR2_PD,DDR2_WR,DDR2_DLL,DDR2_TM,DDR2_CL,DDR2_BT,DDR2_BL};

//EMR1_DDR2
localparam [0:0] DDR2_DLL_EN      = 1'b0;

localparam [0:0] DDR2_DIC      = 1'b0;

localparam [1:0] DDR2_RTT_NOM  = 2'b01;     

localparam [2:0] DDR2_AL       = 3'd2; 
  
localparam [2:0] DDR2_OCD      = 3'b000;
localparam [0:0] DDR2_DQS      = 1'b0;
localparam [0:0] DDR2_RDQS     = 1'b0;
localparam [0:0] DDR2_QOFF     = 1'b0;
localparam [15:0] EMR1_DDR2    = {3'b000,DDR2_QOFF,DDR2_RDQS,DDR2_DQS,DDR2_OCD,DDR2_RTT_NOM[1],DDR2_AL,DDR2_RTT_NOM[0],DDR2_DIC,DDR2_DLL_EN};

localparam [15:0] EMR2_DDR2    =16'h0000;
localparam [15:0] EMR3_DDR2    =16'h0000;
 
//MR_LPDDR
localparam [2:0] LPDDR_BL      = 3'b011;
localparam [0:0] LPDDR_BT      = 1'b0;

localparam [2:0] LPDDR_CL      = 3'd2;

localparam [15:0] MR_LPDDR    = {9'd0,LPDDR_CL,LPDDR_BT,LPDDR_BL};

//EMR_LPDDR

localparam [2:0] LPDDR_DS      = 3'b000;

localparam [15:0] EMR_LPDDR    = {8'd0,LPDDR_DS,5'd0};

localparam [9:0]   TZQINIT      =  10'd128 ;


localparam DFI_CLK_PERIOD =  8000;


`ifdef IPS_DDR_SPEEDUP_SIM                                                  
localparam T200US         = (210*1000*1000 / DFI_CLK_PERIOD) / 100;
`else                                                              
localparam T200US         = (210*1000*1000 / DFI_CLK_PERIOD);      
`endif

`ifdef IPS_DDR_SPEEDUP_SIM                                                  
localparam T500US         = (510*1000*1000 / DFI_CLK_PERIOD) / 100;
`else                                                              
localparam T500US         = (510*1000*1000 / DFI_CLK_PERIOD);      
`endif

localparam T400NS         = 410*1000 / DFI_CLK_PERIOD;
                                  
wire [2:0]                      ddrphy_ioclk_gate            ;
wire                            dll_lock                     ;
wire                            dll_update_n                 ;
wire                            dll_update_n_syn             ;
wire                            ddrphy_dll_rst_n             ;
wire                            dll_update_code_done         ;
wire                            dll_update_req_rst_ctrl      ;
wire                            dll_update_ack_rst_ctrl      ;
wire                            ddrphy_rst_n                 ;
wire [4:0]                      mc_wl                        ;
wire [4:0]                      mc_rl                        ;
wire [15:0]                     mr0                          ;
wire [15:0]                     mr1                          ;
wire [15:0]                     mr2                          ;
wire [15:0]                     mr3                          ;
wire                            calib_done                   ;
wire                            update_cal_req               ;
wire                            update_done                  ;
wire                            ddrphy_rst_req               ;
wire                            ddrphy_rst_ack               ;
wire                            wrlvl_dqs_req                ;
wire                            wrlvl_dqs_resp               ;
wire                            wrlvl_error                  ;
wire                            gatecal_start                ;
wire                            gate_check_pass              ;
wire                            gate_adj_done                ;
wire                            gate_cal_error               ;
wire                            read_pattern_error           ;
wire                            gate_move_en                 ;
wire                            rddata_cal                   ;
wire                            rddata_check_pass            ;
wire                            init_adj_rdel                ;
wire                            adj_rdel_done                ;
wire                            rdel_calibration             ;
wire                            rdel_calib_done              ;
wire                            rdel_calib_error             ;
wire                            rdel_move_en                 ;
wire                            rdel_move_done               ;
wire                            bitslip_ctrl                 ;
wire                            wrcal_check_pass             ;
wire [8:0]                      write_calibration            ;
wire [8:0]                      wrcal_move_en                ;
wire                            wrcal_move_done              ;
wire                            wrcal_error                  ;
wire                            eye_calibration              ;
wire                            eyecal_check_pass            ;
wire                            eyecal_move_done             ;
wire                            eyecal_move_en               ;
wire [2*MEM_DQS_WIDTH-1:0]      comp_val                     ;
wire [MEM_DQS_WIDTH-1:0]        comp_dir                     ;
wire                            dqs_gate_comp_en             ;
wire                            dqs_gate_comp_done           ;
wire                            calib_rst                    ;
wire [MEM_BANK_WIDTH-1:0]       calib_ba                     ;
wire [MEM_ROW_WIDTH-1:0]        calib_address                ;
wire                            calib_cs_n                   ;
wire                            calib_ras_n                  ;
wire                            calib_cas_n                  ;
wire                            calib_we_n                   ;
wire                            calib_cke                    ;
wire                            calib_odt                    ;
wire [3:0]                      calib_wrdata_en              ;
wire [8*MEM_DQ_WIDTH-1:0]       calib_wrdata                 ;
wire [8*MEM_DM_WIDTH-1:0]       calib_wrdata_mask            ;
wire                            ddrphy_dqs_training_rstn     ;
wire [3:0]                      read_cmd                     ;
wire     	                    read_valid                   ;
wire [8*MEM_DQ_WIDTH-1:0]       o_read_data                  ;
wire [3:0]                      phy_wrdata_en                ;
wire [8*MEM_DM_WIDTH-1:0]       phy_wrdata_mask              ;
wire [8*MEM_DQ_WIDTH-1:0]       phy_wrdata                   ;
wire [3:0]                      phy_cke                      ;
wire [3:0]                      phy_cs_n                     ;
wire [3:0]                      phy_ras_n                    ;
wire [3:0]                      phy_cas_n                    ;
wire [3:0]                      phy_we_n                     ;
wire [4*MEM_ROW_WIDTH-1:0]      phy_addr                     ;
wire [4*MEM_BANK_WIDTH-1:0]     phy_ba                       ;
wire [3:0]                      phy_odt                      ;
wire [3:0]                      phy_ck                       ;
wire                            phy_rst                      ;

wire                            phy_sysclk_fb                ;  
wire                            phy_ioclk_fb                 ;
//wire                            phy_pll_lock                 ;
wire                            ddrphy_cpd_rstn              ;
wire                            ddrphy_cpd_up_dnb            ;
wire                            ddrphy_cpd_done              ;
wire                            ddrphy_cpd_start             ;
wire                            gpll_dps_en                  ;
wire                            gpll_dps_dir                 ;
wire                            gpll_dps_done                ;
//wire                            gpll_lock                    ;
wire                            dll_freeze                   ; 
wire                            dll_freeze_syn               ; 
wire                            dll_tran_update_en           ;
wire                            ddrphy_update                ;
wire                            ddrphy_update_done           ;
wire [2*MEM_DQS_WIDTH-1:0]      ddrphy_update_comp_val       ;
wire [MEM_DQS_WIDTH-1:0]        ddrphy_update_comp_dir       ;
wire [2*MEM_DQS_WIDTH-1:0]      dqs_drift                    ;
wire                            ddrphy_iol_rst               ;
wire                            gpll_clkout0                 ;
wire                            pll_refclk                   ;
wire                            g_refclk                     ;
wire                            logic_rstn                   ;
wire                            phy_pll_rst                  ;
wire                            dfi_refresh                  ;

wire                            ddrphy_cpd_rstn_synced       ;
wire                            logic_rstn_synced            ;

wire                            training_error               ;

wire                            force_read_clk_ctrl_syn      ;
wire                            force_samp_position_syn      ;
wire                            samp_position_dyn_adj_syn    ;
wire                            wrcal_position_dyn_adj_syn   ;
wire                            rst_gpll_clkout0             ;
wire                            rst_clk                      ;
wire                            rst_seq_rstn                 ;

wire                            rst_clk_adj_start            ;
wire                            rst_clk_dps_done             ;
wire                            rst_clk_adj_done             ;
wire                            rst_clk_adj_dir              ;
wire                            rst_clk_adj_en               ;      

assign pll_lock = phy_pll_lock & gpll_lock;

//GTP_CLKBUFG u_refclk_bufg
//(
//    .CLKOUT                     (g_refclk                     ),
//    .CLKIN                      (ref_clk                      )
//);

GTP_CLKBUFM u_clkbufm
(
    .CLKOUT                     (pll_refclk                   ),
    .CLKIN                      (ref_clk                      )
);

ips2l_ddrphy_rst_clk_phase_adj_v1_0 #(
    .PHASE_ADJ_DIR              (0                            ),
    .PHASE_ADJ_STEP             (8                            )
)
u_ips2l_ddrphy_rst_clk_phase_adj
(
    .dps_clk                    (ddrphy_sysclk                ),
    .ddr_rstn                   (ddr_rstn                     ),
    .rst_clk_adj_start          (rst_clk_adj_start            ),
    .rst_clk_dps_done           (rst_clk_dps_done             ),
    .cpd_state                  (dbg_rst_dps_state            ),
    .rst_clk_adj_done           (rst_clk_adj_done             ),
    .rst_clk_adj_dir            (rst_clk_adj_dir              ),
    .rst_clk_adj_en             (rst_clk_adj_en               )        
);

ips2l_ddrphy_gpll_v1_3 #(
    .CLKIN_FREQ                 (CLKIN_FREQ                   ),
    .BANDWIDTH                  (GPLL_BANDWIDTH               ),
    .IDIV                       (RST_GPLL_IDIV                ),
    .FDIV                       (RST_GPLL_FDIV                ),
    .DUTYF                      (RST_GPLL_DUTYF               ),
    .ODIV0                      (RST_GPLL_ODIV0               ),
    .ODIV1                      (RST_GPLL_ODIV1               ),
    .DUTY0                      (RST_GPLL_DUTY0               ), 
    .STATIC_PHASE0              (0                            ),
    .INTERNAL_FB                (RST_GPLL_INTERNAL_FB         )    
)rst_clk_gpll(
    .clk_in0                    (ref_clk                      ),
    .pll_rst                    (~ddr_rstn                    ),
    .dps_clk                    (ddrphy_sysclk                ),
    .dps_en                     (rst_clk_adj_en               ),
    .dps_dir                    (rst_clk_adj_dir              ),
    .clkout0_gate               (1'b0                         ),
    .clkout0                    (rst_gpll_clkout0             ),
    .clkout0n                   (                             ),
    .clkout1                    (                             ),
    .clkout1n                   (                             ),
    .dps_done                   (rst_clk_dps_done             ),
    .pll_lock                   (rst_gpll_lock                )    
);

GTP_CLKBUFG u_rst_clk_bufg
(
   .CLKOUT                      (rst_clk                      ),
   .CLKIN                       (rst_gpll_clkout0             )
);

ips2l_rst_sync_v1_3 #(
    .DATA_WIDTH                 (1                            ),
    .DFT_VALUE                  (1'b0                         )
) u_ddrphy_rst_seq_rstn_sync(
    .clk                        (rst_clk                      ),
    .rst_n                      (ddr_rstn                     ),
    .sig_async                  (rst_gpll_lock                ),
    .sig_synced                 (rst_seq_rstn                 )
);

ips2l_ddrphy_gpll_v1_3 #(
    .CLKIN_FREQ                 (CLKIN_FREQ                   ),
    .BANDWIDTH                  (GPLL_BANDWIDTH               ),
    .IDIV                       (GPLL_IDIV                    ),
    .FDIV                       (GPLL_FDIV                    ),
    .DUTYF                      (GPLL_DUTYF                   ),
    .ODIV0                      (GPLL_ODIV0                   ),
    .ODIV1                      (GPLL_ODIV1                   ),
    .DUTY0                      (GPLL_DUTY0                   ), 
    .STATIC_PHASE0              (0                            ),
    .INTERNAL_FB                (GPLL_INTERNAL_FB             )   
)ddrphy_gpll(
    .clk_in0                    (ref_clk                      ),
    .pll_rst                    (phy_pll_rst                  ),
    .dps_clk                    (rst_clk                      ),
    .dps_en                     (gpll_dps_en                  ),
    .dps_dir                    (gpll_dps_dir                 ),
    .clkout0_gate               (1'b0                         ),
    .clkout0                    (gpll_clkout0                 ),
    .clkout0n                   (                             ),
    .clkout1                    (                             ),
    .clkout1n                   (                             ),
    .dps_done                   (gpll_dps_done                ),
    .pll_lock                   (gpll_lock                    )    
);

ips2l_ddrphy_gpll_phase_v1_0 u_ddrphy_gpll_phase 
(
    .gpll_dps_clk               (rst_clk                      ),
    .ddr_rst_n                  (rst_seq_rstn                 ),
    .gpll_dps_done              (gpll_dps_done                ),
    .gpll_dps_dir               (gpll_dps_dir                 ),
    .gpll_dps_phase             (debug_gpll_dps_phase         )       
);
  
GTP_CLKBUFG u_sysclk_bufg
(
    .CLKOUT                     (ddrphy_sysclk                ),
    .CLKIN                      (gpll_clkout0                 )
);


GTP_CLKPD u_ddrphy_cpd(
    .FLAG_PD                    (ddrphy_cpd_up_dnb            ),
    .LOCK                       (                             ),
    .RST                        (ddrphy_cpd_rstn              ),
    .CLK_SAMPLE                 (phy_ioclk_fb                 ),
    .CLK_CTRL                   (ddrphy_sysclk                ),
    .CLK_PHY                    (phy_sysclk_fb                ),
    .DONE                       (ddrphy_cpd_done              )
);

ips2l_rst_sync_v1_3 #(
    .DATA_WIDTH                 (1                            ),
    .DFT_VALUE                  (1'b0                         )
) u_ddrphy_cpd_rstn_sync(
    .clk                        (ddrphy_sysclk                ),
    .rst_n                      (ddrphy_cpd_rstn              ),
    .sig_async                  (1'b1                         ),
    .sig_synced                 (ddrphy_cpd_rstn_synced       )
);

ips2l_ddrphy_cpd_lock_v1_0 u_ips2l_ddrphy_cpd_lock
(
    .ddrphy_sysclk              (ddrphy_sysclk                ),
    .ddrphy_rst_n               (ddrphy_cpd_rstn_synced       ),
    .ddrphy_cpd_up_dnb          (ddrphy_cpd_up_dnb            ),
    .ddrphy_cpd_lock            (ddrphy_cpd_lock              )       
  );

ips2l_ddrphy_cpd_ctrl_v1_3 ddrphy_cpd_ctrl
(
    .dps_clk                    (rst_clk                      ),
    .ddr_rstn                   (logic_rstn                   ),  
    .ddrphy_cpd_start           (ddrphy_cpd_start             ),
    .ddrphy_cpd_up_dnb          (ddrphy_cpd_up_dnb            ),
    .ddrphy_cpd_lock            (ddrphy_cpd_lock              ),
    .ddrphy_cpd_rstn            (ddrphy_cpd_rstn              ),
    .gpll_dps_done              (gpll_dps_done                ),
    .ddrphy_cpd_done            (ddrphy_cpd_done              ),
    .gpll_dps_en                (gpll_dps_en                  ),
    .gpll_dps_dir               (gpll_dps_dir                 ),
    .debug_cpd_offset_adj       (debug_cpd_offset_adj         ),
    .debug_cpd_offset_dir       (debug_cpd_offset_dir         ),
    .debug_cpd_offset           (debug_cpd_offset             ),
    .debug_cpd_state            (debug_cpd_state              ),
    .debug_dps_cnt_dir0         (debug_dps_cnt_dir0           ), 
    .debug_dps_cnt_dir1         (debug_dps_cnt_dir1           ) 
);
                  
 ips2l_ddrphy_reset_ctrl_v1_3  ddrphy_reset_ctrl(
    .ddr_rstn                   (rst_seq_rstn                 ),                    
    .rst_clk                    (rst_clk                      ),
    .ddrphy_sysclk              (ddrphy_sysclk                ),
    .dll_lock                   (dll_lock                     ),
    .pll_lock                   (pll_lock                     ),
    //debug
    .dbg_gpll_scan_rst          (dbg_gpll_scan_rst            ),
    .dbg_gate_start             (dbg_gate_start               ),
    .dbg_cpd_start              (dbg_cpd_start                ),
    .dbg_ddrphy_rst_n           (dbg_ddrphy_rst_n             ),
    //
    .ddrphy_cpd_done            (ddrphy_cpd_done              ),
    .ddrphy_cpd_start           (ddrphy_cpd_start             ),   
    .dll_update_req_rst_ctrl    (dll_update_req_rst_ctrl      ),
    .dll_update_ack_rst_ctrl    (dll_update_ack_rst_ctrl      ), 
    .dll_tran_update_en         (dll_tran_update_en           ),
    .ddrphy_calib_done          (calib_done                   ),
    .training_error             (dfi_error                    ),
    .logic_rstn                 (logic_rstn                   ),
    .phy_pll_rst                (phy_pll_rst                  ),   
    .rst_clk_adj_start          (rst_clk_adj_start            ),
    .rst_clk_adj_done           (rst_clk_adj_done             ),
    .tran_err_rst_cnt           (dbg_tran_err_rst_cnt         ),
    .ddrphy_init_fail           (dbg_ddrphy_init_fail         ),
    .ddrphy_dll_rst_n           (ddrphy_dll_rst_n             ),
    .ddrphy_rst_n               (ddrphy_rst_n                 ),
    .ddrphy_dqs_rst             (ddrphy_dqs_rst               ),
    .ddrphy_iol_rst             (ddrphy_iol_rst               ),
    .ddrphy_ioclk_gate          (ddrphy_ioclk_gate            ),
    .debug_rst_state            (debug_rst_state              )
 );

 ips2l_ddrphy_dll_update_ctrl_v1_3 ddrphy_dll_update_ctrl(
    .rst_clk                    (rst_clk                      ),
    .ddr_rstn                   (logic_rstn                   ),
    .dbg_dll_update_en          (1'b0                         ), //dbg_dll_update_en            ),
    .dfi_refresh                (dfi_refresh                  ),
    .dll_update_req_rst_ctrl    (dll_update_req_rst_ctrl      ),
    .dll_update_ack_rst_ctrl    (dll_update_ack_rst_ctrl      ),
    .dll_tran_update_en         (dll_tran_update_en           ),
    .dll_update_code_done       (dll_update_code_done         ),
    .dll_freeze                 (dll_freeze                   ),
    .dll_update_n               (dll_update_n                 ),
    .dbg_dll_upd_state          (dbg_dll_upd_state            )
 );

ips2l_rst_sync_v1_3 #(
    .DATA_WIDTH                 (1                            ),
    .DFT_VALUE                  (1'b1                         )
) u_dll_update_n_sync(
    .clk                        (ddrphy_sysclk                ),
    .rst_n                      (ddrphy_dll_rst_n             ),
    .sig_async                  (dll_update_n                 ),
    .sig_synced                 (dll_update_n_syn             )
);

ips2l_rst_sync_v1_3 #(
    .DATA_WIDTH                 (1                            ),
    .DFT_VALUE                  (1'b0                         )
) u_dll_freeze_sync(
    .clk                        (ddrphy_sysclk                ),
    .rst_n                      (ddrphy_dll_rst_n             ),
    .sig_async                  (dll_freeze                   ),
    .sig_synced                 (dll_freeze_syn               )
);

ips2l_ddrphy_gate_update_ctrl_v1_3 #(
    .UPDATE_EN                  (1'b0                         ),
    .MEM_DQS_WIDTH              (MEM_DQS_WIDTH                )
)ddrphy_gate_update_ctrl(
    .ddrphy_sysclk              (ddrphy_sysclk                ),
    .ddrphy_rst_n               (ddrphy_rst_n                 ),
    .calib_done                 (calib_done                   ),
    .dqs_drift                  (dqs_drift                    ),
    .ddrphy_update_done         (ddrphy_update_done           ),
    .update_start               (ddrphy_update                ),
    .ddrphy_update_comp_val     (ddrphy_update_comp_val       ),
    .ddrphy_update_comp_dir     (ddrphy_update_comp_dir       )
);

 ips2l_ddrphy_calib_top_v1_10 #(
    .DDR_TYPE                   (DDR_TYPE                     ),
    .WRCAL_EN                   (1'b0                         ),
    .EYECAL_EN                  (EYECAL_EN                    ),
    .T200US                     (T200US                       ),
    .T500US                     (T500US                       ),
    .T400NS                     (T400NS                       ),
    .TMRD                       (TMRD                         ),
    .TMOD                       (TMOD                         ),
    .TXPR                       (TXPR                         ),
    .TRP                        (TRP                          ),
    .TZQINIT                    (TZQINIT                      ),
    .TRFC                       (TRFC                         ),
    .TRCD                       (TRCD                         ),
    .REF_CNT                    (REF_CNT                      ),
    .TEST_DATA_PATTERN0         (TEST_DATA_PATTERN0           ),
    .TEST_DATA_PATTERN1         (TEST_DATA_PATTERN1           ),
    .TEST_DATA_PATTERN2         (TEST_DATA_PATTERN2           ),
    .TEST_DATA_PATTERN3         (TEST_DATA_PATTERN3           ),
    .MEM_ADDR_WIDTH             (MEM_ROW_WIDTH                ),
    .MEM_BANKADDR_WIDTH         (MEM_BANK_WIDTH               ),
    .MEM_DQ_WIDTH               (MEM_DQ_WIDTH                 ),
    .MEM_DM_WIDTH               (MEM_DM_WIDTH                 ),
    .MEM_DQS_WIDTH              (MEM_DQS_WIDTH                )
  )ddrphy_calib_top(            
    .mc_wl                      (mc_wl                        ),
    .mr0                        (mr0                          ),
    .mr1                        (mr1                          ),
    .mr2                        (mr2                          ),
    .mr3                        (mr3                          ),

    .ddrphy_sysclk              (ddrphy_sysclk                ),
    .ddrphy_rst_n               (ddrphy_rst_n                 ),
    .calib_done                 (calib_done                   ),
    .update_done                (update_done                  ),
    .ddrphy_rst_req             (ddrphy_rst_req               ),
    .ddrphy_rst_ack             (ddrphy_rst_ack               ),
    .wrlvl_en                   (wrlvl_en                     ),
    .wrlvl_dqs_req              (wrlvl_dqs_req                ),
    .wrlvl_dqs_resp             (wrlvl_dqs_resp               ),
    .wrlvl_error                (wrlvl_error                  ),
    .gatecal_start              (gatecal_start                ),
    .gate_check_pass            (gate_check_pass              ),
    .gate_adj_done              (gate_adj_done                ),
    .gate_cal_error             (gate_cal_error               ),
    .read_pattern_error         (read_pattern_error           ),
    .gate_move_en               (gate_move_en                 ),
    .rddata_cal                 (rddata_cal                   ),
    .rddata_check_pass          (rddata_check_pass            ),
    .init_adj_rdel              (init_adj_rdel                ),
    .adj_rdel_done              (adj_rdel_done                ),
    .rdel_calibration           (rdel_calibration             ),
    .rdel_calib_done            (rdel_calib_done              ),
    .rdel_calib_error           (rdel_calib_error             ),
    .rdel_move_en               (rdel_move_en                 ),
    .rdel_move_done             (rdel_move_done               ),
    .bitslip_ctrl               (bitslip_ctrl                 ),
    .write_debug                (1'b0                         ),
    .dqgt_debug                 (1'b0                         ),
    .rdel_rd_cnt                (8'd32                        ),

    .wrcal_check_pass           (wrcal_check_pass             ),
    .write_calibration          (write_calibration            ),
    .wrcal_move_en              (wrcal_move_en                ),
    .wrcal_move_done            (wrcal_move_done              ),
    .wrcal_error                (wrcal_error                  ),

    .eye_calibration            (eye_calibration              ),
    .eyecal_check_pass          (eyecal_check_pass            ),
    .eyecal_move_done           (eyecal_move_done             ),
    .eyecal_move_en             (eyecal_move_en               ),
    .dfi_error                  (dfi_error                    ),
    .debug_calib_ctrl           (debug_calib_ctrl             ),

    .update_cal_req             (update_cal_req               ),
    .update_comp_val            (ddrphy_update_comp_val       ),
    .update_comp_dir            (ddrphy_update_comp_dir       ),
    .comp_val                   (comp_val                     ),
    .comp_dir                   (comp_dir                     ),
    .dqs_gate_comp_en           (dqs_gate_comp_en             ),
    .dqs_gate_comp_done         (dqs_gate_comp_done           ),

    .calib_ba                   (calib_ba                     ),
    .calib_address              (calib_address                ),
    .calib_cs_n                 (calib_cs_n                   ),
    .calib_ras_n                (calib_ras_n                  ),
    .calib_cas_n                (calib_cas_n                  ),
    .calib_we_n                 (calib_we_n                   ),
    .calib_cke                  (calib_cke                    ),
    .calib_odt                  (calib_odt                    ),
    .calib_rst                  (calib_rst                    ),
    .calib_wrdata_en            (calib_wrdata_en              ),
    .calib_wrdata               (calib_wrdata                 ),
    .calib_wrdata_mask          (calib_wrdata_mask            )
  );

 ips2l_ddrphy_training_ctrl_v1_0 ddrphy_training_ctrl
 (
    .ddrphy_sysclk              (ddrphy_sysclk                ),
    .ddrphy_rst_n               (ddrphy_rst_n                 ),
    .ddrphy_rst_req             (ddrphy_rst_req               ),
    .ddrphy_rst_ack             (ddrphy_rst_ack               ),
    .ddrphy_dqs_training_rstn   (ddrphy_dqs_training_rstn     )
 );

ips2l_rst_sync_v1_3 #(
    .DATA_WIDTH                 (1                            ),
    .DFT_VALUE                  (1'b0                         )
) u_force_read_clk_ctrl_sync(
    .clk                        (ddrphy_sysclk                ),
    .rst_n                      (ddrphy_rst_n                 ),
    .sig_async                  (force_read_clk_ctrl          ),
    .sig_synced                 (force_read_clk_ctrl_syn      )
);

ips2l_rst_sync_v1_3 #(
    .DATA_WIDTH                 (1                            ),
    .DFT_VALUE                  (1'b0                         )
) u_force_samp_position_sync(
    .clk                        (ddrphy_sysclk                ),
    .rst_n                      (ddrphy_rst_n                 ),
    .sig_async                  (force_samp_position          ),
    .sig_synced                 (force_samp_position_syn      )
);

ips2l_rst_sync_v1_3 #(
    .DATA_WIDTH                 (1                            ),
    .DFT_VALUE                  (1'b0                         )
) u_samp_position_dyn_adj_sync(
    .clk                        (ddrphy_sysclk                ),
    .rst_n                      (ddrphy_rst_n                 ),
    .sig_async                  (samp_position_dyn_adj        ),
    .sig_synced                 (samp_position_dyn_adj_syn    )
);

ips2l_rst_sync_v1_3 #(
    .DATA_WIDTH                 (1                            ),
    .DFT_VALUE                  (1'b0                         )
) u_wrcal_position_dyn_adj_sync(
    .clk                        (ddrphy_sysclk                ),
    .rst_n                      (ddrphy_rst_n                 ),
    .sig_async                  (wrcal_position_dyn_adj       ),
    .sig_synced                 (wrcal_position_dyn_adj_syn   )
);

 ddr3_test_slice_top_v1_10 #(
    .CLKIN_FREQ                 (CLKIN_FREQ                   ), 
    .PPLL_BANDWIDTH             (PPLL_BANDWIDTH               ),
    .DDR_TYPE                   (DDR_TYPE                     ),
    .TEST_DATA_PATTERN0         (TEST_DATA_PATTERN0           ),
    .TEST_DATA_PATTERN1         (TEST_DATA_PATTERN1           ),
    .TEST_DATA_PATTERN2         (TEST_DATA_PATTERN2           ),
    .TEST_DATA_PATTERN3         (TEST_DATA_PATTERN3           ),
    .GATE_MODE                  (1'b1                         ),
    .SC_LDO_CTRL                (SC_LDO_CTRL                  ),
    .SC_DLY_2X                  (SC_DLY_2X                    ),
    .PPLL_IDIV                  (PPLL_IDIV                    ),
    .PPLL_FDIV                  (PPLL_FDIV                    ),
    .PPLL_ODIVPHY               (PPLL_ODIVPHY                 ),
    .MEM_ADDR_WIDTH             (MEM_ROW_WIDTH                ),
    .MEM_BANKADDR_WIDTH         (MEM_BANK_WIDTH               ),
    .MEM_DQ_WIDTH               (MEM_DQ_WIDTH                 ),
    .MEM_DQS_WIDTH              (MEM_DQS_WIDTH                ),
    .MEM_DM_WIDTH               (MEM_DM_WIDTH                 )
 )ddrphy_slice_top(                          
    .mc_rl                      (mc_rl                        ),
    .force_read_clk_ctrl        (force_read_clk_ctrl_syn      ),
    .init_read_clk_ctrl         (init_read_clk_ctrl           ),
    .init_slip_step             (init_slip_step               ),
    .force_samp_position        (force_samp_position_syn      ),
    .samp_position_dyn_adj      (samp_position_dyn_adj_syn    ),
    .init_samp_position_even    (init_samp_position_even      ),
    .init_samp_position_odd     (init_samp_position_odd       ),
    .init_wrlvl_step            (init_wrlvl_step              ),
    .ck_dly_en                  (ck_dly_en                    ),
    .init_ck_dly_step           (init_ck_dly_step             ),
                                               
    .ddrphy_sysclk              (ddrphy_sysclk                ),
    .ddrphy_rst_n               (ddrphy_rst_n                 ),
    .phy_refclk                 (pll_refclk                   ),
    .phy_pll_rst                (phy_pll_rst                  ),
    .clkoutphy_gate             (ddrphy_ioclk_gate            ), 
    .ioclkdiv_rst               (ddrphy_dqs_rst               ), 
    .dll_rstn                   (ddrphy_dll_rst_n             ),
    .dll_freeze                 (dll_freeze_syn               ),
    .dll_update_n               (dll_update_n_syn             ),
    .dll_update_code_done       (dll_update_code_done         ),
    .phy_pll_lock               (phy_pll_lock                 ),
    .phy_dll_lock               (dll_lock                     ),
    .phy_sysclk_fb              (phy_sysclk_fb                ),
    .phy_ioclk_fb               (phy_ioclk_fb                 ),
    .ddrphy_iol_rst             (ddrphy_iol_rst               ),
    
    .ddrphy_dqs_rst             (ddrphy_dqs_rst               ),
    .ddrphy_dqs_training_rstn   (ddrphy_dqs_training_rstn     ),
                          
    .wrlvl_dqs_req              (wrlvl_dqs_req                ),
    .wrlvl_dqs_resp             (wrlvl_dqs_resp               ),
    .wrlvl_error                (wrlvl_error                  ),
    .ck_step_ov_warning         (ck_step_ov_warning           ),
    .wl_step_ov_warning         (wl_step_ov_warning           ),
                           
    .gatecal_start              (gatecal_start                ),
    .gate_check_pass            (gate_check_pass              ),
    .gate_adj_done              (gate_adj_done                ),
    .gate_cal_error             (gate_cal_error               ),
    .gate_move_en               (gate_move_en                 ),
    .read_pattern_error         (read_pattern_error           ), 

    .rddata_cal                 (rddata_cal                   ),
    .rddata_check_pass          (rddata_check_pass            ),
    .read_cmd                   (read_cmd                     ),
    
    .dqs_drift                  (dqs_drift                    ),
    .comp_val                   (comp_val                     ),
    .comp_dir                   (comp_dir                     ),
    .dqs_gate_comp_en           (dqs_gate_comp_en             ),
    .dqs_gate_comp_done         (dqs_gate_comp_done           ),
                          
    .init_adj_rdel              (init_adj_rdel                ),
    .adj_rdel_done              (adj_rdel_done                ),
    .rdel_calibration           (rdel_calibration             ),
    .rdel_calib_done            (rdel_calib_done              ),
    .rdel_calib_error           (rdel_calib_error             ),
    .rdel_move_en               (rdel_move_en                 ),
    .rdel_move_done             (rdel_move_done               ),
    .bitslip_ctrl               (bitslip_ctrl                 ),

    .wrcal_position_dyn_adj     (wrcal_position_dyn_adj_syn   ),           
    .init_wrcal_position        (init_wrcal_position          ),
    .wrcal_check_pass           (wrcal_check_pass             ),
    .write_calibration          (write_calibration            ),
    .wrcal_move_en              (wrcal_move_en                ),
    .wrcal_move_done            (wrcal_move_done              ),
    .wrcal_error                (wrcal_error                  ),
                                                              
    .eye_calibration            (eye_calibration              ),
    .eyecal_check_pass          (eyecal_check_pass            ),
    .eyecal_move_done           (eyecal_move_done             ),
    .eyecal_move_en             (eyecal_move_en               ),

    .read_valid                 (read_valid                   ),
    .o_read_data                (o_read_data                  ),
    .align_error                (align_error                  ),
    
    .ck_dly_set_bin             (ck_dly_set_bin               ),
          
    .phy_wrdata_en              (phy_wrdata_en                ),
    .phy_wrdata_mask            (phy_wrdata_mask              ),
    .phy_wrdata                 (phy_wrdata                   ),
    .phy_cke                    (phy_cke                      ),
    .phy_cs_n                   (phy_cs_n                     ),
    .phy_ras_n                  (phy_ras_n                    ),
    .phy_cas_n                  (phy_cas_n                    ),
    .phy_we_n                   (phy_we_n                     ),
    .phy_addr                   (phy_addr                     ),
    .phy_ba                     (phy_ba                       ),
    .phy_odt                    (phy_odt                      ),
    .phy_ck                     (phy_ck                       ),
    .phy_rst                    (phy_rst                      ),


    .mem_cs_n                   (mem_cs_n                     ),

    .mem_rst_n                  (mem_rst_n                    ),
    .mem_ck                     (mem_ck                       ),
    .mem_ck_n                   (mem_ck_n                     ),
    .mem_cke                    (mem_cke                      ),
    .mem_ras_n                  (mem_ras_n                    ),
    .mem_cas_n                  (mem_cas_n                    ),
    .mem_we_n                   (mem_we_n                     ),
    .mem_odt                    (mem_odt                      ),
    .mem_a                      (mem_a                        ),
    .mem_ba                     (mem_ba                       ),
    .mem_dqs                    (mem_dqs                      ),
    .mem_dqs_n                  (mem_dqs_n                    ),
    .mem_dq                     (mem_dq                       ),
    .mem_dm                     (mem_dm                       ),
    .dbg_slice_status           (dbg_slice_status             ),
    .dbg_slice_state            (dbg_slice_state              ),
    .debug_data                 (debug_data                   )
  );                                              
 
  ips2l_ddrphy_dfi_v1_3 #(
    .DDR_TYPE                   (DDR_TYPE                     ),
    .MEM_ADDR_WIDTH             (MEM_ROW_WIDTH                ),
    .MEM_BANKADDR_WIDTH         (MEM_BANK_WIDTH               ),
    .MEM_DQ_WIDTH               (MEM_DQ_WIDTH                 ),
    .MEM_DQS_WIDTH              (MEM_DQS_WIDTH                ),
    .MEM_DM_WIDTH               (MEM_DM_WIDTH                 )
 )ddrphy_dfi(
    .ddrphy_sysclk              (ddrphy_sysclk                ),
    .ddrphy_rst_n               (ddrphy_rst_n                 ),
    .calib_done                 (calib_done                   ),
    .calib_rst                  (calib_rst                    ),
    .calib_ba                   (calib_ba                     ),
    .calib_address              (calib_address                ),
    .calib_cs_n                 (calib_cs_n                   ),
    .calib_ras_n                (calib_ras_n                  ),
    .calib_cas_n                (calib_cas_n                  ),
    .calib_we_n                 (calib_we_n                   ),
    .calib_cke                  (calib_cke                    ),
    .calib_odt                  (calib_odt                    ),
    .calib_wrdata_en            (calib_wrdata_en              ),
    .calib_wrdata               (calib_wrdata                 ),
    .calib_wrdata_mask          (calib_wrdata_mask            ),
    .read_valid                 (read_valid                   ),
    .o_read_data                (o_read_data                  ),
    
    .ddrphy_update              (ddrphy_update                ),
    .update_cal_req             (update_cal_req               ),
    .update_done                (update_done                  ),
    .ddrphy_update_done         (ddrphy_update_done           ),
     
    .dfi_address                (dfi_address                  ),
    .dfi_bank                   (dfi_bank                     ),
    .dfi_cs_n                   (dfi_cs_n                     ),
    .dfi_cas_n                  (dfi_cas_n                    ),
    .dfi_ras_n                  (dfi_ras_n                    ),
    .dfi_we_n                   (dfi_we_n                     ),
    .dfi_cke                    (dfi_cke                      ),
    .dfi_odt                    (dfi_odt                      ),
    .dfi_wrdata_en              (dfi_wrdata_en                ),
    .dfi_wrdata                 (dfi_wrdata                   ),
    .dfi_wrdata_mask            (dfi_wrdata_mask              ),
    .dfi_rddata                 (dfi_rddata                   ),
    .dfi_rddata_valid           (dfi_rddata_valid             ),
    .dfi_reset_n                (dfi_reset_n                  ),
    .dfi_phyupd_req             (dfi_phyupd_req               ),
    .dfi_phyupd_ack             (dfi_phyupd_ack               ),
    .dfi_init_complete          (dfi_init_complete            ),
    .dfi_refresh                (dfi_refresh                  ),
    .read_cmd                   (read_cmd                     ),
    .phy_ck                     (phy_ck                       ),
    .phy_rst                    (phy_rst                      ),
    .phy_addr                   (phy_addr                     ),
    .phy_ba                     (phy_ba                       ),
    .phy_cs_n                   (phy_cs_n                     ),
    .phy_ras_n                  (phy_ras_n                    ),
    .phy_cas_n                  (phy_cas_n                    ),
    .phy_we_n                   (phy_we_n                     ),
    .phy_cke                    (phy_cke                      ),
    .phy_odt                    (phy_odt                      ),
    .phy_wrdata_en              (phy_wrdata_en                ),
    .phy_wrdata                 (phy_wrdata                   ),
    .phy_wrdata_mask            (phy_wrdata_mask              )
  );

  ips2l_ddrphy_info_v1_0 #(
    .DDR_TYPE                   (DDR_TYPE                     ),
    .MEM_ADDR_WIDTH             (MEM_ROW_WIDTH                ),
    .MEM_BANKADDR_WIDTH         (MEM_BANK_WIDTH               ),
    .MR0_DDR3                   (MR0_DDR3                     ),
    .MR1_DDR3                   (MR1_DDR3                     ),
    .MR2_DDR3                   (MR2_DDR3                     ),
    .MR3_DDR3                   (MR3_DDR3                     ),
    .MR_DDR2                    (MR_DDR2                      ),
    .EMR1_DDR2                  (EMR1_DDR2                    ),
    .EMR2_DDR2                  (EMR2_DDR2                    ),
    .EMR3_DDR2                  (EMR3_DDR2                    ),
    .MR_LPDDR                   (MR_LPDDR                     ),
    .EMR_LPDDR                  (EMR_LPDDR                    )
)ddrphy_info(
    .ddrphy_sysclk              (ddrphy_sysclk                ),
    .ddrphy_rst_n               (ddrphy_rst_n                 ),
    .calib_done                 (calib_done                   ),
    .phy_addr                   (phy_addr                     ),
    .phy_ba                     (phy_ba                       ),
    .phy_cs_n                   (phy_cs_n                     ),
    .phy_cas_n                  (phy_cas_n                    ),
    .phy_ras_n                  (phy_ras_n                    ),
    .phy_we_n                   (phy_we_n                     ),
    .phy_cke                    (phy_cke                      ),
    .mc_rl                      (mc_rl                        ),
    .mc_wl                      (mc_wl                        ),
    .mr0                        (mr0                          ),
    .mr1                        (mr1                          ),
    .mr2                        (mr2                          ),
    .mr3                        (mr3                          )
  );

endmodule

