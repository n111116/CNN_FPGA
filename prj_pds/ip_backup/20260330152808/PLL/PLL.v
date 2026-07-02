
//////////////////////////////////////////////////////////////////////////////
//
// Copyright (c) 2019 PANGO MICROSYSTEMS, INC
// ALL RIGHTS REVERVED.
//
// THE SOURCE CODE CONTAINED HEREIN IS PROPRIETARY TO PANGO MICROSYSTEMS, INC.
// IT SHALL NOT BE REPRODUCED OR DISCLOSED IN WHOLE OR IN PART OR USED BY
// PARTIES WITHOUT WRITTEN AUTHORIZATION FROM THE OWNER.
//
//////////////////////////////////////////////////////////////////////////////
//               
// Library:
// Filename:PLL.v                 
//////////////////////////////////////////////////////////////////////////////
`timescale 1ns/10fs

module PLL (
    
    output wire clkout1,
    
    input wire clkin1,
    
    output wire lock           
    );

    // Parameter
    
    localparam real    CLKIN_FREQ       = 148.5; //@IPC float 10.0,500.0 
    
    localparam         LOCK_MODE        = 0; //@IPC enum 0,1
    
    localparam integer STATIC_RATIOI    = 3; //@IPC int 1,80
    
    localparam integer STATIC_RATIOM    = 1; //@IPC int 1,128 
    
    localparam real    STATIC_RATIO0    = 74.25; //@IPC int 1.0000,128.0000 
        
    localparam integer STATIC_RATIO1    = 1; //@IPC int 1,128 
    
    localparam integer STATIC_RATIO2    = 10; //@IPC int 1,128 
    
    localparam integer STATIC_RATIO3    = 15; //@IPC int 1,128 
    
    localparam integer STATIC_RATIO4    = 15; //@IPC int 1,128 
    
    localparam integer STATIC_RATIO5    = 15; //@IPC int 1,128 
    
    localparam integer STATIC_RATIO6    = 15; //@IPC int 1,128 
    
    localparam real    STATIC_RATIOF    = 15.0; //@IPC int 1.0000,128.0000 
        
    localparam integer STATIC_RATIOPHY  = 1; //@IPC int 1,128 
    
    localparam integer STATIC_DUTY0     = 74; //@IPC int 2,255
    
    localparam integer STATIC_DUTY1     = 2; //@IPC int 2,255
    
    localparam integer STATIC_DUTY2     = 10; //@IPC int 2,255
    
    localparam integer STATIC_DUTY3     = 15; //@IPC int 2,255
    
    localparam integer STATIC_DUTY4     = 15; //@IPC int 2,255
    
    localparam integer STATIC_DUTY5     = 15; //@IPC int 2,255
    
    localparam integer STATIC_DUTY6     = 15; //@IPC int 2,255
    
    localparam integer STATIC_DUTYF     = 15; //@IPC int 2,255
    
    localparam integer STATIC_DUTYPHY   = 2; //@IPC int 2,255
    
    localparam integer STATIC_PHASE     = 0; //@IPC int 0,63 
    
    localparam integer STATIC_PHASE0    = 0; //@IPC int 0,7 
    
    localparam integer STATIC_PHASE1    = 0; //@IPC int 0,7 
    
    localparam integer STATIC_PHASE2    = 0; //@IPC int 0,7 
    
    localparam integer STATIC_PHASE3    = 0; //@IPC int 0,7 
    
    localparam integer STATIC_PHASE4    = 0; //@IPC int 0,7 
    
    localparam integer STATIC_PHASE5    = 0; //@IPC int 0,7 
    
    localparam integer STATIC_PHASE6    = 0; //@IPC int 0,7 
    
    localparam integer STATIC_PHASEF    = 0; //@IPC int 0,7 
    
    localparam integer STATIC_PHASEPHY  = 0; //@IPC int 0,7 
    
    localparam integer STATIC_CPHASE0   = 0; //@IPC int 0,127 
    
    localparam integer STATIC_CPHASE1   = 0; //@IPC int 0,127 
    
    localparam integer STATIC_CPHASE2   = 0; //@IPC int 0,127 
    
    localparam integer STATIC_CPHASE3   = 0; //@IPC int 0,127 
    
    localparam integer STATIC_CPHASE4   = 0; //@IPC int 0,127 
    
    localparam integer STATIC_CPHASE5   = 0; //@IPC int 0,127 
    
    localparam integer STATIC_CPHASE6   = 0; //@IPC int 0,127 
    
    localparam integer STATIC_CPHASEF   = 0; //@IPC int 0,127 
    
    localparam integer STATIC_CPHASEPHY = 0; //@IPC int 0,127 
    
    localparam         CLK_DPS0_EN      = "FALSE"; //@IPC bool 
    
    localparam         CLK_DPS1_EN      = "FALSE"; //@IPC bool 
    
    localparam         CLK_DPS2_EN      = "FALSE"; //@IPC bool 
    
    localparam         CLK_DPS3_EN      = "FALSE"; //@IPC bool 
    
    localparam         CLK_DPS4_EN      = "FALSE"; //@IPC bool 
    
    localparam         CLK_DPS5_EN      = "FALSE"; //@IPC bool 
    
    localparam         CLK_DPS6_EN      = "FALSE"; //@IPC bool 
    
    localparam         CLK_DPSF_EN      = "FALSE"; //@IPC bool 
    
    localparam         CLK_CAS5_EN      = "FALSE"; //@IPC bool 
    
    localparam         CLKOUT0_SYN_EN   = "FALSE"; //@IPC bool 
    
    localparam         CLKOUT1_SYN_EN   = "FALSE"; //@IPC bool 
    
    localparam         CLKOUT2_SYN_EN   = "FALSE"; //@IPC bool 
    
    localparam         CLKOUT3_SYN_EN   = "FALSE"; //@IPC bool 
    
    localparam         CLKOUT4_SYN_EN   = "FALSE"; //@IPC bool 
    
    localparam         CLKOUT5_SYN_EN   = "FALSE"; //@IPC bool 
    
    localparam         CLKOUT6_SYN_EN   = "FALSE"; //@IPC bool 
    
    localparam         CLKOUTF_SYN_EN   = "FALSE"; //@IPC bool 
    
    localparam         CLKOUTPHY_SYN_EN = "FALSE"; //@IPC bool 
    
    localparam         SSC_MODE         = "DISABLE"; //@IPC enum DISABLE, DOWN_LOW, DOWN_HIGH, CENTER_LOW, CENTER_HIGH
    
    localparam real    SSC_FREQ         = 25; //@IPC int 25,250
    
    localparam         INTERNAL_FB      = "CLKOUTF"; //@IPC enum CLKOUT0,CLKOUT1,CLKOUT2,CLKOUT3,CLKOUT4,CLKOUT5,CLKOUT6,DISABLE 
    
    localparam         EXTERNAL_FB      = "DISABLE"; //@IPC enum CLKOUT0,CLKOUT1,CLKOUT2,CLKOUT3,CLKOUT4,CLKOUT5,CLKOUT6,DISABLE 
    
    localparam         BANDWIDTH        = "HIGH"; //@IPC enum OPTIMIZED,LOW,HIGH 
    
    wire clkin2;
    assign clkin2 = 1'b0;
    
    wire clkfb;
    assign clkfb = 1'b0;
    
    wire clkin_sel;
    assign clkin_sel = 1'b0;
    
    wire dps_clk;
    wire dps_en;
    wire dps_dir;
    assign dps_clk = 1'b0;
    assign dps_en = 1'b0;
    assign dps_dir = 1'b0;
        
    wire clkout0_syn;
    assign clkout0_syn = 1'b0;
    
    wire clkout1_syn;
    assign clkout1_syn = 1'b0;
    
    wire clkout2_syn;
    assign clkout2_syn = 1'b0;
    
    wire clkout3_syn;
    assign clkout3_syn = 1'b0;
    
    wire clkout4_syn;
    assign clkout4_syn = 1'b0;
    
    wire clkout5_syn;
    assign clkout5_syn = 1'b0;
        
    wire clkout6_syn;
    assign clkout6_syn = 1'b0;
        
    wire clkoutf_syn;
    assign clkoutf_syn = 1'b0;
    
    wire pll_pwd;
    assign pll_pwd = 1'b0;
    
    wire rst;
    assign rst = 1'b0;
    
    wire apb_clk;
    wire apb_rst_n;
    wire [4:0] apb_addr;
    wire apb_sel;
    wire apb_en;
    wire apb_write;
    wire [15:0] apb_wdata;

    assign apb_clk = 1'd0;
    assign apb_rst_n = 1'd0;
    assign apb_addr [4:0] = 5'd0;
    assign apb_sel = 1'd0;
    assign apb_en = 1'd0;
    assign apb_write = 1'd0;
    assign apb_wdata [15:0] = 16'd0;
    
    GTP_GPLL #(

    .CLKIN_FREQ      (CLKIN_FREQ    ),   
    .LOCK_MODE       (LOCK_MODE     ),   
    .STATIC_RATIOI   (STATIC_RATIOI ),   
    .STATIC_RATIOM   (STATIC_RATIOM ),   
    
    .STATIC_RATIO0   (STATIC_RATIO0 ),   
    .STATIC_RATIO1   (STATIC_RATIO1 ),   
    .STATIC_RATIO2   (STATIC_RATIO2 ),   
    .STATIC_RATIO3   (STATIC_RATIO3 ),   
    .STATIC_RATIO4   (STATIC_RATIO4 ),   
    
    .STATIC_RATIO5   (STATIC_RATIO5 ),   
    .STATIC_RATIO6   (STATIC_RATIO6 ),   
    
    .STATIC_RATIOF   (STATIC_RATIOF ),   
    
    .STATIC_DUTY0    (STATIC_DUTY0  ),  
    .STATIC_DUTY1    (STATIC_DUTY1  ),  
    .STATIC_DUTY2    (STATIC_DUTY2  ),  
    .STATIC_DUTY3    (STATIC_DUTY3  ),  
    .STATIC_DUTY4    (STATIC_DUTY4  ),  
    
    .STATIC_DUTY5    (STATIC_DUTY5  ),  
    .STATIC_DUTY6    (STATIC_DUTY6  ),  
    
    .STATIC_DUTYF    (STATIC_DUTYF  ),  
    
    .STATIC_PHASE    (STATIC_PHASE  ),
    
    .STATIC_PHASE0   (STATIC_PHASE0 ),
    .STATIC_PHASE1   (STATIC_PHASE1 ),
    .STATIC_PHASE2   (STATIC_PHASE2 ),
    .STATIC_PHASE3   (STATIC_PHASE3 ),
    .STATIC_PHASE4   (STATIC_PHASE4 ),
    
    .STATIC_PHASE5   (STATIC_PHASE5 ),
    .STATIC_PHASE6   (STATIC_PHASE6 ),
    
    .STATIC_PHASEF   (STATIC_PHASEF ),
    
    .STATIC_CPHASE0  (STATIC_CPHASE0),
    .STATIC_CPHASE1  (STATIC_CPHASE1),
    .STATIC_CPHASE2  (STATIC_CPHASE2),
    .STATIC_CPHASE3  (STATIC_CPHASE3),
    .STATIC_CPHASE4  (STATIC_CPHASE4),
    
    .STATIC_CPHASE5  (STATIC_CPHASE5),
    .STATIC_CPHASE6  (STATIC_CPHASE6),
    
    .STATIC_CPHASEF  (STATIC_CPHASEF),
    
    .CLK_DPS0_EN     (CLK_DPS0_EN   ),  
    .CLK_DPS1_EN     (CLK_DPS1_EN   ),  
    .CLK_DPS2_EN     (CLK_DPS2_EN   ),  
    .CLK_DPS3_EN     (CLK_DPS3_EN   ),  
    .CLK_DPS4_EN     (CLK_DPS4_EN   ),  
    .CLK_DPS5_EN     (CLK_DPS5_EN   ),  
    .CLK_DPS6_EN     (CLK_DPS6_EN   ),  
    .CLK_DPSF_EN     (CLK_DPSF_EN   ),  
    .CLK_CAS5_EN     (CLK_CAS5_EN   ),  
    
    .CLKOUT0_SYN_EN  (CLKOUT0_SYN_EN),
    .CLKOUT1_SYN_EN  (CLKOUT1_SYN_EN),
    .CLKOUT2_SYN_EN  (CLKOUT2_SYN_EN),
    .CLKOUT3_SYN_EN  (CLKOUT3_SYN_EN),
    .CLKOUT4_SYN_EN  (CLKOUT4_SYN_EN),
    
    .CLKOUT5_SYN_EN  (CLKOUT5_SYN_EN),
    .CLKOUT6_SYN_EN  (CLKOUT6_SYN_EN),
    
    .CLKOUTF_SYN_EN  (CLKOUTF_SYN_EN),
    
    .SSC_MODE       (SSC_MODE       ),
    .SSC_FREQ       (SSC_FREQ       ),
    
    .INTERNAL_FB    (INTERNAL_FB    ),
    .EXTERNAL_FB    (EXTERNAL_FB    ),
    .BANDWIDTH      (BANDWIDTH      )
    
    ) u_gpll (
    
    .CLKOUT0        (               ),
    
    .CLKOUT0N       (               ),
    
    .CLKOUT1        (clkout1        ),
    	
    .CLKOUT1N       (               ),
    
    .CLKOUT2        (               ),
    
    .CLKOUT2N       (               ),
    
    .CLKOUT3        (               ),
    
    .CLKOUT3N       (               ),
    
    .CLKOUT4        (               ),
    
    .CLKOUT5        (               ),
        
    .CLKOUT6        (               ),
        
    .CLKOUTF        (               ),
    
    .CLKOUTFN       (               ),
    
    .LOCK           (lock           ),
    
    .DPS_DONE       (               ),
        
    .DPS_CLK        (dps_clk        ),
    .DPS_EN         (dps_en         ),
    .DPS_DIR        (dps_dir        ),
    
    .CLKIN1         (clkin1         ),
    
    .CLKIN2         (clkin2         ),
    
    .CLKFB          (clkfb          ),
    .CLKIN_SEL      (clkin_sel      ),
    .CLKOUT0_SYN    (clkout0_syn    ),
    .CLKOUT1_SYN    (clkout1_syn    ),
    .CLKOUT2_SYN    (clkout2_syn    ),
    .CLKOUT3_SYN    (clkout3_syn    ),
    .CLKOUT4_SYN    (clkout4_syn    ),
    
    .CLKOUT5_SYN    (clkout5_syn    ),
    .CLKOUT6_SYN    (clkout6_syn    ),
    
    .CLKOUTF_SYN    (clkoutf_syn    ),
    .PLL_PWD        (pll_pwd        ),
    .RST            (rst            ),
    
    .APB_RDATA      (               ),
    .APB_READY      (               ),
    
    .APB_CLK        (apb_clk        ),
    .APB_RST_N      (apb_rst_n      ),
    .APB_ADDR       (apb_addr[4:0]  ),
    .APB_SEL        (apb_sel        ),
    .APB_EN         (apb_en         ),
    .APB_WRITE      (apb_write      ),
    .APB_WDATA      (apb_wdata[15:0])   
);


endmodule
