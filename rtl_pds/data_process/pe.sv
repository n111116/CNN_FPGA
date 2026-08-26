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

    localparam int PRODUCT_WIDTH = DATA_WIDTH + WEIGHT_WIDTH;

    function automatic logic signed [PRODUCT_WIDTH-1:0] mul_no_dsp;
        input logic [DATA_WIDTH-1:0]   d_in;
        input logic signed [WEIGHT_WIDTH-1:0] w_in;
        logic signed [PRODUCT_WIDTH-1:0] acc;
        logic signed [PRODUCT_WIDTH-1:0] d_ext;
        int bit_idx;
        begin
            acc   = '0;
            d_ext = $signed({1'b0, d_in});
            for (bit_idx = 0; bit_idx < WEIGHT_WIDTH-1; bit_idx = bit_idx + 1) begin
                if (w_in[bit_idx]) begin
                    acc = acc + (d_ext <<< bit_idx);
                end
            end
            if (w_in[WEIGHT_WIDTH-1]) begin
                acc = acc - (d_ext <<< (WEIGHT_WIDTH-1));
            end
            mul_no_dsp = acc;
        end
    endfunction

    // 用于存储乘法结果的寄存器
    // 乘法结果宽度为 DATA_WIDTH + WEIGHT_WIDTH
    reg signed [PRODUCT_WIDTH - 1:0] mult_result_reg;

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
                mult_result_reg <= mul_no_dsp(D_reg, W_reg); // 纯移位加法，不推 DSP
                y_out <= y_in + mult_result_reg; 
            end
        end
    end

endmodule
