//****************************************Copyright (c)***********************************//
//原子哥在线教学平台：www.yuanzige.com
//技术支持：http://www.openedv.com/forum.php
//淘宝店铺：https://zhengdianyuanzi.tmall.com
//关注微信公众平台微信号："正点原子"，免费获取ZYNQ & FPGA & STM32 & LINUX资料。
//版权所有，盗版必究。
//Copyright(C) 正点原子 2023-2033
//All rights reserved                                  
//----------------------------------------------------------------------------------------
// File name:           usb_rw
// Created by:          正点原子
// Created date:        2024年6月3日14:17:02
// Version:             V1.0
// Descriptions:       USB读写模块
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module usb_rw
 #(
   parameter IDLE       =3'd1,   //初始化状态
   parameter READ_ADDR  =3'd2,   //读地址状态
   parameter WRITE_ADDR =3'd3,   //写地址状态
   parameter READ_DATA  =3'd4,   //读数据状态
   parameter WRITE_DATA =3'd5,   //写数据状态   
   parameter PORT_NUM   = 2      // 芯片个数
   )(
    input             clk_usb   ,//100Mhz时钟
    input             sys_rst_n,  //系统复位
    input   [12:0]    fifo_data_count,//fifo读数据计数
    //usb3.0
    output reg        slcs    ,   //片选信号        
    output reg [1:0]  usb_addr,   //缓冲区选择       
    output reg        slrd    ,   //读请求信号，读数据在读请求生效后第二个时钟上升沿出来低电平有效 
    output reg        sloe    ,   //读写使能信号，0读1写
    output reg        slwr    ,   //写请求信号，与写数据同步低电平有效
    input             flaga_1,    //缓冲区An的空满信号
    input             flagb_1,    //缓冲区Am的空满信号
    input             flagc_1,    //缓冲区An的空满信号
    input             flagd_1,    //缓冲区Am的空满信号
    input             pktend ,    //写一包数据最后一个数据的标志
    output reg  [2:0] state       //状态寄存器
   );
    
//reg define 
reg  [2:0]  next_state ;         //次态寄存器
reg         read_addr_done;      //读地址完成信号
reg         write_addr_done;     //写地址完成信号
reg         write_done;          //写数据完成信号
reg         read_done;           //读数据完成信号

//*****************************************************
//**                    main code
//*****************************************************

//读写测试的三态式状态机
always@(posedge clk_usb or negedge sys_rst_n)begin
    if(!sys_rst_n)
        state <= IDLE; 
    else 
        state <= next_state; 
end

always@(*)begin
    case(state)
        IDLE:begin
                if(flagc_1)                      //缓冲区An不空，有数据
                    next_state <= READ_ADDR;     //进入读地址状态
                else if(fifo_data_count > 0)     // 有足够多的数据时开始写
                    next_state <= WRITE_ADDR;    //进入写地址状态
                else 
                    next_state <= IDLE;          //否则保持初始化状态
                end         
            READ_ADDR:begin                      //进入读地址状态
                if(read_addr_done)               //读地址完成
                    next_state <= READ_DATA;     //进入读数据状态
                else 
                    next_state <= READ_ADDR;     //读地址没有完成，继续读地址
                end         
            WRITE_ADDR:begin                     //进入写地址状态
                if(write_addr_done)              //写地址完成
                    next_state <= WRITE_DATA;    //进入写数据状态
                else 
                    next_state <= WRITE_ADDR;    //写地址没有完成，继续写地址
                end     
            READ_DATA:begin                      //进入读数据状态
                if(read_done)                    //读数据完成
                    next_state <= IDLE;          //恢复初始化状态
                else 
                    next_state <= READ_DATA;     //否则继续读数据
                end     
            WRITE_DATA:begin                     //进入写数据状态
                if(write_done || (~flagb_1) )    //写数据完成或者缓冲区Am已写满
                    next_state <= IDLE;          //恢复初始化状态
                else 
                    next_state <= WRITE_DATA;    //否则继续写数据
                end
        default:;
    endcase
end

always@(posedge clk_usb or negedge sys_rst_n )begin
    if(!sys_rst_n)begin
        sloe            <= 1'b1;
        slrd            <= 1'b1;
        usb_addr        <= 2'b00;
        slcs            <= 1'b1;
        slwr            <= 1'b1;
        read_addr_done  <= 1'b0;
        write_addr_done <= 1'b0;
    end     
    else begin
        case(state)
            IDLE:begin
                sloe            <= 1'b1;
                slrd            <= 1'b1;
                usb_addr        <= 2'b00;
                slcs            <= 1'b0;
                slwr            <= 1'b1;
                read_addr_done  <= 1'b0;
                write_addr_done <= 1'b0;
                write_done      <= 1'b0;
                read_done       <= 1'b0;
            end
            READ_ADDR:begin
                sloe           <= 1'b0;             
                usb_addr       <= 2'b11;
                slwr           <= 1'b1;
                read_addr_done <= 1'b1;
            end
            READ_DATA:begin
                if(flagc_1)begin
                    slrd     <= 1'b0;
                end 
                else if(~flagd_1 && ~flagc_1)begin
                    slrd      <= 1'b1;
                    sloe      <= 1'b1;  
                    read_done <= 1'b1;
                end
            end
            WRITE_ADDR:begin
                usb_addr        <= 2'b00;
                write_addr_done <= 1'b1;
                sloe            <= 1'b1;
            end
            WRITE_DATA:begin
                if(~flagb_1 || ~pktend)begin
                    write_done <= 1'b1;
                    slwr       <= 1'b1;
                end
                else if(~write_done) begin                  
                    slwr <= 1'b0;
                end
                else
                 ;      
            end
            default:;
        endcase
    end
end

endmodule