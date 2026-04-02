`timescale 1ns / 1ps
//****************************************Copyright (c)***********************************//
//原子哥在线教学平台：www.yuanzige.com
//技术支持：http://www.openedv.com/forum.php
//淘宝店铺：https://zhengdianyuanzi.tmall.com
//关注微信公众平台微信号："正点原子"，免费获取ZYNQ & FPGA & STM32 & LINUX资料。
//版权所有，盗版必究。
//Copyright(C) 正点原子 2023-2033
//All rights reserved                                  
//----------------------------------------------------------------------------------------
// File name:           hdmi_loop
// Created by:          正点原子
// Created date:        2023年2月3日14:17:02
// Version:             V1.0
// Descriptions:        HDMI环回实验
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//
module hdmi_loop(
    input         		sys_clk_p,     // input system clock 100MHz
    input         		sys_clk_n, 
    input         		sys_rst_n,     
        
    output            	rstn_out,     //芯片复位信号，低有效
    output            	iic_scl,      //I2C的串行时钟信号
    inout             	iic_sda,      //I2C的串行数据信号
	
	input               video_clk_in,    //输入时钟                        
    input            	video_vs_in,     //场同步信号
    input            	video_hs_in,     //行同步信号
    input            	video_de_in,     //数据使能
    input      [23:0]   video_rgb_in,     //RGB888颜色数据
   
    output              video_clk_out,    //输出时钟                        
    output reg          video_vs_out,     //场同步信号
    output reg          video_hs_out,     //行同步信号
    output reg          video_de_out,     //数据使能
    output reg [23:0]   video_rgb_out     //RGB888颜色数据
);

//wire define
wire        cfg_clk;           //10m时钟
wire        locked;            //pll锁定信号
wire        video_clk;
wire        init_over;

//reg define
reg        video_vs_in_dly;           
reg        video_hs_in_dly;            
reg        video_de_in_dly;
reg [23:0] video_rgb_in_dly;
reg        video_vs_in_dly1;           
reg        video_hs_in_dly1;            
reg        video_de_in_dly1;
reg [23:0] video_rgb_in_dly1;
reg        video_vs_in_dly2;           
reg        video_hs_in_dly2;            
reg        video_de_in_dly2;
reg [23:0] video_rgb_in_dly2;

//*****************************************************
//**                    main code
//*****************************************************  

assign rst_n = sys_rst_n &&  locked;

pll_config u_pll_config(
    // Clock out ports
    .clk_out1       (cfg_clk),          // output clk_out1 // 频率10
    // Status and control signals
    .reset          (~sys_rst_n),       // input reset
    .locked         (locked),           // output locked
    // Clock in ports
    .clk_in1_p      (sys_clk_p),        // input clk_in1_p
    .clk_in1_n      (sys_clk_n)
);

BUFG BUFG_inst (
    .O              (video_clk_in_bufg),// 1-bit output: Clock output.
    .I              (video_clk_in)      // 1-bit input: Clock input.
);

clk_wiz_0 u_clk_wiz_0(
    // Clock out ports
    .clk_out1       (video_clk_out),    // output clk_out1 // 频率 75 相位 0
    .clk_out2       (video_clk),        // output clk_out2 // 频率 75 相位 0
    // Status and control signals
    .reset          (~sys_rst_n),       // input reset
    .locked         (locked_0),         // output locked
   // Clock in ports
    .clk_in1        (video_clk_in_bufg)
);

//例化视频芯片控制模块
ms72xx_ctl ms72xx_ctl(
    .clk            (cfg_clk    ), 
    .rst_n          (rst_n      ),  

    .rstn_out       (rstn_out   ),      //配置全部完成标志                        
    .init_over      (init_over  ),      //芯片复位信号，低有效
    .iic_scl        (iic_scl    ), 
    .iic_sda        (iic_sda    )  
);

always  @(posedge video_clk)begin
    video_vs_in_dly  <= video_vs_in;
    video_hs_in_dly  <= video_hs_in;
    video_de_in_dly  <= video_de_in;
    video_rgb_in_dly <= video_rgb_in;
    video_vs_in_dly1  <= video_vs_in_dly;
    video_hs_in_dly1  <= video_hs_in_dly;
    video_de_in_dly1  <= video_de_in_dly;
    video_rgb_in_dly1 <= video_rgb_in_dly;
    video_vs_in_dly2  <= video_vs_in_dly1;
    video_hs_in_dly2  <= video_hs_in_dly1;
    video_de_in_dly2  <= video_de_in_dly1;
    video_rgb_in_dly2 <= video_rgb_in_dly1;
end 

always  @(posedge video_clk)begin
    if(!init_over)begin  //在没有配置完时，信号输出0
	    video_vs_out  <=  1'b0  ;
        video_hs_out  <=  1'b0  ;
        video_de_out  <=  1'b0  ;
        video_rgb_out <=  24'd0 ;
    end
	else begin
	    video_vs_out  <= video_vs_in_dly2 ;
        video_hs_out  <= video_hs_in_dly2 ;
        video_de_out  <= video_de_in_dly2 ;
        video_rgb_out <= video_rgb_in_dly2;       
    end
end 

endmodule