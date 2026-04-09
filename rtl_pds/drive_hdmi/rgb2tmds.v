`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Myminieye
// Engineer: Ori
// 
// Create Date: 2019-09-16 19:46
// Design Name: 
// Module Name: rgb2tmds
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
module rgb2tmds (
    output             tmds_clk_p,
    output             tmds_clk_n,
    output [2:0]       tmds_data_p,
    output [2:0]       tmds_data_n,
    
    input              rstn,
    
    input [23:0]       vid_pdata,
    input              vid_pvde,
    input              vid_phsync,
    input              vid_pvsync,
    input              pixelclk,
    
    input              serialclk 
);

   reg  [7:0]         pdataout[2:0];     //编码输入并行输入数据
   wire [9:0]         pdataoutraw[2:0];  //编码输出并行数据
   wire [2:0]         pvde;              //DE使能信号
   wire [2:0]         pc0;               //控制信号
   wire [2:0]         pc1;               //控制信号
   
   //DVI clock output
   outputserdes #(
       .KPARALLELWIDTH   (  10  )
   ) 
   clockserializer(
       .pixelclk         (  pixelclk        ),              
       .serialclk        (  serialclk       ),              
       .sdataout_p       (  tmds_clk_p      ),              
       .sdataout_n       (  tmds_clk_n      ),              
       .pdataout         (  10'b1111100000  ),               
       .rstn             (  rstn            )               
   );
   
   generate
       genvar  i;
       for (i = 0; i <= 2; i = i + 1)
       begin :encoder   
            //tmds encoder                           
            tmds_encoder dataencoder(
                .pix_clk     (  pixelclk       ), // pixel clock input                            
                .dout        (  pdataoutraw[i] ), // data outputs   [9:0]            
                .rstn        (  rstn           ), // async. reset input (active high)              
                .din         (  pdataout[i]    ), // data inputs: expect registered [7:0]               
                .c0          (  pc0[i]         ), // c0 input                                      
                .c1          (  pc1[i]         ), // c1 input                                      
                .de          (  pvde[i]        )  // de input                                                           
            );                                      
            
            //tmds parall to serial                                    
            outputserdes #(                         
                .KPARALLELWIDTH  (  10         )    
            ) 
            dataserializer(
                .pixelclk    (  pixelclk       ),               
                .serialclk   (  serialclk      ),               
                .sdataout_p  (  tmds_data_p[i] ),                
                .sdataout_n  (  tmds_data_n[i] ),                
                .pdataout    (  pdataoutraw[i] ),               
                .rstn        (  rstn           )                
           );
       end
   endgenerate
   
   always @(*) pdataout[2] = vid_pdata[23:16];
   always @(*) pdataout[1] = vid_pdata[15:8];
   always @(*) pdataout[0] = vid_pdata[7:0];
   assign pc0[2:1] = {2{1'b0}};
   assign pc1[2:1] = {2{1'b0}};
   assign pc0[0] = vid_phsync;
   assign pc1[0] = vid_pvsync;
   assign pvde = {vid_pvde, vid_pvde, vid_pvde};
   
endmodule
