// 激活函数的 LUT 实现
module activation_lut #(
    // [修改]：去掉了 int, bit, string 等显式类型声明
    parameter INPUT_WIDTH   = 13,
    parameter OUTPUT_WIDTH  = 8,
    parameter CONV_POSITIVE = 1,
    parameter LUT_FILE      = "sigmoid_lut_8bit_to_8bit_h.mem"
)(
    input  logic                    clk,
    input  logic                    in_valid,
    input  logic [INPUT_WIDTH-1:0]  val_in,
    
    output logic                    out_valid,
    output logic [OUTPUT_WIDTH-1:0] confidence_out
);

    // =========================================================
    // 建立查找表 (LUT ROM)
    // =========================================================
    // [修改]：去掉了 localparam 后面的 int
    localparam ROM_DEPTH = 1 << INPUT_WIDTH;
    
    // 定义 ROM (内部存储器允许使用非压缩数组，这个不用改)
    logic [OUTPUT_WIDTH-1:0] lut_rom [0:ROM_DEPTH-1];

    // 初始化 ROM
    initial begin
        // 使用 $readmemb 读取二进制文件，或 $readmemh 读取十六进制文件
        $readmemh(LUT_FILE, lut_rom); 
    end

    // =========================================================
    // 查表逻辑
    // =========================================================
    always_ff @(posedge clk) begin
        out_valid <= in_valid;
        
        if (in_valid) begin
            // 直接以输入值作为地址查表
            // 在生成 .mem 文件时就处理好偏移
            confidence_out <= lut_rom[val_in];
        end
    end

endmodule