module my_fifo #(
    parameter DATA_WIDTH = 8,          // 数据位宽
    parameter FIFO_DEPTH = 16          // FIFO深度（必须为2的幂）
)(
    input  logic                     rd_clk,      // 读时钟
    input  logic                     wr_clk,      // 写时钟
    input  logic                     rst,         // 高有效异步复位
    input  logic                     wr_en,       // 写使能
    input  logic [DATA_WIDTH-1:0]    din,         // 写数据
    input  logic                     rd_en,       // 读使能
    output logic [DATA_WIDTH-1:0]    dout,        // 读数据
    output logic                     full,        // 满标志（写时钟域）
    output logic                     empty        // 空标志（读时钟域）
);

// 计算地址位宽（多一位用于满/空判断）
localparam ADDR_WIDTH = $clog2(FIFO_DEPTH);      // 实际地址位宽
localparam PTR_WIDTH  = ADDR_WIDTH + 1;          // 指针位宽（含MSB）

// 存储器定义
reg [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];

// 二进制指针（各时钟域独立）
reg [PTR_WIDTH-1:0] wr_ptr;      // 写指针（二进制）
reg [PTR_WIDTH-1:0] rd_ptr;      // 读指针（二进制）

// 格雷码指针
wire [PTR_WIDTH-1:0] wr_ptr_gray;
wire [PTR_WIDTH-1:0] rd_ptr_gray;

// 同步器寄存器（两级）
reg [PTR_WIDTH-1:0] wr_ptr_gray_sync1, wr_ptr_gray_sync2; // 同步到读时钟域
reg [PTR_WIDTH-1:0] rd_ptr_gray_sync1, rd_ptr_gray_sync2; // 同步到写时钟域

// 同步后的格雷码
wire [PTR_WIDTH-1:0] wr_ptr_gray_sync = wr_ptr_gray_sync2;
wire [PTR_WIDTH-1:0] rd_ptr_gray_sync = rd_ptr_gray_sync2;

// 格雷码转二进制函数
function [PTR_WIDTH-1:0] gray2bin;
    input [PTR_WIDTH-1:0] gray;
    integer i;
    begin
        gray2bin[PTR_WIDTH-1] = gray[PTR_WIDTH-1];
        for (i = PTR_WIDTH-2; i >= 0; i = i - 1)
            gray2bin[i] = gray2bin[i+1] ^ gray[i];
    end
endfunction

// 二进制转格雷码函数
function [PTR_WIDTH-1:0] bin2gray;
    input [PTR_WIDTH-1:0] bin;
    begin
        bin2gray = (bin >> 1) ^ bin;
    end
endfunction

// 写时钟域：写指针更新及存储器写入
always @(posedge wr_clk or posedge rst) begin
    if (rst)
        wr_ptr <= {PTR_WIDTH{1'b0}};
    else if (wr_en && !full)
        wr_ptr <= wr_ptr + 1'b1;
end

always @(posedge wr_clk) begin
    if (wr_en && !full)
        mem[wr_ptr[ADDR_WIDTH-1:0]] <= din;
end

// 读时钟域：读指针更新
always @(posedge rd_clk or posedge rst) begin
    if (rst)
        rd_ptr <= {PTR_WIDTH{1'b0}};
    else if (rd_en && !empty)
        rd_ptr <= rd_ptr + 1'b1;
end

// 读数据输出，时序逻辑
always @(posedge rd_clk) begin
    if(rd_en) begin
        dout <= mem[rd_ptr[ADDR_WIDTH-1:0]];
    end
end

// 生成格雷码
assign wr_ptr_gray = bin2gray(wr_ptr);
assign rd_ptr_gray = bin2gray(rd_ptr);

// 同步写指针格雷码到读时钟域
always @(posedge rd_clk or posedge rst) begin
    if (rst) begin
        wr_ptr_gray_sync1 <= {PTR_WIDTH{1'b0}};
        wr_ptr_gray_sync2 <= {PTR_WIDTH{1'b0}};
    end else begin
        wr_ptr_gray_sync1 <= wr_ptr_gray;
        wr_ptr_gray_sync2 <= wr_ptr_gray_sync1;
    end
end

// 同步读指针格雷码到写时钟域
always @(posedge wr_clk or posedge rst) begin
    if (rst) begin
        rd_ptr_gray_sync1 <= {PTR_WIDTH{1'b0}};
        rd_ptr_gray_sync2 <= {PTR_WIDTH{1'b0}};
    end else begin
        rd_ptr_gray_sync1 <= rd_ptr_gray;
        rd_ptr_gray_sync2 <= rd_ptr_gray_sync1;
    end
end

// 满标志生成（写时钟域）
wire [PTR_WIDTH-1:0] rd_ptr_sync_bin = gray2bin(rd_ptr_gray_sync);
assign full = (wr_ptr[PTR_WIDTH-1] != rd_ptr_sync_bin[PTR_WIDTH-1]) &&
              (wr_ptr[PTR_WIDTH-2:0] == rd_ptr_sync_bin[PTR_WIDTH-2:0]);

// 空标志生成（读时钟域）
wire [PTR_WIDTH-1:0] wr_ptr_sync_bin = gray2bin(wr_ptr_gray_sync);
assign empty = (rd_ptr == wr_ptr_sync_bin);

endmodule