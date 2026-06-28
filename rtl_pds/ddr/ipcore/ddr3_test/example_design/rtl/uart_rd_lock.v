`timescale 1ns/1ns
module uart_rd_lock
(                        
    input                                core_clk           ,
    input                                core_rst_n         ,   

    input                                uart_read_req      ,
    output reg                           uart_read_ack      ,
    input [7:0]                          uart_read_addr     ,

    input [31:0]                         status_bus_80          ,         
    input [31:0]                         status_bus_81          ,         
    input [31:0]                         status_bus_82          ,         
    input [31:0]                         status_bus_83          ,         
    input [31:0]                         status_bus_84          ,         
    input [31:0]                         status_bus_85          ,         
    input [31:0]                         status_bus_86          ,         
    input [31:0]                         status_bus_87          ,         
    input [31:0]                         status_bus_88          ,         
    input [31:0]                         status_bus_89          ,         
    input [31:0]                         status_bus_8a          ,         
    input [31:0]                         status_bus_8b          ,         
    input [31:0]                         status_bus_8c          ,         
    input [31:0]                         status_bus_8d          ,         
    input [31:0]                         status_bus_8e          ,         
    input [31:0]                         status_bus_8f          ,         

    input [31:0]                         status_bus_90          ,         
    input [31:0]                         status_bus_91          ,         
    input [31:0]                         status_bus_92          ,         
    input [31:0]                         status_bus_93          ,         
    input [31:0]                         status_bus_94          ,         
    input [31:0]                         status_bus_95          ,         
    input [31:0]                         status_bus_96          ,         
    input [31:0]                         status_bus_97          ,         
    input [31:0]                         status_bus_98          ,         
    input [31:0]                         status_bus_99          ,         
    input [31:0]                         status_bus_9a          ,         
    input [31:0]                         status_bus_9b          ,         
    input [31:0]                         status_bus_9c          ,         
    input [31:0]                         status_bus_9d          ,         
    input [31:0]                         status_bus_9e          ,         
    input [31:0]                         status_bus_9f          ,    

    input [31:0]                         status_bus_a0          ,         
    input [31:0]                         status_bus_a1          ,         
    input [31:0]                         status_bus_a2          ,  
    input [31:0]                         status_bus_a3          ,         
    input [31:0]                         status_bus_a4          ,         
    input [31:0]                         status_bus_a5          ,         
    input [31:0]                         status_bus_a6          ,         
    input [31:0]                         status_bus_a7          ,         
    input [31:0]                         status_bus_a8          ,         
    input [31:0]                         status_bus_a9          ,         
    input [31:0]                         status_bus_aa          ,         
    input [31:0]                         status_bus_ab          ,         
    input [31:0]                         status_bus_ac          ,         
    input [31:0]                         status_bus_ad          ,         
    input [31:0]                         status_bus_ae          ,         
    input [31:0]                         status_bus_af          ,    

    input [31:0]                         status_bus_b0          ,         
    input [31:0]                         status_bus_b1          ,         
    input [31:0]                         status_bus_b2          ,         
    input [31:0]                         status_bus_b3          ,         
    input [31:0]                         status_bus_b4          ,         
    input [31:0]                         status_bus_b5          ,         
    input [31:0]                         status_bus_b6          ,         
    input [31:0]                         status_bus_b7          ,         
    input [31:0]                         status_bus_b8          ,         
    input [31:0]                         status_bus_b9          ,         
    input [31:0]                         status_bus_ba          ,         
    input [31:0]                         status_bus_bb          ,         
    input [31:0]                         status_bus_bc          ,         
    input [31:0]                         status_bus_bd          ,         
    input [31:0]                         status_bus_be          ,         
    input [31:0]                         status_bus_bf          ,    

    input [31:0]                         status_bus_c0          ,         
    input [31:0]                         status_bus_c1          ,         
    input [31:0]                         status_bus_c2          ,         
    input [31:0]                         status_bus_c3          ,         
    input [31:0]                         status_bus_c4          ,         
    input [31:0]                         status_bus_c5          ,         
    input [31:0]                         status_bus_c6          ,         
    input [31:0]                         status_bus_c7          ,         
    input [31:0]                         status_bus_c8          ,         
    input [31:0]                         status_bus_c9          ,         
    input [31:0]                         status_bus_ca          ,         
    input [31:0]                         status_bus_cb          ,         
    input [31:0]                         status_bus_cc          ,         
    input [31:0]                         status_bus_cd          ,         
    input [31:0]                         status_bus_ce          ,         
    input [31:0]                         status_bus_cf          ,    

    input [31:0]                         status_bus_d0          ,         
    input [31:0]                         status_bus_d1          ,         
    input [31:0]                         status_bus_d2          ,         
    input [31:0]                         status_bus_d3          ,         
    input [31:0]                         status_bus_d4          ,         
    input [31:0]                         status_bus_d5          ,         
    input [31:0]                         status_bus_d6          ,         
    input [31:0]                         status_bus_d7          ,         
    input [31:0]                         status_bus_d8          ,         
    input [31:0]                         status_bus_d9          ,         
    input [31:0]                         status_bus_da          ,         
    input [31:0]                         status_bus_db          ,         
    input [31:0]                         status_bus_dc          ,         
    input [31:0]                         status_bus_dd          ,         
    input [31:0]                         status_bus_de          ,         
    input [31:0]                         status_bus_df          ,    

    input [31:0]                         status_bus_e0          ,         
    input [31:0]                         status_bus_e1          ,         
    input [31:0]                         status_bus_e2          ,         
    input [31:0]                         status_bus_e3          ,         
    input [31:0]                         status_bus_e4          ,         

    output reg [31:0]                    status_bus_lock            
);

reg  uart_read_req_syn1;
reg  uart_read_req_syn2;
reg  uart_read_req_syn3;
wire uart_read_req_inv;

always @(posedge core_clk or negedge core_rst_n)
begin
    if(!core_rst_n)
    begin
       uart_read_req_syn1 <= 1'b0;
       uart_read_req_syn2 <= 1'b0;
       uart_read_req_syn3 <= 1'b0;
    end
    else
    begin
       uart_read_req_syn1 <= uart_read_req;
       uart_read_req_syn2 <= uart_read_req_syn1;
       uart_read_req_syn3 <= uart_read_req_syn2;
    end
end

assign uart_read_req_inv = uart_read_req_syn3 ^ uart_read_req_syn2;

always @(posedge core_clk or negedge core_rst_n)
begin
    if(!core_rst_n)
        uart_read_ack <= 1'b0;
    else if(uart_read_req_inv)
        uart_read_ack <= ~uart_read_ack;
    else;
end

always @(posedge core_clk or negedge core_rst_n)
begin
    if(!core_rst_n)
        status_bus_lock <= 32'b0;         
    else if(uart_read_req_inv)
    begin
        case(uart_read_addr)
            8'h80: status_bus_lock <= status_bus_80;         
            8'h81: status_bus_lock <= status_bus_81;         
            8'h82: status_bus_lock <= status_bus_82;         
            8'h83: status_bus_lock <= status_bus_83;         
            8'h84: status_bus_lock <= status_bus_84;         
            8'h85: status_bus_lock <= status_bus_85;         
            8'h86: status_bus_lock <= status_bus_86;         
            8'h87: status_bus_lock <= status_bus_87;         
            8'h88: status_bus_lock <= status_bus_88;         
            8'h89: status_bus_lock <= status_bus_89;         
            8'h8a: status_bus_lock <= status_bus_8a;         
            8'h8b: status_bus_lock <= status_bus_8b;         
            8'h8c: status_bus_lock <= status_bus_8c;         
            8'h8d: status_bus_lock <= status_bus_8d;         
            8'h8e: status_bus_lock <= status_bus_8e;         
            8'h8f: status_bus_lock <= status_bus_8f;

            8'h90: status_bus_lock <= status_bus_90;         
            8'h91: status_bus_lock <= status_bus_91;         
            8'h92: status_bus_lock <= status_bus_92;         
            8'h93: status_bus_lock <= status_bus_93;         
            8'h94: status_bus_lock <= status_bus_94;         
            8'h95: status_bus_lock <= status_bus_95;         
            8'h96: status_bus_lock <= status_bus_96;         
            8'h97: status_bus_lock <= status_bus_97;         
            8'h98: status_bus_lock <= status_bus_98;         
            8'h99: status_bus_lock <= status_bus_99;         
            8'h9a: status_bus_lock <= status_bus_9a;         
            8'h9b: status_bus_lock <= status_bus_9b;         
            8'h9c: status_bus_lock <= status_bus_9c;         
            8'h9d: status_bus_lock <= status_bus_9d;         
            8'h9e: status_bus_lock <= status_bus_9e;         
            8'h9f: status_bus_lock <= status_bus_9f;

            8'ha0: status_bus_lock <= status_bus_a0;         
            8'ha1: status_bus_lock <= status_bus_a1;         
            8'ha2: status_bus_lock <= status_bus_a2;
            8'ha3: status_bus_lock <= status_bus_a3;         
            8'ha4: status_bus_lock <= status_bus_a4;         
            8'ha5: status_bus_lock <= status_bus_a5;         
            8'ha6: status_bus_lock <= status_bus_a6;         
            8'ha7: status_bus_lock <= status_bus_a7;         
            8'ha8: status_bus_lock <= status_bus_a8;         
            8'ha9: status_bus_lock <= status_bus_a9;         
            8'haa: status_bus_lock <= status_bus_aa;         
            8'hab: status_bus_lock <= status_bus_ab;         
            8'hac: status_bus_lock <= status_bus_ac;         
            8'had: status_bus_lock <= status_bus_ad;         
            8'hae: status_bus_lock <= status_bus_ae;         
            8'haf: status_bus_lock <= status_bus_af;

            8'hb0: status_bus_lock <= status_bus_b0;         
            8'hb1: status_bus_lock <= status_bus_b1;         
            8'hb2: status_bus_lock <= status_bus_b2;         
            8'hb3: status_bus_lock <= status_bus_b3;         
            8'hb4: status_bus_lock <= status_bus_b4;         
            8'hb5: status_bus_lock <= status_bus_b5;         
            8'hb6: status_bus_lock <= status_bus_b6;         
            8'hb7: status_bus_lock <= status_bus_b7;         
            8'hb8: status_bus_lock <= status_bus_b8;         
            8'hb9: status_bus_lock <= status_bus_b9;         
            8'hba: status_bus_lock <= status_bus_ba;         
            8'hbb: status_bus_lock <= status_bus_bb;         
            8'hbc: status_bus_lock <= status_bus_bc;         
            8'hbd: status_bus_lock <= status_bus_bd;         
            8'hbe: status_bus_lock <= status_bus_be;         
            8'hbf: status_bus_lock <= status_bus_bf;

            8'hc0: status_bus_lock <= status_bus_c0;         
            8'hc1: status_bus_lock <= status_bus_c1;         
            8'hc2: status_bus_lock <= status_bus_c2;         
            8'hc3: status_bus_lock <= status_bus_c3;         
            8'hc4: status_bus_lock <= status_bus_c4;         
            8'hc5: status_bus_lock <= status_bus_c5;         
            8'hc6: status_bus_lock <= status_bus_c6;         
            8'hc7: status_bus_lock <= status_bus_c7;         
            8'hc8: status_bus_lock <= status_bus_c8;         
            8'hc9: status_bus_lock <= status_bus_c9;         
            8'hca: status_bus_lock <= status_bus_ca;         
            8'hcb: status_bus_lock <= status_bus_cb;         
            8'hcc: status_bus_lock <= status_bus_cc;         
            8'hcd: status_bus_lock <= status_bus_cd;         
            8'hce: status_bus_lock <= status_bus_ce;         
            8'hcf: status_bus_lock <= status_bus_cf;
           
            8'hd0: status_bus_lock <= status_bus_d0;         
            8'hd1: status_bus_lock <= status_bus_d1;         
            8'hd2: status_bus_lock <= status_bus_d2;         
            8'hd3: status_bus_lock <= status_bus_d3;         
            8'hd4: status_bus_lock <= status_bus_d4;         
            8'hd5: status_bus_lock <= status_bus_d5;         
            8'hd6: status_bus_lock <= status_bus_d6;         
            8'hd7: status_bus_lock <= status_bus_d7;         
            8'hd8: status_bus_lock <= status_bus_d8;         
            8'hd9: status_bus_lock <= status_bus_d9;         
            8'hda: status_bus_lock <= status_bus_da;         
            8'hdb: status_bus_lock <= status_bus_db;         
            8'hdc: status_bus_lock <= status_bus_dc;         
            8'hdd: status_bus_lock <= status_bus_dd;         
            8'hde: status_bus_lock <= status_bus_de;         
            8'hdf: status_bus_lock <= status_bus_df;
             
            8'he0: status_bus_lock <= status_bus_e0;         
            8'he1: status_bus_lock <= status_bus_e1;         
            8'he2: status_bus_lock <= status_bus_e2;         
            8'he3: status_bus_lock <= status_bus_e3;         
            8'he4: status_bus_lock <= status_bus_e4;         
            default : status_bus_lock <= 32'b0;
        endcase
    end
    else;
end

endmodule
