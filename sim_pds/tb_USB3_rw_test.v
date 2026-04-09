`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/06/04 10:10:18
// Design Name: 
// Module Name: tb_USB3_rw_test
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_USB3_rw_test();

//parameter define
parameter  CLK_PERIOD = 10; //时钟周期10ns

//reg define
reg           sys_clk_p;
reg           sys_clk_n;
reg           sys_rst_n;

reg           flaga;          //缓冲区An的空满信号
reg           flagb;          //缓冲区Am的空满信号
reg           flagc;          //缓冲区An的空满信号
reg           flagd;          //缓冲区Am的空满信号

//wire define
wire          pclk     ;     //数据随路时钟               
wire          slcs     ;     //片选信号     
wire   [1:0]  usb_addr ;     //缓冲区选择        
wire          slrd     ;     //读请求信号，读数据在读请求生效后第二个时钟上升沿出来低电平有效  
wire          sloe     ;     //读写使能信号，0读1写
wire          slwr     ;     //写请求信号，与写数据同步低电平有效
wire          pktend   ;     //写一包数据最后一个数据的标志
wire          usb_rest ;     //usb复位信号
wire          usb_int  ;     //usb中断信号
wire   [31:0] usb_data ;  //usb双向数据总线

//信号初始化
initial begin
    sys_clk_p <= 1'b0;
    sys_clk_n <= 1'b1;
    sys_rst_n <= 1'b0;
    flaga     <= 1'b0;
    flagb     <= 1'b0;
    flagc     <= 1'b0;
    flagd     <= 1'b0;
    #200
    sys_rst_n <= 1'b1;
    flagc     <= 1'b1;
    flaga     <= 1'b1;
    flagb     <= 1'b1;
    #2000
    flagc     <= 1'b0;
    flagd     <= 1'b0;

end

//产生时钟
always #(CLK_PERIOD/2) sys_clk_p = ~sys_clk_p;
always #(CLK_PERIOD/2) sys_clk_n = ~sys_clk_n;

assign usb_data = (flaga == 1'b1) ? 32'h31313131  : {32{1'bz}};

USB3_rw_test USB3_rw_test(
.sys_clk_p   (sys_clk_p),   //系统差分输入时钟P端 
.sys_clk_n   (sys_clk_n),   //系统差分输入时钟N端    
.sys_rst_n   (sys_rst_n),   //系统复位
.pclk        (pclk     ),   //数据随路时钟                
.slcs        (slcs     ),   //片选信号      
.usb_data    (usb_data ),   //usb双向数据总线
.usb_addr    (usb_addr ),   //缓冲区选择     
.slrd        (slrd     ),   //读请求信号，读数据在读请求生效后第二个时钟上升沿出来低电平有效   
.sloe        (sloe     ),   //读写使能信号，0读1写
.slwr        (slwr     ),   //写请求信号，与写数据同步低电平有效
.flaga       (flaga    ),   //缓冲区An的空满信号(高满低空)
.flagb       (flagb    ),   //缓冲区Am的空满信号
.flagc       (flagc    ),   //缓冲区An的空满信号
.flagd       (flagd    ),   //缓冲区Am的空满信号
.pktend      (pktend   ),   //写一包数据最后一个数据的标志
.usb_rest    (usb_rest ),   //usb复位信号
.usb_int     (usb_int  )    //usb中断信号
   );
   
endmodule
