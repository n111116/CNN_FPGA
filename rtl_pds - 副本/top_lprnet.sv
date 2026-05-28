// =========================================================
// lprnet的顶层模块，包含从layer20到layer28和后处理模块
// =========================================================
`include "data_process/header/layer20.vh"
`include "data_process/header/layer21.vh"
`include "data_process/header/layer22.vh"
`include "data_process/header/layer23.vh"
`include "data_process/header/layer24.vh"
`include "data_process/header/layer25.vh"
`include "data_process/header/layer26.vh"
`include "data_process/header/layer27.vh"
`include "data_process/header/layer28.vh"

module lprnet_top #(
    // 后处理模块的固定参数，提升为顶层参数方便配置
    parameter bit CONV_POSITIVE = 1,  // 寻找最大激活通道
    parameter int BLANK_CHAR    = 75, // 空白符对应的通道索引
    // 计算 CTC 输出的字符宽度
    parameter int POST_CH_OUT_NUM = CYCLE_PERIOD_OUT_LAYER28 * PE_COL_NUM_LAYER28,
    parameter int POST_CH_WIDTH   = $clog2(POST_CH_OUT_NUM)
) (
    input  logic clk,
    input  logic clk_en,
    input  logic rst_n,

    // ---------------- Layer 20 (Input Layer) 接口 ----------------
    input  logic                          new_line_input_1,
    input  logic                          data_input_valid,
    input  logic  [PE_PAGE_NUM_LAYER20-1:0] [DATA_WIDTH_LAYER20-1:0] data_input,

    // ---------------- Post Process (Output) 接口 ----------------
    output logic [POST_CH_WIDTH-1:0]      out_char,
    output logic                          out_valid,
    output logic                          frame_start_out
);

    // =========================================================
    // 内部连线定义 (中间层互联)
    // =========================================================
    
    // Layer 20 -> Layer 21
    logic [PE_COL_NUM_LAYER20-1:0] [OUT_WIDTH_LAYER20-1:0] layer_y_out_layer20;
    logic out_valid_layer20;
    logic new_line_out_1_layer20;

    // Layer 21 -> Layer 22
    logic [PE_COL_NUM_LAYER21-1:0] [OUT_WIDTH_LAYER21-1:0] layer_y_out_layer21 ;
    logic out_valid_layer21;
    logic new_line_out_1_layer21;

    // Layer 22 -> Layer 23
    logic [PE_COL_NUM_LAYER22-1:0] [OUT_WIDTH_LAYER22-1:0] layer_y_out_layer22 ;
    logic out_valid_layer22;
    logic new_line_out_1_layer22;

    // Layer 23 -> Layer 24
    logic [PE_COL_NUM_LAYER23-1:0] [OUT_WIDTH_LAYER23-1:0] layer_y_out_layer23 ;
    logic out_valid_layer23;
    logic new_line_out_1_layer23;

    // Layer 24 -> Layer 25
    logic [PE_COL_NUM_LAYER24-1:0] [OUT_WIDTH_LAYER24-1:0] layer_y_out_layer24 ;
    logic out_valid_layer24;
    logic new_line_out_1_layer24;

    // Layer 25 -> Layer 26
    logic [PE_COL_NUM_LAYER25-1:0] [OUT_WIDTH_LAYER25-1:0] layer_y_out_layer25 ;
    logic out_valid_layer25;
    logic new_line_out_1_layer25;

    // Layer 26 -> Layer 27
    logic [PE_COL_NUM_LAYER26-1:0] [OUT_WIDTH_LAYER26-1:0] layer_y_out_layer26 ;
    logic out_valid_layer26;
    logic new_line_out_1_layer26;

    // Layer 27 -> Layer 28
    logic [PE_COL_NUM_LAYER27-1:0] [OUT_WIDTH_LAYER27-1:0] layer_y_out_layer27 ;
    logic out_valid_layer27;
    logic new_line_out_1_layer27;

    // Layer 28 -> Post Process
    logic [PE_COL_NUM_LAYER28-1:0] [OUT_WIDTH_LAYER28-1:0] layer_y_out_layer28 ;
    logic out_valid_layer28;
    logic new_line_out_1_layer28;
    
    // 无符号转有符号 (针对 Post Process 的要求)
    logic signed [PE_COL_NUM_LAYER28-1:0] [OUT_WIDTH_LAYER28-1:0] layer28_y_out_signed ;
    int idc;
    always_comb begin
        for(idc = 0; idc < PE_COL_NUM_LAYER28; idc = idc + 1) begin
            layer28_y_out_signed[idc] = $signed(layer_y_out_layer28[idc]);
        end
    end


    // =========================================================
    // 网络层级例化 (Layer 20 ~ 28 + Post Process)
    // =========================================================
    
    // Layer 20 (Top layer in this chain)
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER20), .PE_PAGE_NUM(PE_PAGE_NUM_LAYER20), .PE_ROW_NUM(PE_ROW_NUM_LAYER20),
        .PE_COL_NUM(PE_COL_NUM_LAYER20), .KERNEL_COL(KERNEL_COL_LAYER20), .KERNEL_ROW(KERNEL_ROW_LAYER20),
        .WITH_RELU(WITH_RELU_LAYER20), .MAX_POOL(MAX_POOL_LAYER20), .DATA_WIDTH(DATA_WIDTH_LAYER20),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER20), .USE_DSP_PE(USE_DSP_PE_LAYER20), .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER20),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER20), .IMG_COL(IMG_COL_LAYER20), .IMG_ROW(IMG_ROW_LAYER20),
        .STEP_COL(STEP_COL_LAYER20), .STEP_ROW(STEP_ROW_LAYER20), .SHIFT_KEY(SHIFT_KEY_LAYER20),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER20), .OUT_WIDTH(OUT_WIDTH_LAYER20), .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER20),
        .ACC_WIDTH(ACC_WIDTH_LAYER20)
    ) u_layer20 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_input_1), .data_input_valid(data_input_valid), .data_input(data_input),
        .y_out(layer_y_out_layer20), .new_line_out_1(new_line_out_1_layer20), .output_valid(out_valid_layer20)
    );

    // Layer 21
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER21), .PE_PAGE_NUM(PE_PAGE_NUM_LAYER21), .PE_ROW_NUM(PE_ROW_NUM_LAYER21),
        .PE_COL_NUM(PE_COL_NUM_LAYER21), .KERNEL_COL(KERNEL_COL_LAYER21), .KERNEL_ROW(KERNEL_ROW_LAYER21),
        .WITH_RELU(WITH_RELU_LAYER21), .MAX_POOL(MAX_POOL_LAYER21), .DATA_WIDTH(DATA_WIDTH_LAYER21),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER21), .USE_DSP_PE(USE_DSP_PE_LAYER21), .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER21),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER21), .IMG_COL(IMG_COL_LAYER21), .IMG_ROW(IMG_ROW_LAYER21),
        .STEP_COL(STEP_COL_LAYER21), .STEP_ROW(STEP_ROW_LAYER21), .SHIFT_KEY(SHIFT_KEY_LAYER21),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER21), .OUT_WIDTH(OUT_WIDTH_LAYER21), .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER21),
        .ACC_WIDTH(ACC_WIDTH_LAYER21)
    ) u_layer21 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer20), .data_input_valid(out_valid_layer20), .data_input(layer_y_out_layer20),
        .y_out(layer_y_out_layer21), .new_line_out_1(new_line_out_1_layer21), .output_valid(out_valid_layer21)
    );

    // Layer 22
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER22), .PE_PAGE_NUM(PE_PAGE_NUM_LAYER22), .PE_ROW_NUM(PE_ROW_NUM_LAYER22),
        .PE_COL_NUM(PE_COL_NUM_LAYER22), .KERNEL_COL(KERNEL_COL_LAYER22), .KERNEL_ROW(KERNEL_ROW_LAYER22),
        .WITH_RELU(WITH_RELU_LAYER22), .MAX_POOL(MAX_POOL_LAYER22), .DATA_WIDTH(DATA_WIDTH_LAYER22),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER22), .USE_DSP_PE(USE_DSP_PE_LAYER22), .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER22),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER22), .IMG_COL(IMG_COL_LAYER22), .IMG_ROW(IMG_ROW_LAYER22),
        .STEP_COL(STEP_COL_LAYER22), .STEP_ROW(STEP_ROW_LAYER22), .SHIFT_KEY(SHIFT_KEY_LAYER22),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER22), .OUT_WIDTH(OUT_WIDTH_LAYER22), .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER22),
        .ACC_WIDTH(ACC_WIDTH_LAYER22)
    ) u_layer22 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer21), .data_input_valid(out_valid_layer21), .data_input(layer_y_out_layer21),
        .y_out(layer_y_out_layer22), .new_line_out_1(new_line_out_1_layer22), .output_valid(out_valid_layer22)
    );

    // Layer 23
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER23), .PE_PAGE_NUM(PE_PAGE_NUM_LAYER23), .PE_ROW_NUM(PE_ROW_NUM_LAYER23),
        .PE_COL_NUM(PE_COL_NUM_LAYER23), .KERNEL_COL(KERNEL_COL_LAYER23), .KERNEL_ROW(KERNEL_ROW_LAYER23),
        .WITH_RELU(WITH_RELU_LAYER23), .MAX_POOL(MAX_POOL_LAYER23), .DATA_WIDTH(DATA_WIDTH_LAYER23),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER23), .USE_DSP_PE(USE_DSP_PE_LAYER23), .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER23),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER23), .IMG_COL(IMG_COL_LAYER23), .IMG_ROW(IMG_ROW_LAYER23),
        .STEP_COL(STEP_COL_LAYER23), .STEP_ROW(STEP_ROW_LAYER23), .SHIFT_KEY(SHIFT_KEY_LAYER23),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER23), .OUT_WIDTH(OUT_WIDTH_LAYER23), .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER23),
        .ACC_WIDTH(ACC_WIDTH_LAYER23)
    ) u_layer23 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer22), .data_input_valid(out_valid_layer22), .data_input(layer_y_out_layer22),
        .y_out(layer_y_out_layer23), .new_line_out_1(new_line_out_1_layer23), .output_valid(out_valid_layer23)
    );

    // Layer 24
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER24), .PE_PAGE_NUM(PE_PAGE_NUM_LAYER24), .PE_ROW_NUM(PE_ROW_NUM_LAYER24),
        .PE_COL_NUM(PE_COL_NUM_LAYER24), .KERNEL_COL(KERNEL_COL_LAYER24), .KERNEL_ROW(KERNEL_ROW_LAYER24),
        .WITH_RELU(WITH_RELU_LAYER24), .MAX_POOL(MAX_POOL_LAYER24), .DATA_WIDTH(DATA_WIDTH_LAYER24),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER24), .USE_DSP_PE(USE_DSP_PE_LAYER24), .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER24),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER24), .IMG_COL(IMG_COL_LAYER24), .IMG_ROW(IMG_ROW_LAYER24),
        .STEP_COL(STEP_COL_LAYER24), .STEP_ROW(STEP_ROW_LAYER24), .SHIFT_KEY(SHIFT_KEY_LAYER24),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER24), .OUT_WIDTH(OUT_WIDTH_LAYER24), .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER24),
        .ACC_WIDTH(ACC_WIDTH_LAYER24)
    ) u_layer24 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer23), .data_input_valid(out_valid_layer23), .data_input(layer_y_out_layer23),
        .y_out(layer_y_out_layer24), .new_line_out_1(new_line_out_1_layer24), .output_valid(out_valid_layer24)
    );

    // Layer 25
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER25), .PE_PAGE_NUM(PE_PAGE_NUM_LAYER25), .PE_ROW_NUM(PE_ROW_NUM_LAYER25),
        .PE_COL_NUM(PE_COL_NUM_LAYER25), .KERNEL_COL(KERNEL_COL_LAYER25), .KERNEL_ROW(KERNEL_ROW_LAYER25),
        .WITH_RELU(WITH_RELU_LAYER25), .MAX_POOL(MAX_POOL_LAYER25), .DATA_WIDTH(DATA_WIDTH_LAYER25),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER25), .USE_DSP_PE(USE_DSP_PE_LAYER25), .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER25),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER25), .IMG_COL(IMG_COL_LAYER25), .IMG_ROW(IMG_ROW_LAYER25),
        .STEP_COL(STEP_COL_LAYER25), .STEP_ROW(STEP_ROW_LAYER25), .SHIFT_KEY(SHIFT_KEY_LAYER25),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER25), .OUT_WIDTH(OUT_WIDTH_LAYER25), .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER25),
        .ACC_WIDTH(ACC_WIDTH_LAYER25)
    ) u_layer25 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer24), .data_input_valid(out_valid_layer24), .data_input(layer_y_out_layer24),
        .y_out(layer_y_out_layer25), .new_line_out_1(new_line_out_1_layer25), .output_valid(out_valid_layer25)
    );

    // Layer 26
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER26), .PE_PAGE_NUM(PE_PAGE_NUM_LAYER26), .PE_ROW_NUM(PE_ROW_NUM_LAYER26),
        .PE_COL_NUM(PE_COL_NUM_LAYER26), .KERNEL_COL(KERNEL_COL_LAYER26), .KERNEL_ROW(KERNEL_ROW_LAYER26),
        .WITH_RELU(WITH_RELU_LAYER26), .MAX_POOL(MAX_POOL_LAYER26), .DATA_WIDTH(DATA_WIDTH_LAYER26),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER26), .USE_DSP_PE(USE_DSP_PE_LAYER26), .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER26),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER26), .IMG_COL(IMG_COL_LAYER26), .IMG_ROW(IMG_ROW_LAYER26),
        .STEP_COL(STEP_COL_LAYER26), .STEP_ROW(STEP_ROW_LAYER26), .SHIFT_KEY(SHIFT_KEY_LAYER26),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER26), .OUT_WIDTH(OUT_WIDTH_LAYER26), .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER26),
        .ACC_WIDTH(ACC_WIDTH_LAYER26)
    ) u_layer26 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer25), .data_input_valid(out_valid_layer25), .data_input(layer_y_out_layer25),
        .y_out(layer_y_out_layer26), .new_line_out_1(new_line_out_1_layer26), .output_valid(out_valid_layer26)
    );

    // Layer 27
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER27), .PE_PAGE_NUM(PE_PAGE_NUM_LAYER27), .PE_ROW_NUM(PE_ROW_NUM_LAYER27),
        .PE_COL_NUM(PE_COL_NUM_LAYER27), .KERNEL_COL(KERNEL_COL_LAYER27), .KERNEL_ROW(KERNEL_ROW_LAYER27),
        .WITH_RELU(WITH_RELU_LAYER27), .MAX_POOL(MAX_POOL_LAYER27), .DATA_WIDTH(DATA_WIDTH_LAYER27),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER27), .USE_DSP_PE(USE_DSP_PE_LAYER27), .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER27),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER27), .IMG_COL(IMG_COL_LAYER27), .IMG_ROW(IMG_ROW_LAYER27),
        .STEP_COL(STEP_COL_LAYER27), .STEP_ROW(STEP_ROW_LAYER27), .SHIFT_KEY(SHIFT_KEY_LAYER27),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER27), .OUT_WIDTH(OUT_WIDTH_LAYER27), .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER27),
        .ACC_WIDTH(ACC_WIDTH_LAYER27)
    ) u_layer27 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer26), .data_input_valid(out_valid_layer26), .data_input(layer_y_out_layer26),
        .y_out(layer_y_out_layer27), .new_line_out_1(new_line_out_1_layer27), .output_valid(out_valid_layer27)
    );

    // Layer 28
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER28), .PE_PAGE_NUM(PE_PAGE_NUM_LAYER28), .PE_ROW_NUM(PE_ROW_NUM_LAYER28),
        .PE_COL_NUM(PE_COL_NUM_LAYER28), .KERNEL_COL(KERNEL_COL_LAYER28), .KERNEL_ROW(KERNEL_ROW_LAYER28),
        .WITH_RELU(WITH_RELU_LAYER28), .MAX_POOL(MAX_POOL_LAYER28), .DATA_WIDTH(DATA_WIDTH_LAYER28),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER28), .USE_DSP_PE(USE_DSP_PE_LAYER28), .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER28),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER28), .IMG_COL(IMG_COL_LAYER28), .IMG_ROW(IMG_ROW_LAYER28),
        .STEP_COL(STEP_COL_LAYER28), .STEP_ROW(STEP_ROW_LAYER28), .SHIFT_KEY(SHIFT_KEY_LAYER28),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER28), .OUT_WIDTH(OUT_WIDTH_LAYER28), .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER28),
        .ACC_WIDTH(ACC_WIDTH_LAYER28)
    ) u_layer28 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer27), .data_input_valid(out_valid_layer27), .data_input(layer_y_out_layer27),
        .y_out(layer_y_out_layer28), .new_line_out_1(new_line_out_1_layer28), .output_valid(out_valid_layer28)
    );

    // LPRNet Post Process (CTC Decoder)
    lprnet_post_process #(
        .PE_COL_NUM(PE_COL_NUM_LAYER28),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER28),
        .IMG_COL(IMG_COL_LAYER28),
        .IMG_ROW(IMG_ROW_LAYER28),
        .DATA_WIDTH(OUT_WIDTH_LAYER28), 
        .ACC_WIDTH(OUT_WIDTH_LAYER28 + $clog2(IMG_ROW_LAYER28)), 
        .CONV_POSITIVE(CONV_POSITIVE),
        .BLANK_CHAR(BLANK_CHAR)
    ) u_post_process (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(rst_n),
        
        .new_line_input_1(new_line_out_1_layer28),
        .data_input_valid(out_valid_layer28),
        .data_input(layer28_y_out_signed),   // 接入经过 $signed() 转换的数据
        
        .out_char(out_char),
        .out_valid(out_valid),
        .frame_start_out(frame_start_out)
    );

endmodule