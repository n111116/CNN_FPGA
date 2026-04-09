// 卷积核列处理单元（1维输入数组）
// PE_ROW_NUM个PE单元，每个单元执行乘法+加法（2周期）
// 使用clk_en控制计算使能
module pe_col #(
    parameter int unsigned PE_ROW_NUM = 9,           // PE单元数量
    parameter int unsigned DATA_WIDTH   = 7,        // 数据位宽
    parameter int unsigned WEIGHT_WIDTH = 8,        // 权重位宽
    parameter int unsigned OUTPUT_WIDTH = DATA_WIDTH + WEIGHT_WIDTH + $clog2(PE_ROW_NUM+1),  // 输出位宽
    parameter USE_DSP_PE          = "yes"    // 是否使用DSP资源进行乘法运算
) (
    input  logic                            clk,
    input  logic                            clk_en, // 时钟使能
    // 1维数据输入 (卷积核展开)
    input  logic [PE_ROW_NUM-1:0] [DATA_WIDTH-1:0] D ,
    // 1维权重输入 (卷积核展开)
    input  logic signed [PE_ROW_NUM-1:0] [WEIGHT_WIDTH-1:0]  W ,
    // 链式输出
    output logic signed [OUTPUT_WIDTH-1:0]  y_out
);

    // PE链式输出信号
    logic signed [OUTPUT_WIDTH-1:0] y_chain [PE_ROW_NUM+1];
    assign y_chain[0] = 0;

    // 实例化PE_ROW_NUM个PE单元
    for (genvar j = 0; j < PE_ROW_NUM; j++) begin : pe_inst
    
        pe #(
            .DATA_WIDTH    (DATA_WIDTH),
            .WEIGHT_WIDTH  (WEIGHT_WIDTH),
            .ADDER2_WIDTH  (OUTPUT_WIDTH),
            .OUTPUT_WIDTH  (OUTPUT_WIDTH),
            .USE_DSP_PE    (USE_DSP_PE)
        ) u_pe (
            .clk    (clk),
            .clk_en (clk_en),
            .D      (D[j]),
            .W      (W[j]),
            .y_in   (y_chain[j]),
            .y_out  (y_chain[j+1])
        );
    end

    assign y_out = y_chain[PE_ROW_NUM];

endmodule