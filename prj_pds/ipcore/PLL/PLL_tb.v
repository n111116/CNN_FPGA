

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

module PLL_tb ();

    
    localparam real    CLKIN_FREQ      = 74.25; //@IPC float 10.0,500.0 
    
    localparam         INTERNAL_FB     = "CLKOUTF";
    
    localparam         EXTERNAL_FB     = "DISABLE";
        

    wire        clkout0         ;
    wire        clkout0_n       ;
    wire        clkout1         ;
    wire        clkout1_n       ;
    wire        clkout2         ;
    wire        clkout2_n       ;
    wire        clkout3         ;
    wire        clkout3_n       ;
    wire        clkout4         ;
    wire        clkout5         ;
    wire        clkout6         ;
    wire        clkoutf         ;
    wire        clkoutf_n       ;
    wire        clkoutphy       ;
    wire        clkoutphy_n     ;
    wire        clkfb =  (EXTERNAL_FB == "DISABLE") ? 1'b0 :
    	                 (EXTERNAL_FB == "CLKOUT0") ? clkout0 :
                    	 (EXTERNAL_FB == "CLKOUT1") ? clkout1 :
                    	 (EXTERNAL_FB == "CLKOUT2") ? clkout2 :
                    	 (EXTERNAL_FB == "CLKOUT3") ? clkout3 :
                    	 (EXTERNAL_FB == "CLKOUT4") ? clkout4 :
                    	 (EXTERNAL_FB == "CLKOUT5") ? clkout5 :
                    	 (EXTERNAL_FB == "CLKOUT6") ? clkout6 :
                    	 (EXTERNAL_FB == "CLKOUTF") ? clkoutf : 1'b0;
    wire        lock            ;
    wire        dps_done        ;
    wire [15:0] apb_rdata       ;
    wire        apb_ready       ;
    wire        clkin1_p        ;
    wire        clkin1_n        ;
    wire        clkin2_p        ;
    wire        clkin2_n        ;

    reg         clkin1          ;
    reg         clkin2          ;
    reg         clkin_sel       ;
    reg         dps_clk         ;
    reg         dps_en          ;
    reg         dps_dir         ;
    reg         clkout0_syn     ;
    reg         clkout1_syn     ;
    reg         clkout2_syn     ;
    reg         clkout3_syn     ;
    reg         clkout4_syn     ;
    reg         clkout5_syn     ;
    reg         clkout6_syn     ;
    reg         clkoutf_syn     ;
    reg         clkoutphy_syn   ;
    reg         clkout0_bufce   ;
    reg         clkout1_bufce   ;
    reg         clkout2_bufce   ;
    reg         clkout3_bufce   ;
    reg         clkout4_bufce   ;
    reg         clkout5_bufce   ;
    reg         clkout6_bufce   ;
    reg         clkoutf_bufce   ;
    reg         pll_pwd         ;
    reg         rst             ;
    reg         apb_clk         ;
    reg         apb_rst_n       ;
    reg  [4:0]  apb_addr        ;
    reg         apb_sel         ;
    reg         apb_en          ;
    reg         apb_write       ;
    reg  [15:0] apb_wdata       ; 

    assign      clkin1_p = clkin1 ;
    assign      clkin1_n = ~clkin1;
    assign      clkin2_p = clkin2 ;
    assign      clkin2_n = ~clkin2;
    
    initial
    begin
        clkin_sel       = 1'b0;
        dps_clk         = 1'b0;
        dps_en          = 1'b0;
        dps_dir         = 1'b0;
        clkout0_syn     = 1'b0;
        clkout1_syn     = 1'b0;
        clkout2_syn     = 1'b0;
        clkout3_syn     = 1'b0;
        clkout4_syn     = 1'b0;
        clkout5_syn     = 1'b0;
        clkout6_syn     = 1'b0;
        clkoutf_syn     = 1'b0;
        clkoutphy_syn   = 1'b0;
        clkout0_bufce   = 1'b1;
        clkout1_bufce   = 1'b1;
        clkout2_bufce   = 1'b1;
        clkout3_bufce   = 1'b1;
        clkout4_bufce   = 1'b1;
        clkout5_bufce   = 1'b1;
        clkout6_bufce   = 1'b1;
        clkoutf_bufce   = 1'b1;
        pll_pwd         = 1'b0;
        apb_clk         = 1'b0;
        apb_rst_n       = 1'b0;
        apb_addr        = 5'b0;
        apb_sel         = 1'b0;
        apb_en          = 1'b0;
        apb_write       = 1'b0;
        apb_wdata       = 16'b0; 
    end

    // clkin1 generation
    initial
    begin
        clkin1 = 0;
        forever #(500/CLKIN_FREQ) clkin1 = ~clkin1;
    end
    
    // clkin2 generation
    initial
    begin
        clkin2 = 1;
        forever #(500/CLKIN_FREQ) clkin2 = ~clkin2;
    end

    // reset and power down generation
    initial
    begin
        pll_pwd  = 1'b1;
        rst      = 1'b1;
        #50
        pll_pwd  = 1'b0;
        #50
        rst      = 1'b0;
    end

PLL U_PLL(
    
    .clkout1        (clkout1        ),
    
    .clkout2        (clkout2        ),
    
    .clkin1         (clkin1         ),
    
    .lock           (lock           )
    );

 

//******************Results Checking************************
    reg  lock_ff1 = 1'b0;
    reg  lock_ff2 = 1'b0;
    reg  lock_ff3 = 1'b0;
    reg  lock_neg = 1'b0;
    wire chk_ok;
    
    
    always @( posedge clkin1)
    begin
        lock_ff1 <= lock;
        lock_ff2 <= lock_ff1;
        lock_ff3 <= lock_ff2;
    end

    always @( posedge clkin1)
    begin
        if(rst==1'b1)
	    lock_neg <= 1'b0;
        else if((lock_ff2==1'b0)&&(lock_ff3==1'b1))
	    lock_neg <= 1'b1;
	else ;    
    end
    assign chk_ok = lock_ff3 & (~lock_neg);
    



    integer handle;
    initial begin
        #50000
        handle = $fopen ("sim_results.log","a");
        $fdisplay(handle,"chk_ok = %b,  $realtime = %-10d",chk_ok,$realtime );
	$display("Simulation Starts.") ;
	$display("Simulation is done.") ;
	if (chk_ok==1'b0)
	    $display("Simulation Failed due to Error Found.") ;
	else
	    $display("Simulation Success.") ;
        $finish;
    end

endmodule
