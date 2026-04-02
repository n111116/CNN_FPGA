//****************************************Copyright (c)***********************************//
//原子哥在线教学平台：www.yuanzige.com
//技术支持：www.openedv.com
//淘宝店铺：http://openedv.taobao.com
//关注微信公众平台微信号："正点原子"，免费获取ZYNQ & FPGA & STM32 & LINUX资料。
//版权所有，盗版必究。
//Copyright(C) 正点原子 2018-2028
//All rights reserved
//----------------------------------------------------------------------------------------
// File name:           i2c_ms7200_cfg
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

module i2c_ms7200_cfg
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
localparam  REG_NUM = 9'd300  ;       //总共需要配置的寄存器个数

//reg define
reg    [12:0]   start_init_cnt;        //等待延时计数器
reg    [8:0]    init_reg_cnt  ;        //寄存器配置个数计数器
reg    [13:0]   cfg_delay_cnt  ;       //寄存器配置之间延迟计数器
reg    [15:0]   rstn_1ms       ;
reg    [31:0]   freq_rec;
reg    [31:0]   freq_rec_reg;
reg             freq_ensure;
reg    [1:0]    state_cnt;

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

//寄存器配置个数计数    
always @(posedge clk or negedge rstn_out) begin
    if(!rstn_out)
        init_reg_cnt <= 9'd0;
    else if( (init_reg_cnt == REG_NUM ) && i2c_exec && (state_cnt == 0))   
        init_reg_cnt <= 9'd0;
	else if( (init_reg_cnt == 3) && i2c_exec && (state_cnt == 1))
        init_reg_cnt <= 9'd0;
	else if( (init_reg_cnt == 6) && i2c_exec && (state_cnt == 2))
        init_reg_cnt <= 9'd0;		
    else if(i2c_exec )   
        init_reg_cnt <= init_reg_cnt + 9'b1;
	else
        init_reg_cnt <= init_reg_cnt ;			
end

//i2c触发执行信号   
always @(posedge clk or negedge rstn_out) begin
    if(!rstn_out)
        i2c_exec <= 1'b0;
    else if(start_init_cnt == 13'd4999)
        i2c_exec <= 1'b1;
    else if(i2c_done )
        i2c_exec <= 1'b1;	
    else
        i2c_exec <= 1'b0;
end 

//配置I2C读写控制信号
always @(posedge clk or negedge rstn_out) begin
    if(!rstn_out)
        i2c_rh_wl <= 1'b1;
    else if(state_cnt == 1)
        i2c_rh_wl <= 1'b1; 
	else	
        i2c_rh_wl <= 1'b0; 	
end

//初始化完成信号
always @(posedge clk or negedge rstn_out) begin
    if(!rstn_out)
        init_done <= 1'b0;
    else if((init_reg_cnt == 6) && i2c_done && (state_cnt == 2))  
        init_done <= 1'b1; 
	else
        init_done <= init_done; 	
end

always @(posedge clk or negedge rstn_out) begin
    if(!rstn_out)
        state_cnt <= 2'd0;
    else if((init_reg_cnt == REG_NUM) && i2c_exec && (state_cnt == 0))  
        state_cnt <= 2'd1; 
	else if((init_reg_cnt == 3) && i2c_exec && (state_cnt == 1))	
		if(freq_ensure)
			state_cnt <= 2'd2; 	
		else
			state_cnt <= 2'd1; 			
	else if((init_reg_cnt == 6) && i2c_exec && (state_cnt == 2))	
        state_cnt <= 2'd1; 
	else
        state_cnt <= state_cnt; 	
	
end

//寄存时钟数据
always @(posedge clk or negedge rstn_out) begin
    if(!rstn_out)
        freq_rec <= 32'd0;
    else if((init_reg_cnt == 9'd0) && i2c_done)  
        freq_rec <= {24'd0,i2c_data_r};  
    else if((init_reg_cnt == 9'd1) && i2c_done)
        freq_rec <= {16'd0,i2c_data_r,freq_rec[7:0]};   
    else if((init_reg_cnt == 9'd2) && i2c_done)  
        freq_rec <= {8'd0,i2c_data_r,freq_rec[15:0]};   
    else if((init_reg_cnt == 9'd3) && i2c_done)
        freq_rec <= {i2c_data_r,freq_rec[23:0]};   
 	else
        freq_rec <= freq_rec; 			
end

always @(posedge clk or negedge rstn_out)begin
    if(!rstn_out)
        freq_rec_reg   <= 32'd0;
    else if(freq_ensure)  
        freq_rec_reg <= 32'd0;      
    else if(state_cnt == 1 && init_reg_cnt == 9'd3 && i2c_exec)
        freq_rec_reg <= freq_rec;
    else
        freq_rec_reg <= freq_rec_reg;	
end
    
//等待时钟锁定
always @(posedge clk or negedge rstn_out)begin
	if(!rstn_out)
	    freq_ensure <= 1'b0;
	else if(state_cnt == 2)
	    freq_ensure <= 1'b0;
  	else if(state_cnt == 1 && init_reg_cnt == 9'd3 && i2c_exec && (freq_rec_reg[25:24]==2'b00) && (freq_rec[25:24] == 2'b10))    	
	    freq_ensure <= 1'b1;
    else
        freq_ensure <= freq_ensure;
end

//配置寄存器地址与数据
always @(posedge clk or negedge rstn_out) begin
    if(!rstn_out)
        i2c_data <= 24'b0;
    else begin
	    if(state_cnt == 0)begin
			case(init_reg_cnt)
				9'd0   : i2c_data <= {16'h0003,8'h5a}; 
				9'd1   : i2c_data <= {16'h0204, 8'h02}; 
				9'd2   : i2c_data <= {16'h0205, 8'h40}; 
				9'd3   : i2c_data <= {16'h0004, 8'h01}; 
				9'd4   : i2c_data <= {16'h0009, 8'h26}; 
				9'd5   : i2c_data <= {16'h102E, 8'h01};
				9'd6   : i2c_data <= {16'h1025, 8'hB0};
				9'd7   : i2c_data <= {16'h102D, 8'h83}; 
				9'd8   : i2c_data <= {16'h1000, 8'h20}; 
				9'd9   : i2c_data <= {16'h100F, 8'h04};     
				9'd10  : i2c_data <= {16'h0003, 8'hC3};
				9'd11  : i2c_data <= {16'h103B, 8'h02};
				9'd12  : i2c_data <= {16'h00E1, 8'h00};
				9'd13  : i2c_data <= {16'h00A8, 8'h08};
				9'd14  : i2c_data <= {16'h000A, 8'h00};
				9'd15  : i2c_data <= {16'h0016, 8'h02};
				9'd16  : i2c_data <= {16'h00E2, 8'h01};
				9'd17  : i2c_data <= {16'h00C2, 8'h14};
				9'd18  : i2c_data <= {16'h102D, 8'hC7};
				9'd19  : i2c_data <= {16'h1005, 8'h04};
				9'd20  : i2c_data <= {16'h1003, 8'h14};
				9'd21  : i2c_data <= {16'h1004, 8'h01};
				9'd22  : i2c_data <= {16'h1000, 8'h60};
				9'd23  : i2c_data <= {16'h1020, 8'h13};
				9'd24  : i2c_data <= {16'h1021, 8'h04}; 
				9'd25  : i2c_data <= {16'h1022, 8'h04}; 
				9'd26  : i2c_data <= {16'h1023, 8'h0C}; 
				9'd27  : i2c_data <= {16'h102B, 8'h33};
				9'd28  : i2c_data <= {16'h102C, 8'h33};
				9'd29  : i2c_data <= {16'h00F0, 8'h10};
				9'd30  : i2c_data <= {16'h000C, 8'h80}; 
				9'd31  : i2c_data <= {16'h0D00, 8'h00}; 
				9'd32  : i2c_data <= {16'h0D01, 8'hFF}; 
				9'd33  : i2c_data <= {16'h0D02, 8'hFF};
				9'd34  : i2c_data <= {16'h0D03, 8'hFF};
				9'd35  : i2c_data <= {16'h0D04, 8'hFF};
				9'd36  : i2c_data <= {16'h0D05, 8'hFF};
				9'd37  : i2c_data <= {16'h0D06, 8'hFF};
				9'd38  : i2c_data <= {16'h0D07, 8'h00};
				9'd39  : i2c_data <= {16'h0D00, 8'h00};
				9'd40  : i2c_data <= {16'h0D01, 8'hFF}; 
				9'd41  : i2c_data <= {16'h0D02, 8'hFF}; 
				9'd42  : i2c_data <= {16'h0D03, 8'hFF}; 
				9'd43  : i2c_data <= {16'h0D04, 8'hFF}; 
				9'd44  : i2c_data <= {16'h0D05, 8'hFF}; 
				9'd45  : i2c_data <= {16'h0D06, 8'hFF}; 
				9'd46  : i2c_data <= {16'h0D07, 8'h00}; 
				9'd47  : i2c_data <= {16'h0D08, 8'h4C}; 
				9'd48  : i2c_data <= {16'h0D09, 8'h2D}; 
				9'd49  : i2c_data <= {16'h0D0A, 8'hFF};
				9'd50  : i2c_data <= {16'h0D0B, 8'h0D}; 
				9'd51  : i2c_data <= {16'h0D0C, 8'h58}; 
				9'd52  : i2c_data <= {16'h0D0D, 8'h4D}; 
				9'd53  : i2c_data <= {16'h0D0E, 8'h51}; 
				9'd54  : i2c_data <= {16'h0D0F, 8'h30}; 
				9'd55  : i2c_data <= {16'h0D10, 8'h1C};
				9'd56  : i2c_data <= {16'h0D11, 8'h1C};
				9'd57  : i2c_data <= {16'h0D12, 8'h01}; 
				9'd58  : i2c_data <= {16'h0D13, 8'h03}; 
				9'd59  : i2c_data <= {16'h0D14, 8'h80};
				9'd60  : i2c_data <= {16'h0D15, 8'h3D};
				9'd61  : i2c_data <= {16'h0D16, 8'h23};
				9'd62  : i2c_data <= {16'h0D17, 8'h78};
				9'd63  : i2c_data <= {16'h0D18, 8'h2A};
				9'd64  : i2c_data <= {16'h0D19, 8'h5F};
				9'd65  : i2c_data <= {16'h0D1A, 8'hB1};
				9'd66  : i2c_data <= {16'h0D1B, 8'hA2};
				9'd67  : i2c_data <= {16'h0D1C, 8'h57};
				9'd68  : i2c_data <= {16'h0D1D, 8'h4F};
				9'd69  : i2c_data <= {16'h0D1E, 8'hA2};
				9'd70  : i2c_data <= {16'h0D1F, 8'h28};
				9'd71  : i2c_data <= {16'h0D20, 8'h0F};
				9'd72  : i2c_data <= {16'h0D21, 8'h50};
				9'd73  : i2c_data <= {16'h0D22, 8'h54};
				9'd74  : i2c_data <= {16'h0D23, 8'hBF}; 
				9'd75  : i2c_data <= {16'h0D24, 8'hEF}; 
				9'd76  : i2c_data <= {16'h0D25, 8'h80}; 
				9'd77  : i2c_data <= {16'h0D26, 8'h71};
				9'd78  : i2c_data <= {16'h0D27, 8'h4F};
				9'd79  : i2c_data <= {16'h0D28, 8'h81};
				9'd80  : i2c_data <= {16'h0D29, 8'h00}; 
				9'd81  : i2c_data <= {16'h0D2A, 8'h81}; 
				9'd82  : i2c_data <= {16'h0D2B, 8'hC0}; 
				9'd83  : i2c_data <= {16'h0D2C, 8'h81};
				9'd84  : i2c_data <= {16'h0D2D, 8'h80};
				9'd85  : i2c_data <= {16'h0D2E, 8'h95};
				9'd86  : i2c_data <= {16'h0D2F, 8'h00};
				9'd87  : i2c_data <= {16'h0D30, 8'hA9};
				9'd88  : i2c_data <= {16'h0D31, 8'hC0};
				9'd89  : i2c_data <= {16'h0D32, 8'hB3};
				9'd90  : i2c_data <= {16'h0D33, 8'h00}; 
				9'd91  : i2c_data <= {16'h0D34, 8'h01}; 
				9'd92  : i2c_data <= {16'h0D35, 8'h01}; 
				9'd93  : i2c_data <= {16'h0D36, 8'h04}; 
				9'd94  : i2c_data <= {16'h0D37, 8'h74}; 
				9'd95  : i2c_data <= {16'h0D38, 8'h00}; 
				9'd96  : i2c_data <= {16'h0D39, 8'h30}; 
				9'd97  : i2c_data <= {16'h0D3A, 8'hF2}; 
				9'd98  : i2c_data <= {16'h0D3B, 8'h70}; 
				9'd99  : i2c_data <= {16'h0D3C, 8'h5A};
				9'd100 : i2c_data <= {16'h0D3D, 8'h80}; 
				9'd101 : i2c_data <= {16'h0D3E, 8'hB0}; 
				9'd102 : i2c_data <= {16'h0D3F, 8'h58}; 
				9'd103 : i2c_data <= {16'h0D40, 8'h8A}; 
				9'd104 : i2c_data <= {16'h0D41, 8'h00}; 
				9'd105 : i2c_data <= {16'h0D42, 8'h60};
				9'd106 : i2c_data <= {16'h0D43, 8'h59};
				9'd107 : i2c_data <= {16'h0D44, 8'h21}; 
				9'd108 : i2c_data <= {16'h0D45, 8'h00}; 
				9'd109 : i2c_data <= {16'h0D46, 8'h00};
				9'd110 : i2c_data <= {16'h0D47, 8'h1E};
				9'd111 : i2c_data <= {16'h0D48, 8'h00};
				9'd112 : i2c_data <= {16'h0D49, 8'h00};
				9'd113 : i2c_data <= {16'h0D4A, 8'h00};
				9'd114 : i2c_data <= {16'h0D4B, 8'hFD};
				9'd115 : i2c_data <= {16'h0D4C, 8'h00};
				9'd116 : i2c_data <= {16'h0D4D, 8'h18};
				9'd117 : i2c_data <= {16'h0D4E, 8'h4B};
				9'd118 : i2c_data <= {16'h0D4F, 8'h1E};
				9'd119 : i2c_data <= {16'h0D50, 8'h5A};
				9'd120 : i2c_data <= {16'h0D51, 8'h1E};
				9'd121 : i2c_data <= {16'h0D52, 8'h00};
				9'd122 : i2c_data <= {16'h0D53, 8'h0A};
				9'd123 : i2c_data <= {16'h0D54, 8'h20};
				9'd124 : i2c_data <= {16'h0D55, 8'h20}; 
				9'd125 : i2c_data <= {16'h0D56, 8'h20}; 
				9'd126 : i2c_data <= {16'h0D57, 8'h20}; 
				9'd127 : i2c_data <= {16'h0D58, 8'h20};
				9'd128 : i2c_data <= {16'h0D59, 8'h20};
				9'd129 : i2c_data <= {16'h0D5A, 8'h00};
				9'd130 : i2c_data <= {16'h0D5B, 8'h00}; 
				9'd131 : i2c_data <= {16'h0D5C, 8'h00}; 
				9'd132 : i2c_data <= {16'h0D5D, 8'hFC}; 
				9'd133 : i2c_data <= {16'h0D5E, 8'h00};
				9'd134 : i2c_data <= {16'h0D5F, 8'h55};
				9'd135 : i2c_data <= {16'h0D60, 8'h32};
				9'd136 : i2c_data <= {16'h0D61, 8'h38};
				9'd137 : i2c_data <= {16'h0D62, 8'h48};
				9'd138 : i2c_data <= {16'h0D63, 8'h37};
				9'd139 : i2c_data <= {16'h0D64, 8'h35};
				9'd140 : i2c_data <= {16'h0D65, 8'h78}; 
				9'd141 : i2c_data <= {16'h0D66, 8'h0A}; 
				9'd142 : i2c_data <= {16'h0D67, 8'h20}; 
				9'd143 : i2c_data <= {16'h0D68, 8'h20}; 
				9'd144 : i2c_data <= {16'h0D69, 8'h20}; 
				9'd145 : i2c_data <= {16'h0D6A, 8'h20}; 
				9'd146 : i2c_data <= {16'h0D6B, 8'h20}; 
				9'd147 : i2c_data <= {16'h0D6C, 8'h00}; 
				9'd148 : i2c_data <= {16'h0D6D, 8'h00}; 
				9'd149 : i2c_data <= {16'h0D6E, 8'h00};
				9'd150 : i2c_data <= {16'h0D6F, 8'hFF}; 
				9'd151 : i2c_data <= {16'h0D70, 8'h00}; 
				9'd152 : i2c_data <= {16'h0D71, 8'h48}; 
				9'd153 : i2c_data <= {16'h0D72, 8'h54}; 
				9'd154 : i2c_data <= {16'h0D73, 8'h50}; 
				9'd155 : i2c_data <= {16'h0D74, 8'h4B};
				9'd156 : i2c_data <= {16'h0D75, 8'h37};
				9'd157 : i2c_data <= {16'h0D76, 8'h30}; 
				9'd158 : i2c_data <= {16'h0D77, 8'h30}; 
				9'd159 : i2c_data <= {16'h0D78, 8'h30};
				9'd160 : i2c_data <= {16'h0D79, 8'h35};
				9'd161 : i2c_data <= {16'h0D7A, 8'h31};
				9'd162 : i2c_data <= {16'h0D7B, 8'h0A};
				9'd163 : i2c_data <= {16'h0D7C, 8'h20};
				9'd164 : i2c_data <= {16'h0D7D, 8'h20};
				9'd165 : i2c_data <= {16'h0D7E, 8'h01};
				9'd166 : i2c_data <= {16'h0D7F, 8'hF7};
				9'd167 : i2c_data <= {16'h0D80, 8'h02};
				9'd168 : i2c_data <= {16'h0D81, 8'h03};
				9'd169 : i2c_data <= {16'h0D82, 8'h26};
				9'd170 : i2c_data <= {16'h0D83, 8'hF0};
				9'd171 : i2c_data <= {16'h0D84, 8'h4B};
				9'd172 : i2c_data <= {16'h0D85, 8'h5F};
				9'd173 : i2c_data <= {16'h0D86, 8'h10};
				9'd174 : i2c_data <= {16'h0D87, 8'h04}; 
				9'd175 : i2c_data <= {16'h0D88, 8'h1F}; 
				9'd176 : i2c_data <= {16'h0D89, 8'h13}; 
				9'd177 : i2c_data <= {16'h0D8A, 8'h03};
				9'd178 : i2c_data <= {16'h0D8B, 8'h12};
				9'd179 : i2c_data <= {16'h0D8C, 8'h20};
				9'd180 : i2c_data <= {16'h0D8D, 8'h22}; 
				9'd181 : i2c_data <= {16'h0D8E, 8'h5E}; 
				9'd182 : i2c_data <= {16'h0D8F, 8'h5D}; 
				9'd183 : i2c_data <= {16'h0D90, 8'h23};
				9'd184 : i2c_data <= {16'h0D91, 8'h09};
				9'd185 : i2c_data <= {16'h0D92, 8'h07};
				9'd186 : i2c_data <= {16'h0D93, 8'h07};
				9'd187 : i2c_data <= {16'h0D94, 8'h83};
				9'd188 : i2c_data <= {16'h0D95, 8'h01};
				9'd189 : i2c_data <= {16'h0D96, 8'h00};
				9'd190 : i2c_data <= {16'h0D97, 8'h00}; 
				9'd191 : i2c_data <= {16'h0D98, 8'h6D}; 
				9'd192 : i2c_data <= {16'h0D99, 8'h03}; 
				9'd193 : i2c_data <= {16'h0D9A, 8'h0C}; 
				9'd194 : i2c_data <= {16'h0D9B, 8'h00}; 
				9'd195 : i2c_data <= {16'h0D9C, 8'h10}; 
				9'd196 : i2c_data <= {16'h0D9D, 8'h00}; 
				9'd197 : i2c_data <= {16'h0D9E, 8'h80}; 
				9'd198 : i2c_data <= {16'h0D9F, 8'h3C}; 
				9'd199 : i2c_data <= {16'h0DA0, 8'h20};		
				9'd200 : i2c_data <= {16'h0DA1, 8'h10}; 
				9'd201 : i2c_data <= {16'h0DA2, 8'h60}; 
				9'd202 : i2c_data <= {16'h0DA3, 8'h01}; 
				9'd203 : i2c_data <= {16'h0DA4, 8'h02}; 
				9'd204 : i2c_data <= {16'h0DA5, 8'h03}; 
				9'd205 : i2c_data <= {16'h0DA6, 8'h02};
				9'd206 : i2c_data <= {16'h0DA7, 8'h3A};
				9'd207 : i2c_data <= {16'h0DA8, 8'h80}; 
				9'd208 : i2c_data <= {16'h0DA9, 8'h18}; 
				9'd209 : i2c_data <= {16'h0DAA, 8'h71};
				9'd210 : i2c_data <= {16'h0DAB, 8'h38};
				9'd211 : i2c_data <= {16'h0DAC, 8'h2D};
				9'd212 : i2c_data <= {16'h0DAD, 8'h40};
				9'd213 : i2c_data <= {16'h0DAE, 8'h58};
				9'd214 : i2c_data <= {16'h0DAF, 8'h2C};
				9'd215 : i2c_data <= {16'h0DB0, 8'h45};
				9'd216 : i2c_data <= {16'h0DB1, 8'h00};
				9'd217 : i2c_data <= {16'h0DB2, 8'h60};
				9'd218 : i2c_data <= {16'h0DB3, 8'h59};
				9'd219 : i2c_data <= {16'h0DB4, 8'h21};
				9'd220 : i2c_data <= {16'h0DB5, 8'h00};
				9'd221 : i2c_data <= {16'h0DB6, 8'h00};
				9'd222 : i2c_data <= {16'h0DB7, 8'h1E};
				9'd223 : i2c_data <= {16'h0DB8, 8'h02};
				9'd224 : i2c_data <= {16'h0DB9, 8'h3A}; 
				9'd225 : i2c_data <= {16'h0DBA, 8'h80}; 
				9'd226 : i2c_data <= {16'h0DBB, 8'hD0}; 
				9'd227 : i2c_data <= {16'h0DBC, 8'h72};
				9'd228 : i2c_data <= {16'h0DBD, 8'h38};
				9'd229 : i2c_data <= {16'h0DBE, 8'h2D};
				9'd230 : i2c_data <= {16'h0DBF, 8'h40}; 
				9'd231 : i2c_data <= {16'h0DC0, 8'h10}; 
				9'd232 : i2c_data <= {16'h0DC1, 8'h2C}; 
				9'd233 : i2c_data <= {16'h0DC2, 8'h45};
				9'd234 : i2c_data <= {16'h0DC3, 8'h80};
				9'd235 : i2c_data <= {16'h0DC4, 8'h60};
				9'd236 : i2c_data <= {16'h0DC5, 8'h59};
				9'd237 : i2c_data <= {16'h0DC6, 8'h21};
				9'd238 : i2c_data <= {16'h0DC7, 8'h00};
				9'd239 : i2c_data <= {16'h0DC8, 8'h00};
				9'd240 : i2c_data <= {16'h0DC9, 8'h1E}; 
				9'd241 : i2c_data <= {16'h0DCA, 8'h01}; 
				9'd242 : i2c_data <= {16'h0DCB, 8'h1D}; 
				9'd243 : i2c_data <= {16'h0DCC, 8'h00}; 
				9'd244 : i2c_data <= {16'h0DCD, 8'h72}; 
				9'd245 : i2c_data <= {16'h0DCE, 8'h51}; 
				9'd246 : i2c_data <= {16'h0DCF, 8'hD0}; 
				9'd247 : i2c_data <= {16'h0DD0, 8'h1E}; 
				9'd248 : i2c_data <= {16'h0DD1, 8'h20}; 
				9'd249 : i2c_data <= {16'h0DD2, 8'h6E};
				9'd250 : i2c_data <= {16'h0DD3, 8'h28}; 
				9'd251 : i2c_data <= {16'h0DD4, 8'h55}; 
				9'd252 : i2c_data <= {16'h0DD5, 8'h00}; 
				9'd253 : i2c_data <= {16'h0DD6, 8'h60}; 
				9'd254 : i2c_data <= {16'h0DD7, 8'h59}; 
				9'd255 : i2c_data <= {16'h0DD8, 8'h21};
				9'd256 : i2c_data <= {16'h0DD9, 8'h00};
				9'd257 : i2c_data <= {16'h0DDA, 8'h00}; 
				9'd258 : i2c_data <= {16'h0DDB, 8'h1E}; 
				9'd259 : i2c_data <= {16'h0DDC, 8'h56};
				9'd260 : i2c_data <= {16'h0DDD, 8'h5E};
				9'd261 : i2c_data <= {16'h0DDE, 8'h00};
				9'd262 : i2c_data <= {16'h0DDF, 8'hA0};
				9'd263 : i2c_data <= {16'h0DE0, 8'hA0};
				9'd264 : i2c_data <= {16'h0DE1, 8'hA0};
				9'd265 : i2c_data <= {16'h0DE2, 8'h29};
				9'd266 : i2c_data <= {16'h0DE3, 8'h50};
				9'd267 : i2c_data <= {16'h0DE4, 8'h30};
				9'd268 : i2c_data <= {16'h0DE5, 8'h20};
				9'd269 : i2c_data <= {16'h0DE6, 8'h35};
				9'd270 : i2c_data <= {16'h0DE7, 8'h00};
				9'd271 : i2c_data <= {16'h0DE8, 8'h60};
				9'd272 : i2c_data <= {16'h0DE9, 8'h59};
				9'd273 : i2c_data <= {16'h0DEA, 8'h21};
				9'd274 : i2c_data <= {16'h0DEB, 8'h00}; 
				9'd275 : i2c_data <= {16'h0DEC, 8'h00}; 
				9'd276 : i2c_data <= {16'h0DED, 8'h1A}; 
				9'd277 : i2c_data <= {16'h0DEE, 8'h00};
				9'd278 : i2c_data <= {16'h0DEF, 8'h00};
				9'd279 : i2c_data <= {16'h0DF0, 8'h00};
				9'd280 : i2c_data <= {16'h0DF1, 8'h00}; 
				9'd281 : i2c_data <= {16'h0DF2, 8'h00}; 
				9'd282 : i2c_data <= {16'h0DF3, 8'h00}; 
				9'd283 : i2c_data <= {16'h0DF4, 8'h00};
				9'd284 : i2c_data <= {16'h0DF5, 8'h00};
				9'd285 : i2c_data <= {16'h0DF6, 8'h00};
				9'd286 : i2c_data <= {16'h0DF7, 8'h00};
				9'd287 : i2c_data <= {16'h0DF8, 8'h00};
				9'd288 : i2c_data <= {16'h0DF9, 8'h00};
				9'd289 : i2c_data <= {16'h0DFA, 8'h00};
				9'd290 : i2c_data <= {16'h0DFB, 8'h00}; 
				9'd291 : i2c_data <= {16'h0DFC, 8'h00}; 
				9'd292 : i2c_data <= {16'h0DFD, 8'h00}; 
				9'd293 : i2c_data <= {16'h0DFE, 8'h00}; 
				9'd294 : i2c_data <= {16'h0DFF, 8'hA8}; 
				9'd295 : i2c_data <= {16'h000C, 8'h00}; 
				9'd296 : i2c_data <= {16'h000A, 8'h04}; 
				9'd297 : i2c_data <= {16'h2000, 8'h0F}; 
				9'd298 : i2c_data <= {16'h2001, 8'h00}; 
				9'd299 : i2c_data <= {16'h2002, 8'h00};	
				9'd300 : i2c_data <= {16'h2003, 8'h01};				
				
				default : i2c_data <=  {16'h0003,8'h5a}; 
			endcase
		end	
		else if(state_cnt == 1)begin
			case(init_reg_cnt)
				9'd0   : i2c_data <= {16'h209C, 8'h00};
				9'd1   : i2c_data <= {16'h209D, 8'h00};
				9'd2   : i2c_data <= {16'h209E, 8'h00};
				9'd3   : i2c_data <= {16'h209F, 8'h00};
				default : i2c_data <=  {16'h209C,8'h00}; 
			endcase
		end	
		else begin
			case(init_reg_cnt)
				9'd0   : i2c_data <= {16'h1010, 8'h01};
				9'd1   : i2c_data <= {16'h1024, 8'h00};
				9'd2   : i2c_data <= {16'h0200, 8'h00};
				9'd3   : i2c_data <= {16'h1024, 8'h70};
				9'd4   : i2c_data <= {16'h0200, 8'h07};
				9'd5   : i2c_data <= {16'h0215, 8'h01};
				9'd6   : i2c_data <= {16'h0215, 8'h00};				
				default : i2c_data <=  {16'h0003,8'h5a}; 
			endcase		
		
		end
		
    end
end

endmodule