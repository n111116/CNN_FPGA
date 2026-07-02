

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
// Filename:ipm2l_fifo.v
//
//////////////////////////////////////////////////////////////////////////////

module ipm2l_fifo_v1_10_ip_fifo #(
    parameter  c_CAS_MODE          = "18K"         ,   // "18K", "36K", "64K"
    parameter  c_WR_DEPTH_WIDTH    = 10            ,
    parameter  c_WR_DATA_WIDTH     = 32            ,
    parameter  c_RD_DEPTH_WIDTH    = 10            ,
    parameter  c_RD_DATA_WIDTH     = 32            ,
    parameter  c_OUTPUT_REG        = 0             ,
    parameter  c_RD_OCE_EN         = 0             ,
    parameter  c_FAB_REG           = 0             ,
    parameter  c_RESET_TYPE        = "ASYNC_RESET" ,
    parameter  c_POWER_OPT         = 0             ,
    parameter  c_RD_CLK_OR_POL_INV = 0             ,
    parameter  c_WR_BYTE_EN        = 0             ,
    parameter  c_BE_WIDTH          = 8             ,
    parameter  c_FIFO_TYPE         = "SYN"         ,
    parameter  c_ALMOST_FULL_NUM   = 508           ,
    parameter  c_ALMOST_EMPTY_NUM  = 4
) (
    input  wire  [c_WR_DATA_WIDTH-1 : 0]                  wr_data         ,
    input  wire                                           wr_en           ,
    input  wire                                           wr_clk          ,
    output wire                                           wr_full         ,
    input  wire                                           wr_rst          ,
    input  wire  [c_BE_WIDTH-1 : 0]                       wr_byte_en      ,
    output wire                                           almost_full     ,
    output wire  [c_WR_DEPTH_WIDTH : 0]                   wr_water_level  ,

    output wire  [c_RD_DATA_WIDTH-1 : 0]                  rd_data         ,
    input  wire                                           rd_en           ,
    input  wire                                           rd_clk          ,
    output wire                                           rd_empty        ,
    input  wire                                           rd_rst          ,
    input  wire                                           rd_oce          ,
    output wire                                           almost_empty    ,
    output wire  [c_RD_DEPTH_WIDTH : 0]                   rd_water_level
);

//**************************************************************************************************************
//declare inner variables
 wire  [c_WR_DEPTH_WIDTH-1 : 0]  wr_addr;
 wire  [c_RD_DEPTH_WIDTH-1 : 0]  rd_addr;

//**************************************************************************************************************

ipm2l_sdpram_v1_10_ip_fifo
#(
    .c_CAS_MODE             ( c_CAS_MODE            ),
    .c_WR_ADDR_WIDTH        ( c_WR_DEPTH_WIDTH      ),
    .c_WR_DATA_WIDTH        ( c_WR_DATA_WIDTH       ),
    .c_RD_ADDR_WIDTH        ( c_RD_DEPTH_WIDTH      ),
    .c_RD_DATA_WIDTH        ( c_RD_DATA_WIDTH       ),
    .c_OUTPUT_REG           ( c_OUTPUT_REG          ),
    .c_RD_OCE_EN            ( c_RD_OCE_EN           ),
    .c_FAB_REG              ( c_FAB_REG             ),
    .c_WR_ADDR_STROBE_EN    ( 0                     ),
    .c_RD_ADDR_STROBE_EN    ( 0                     ),
    .c_WR_CLK_EN            ( 1                     ),
    .c_RD_CLK_EN            ( 1                     ),
    .c_RESET_TYPE           ( c_RESET_TYPE          ),
    .c_POWER_OPT            ( c_POWER_OPT           ),
    .c_RD_CLK_OR_POL_INV    ( c_RD_CLK_OR_POL_INV   ),
    .c_INIT_FILE            ( "NONE"                ),
    .c_INIT_FORMAT          ( "BIN"                 ),
    .c_WR_BYTE_EN           ( c_WR_BYTE_EN          ),
    .c_BE_WIDTH             ( c_BE_WIDTH            )
) U_ipm2l_sdpram (
    .wr_data                ( wr_data               ),
    .wr_addr                ( wr_addr               ),
    .wr_en                  ( wr_en                 ),
    .wr_clk                 ( wr_clk                ),
    .wr_clk_en              ( 1'b1                  ),
    .wr_rst                 ( wr_rst                ),
    .wr_byte_en             ( wr_byte_en            ),
    .wr_addr_strobe         ( 1'b0                  ),

    .rd_data                ( rd_data               ),
    .rd_addr                ( rd_addr               ),
    .rd_clk                 ( rd_clk                ),
    .rd_clk_en              ( rd_en                 ),
    .rd_rst                 ( rd_rst                ),
    .rd_oce                 ( rd_oce                ),
    .rd_addr_strobe         ( 1'b0                  )
);

ipm2l_fifo_ctrl_v1_1_ip_fifo #(
    .c_WR_DEPTH_WIDTH       ( c_WR_DEPTH_WIDTH      ),
    .c_RD_DEPTH_WIDTH       ( c_RD_DEPTH_WIDTH      ),
    .c_FIFO_TYPE            ( c_FIFO_TYPE           ),
    .c_ALMOST_FULL_NUM      ( c_ALMOST_FULL_NUM     ),
    .c_ALMOST_EMPTY_NUM     ( c_ALMOST_EMPTY_NUM    )
) U_ipm2l_fifo_ctrl (
    .wclk                   ( wr_clk                ),
    .w_en                   ( wr_en                 ),
    .waddr                  ( wr_addr               ),
    .wrst                   ( wr_rst                ),
    .wfull                  ( wr_full               ),
    .almost_full            ( almost_full           ),
    .wr_water_level         ( wr_water_level        ),

    .rclk                   ( rd_clk                ),
    .r_en                   ( rd_en                 ),
    .raddr                  ( rd_addr               ),
    .rrst                   ( rd_rst                ),
    .rempty                 ( rd_empty              ),
    .almost_empty           ( almost_empty          ),
    .rd_water_level         ( rd_water_level        )
);
endmodule
