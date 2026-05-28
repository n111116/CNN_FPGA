// 卷积中最基础的单元，实现单个乘加操作
module pe #(
    parameter DATA_WIDTH    = 10'd7,
    parameter WEIGHT_WIDTH  = 10'd8,
    parameter ADDER2_WIDTH  = 10'd18,
    parameter OUTPUT_WIDTH  = 10'd19,
    parameter USE_DSP_PE = "no"  // 是否使用DSP资源进行乘法运算
) (
    input                               clk,
    input                               clk_en,    // 时钟使能信号
    input           [DATA_WIDTH-1:0]    D,         // 7位无符号输入
    input signed    [WEIGHT_WIDTH-1:0]  W,         // 8位有符号输入
    input signed    [ADDER2_WIDTH-1:0]  y_in,      // 18位有符号输入
    output reg signed [OUTPUT_WIDTH-1:0] y_out     // 19位有符号输出
   // (* USE_DSP = "yes" *) output reg signed [OUTPUT_WIDTH-1:0] y_out     // 19位有符号输出
);

    // 用于存储乘法结果的寄存器
    // 乘法结果宽度为 DATA_WIDTH + WEIGHT_WIDTH
    reg signed [DATA_WIDTH + WEIGHT_WIDTH - 1:0] mult_result_reg;

    logic signed [DATA_WIDTH:0] D_reg;
    logic signed [WEIGHT_WIDTH-1:0] W_reg;
    logic signed [DATA_WIDTH:0] D_reg_reg;
    logic signed [WEIGHT_WIDTH-1:0] W_reg_reg;

    // 第一个时钟周期：计算乘法 D * W
    always @(posedge clk) begin
        if (clk_en) begin
            // 将无符号 D 转换为有符号数再进行乘法
            if(USE_DSP_PE == "yes") begin
                D_reg <= $signed({1'b0,D});
                W_reg <= W;
                D_reg_reg <= D_reg;
                W_reg_reg <= W_reg;
                y_out <= D_reg_reg * W_reg_reg + y_in;
            end else begin
                D_reg <= $signed({1'b0,D});
                W_reg <= W;
                mult_result_reg <= D_reg * W_reg; // 乘法中间结果
                y_out <= y_in + mult_result_reg; 
            end
        end
    end

endmodule