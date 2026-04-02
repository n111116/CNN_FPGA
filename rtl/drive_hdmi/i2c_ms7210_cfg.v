//****************************************Copyright (c)***********************************//
//原子哥在线教学平台：www.yuanzige.com
//技术支持：www.openedv.com
//淘宝店铺：http://openedv.taobao.com
//关注微信公众平台微信号："正点原子"，免费获取ZYNQ & FPGA & STM32 & LINUX资料。
//版权所有，盗版必究。
//Copyright(C) 正点原子 2018-2028
//All rights reserved
//----------------------------------------------------------------------------------------
// File name:           i2c_ms7210_cfg
// Last modified Date:  2020/05/04 9:19:08
// Last Version:        V1.0
// Descriptions:        iic配置
//                      
//----------------------------------------------------------------------------------------
// Created by:          正点原子
// Created date:        2019/05/04 9:19:08
// Version:             V1.0
// Descriptions:        The original version
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module i2c_ms7210_cfg
   (  
    input                clk      ,     //时钟信号
    input                rst_n    ,     //复位信号，低电平有效
    
    input        [7:0]   i2c_data_r,    //I2C读出的数据
    input                i2c_done ,     //I2C寄存器配置完成信号
    output  reg          i2c_exec ,     //I2C触发执行信号   
    output  reg  [23:0]  i2c_data ,     //I2C要配置的地址与数据(高16位地址,低8位数据)
    output  reg          i2c_rh_wl,     //I2C读写控制信号
    output                rstn_out,     //芯片复位信号，低有效
    output  reg          init_done      //初始化完成信号
    );

//parameter define
localparam  REG_NUM = 8'd50  ;       //总共需要配置的寄存器个数

//reg define
reg    [12:0]   start_init_cnt;        //等待延时计数器
reg    [7:0]    init_reg_cnt  ;        //寄存器配置个数计数器
reg    [13:0]   cfg_delay_cnt  ;       //寄存器配置之间延迟计数器
reg    [15:0]   rstn_1ms       ;

//*****************************************************
//**                    main code
//*****************************************************

assign rstn_out = (rstn_1ms == 16'd1000) && rst_n;

//产生芯片复位信号的延迟计数器
always @(posedge clk)begin
    if(!rst_n)
    	 rstn_1ms <= 16'd0;
    else begin
    	if(rstn_1ms == 16'd1000)
    		rstn_1ms <= rstn_1ms;
        else
    		rstn_1ms <= rstn_1ms + 1'b1;
    end
end

//clk时钟配置成1MHZ,周期为1us 5000*1us = 5ms
//上电到开始配置IIC等待5ms
always @(posedge clk or negedge rstn_out) begin
    if(!rstn_out)
        start_init_cnt <= 13'b0;
    else if(start_init_cnt < 13'd5000) begin
        start_init_cnt <= start_init_cnt + 1'b1;                    
    end
end

//每个寄存器配置之间延迟20us    
always @(posedge clk or negedge rstn_out) begin
    if(!rstn_out)
        cfg_delay_cnt <= 8'd0;
    else if(i2c_done)   
        cfg_delay_cnt <= 8'd0;
	else if(cfg_delay_cnt >6000)
        cfg_delay_cnt <= cfg_delay_cnt ;		
	else
        cfg_delay_cnt <= cfg_delay_cnt + 8'b1;	
		
end

//寄存器配置个数计数    
always @(posedge clk or negedge rstn_out) begin
    if(!rstn_out)
        init_reg_cnt <= 8'd0;
    else if(i2c_exec)   
        init_reg_cnt <= init_reg_cnt + 8'b1;
end

//i2c触发执行信号   
always @(posedge clk or negedge rstn_out) begin
    if(!rstn_out)
        i2c_exec <= 1'b0;
    else if(start_init_cnt == 13'd4999)
        i2c_exec <= 1'b1;
    else if(i2c_done && (init_reg_cnt < REG_NUM) && (init_reg_cnt != 21))
        i2c_exec <= 1'b1;
    else if((cfg_delay_cnt == 5999) && (init_reg_cnt == 21))
        i2c_exec <= 1'b1;		
    else
        i2c_exec <= 1'b0;
end 

//配置I2C读写控制信号
always @(posedge clk or negedge rstn_out) begin
    if(!rstn_out)
        i2c_rh_wl <= 1'b1;
    else 
        i2c_rh_wl <= 1'b0;  
end

//初始化完成信号
always @(posedge clk or negedge rstn_out) begin
    if(!rstn_out)
        init_done <= 1'b0;
    else if((init_reg_cnt == REG_NUM) && i2c_done)  
        init_done <= 1'b1;  
end

//配置寄存器地址与数据
always @(posedge clk or negedge rstn_out) begin
    if(!rstn_out)
        i2c_data <= 24'b0;
    else begin
        case(init_reg_cnt)
            8'd0  : i2c_data <= {16'h0003,8'h5a}; 
            8'd1  : i2c_data <= {16'h1281,8'h04}; 
            8'd2  : i2c_data <= {16'h0016,8'h04}; 
            8'd3  : i2c_data <= {16'h0009,8'h01}; 
            8'd4  : i2c_data <= {16'h0007,8'h09}; 
            8'd5  : i2c_data <= {16'h0008,8'hF0};
            8'd6  : i2c_data <= {16'h000A,8'hF0};
            8'd7  : i2c_data <= {16'h0006,8'h11}; 
            8'd8  : i2c_data <= {16'h0531,8'h84}; 
            8'd9  : i2c_data <= {16'h0900,8'h20};
            8'd10 : i2c_data <= {16'h0901,8'h47};
            8'd11 : i2c_data <= {16'h0904,8'h09};
            8'd12 : i2c_data <= {16'h0923,8'h07};
            8'd13 : i2c_data <= {16'h0924,8'h44};
            8'd14 : i2c_data <= {16'h0925,8'h44};
            8'd15 : i2c_data <= {16'h090F,8'h80};
            8'd16 : i2c_data <= {16'h091F,8'h07};
            8'd17 : i2c_data <= {16'h0920,8'h1E};
            8'd18 : i2c_data <= {16'h0018,8'h20};
            8'd19 : i2c_data <= {16'h05c0,8'hFE};
            8'd20 : i2c_data <= {16'h000B,8'h00};
            8'd21 : i2c_data <= {16'h0507,8'h06};
            8'd22 : i2c_data <= {16'h0906,8'h04};
            8'd23 : i2c_data <= {16'h0920,8'h5E};
            8'd24 : i2c_data <= {16'h0926,8'hDD}; 
            8'd25 : i2c_data <= {16'h0927,8'h0D}; 
            8'd26 : i2c_data <= {16'h0928,8'h88}; 
            8'd27 : i2c_data <= {16'h0929,8'h08};
            8'd28 : i2c_data <= {16'h0910,8'h01};
            8'd29 : i2c_data <= {16'h000B,8'h11};
            8'd30 : i2c_data <= {16'h050E,8'h00}; 
            8'd31 : i2c_data <= {16'h050A,8'h82}; 
            8'd32 : i2c_data <= {16'h0509,8'h02}; 
            8'd33 : i2c_data <= {16'h050B,8'h0D};
            8'd34 : i2c_data <= {16'h050D,8'h06};
            8'd35 : i2c_data <= {16'h050D,8'h11};
            8'd36 : i2c_data <= {16'h050D,8'h58};
            8'd37 : i2c_data <= {16'h050D,8'h00};
            8'd38 : i2c_data <= {16'h050D,8'h00};
            8'd39 : i2c_data <= {16'h050D,8'h00};
            8'd40 : i2c_data <= {16'h050D,8'h00}; 
            8'd41 : i2c_data <= {16'h050D,8'h00}; 
            8'd42 : i2c_data <= {16'h050D,8'h00}; 
            8'd43 : i2c_data <= {16'h050D,8'h00}; 
            8'd44 : i2c_data <= {16'h050D,8'h00}; 
            8'd45 : i2c_data <= {16'h050D,8'h00}; 
            8'd46 : i2c_data <= {16'h050D,8'h00}; 
            8'd47 : i2c_data <= {16'h050D,8'h00}; 
            8'd48 : i2c_data <= {16'h050E,8'h40}; 
            8'd49 : i2c_data <= {16'h0507,8'h00};
            default : i2c_data <= {16'h0003,8'h5a}; 
        endcase
    end
end

endmodule