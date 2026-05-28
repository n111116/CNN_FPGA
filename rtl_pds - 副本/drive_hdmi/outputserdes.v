`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Myminieye
// Engineer: Ori
// 
// Create Date: 2019-09-16 19:46
// Design Name: 
// Module Name: outputserdes
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// Revision: v1.0
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`define UD #1
module outputserdes#(
    parameter                  KPARALLELWIDTH = 10
)(
    input                      pixelclk,
    input                      serialclk,
    input                      rstn,
    
    input [KPARALLELWIDTH-1:0] pdataout,
    
    output                     sdataout_p,
    output                     sdataout_n 
);

    wire                       sDataOut;
    wire                       ocascade1;
    wire                       ocascade2;
    
//    OBUFDS #(
//        .IOSTANDARD (  "TMDS_33"   )
//    ) OutputBuffer(
//        .O          (  sdataout_p  ),           
//        .OB         (  sdataout_n  ),           
//        .I          (  sDataOut    )            
//    );
   
   
    GTP_OUTBUFDS #(
        .IOSTANDARD("TMDS") 
    ) OutputBuffer (
        .O(sdataout_p), // OUTPUT  
        .OB(sdataout_n),// OUTPUT  
        .I(sDataOut)  // INPUT  
    );



GTP_OSERDES_E2 #(
		. GRS_EN        ( "TRUE"       ),
		. OSERDES_MODE  ( "DDR10TO1" ),
		. TSERDES_EN    ( "FALSE"      ),
		. UPD0_SHIFT_EN ( "FALSE"      ), 
		. UPD1_SHIFT_EN ( "FALSE"      ), 
		. INIT_SET      ( 2'b00        ), 
		. GRS_TYPE_DQ   ( "RESET"      ), 
		. LRS_TYPE_DQ0  ( "ASYNC_RESET"), 
		. LRS_TYPE_DQ1  ( "ASYNC_RESET"), 
		. LRS_TYPE_DQ2  ( "ASYNC_RESET"), 
		. LRS_TYPE_DQ3  ( "ASYNC_RESET"), 
		. GRS_TYPE_TQ   ( "RESET"      ), 
		. LRS_TYPE_TQ0  ( "ASYNC_RESET"), 
		. LRS_TYPE_TQ1  ( "ASYNC_RESET"), 
		. LRS_TYPE_TQ2  ( "ASYNC_RESET"), 
		. LRS_TYPE_TQ3  ( "ASYNC_RESET"), 
		. TRI_EN        ( "FALSE"      ),
		. TBYTE_EN      ( "FALSE"      ), 
		. MIPI_EN       ( "FALSE"      ), 
		. OCASCADE_EN   ( "FALSE"      )    //"FALSE","TRUE"
)SerializerMaster(

		. RST           ( ~rstn    ),
		. OCE           ( 1'b1           ),
		. TCE           ( 1'b0           ),
		. OCLKDIV       ( pixelclk   ),
		. SERCLK        ( serialclk       ),
		. OCLK          ( serialclk       ),
		. MIPI_CTRL     (                ),
		. UPD0_SHIFT    ( 1'b0           ),
		. UPD1_SHIFT    ( 1'b0           ),
		. OSHIFTIN0     ( ocascade1   ),
		. OSHIFTIN1     ( ocascade2   ),
		. DI            ( pdataout[7:0] ),
		. TI            (                ),
		. TBYTE_IN      (                ),
		. OSHIFTOUT0    (                ),
		. OSHIFTOUT1    (                ),
		. DO            (  sDataOut  ),
		. TQ            (                )
);



GTP_OSERDES_E2 #(
		. GRS_EN        ( "TRUE"       ),
		. OSERDES_MODE  ( "DDR10TO1" ),
		. TSERDES_EN    ( "FALSE"      ),
		. UPD0_SHIFT_EN ( "FALSE"      ), 
		. UPD1_SHIFT_EN ( "FALSE"      ), 
		. INIT_SET      ( 2'b00        ), 
		. GRS_TYPE_DQ   ( "RESET"      ), 
		. LRS_TYPE_DQ0  ( "ASYNC_RESET"), 
		. LRS_TYPE_DQ1  ( "ASYNC_RESET"), 
		. LRS_TYPE_DQ2  ( "ASYNC_RESET"), 
		. LRS_TYPE_DQ3  ( "ASYNC_RESET"), 
		. GRS_TYPE_TQ   ( "RESET"      ), 
		. LRS_TYPE_TQ0  ( "ASYNC_RESET"), 
		. LRS_TYPE_TQ1  ( "ASYNC_RESET"), 
		. LRS_TYPE_TQ2  ( "ASYNC_RESET"), 
		. LRS_TYPE_TQ3  ( "ASYNC_RESET"), 
		. TRI_EN        ( "FALSE"      ),
		. TBYTE_EN      ( "FALSE"      ), 
		. MIPI_EN       ( "FALSE"      ), 
		. OCASCADE_EN   ( "TRUE"       )    //"FALSE","TRUE"
)SerializerSlave(

		. RST           ( ~rstn    ),
		. OCE           ( 1'b1           ),
		. TCE           ( 1'b0           ),
		. OCLKDIV       ( pixelclk   ),
		. SERCLK        ( serialclk       ),
		. OCLK          ( serialclk       ),
		. MIPI_CTRL     (                ),
		. UPD0_SHIFT    ( 1'b0           ),
		. UPD1_SHIFT    ( 1'b0           ),
		. OSHIFTIN0     (    ),
		. OSHIFTIN1     (    ),
		. DI            ( {4'b0,pdataout[9:8],2'b0} ),
		. TI            (                ),
		. TBYTE_IN      (                ),
		. OSHIFTOUT0    (  ocascade1              ),
		. OSHIFTOUT1    (  ocascade2              ),
		. DO            (    ),
		. TQ            (                )
);



endmodule
