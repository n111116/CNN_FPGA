module ADC(
    //input [1:0]     VA,
    input [31:0] 		VAUX, 
    input 					clk,
    input [7:0] 		PADDR, 
    input 					PSEL,
    input 					PENABLE,
    input 					PWRITE,
    input           CONVST, 
    input           RST_N,
    //input           LOADSC_N,
    output 					PREADY,    
    
    inout  [15:0]   PDATA,
    output          OVER_TEMP,
    output          LOGIC_DONE_A,
    output          LOGIC_DONE_B,
    output          ADC_CLK_OUT,
    output          DMODIFIED, 
    output [4:0]    ALARM   
);

wire [15:0] PWDATA;
wire [15:0] PRDATA;

parameter CREG_00H  = 16'b1011_0000_0011_1111;
parameter CREG_01H  = 16'b1100_1000_0001_1110;
parameter CREG_02H  = 16'b0000_0000_0000_0000;
parameter CREG_31H  = 16'b0000_0000_0000_0000;
parameter CREG_03H  = 16'b0100_0000_0111_1100;
parameter CREG_04H  = 16'b0000_0000_0000_0000;
parameter CREG_0AH  = 16'b0000_0000_0000_0000;
parameter CREG_05H  = 16'b0100_0000_0000_0000;
parameter CREG_06H  = 16'b0100_0000_0000_0000;
parameter CREG_0CH  = 16'b0000_0000_0000_0000;
parameter CREG_07H  = 16'b0000_0000_0111_1100;
parameter CREG_08H  = 16'b0000_0000_0000_0000;
parameter CREG_0EH  = 16'b0000_0000_0000_0000;
parameter CREG_20H  = 16'b0000_0000_0000;
parameter CREG_21H  = 16'b0000_0000_0000;
parameter CREG_22H  = 16'b0000_0000_0000;
parameter CREG_23H  = 16'b0000_0000_0000;
parameter CREG_24H  = 16'b0000_0000_0000;
parameter CREG_25H  = 16'b0000_0000_0000;
parameter CREG_26H  = 16'b0000_0000_0000;
parameter CREG_27H  = 16'b0000_0000_0000;
parameter CREG_28H  = 16'b0000_0000_0000;
parameter CREG_29H  = 16'b0000_0000_0000;
parameter CREG_2AH  = 16'b1100_1100_0010;
parameter CREG_2BH  = 16'b1010_0101_1011;

assign PDATA = PWRITE ? 16'hz : PRDATA ;
assign PWDATA = PWRITE ? PDATA :16'hFFFF ;

GTP_ADC_E2
#(
    .CREG_00H (CREG_00H),
    .CREG_01H (CREG_01H),
    .CREG_02H (CREG_02H),
    .CREG_31H (CREG_31H),
    .CREG_03H (CREG_03H),
    .CREG_04H (CREG_04H),
    .CREG_0AH (CREG_0AH),
    .CREG_05H (CREG_05H),
    .CREG_06H (CREG_06H),
    .CREG_0CH (CREG_0CH),
    .CREG_07H (CREG_07H),
    .CREG_08H (CREG_08H),
    .CREG_0EH (CREG_0EH),
    .CREG_20H (CREG_20H),
    .CREG_21H (CREG_21H),
    .CREG_22H (CREG_22H),
    .CREG_23H (CREG_23H),
    .CREG_24H (CREG_24H),
    .CREG_25H (CREG_25H),
    .CREG_26H (CREG_26H),
    .CREG_27H (CREG_27H),
    .CREG_28H (CREG_28H),
    .CREG_29H (CREG_29H),
    .CREG_2AH (CREG_2AH),
    .CREG_2BH (CREG_2BH)
		)
XADC
(
    //Analog Input
    //.VA					  (VA), //0:N, 1:P
    .VAUX					(VAUX), //even:N, odd:P
    .RST_N				(RST_N),
    .CONVST				(CONVST), //EVENT_DRV,
    .LOADSC_N			(1'b1), //LOAD_SC_N,
   
    //APB
    .DCLK					(clk),
    .DADDR				(PADDR),
    .DEN					(PSEL),
    .SECEN				(PENABLE),
    .DWE					(PWRITE),
    .DI						(PWDATA),
    
    //output
    .DO						(PRDATA),
    .DRDY         (PREADY),

    //SRB
    .OVER_TEMP		(OVER_TEMP),
    .LOGIC_DONE_A	(LOGIC_DONE_A),
    .LOGIC_DONE_B	(LOGIC_DONE_B),
    .ADC_CLK_OUT	(ADC_CLK_OUT),
    .DMODIFIED		(DMODIFIED),
    .ALARM   			(ALARM)
);

endmodule