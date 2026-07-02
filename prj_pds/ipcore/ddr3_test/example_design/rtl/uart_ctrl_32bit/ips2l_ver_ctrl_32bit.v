
//////////////////////////////////////////////////////////////////////////////
//
// Copyright (c) 2020 PANGO MICROSYSTEMS, INC
// ALL RIGHTS REVERVED.
//
// THE SOURCE CODE CONTAINED HEREIN IS PROPRIETARY TO PANGO MICROSYSTEMS, INC.
// IT SHALL NOT BE REPRODUCED OR DISCLOSED IN WHOLE OR IN PART OR USED BY
// PARTIES WITHOUT WRITTEN AUTHORIZATION FROM THE OWNER.
//
//////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module ips2l_ver_ctrl_32bit #(
    parameter DFT_CTRL_BUS_0  = 32'h0000_0000,
    parameter DFT_CTRL_BUS_1  = 32'h0000_0000,
    parameter DFT_CTRL_BUS_2  = 32'h0000_0000,
    parameter DFT_CTRL_BUS_3  = 32'h0000_0000,
    parameter DFT_CTRL_BUS_4  = 32'h0000_0000,
    parameter DFT_CTRL_BUS_5  = 32'h0000_0000,
    parameter DFT_CTRL_BUS_6  = 32'h0000_0000,
    parameter DFT_CTRL_BUS_7  = 32'h0000_0000,
    parameter DFT_CTRL_BUS_8  = 32'h0000_0000,
    parameter DFT_CTRL_BUS_9  = 32'h0000_0000,
    parameter DFT_CTRL_BUS_10 = 32'h0000_0000,
    parameter DFT_CTRL_BUS_11 = 32'h0000_0000,
    parameter DFT_CTRL_BUS_12 = 32'h0000_0000,
    parameter DFT_CTRL_BUS_13 = 32'h0000_0000
)(
    input               clk                    ,
    input               rst_n                  ,

    input       [7:0]   addr                   ,
    input       [31:0]  data                   ,
    input               we                     ,
    input               cmd_en                 ,
    output  reg         cmd_done               ,

    output  wire [31:0] fifo_data              ,
    input               fifo_data_valid        ,
    output  reg         fifo_data_req          ,

    output  reg        read_req                ,
    input              read_ack                ,

    output  reg [31:0]  ctrl_bus_0             ,
    output  reg [31:0]  ctrl_bus_1             ,
    output  reg [31:0]  ctrl_bus_2             ,
    output  reg [31:0]  ctrl_bus_3             ,
    output  reg [31:0]  ctrl_bus_4             ,
    output  reg [31:0]  ctrl_bus_5             ,
    output  reg [31:0]  ctrl_bus_6             ,
    output  reg [31:0]  ctrl_bus_7             ,
    output  reg [31:0]  ctrl_bus_8              ,
    output  reg [31:0]  ctrl_bus_9              ,
    output  reg [31:0]  ctrl_bus_10             ,
    output  reg [31:0]  ctrl_bus_11             ,
    output  reg [31:0]  ctrl_bus_12             ,
    output  reg [31:0]  ctrl_bus_13             ,
     
    input   [31:0]  status_bus          
);

reg  [31:0] rd_data   ;
reg  [1:0]  clk_cnt   ;
reg         we_rg     ;
wire        clk_pos   ;
wire [31:0] version_id;

reg         read_ack_syn1;
reg         read_ack_syn2;
reg         read_ack_syn3;
reg         read_ack_inv;

assign version_id = 32'h20200729;

always @(posedge clk or negedge rst_n)
begin
    if(~rst_n)
        clk_cnt <= 2'd0;
    else
        clk_cnt <= clk_cnt + 2'd1;
end

assign clk_pos = clk_cnt == 2'd3;

always @(posedge clk or negedge rst_n)
begin
    if(~rst_n)
        we_rg <= 1'b0;
    else if(cmd_en && we)
        we_rg <= 1'b1;
    else if(clk_pos)
        we_rg <= 1'b0;
    else;
end

always @(posedge clk or negedge rst_n)
begin
    if(~rst_n)
    begin
        ctrl_bus_0 <= DFT_CTRL_BUS_0;
        ctrl_bus_1 <= DFT_CTRL_BUS_1;
        ctrl_bus_2 <= DFT_CTRL_BUS_2;
        ctrl_bus_3 <= DFT_CTRL_BUS_3;
        ctrl_bus_4 <= DFT_CTRL_BUS_4;
        ctrl_bus_5 <= DFT_CTRL_BUS_5;
        ctrl_bus_6 <= DFT_CTRL_BUS_6;
        ctrl_bus_7 <= DFT_CTRL_BUS_7;
        ctrl_bus_8 <= DFT_CTRL_BUS_8;
        ctrl_bus_9 <= DFT_CTRL_BUS_9;
        ctrl_bus_10 <= DFT_CTRL_BUS_10;
        ctrl_bus_11 <= DFT_CTRL_BUS_11;
        ctrl_bus_12 <= DFT_CTRL_BUS_12;
        ctrl_bus_13 <= DFT_CTRL_BUS_13;
    end
    else if(we_rg && clk_pos)
    begin
        case(addr)
            8'h00: ctrl_bus_0 <= data;
            8'h01: ctrl_bus_1 <= data;
            8'h02: ctrl_bus_2 <= data;
            8'h03: ctrl_bus_3 <= data;
            8'h04: ctrl_bus_4 <= data;
            8'h05: ctrl_bus_5 <= data;
            8'h06: ctrl_bus_6 <= data;
            8'h07: ctrl_bus_7 <= data;
            8'h08: ctrl_bus_8 <= data;
            8'h09: ctrl_bus_9 <= data;
            8'h0a: ctrl_bus_10 <= data;
            8'h0b: ctrl_bus_11 <= data;
            8'h0c: ctrl_bus_12 <= data;
            8'h0d: ctrl_bus_13 <= data;
            default:;
        endcase
    end
    else;
    //else if(clk_pos)
    //begin
    //    ctrl_bus_2[0] <= 1'b0;
    //end
end

always @(posedge clk or negedge rst_n)
begin
    if(~rst_n)
        read_req <= 1'b0;
    else if(cmd_en && ~we)
        read_req <= ~read_req;
    else;
end

always @(posedge clk or negedge rst_n)
begin
    if(~rst_n)
    begin
        read_ack_syn1 <= 1'b0;
        read_ack_syn2 <= 1'b0;
        read_ack_syn3 <= 1'b0;
        read_ack_inv  <= 1'b0;
    end
    else
    begin
        read_ack_syn1 <= read_ack;
        read_ack_syn2 <= read_ack_syn1;
        read_ack_syn3 <= read_ack_syn2;
        read_ack_inv  <= read_ack_syn3 ^ read_ack_syn2;
    end
end

always @(posedge clk or negedge rst_n)
begin
    if(~rst_n)
    begin
        rd_data <= 32'd0;
    end
    else if(read_ack_inv)
    begin
        case(addr)
            8'h00: rd_data <= ctrl_bus_0;
            8'h01: rd_data <= ctrl_bus_1;
            8'h02: rd_data <= ctrl_bus_2;
            8'h03: rd_data <= ctrl_bus_3;
            8'h04: rd_data <= ctrl_bus_4;
            8'h05: rd_data <= ctrl_bus_5;
            8'h06: rd_data <= ctrl_bus_6;
            8'h07: rd_data <= ctrl_bus_7;
            8'h08: rd_data <= ctrl_bus_8;
            8'h09: rd_data <= ctrl_bus_9;
            8'h0a: rd_data <= ctrl_bus_10;
            8'h0b: rd_data <= ctrl_bus_11;
            8'h0c: rd_data <= ctrl_bus_12;
            8'h0d: rd_data <= ctrl_bus_13;
            8'hff: rd_data <= version_id;
            default: rd_data <= status_bus;
        endcase
    end
    else;
end

always @(posedge clk or negedge rst_n)
begin
    if(~rst_n)
        cmd_done <= 1'b0;
    else if(read_ack_inv || (we_rg & clk_pos))
        cmd_done <= 1'b1;
    else
        cmd_done <= 1'b0;
end

assign fifo_data = rd_data;

always @(posedge clk or negedge rst_n)
begin
    if(~rst_n)
        fifo_data_req <= 1'b0;
    else if(read_ack_inv & fifo_data_valid)
        fifo_data_req <= 1'b1;
    else
        fifo_data_req <= 1'b0;
end

endmodule
