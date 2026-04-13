// =========================================================
// 头文件 Include
// =========================================================
`include "data_process/header/layer0.vh"
`include "data_process/header/layer1.vh"
`include "data_process/header/layer2.vh"
`include "data_process/header/layer3.vh"
`include "data_process/header/layer4.vh"
`include "data_process/header/layer5.vh"
`include "data_process/header/layer6.vh"
`include "data_process/header/layer7.vh"
`include "data_process/header/layer8.vh"
`include "data_process/header/layer9.vh"
`include "data_process/header/layer10.vh"
// `include "data_process/header/layer11.vh" // 第11层已被移除，注释掉头文件

module top_yolo #(
    // --- Post Process (原 Layer 11, 现接 Layer 10) 参数 ---
    parameter LUT_FILE      = "sigmoid_lut_9bit_to_8bit_h.mem",
    parameter bit    CONV_POSITIVE = 1,
    parameter int    CONF_WIDTH    = 8,
    parameter int    CONF_THRESH   = 50
) (
    // ---------------- 全局控制信号 ----------------
    input  logic                                                clk,
    input  logic                                                clk_en,
    input  logic                                                rst_n,

    // ---------------- 输入接口 (To Layer 0) ----------------
    input  logic                                                new_line_input_1,
    input  logic                                                data_input_valid,
    // 压缩数组形式
    input  logic [PE_PAGE_NUM_LAYER0-1:0][DATA_WIDTH_LAYER0-1:0] data_input,

    // ---------------- 输出接口 1 (Layer 7 原始特征图) ----------------
    // 压缩数组形式
    output logic [PE_COL_NUM_LAYER7-1:0][OUT_WIDTH_LAYER7-1:0]  layer_y_out_layer7,
    output logic                                                out_valid_layer7,
    output logic                                                new_line_out_1_layer7,

    // ---------------- 输出接口 2 (Layer 10 经后处理打包输出) ----------------
    output logic [31:0]                                         post_packet_data,
    output logic                                                post_packet_valid,
    output logic                                                post_frame_done
);
    // =========================================================
    // 各层连线定义
    // =========================================================
    // Layer 0 -> Layer 1
    logic [PE_COL_NUM_LAYER0-1:0][OUT_WIDTH_LAYER0-1:0] layer_y_out_layer0;
    logic out_valid_layer0;
    logic new_line_out_1_layer0;

    // Layer 1 -> Layer 2
    logic [PE_COL_NUM_LAYER1-1:0][OUT_WIDTH_LAYER1-1:0] layer_y_out_layer1;
    logic out_valid_layer1;
    logic new_line_out_1_layer1;

    // Layer 2 -> Layer 3
    logic [PE_COL_NUM_LAYER2-1:0][OUT_WIDTH_LAYER2-1:0] layer_y_out_layer2;
    logic out_valid_layer2;
    logic new_line_out_1_layer2;

    // Layer 3 -> Layer 4
    logic [PE_COL_NUM_LAYER3-1:0][OUT_WIDTH_LAYER3-1:0] layer_y_out_layer3;
    logic out_valid_layer3;
    logic new_line_out_1_layer3;

    // Layer 4 -> Layer 5 & Layer 8
    logic [PE_COL_NUM_LAYER4-1:0][OUT_WIDTH_LAYER4-1:0] layer_y_out_layer4;
    logic out_valid_layer4;
    logic new_line_out_1_layer4;

    // Layer 5 -> Layer 6
    logic [PE_COL_NUM_LAYER5-1:0][OUT_WIDTH_LAYER5-1:0] layer_y_out_layer5;
    logic out_valid_layer5;
    logic new_line_out_1_layer5;

    // Layer 6 -> Layer 7
    logic [PE_COL_NUM_LAYER6-1:0][OUT_WIDTH_LAYER6-1:0] layer_y_out_layer6;
    logic out_valid_layer6;
    logic new_line_out_1_layer6;

    // Layer 7 -> Adapter (在模块输出端口中已定义 Layer 7 信号)
    
    // Layer 8 -> Layer 9
    logic [PE_COL_NUM_LAYER8-1:0][OUT_WIDTH_LAYER8-1:0] layer_y_out_layer8;
    logic out_valid_layer8;
    logic new_line_out_1_layer8;
    
    // Layer 9 -> Layer 10
    logic [PE_COL_NUM_LAYER9-1:0][OUT_WIDTH_LAYER9-1:0] layer_y_out_layer9;
    logic out_valid_layer9;
    logic new_line_out_1_layer9;

    // Layer 10 -> Cv3 conv2d Post Process
    logic [PE_COL_NUM_LAYER10-1:0][OUT_WIDTH_LAYER10-1:0] layer_y_out_layer10;
    logic out_valid_layer10;
    logic new_line_out_1_layer10;


// =========================================================
// CNN 层级例化
// =========================================================
    // Layer 0
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER0),
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER0),
        .PE_ROW_NUM(PE_ROW_NUM_LAYER0),
        .PE_COL_NUM(PE_COL_NUM_LAYER0),
        .KERNEL_COL(KERNEL_COL_LAYER0),
        .KERNEL_ROW(KERNEL_ROW_LAYER0),
        .WITH_RELU(WITH_RELU_LAYER0),
        .MAX_POOL(MAX_POOL_LAYER0),
        .DATA_WIDTH(DATA_WIDTH_LAYER0),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER0),
        .USE_DSP_PE(USE_DSP_PE_LAYER0),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER0),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER0),
        .IMG_COL(IMG_COL_LAYER0),
        .IMG_ROW(IMG_ROW_LAYER0),
        .STEP_COL(STEP_COL_LAYER0),
        .STEP_ROW(STEP_ROW_LAYER0),
        .SHIFT_KEY(SHIFT_KEY_LAYER0),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER0),
        .OUT_WIDTH(OUT_WIDTH_LAYER0),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER0),
        .ACC_WIDTH(ACC_WIDTH_LAYER0)
    ) u_layer0 (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(rst_n),
        .new_line_input_1(new_line_input_1),
        .data_input_valid(data_input_valid),
        .data_input(data_input),
        .y_out(layer_y_out_layer0),
        .new_line_out_1(new_line_out_1_layer0),
        .output_valid(out_valid_layer0)
    );

    // Layer 1
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER1),
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER1),
        .PE_ROW_NUM(PE_ROW_NUM_LAYER1),
        .PE_COL_NUM(PE_COL_NUM_LAYER1),
        .KERNEL_COL(KERNEL_COL_LAYER1),
        .KERNEL_ROW(KERNEL_ROW_LAYER1),
        .WITH_RELU(WITH_RELU_LAYER1),
        .MAX_POOL(MAX_POOL_LAYER1),
        .DATA_WIDTH(DATA_WIDTH_LAYER1),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER1),
        .USE_DSP_PE(USE_DSP_PE_LAYER1),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER1),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER1),
        .IMG_COL(IMG_COL_LAYER1),
        .IMG_ROW(IMG_ROW_LAYER1),
        .STEP_COL(STEP_COL_LAYER1),
        .STEP_ROW(STEP_ROW_LAYER1),
        .SHIFT_KEY(SHIFT_KEY_LAYER1),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER1),
        .OUT_WIDTH(OUT_WIDTH_LAYER1),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER1),
        .ACC_WIDTH(ACC_WIDTH_LAYER1)
    ) u_layer1 (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer0),
        .data_input_valid(out_valid_layer0),
        .data_input(layer_y_out_layer0),
        .y_out(layer_y_out_layer1),
        .new_line_out_1(new_line_out_1_layer1),
        .output_valid(out_valid_layer1)
    );

    // Layer 2
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER2),
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER2),
        .PE_ROW_NUM(PE_ROW_NUM_LAYER2),
        .PE_COL_NUM(PE_COL_NUM_LAYER2),
        .KERNEL_COL(KERNEL_COL_LAYER2),
        .KERNEL_ROW(KERNEL_ROW_LAYER2),
        .WITH_RELU(WITH_RELU_LAYER2),
        .MAX_POOL(MAX_POOL_LAYER2),
        .DATA_WIDTH(DATA_WIDTH_LAYER2),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER2),
        .USE_DSP_PE(USE_DSP_PE_LAYER2),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER2),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER2),
        .IMG_COL(IMG_COL_LAYER2),
        .IMG_ROW(IMG_ROW_LAYER2),
        .STEP_COL(STEP_COL_LAYER2),
        .STEP_ROW(STEP_ROW_LAYER2),
        .SHIFT_KEY(SHIFT_KEY_LAYER2),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER2),
        .OUT_WIDTH(OUT_WIDTH_LAYER2),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER2),
        .ACC_WIDTH(ACC_WIDTH_LAYER2)
    ) u_layer2 (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer1),
        .data_input_valid(out_valid_layer1),
        .data_input(layer_y_out_layer1),
        .y_out(layer_y_out_layer2),
        .new_line_out_1(new_line_out_1_layer2),
        .output_valid(out_valid_layer2)
    );

    // Layer 3
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER3),
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER3),
        .PE_ROW_NUM(PE_ROW_NUM_LAYER3),
        .PE_COL_NUM(PE_COL_NUM_LAYER3),
        .KERNEL_COL(KERNEL_COL_LAYER3),
        .KERNEL_ROW(KERNEL_ROW_LAYER3),
        .WITH_RELU(WITH_RELU_LAYER3),
        .MAX_POOL(MAX_POOL_LAYER3),
        .DATA_WIDTH(DATA_WIDTH_LAYER3),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER3),
        .USE_DSP_PE(USE_DSP_PE_LAYER3),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER3),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER3),
        .IMG_COL(IMG_COL_LAYER3),
        .IMG_ROW(IMG_ROW_LAYER3),
        .STEP_COL(STEP_COL_LAYER3),
        .STEP_ROW(STEP_ROW_LAYER3),
        .SHIFT_KEY(SHIFT_KEY_LAYER3),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER3),
        .OUT_WIDTH(OUT_WIDTH_LAYER3),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER3),
        .ACC_WIDTH(ACC_WIDTH_LAYER3)
    ) u_layer3 (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer2),
        .data_input_valid(out_valid_layer2),
        .data_input(layer_y_out_layer2),
        .y_out(layer_y_out_layer3),
        .new_line_out_1(new_line_out_1_layer3),
        .output_valid(out_valid_layer3)
    );

    // Layer 4
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER4),
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER4),
        .PE_ROW_NUM(PE_ROW_NUM_LAYER4),
        .PE_COL_NUM(PE_COL_NUM_LAYER4),
        .KERNEL_COL(KERNEL_COL_LAYER4),
        .KERNEL_ROW(KERNEL_ROW_LAYER4),
        .WITH_RELU(WITH_RELU_LAYER4),
        .MAX_POOL(MAX_POOL_LAYER4),
        .DATA_WIDTH(DATA_WIDTH_LAYER4),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER4),
        .USE_DSP_PE(USE_DSP_PE_LAYER4),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER4),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER4),
        .IMG_COL(IMG_COL_LAYER4),
        .IMG_ROW(IMG_ROW_LAYER4),
        .STEP_COL(STEP_COL_LAYER4),
        .STEP_ROW(STEP_ROW_LAYER4),
        .SHIFT_KEY(SHIFT_KEY_LAYER4),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER4),
        .OUT_WIDTH(OUT_WIDTH_LAYER4),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER4),
        .ACC_WIDTH(ACC_WIDTH_LAYER4)
    ) u_layer4 (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer3),
        .data_input_valid(out_valid_layer3),
        .data_input(layer_y_out_layer3),
        .y_out(layer_y_out_layer4),
        .new_line_out_1(new_line_out_1_layer4),
        .output_valid(out_valid_layer4)
    );

    // Layer 5
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER5),
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER5),
        .PE_ROW_NUM(PE_ROW_NUM_LAYER5),
        .PE_COL_NUM(PE_COL_NUM_LAYER5),
        .KERNEL_COL(KERNEL_COL_LAYER5),
        .KERNEL_ROW(KERNEL_ROW_LAYER5),
        .WITH_RELU(WITH_RELU_LAYER5),
        .MAX_POOL(MAX_POOL_LAYER5),
        .DATA_WIDTH(DATA_WIDTH_LAYER5),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER5),
        .USE_DSP_PE(USE_DSP_PE_LAYER5),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER5),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER5),
        .IMG_COL(IMG_COL_LAYER5),
        .IMG_ROW(IMG_ROW_LAYER5),
        .STEP_COL(STEP_COL_LAYER5),
        .STEP_ROW(STEP_ROW_LAYER5),
        .SHIFT_KEY(SHIFT_KEY_LAYER5),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER5),
        .OUT_WIDTH(OUT_WIDTH_LAYER5),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER5),
        .ACC_WIDTH(ACC_WIDTH_LAYER5)
    ) u_layer5 (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer4),
        .data_input_valid(out_valid_layer4),
        .data_input(layer_y_out_layer4),
        .y_out(layer_y_out_layer5),
        .new_line_out_1(new_line_out_1_layer5),
        .output_valid(out_valid_layer5)
    );

    // Layer 6
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER6),
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER6),
        .PE_ROW_NUM(PE_ROW_NUM_LAYER6),
        .PE_COL_NUM(PE_COL_NUM_LAYER6),
        .KERNEL_COL(KERNEL_COL_LAYER6),
        .KERNEL_ROW(KERNEL_ROW_LAYER6),
        .WITH_RELU(WITH_RELU_LAYER6),
        .MAX_POOL(MAX_POOL_LAYER6),
        .DATA_WIDTH(DATA_WIDTH_LAYER6),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER6),
        .USE_DSP_PE(USE_DSP_PE_LAYER6),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER6),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER6),
        .IMG_COL(IMG_COL_LAYER6),
        .IMG_ROW(IMG_ROW_LAYER6),
        .STEP_COL(STEP_COL_LAYER6),
        .STEP_ROW(STEP_ROW_LAYER6),
        .SHIFT_KEY(SHIFT_KEY_LAYER6),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER6),
        .OUT_WIDTH(OUT_WIDTH_LAYER6),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER6),
        .ACC_WIDTH(ACC_WIDTH_LAYER6)
    ) u_layer6 (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer5),
        .data_input_valid(out_valid_layer5),
        .data_input(layer_y_out_layer5),
        .y_out(layer_y_out_layer6),
        .new_line_out_1(new_line_out_1_layer6),
        .output_valid(out_valid_layer6)
    );

    // Layer 7 作为输出端口的一部分
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER7),
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER7),
        .PE_ROW_NUM(PE_ROW_NUM_LAYER7),
        .PE_COL_NUM(PE_COL_NUM_LAYER7),
        .KERNEL_COL(KERNEL_COL_LAYER7),
        .KERNEL_ROW(KERNEL_ROW_LAYER7),
        .WITH_RELU(WITH_RELU_LAYER7),
        .MAX_POOL(MAX_POOL_LAYER7),
        .DATA_WIDTH(DATA_WIDTH_LAYER7),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER7),
        .USE_DSP_PE(USE_DSP_PE_LAYER7),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER7),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER7),
        .IMG_COL(IMG_COL_LAYER7),
        .IMG_ROW(IMG_ROW_LAYER7),
        .STEP_COL(STEP_COL_LAYER7),
        .STEP_ROW(STEP_ROW_LAYER7),
        .SHIFT_KEY(SHIFT_KEY_LAYER7),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER7),
        .OUT_WIDTH(OUT_WIDTH_LAYER7),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER7),
        .ACC_WIDTH(ACC_WIDTH_LAYER7)
    ) u_layer7 (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer6),
        .data_input_valid(out_valid_layer6),
        .data_input(layer_y_out_layer6),
        
        // --- 核心修改：连接到模块的 Top 级输出接口 ---
        .y_out(layer_y_out_layer7),
        .new_line_out_1(new_line_out_1_layer7),
        .output_valid(out_valid_layer7)
    );

    // Layer 8
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER8),
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER8),
        .PE_ROW_NUM(PE_ROW_NUM_LAYER8),
        .PE_COL_NUM(PE_COL_NUM_LAYER8),
        .KERNEL_COL(KERNEL_COL_LAYER8),
        .KERNEL_ROW(KERNEL_ROW_LAYER8),
        .WITH_RELU(WITH_RELU_LAYER8),
        .MAX_POOL(MAX_POOL_LAYER8),
        .DATA_WIDTH(DATA_WIDTH_LAYER8),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER8),
        .USE_DSP_PE(USE_DSP_PE_LAYER8),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER8),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER8),
        .IMG_COL(IMG_COL_LAYER8),
        .IMG_ROW(IMG_ROW_LAYER8),
        .STEP_COL(STEP_COL_LAYER8),
        .STEP_ROW(STEP_ROW_LAYER8),
        .SHIFT_KEY(SHIFT_KEY_LAYER8),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER8),
        .OUT_WIDTH(OUT_WIDTH_LAYER8),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER8),
        .ACC_WIDTH(ACC_WIDTH_LAYER8)
    ) u_layer8 (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(rst_n),
        // 从 Layer 4 的输出端口取数据
        .new_line_input_1(new_line_out_1_layer4),
        .data_input_valid(out_valid_layer4),
        .data_input(layer_y_out_layer4),
        .y_out(layer_y_out_layer8),
        .new_line_out_1(new_line_out_1_layer8),
        .output_valid(out_valid_layer8)
    );

    // Layer 9 (路由分支，从 Layer 8 取数据)
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER9),
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER9),
        .PE_ROW_NUM(PE_ROW_NUM_LAYER9),
        .PE_COL_NUM(PE_COL_NUM_LAYER9),
        .KERNEL_COL(KERNEL_COL_LAYER9),
        .KERNEL_ROW(KERNEL_ROW_LAYER9),
        .WITH_RELU(WITH_RELU_LAYER9),
        .MAX_POOL(MAX_POOL_LAYER9),
        .DATA_WIDTH(DATA_WIDTH_LAYER9),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER9),
        .USE_DSP_PE(USE_DSP_PE_LAYER9),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER9),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER9),
        .IMG_COL(IMG_COL_LAYER9),
        .IMG_ROW(IMG_ROW_LAYER9),
        .STEP_COL(STEP_COL_LAYER9),
        .STEP_ROW(STEP_ROW_LAYER9),
        .SHIFT_KEY(SHIFT_KEY_LAYER9),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER9),
        .OUT_WIDTH(OUT_WIDTH_LAYER9),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER9),
        .ACC_WIDTH(ACC_WIDTH_LAYER9)
    ) u_layer9 (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer8),
        .data_input_valid(out_valid_layer8),
        .data_input(layer_y_out_layer8),
        
        .y_out(layer_y_out_layer9),
        .new_line_out_1(new_line_out_1_layer9),
        .output_valid(out_valid_layer9)
    );

    // Layer 10
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER10),
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER10),
        .PE_ROW_NUM(PE_ROW_NUM_LAYER10),
        .PE_COL_NUM(PE_COL_NUM_LAYER10),
        .KERNEL_COL(KERNEL_COL_LAYER10),
        .KERNEL_ROW(KERNEL_ROW_LAYER10),
        .WITH_RELU(WITH_RELU_LAYER10),
        .MAX_POOL(MAX_POOL_LAYER10),
        .DATA_WIDTH(DATA_WIDTH_LAYER10),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER10),
        .USE_DSP_PE(USE_DSP_PE_LAYER10),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER10),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER10),
        .IMG_COL(IMG_COL_LAYER10),
        .IMG_ROW(IMG_ROW_LAYER10),
        .STEP_COL(STEP_COL_LAYER10),
        .STEP_ROW(STEP_ROW_LAYER10),
        .SHIFT_KEY(SHIFT_KEY_LAYER10),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER10),
        .OUT_WIDTH(OUT_WIDTH_LAYER10),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER10),
        .ACC_WIDTH(ACC_WIDTH_LAYER10)
    ) u_layer10 (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer9),
        .data_input_valid(out_valid_layer9),
        .data_input(layer_y_out_layer9),
        .y_out(layer_y_out_layer10),
        .new_line_out_1(new_line_out_1_layer10),
        .output_valid(out_valid_layer10)
    );

    // Post Process 模块 (原连在Layer11，现改接Layer10)
    post_cv3_conv2d #(
        // --- 核心修改：所有参数替换为 Layer10 ---
        .DATA_WIDTH(OUT_WIDTH_LAYER10), 
        .OUT_WIDTH(32),                 
        .PE_COL_NUM(PE_COL_NUM_LAYER10),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER10),
        .LUT_FILE(LUT_FILE),
        .IMG_COL(IMG_COL_LAYER10),
        .IMG_ROW(IMG_ROW_LAYER10),
        .CONV_POSITIVE(CONV_POSITIVE),
        .CONF_WIDTH(CONF_WIDTH),
        .CONF_THRESH(CONF_THRESH)
    ) u_post_process (
        .clk(clk),
        .rst_n(rst_n),

        // --- 核心修改：从 Layer10 接收数据 ---
        .new_line_in_1(new_line_out_1_layer10),
        .data_input_valid(out_valid_layer10),
        .data_in(layer_y_out_layer10),

        // Output to Adapter
        .packet_data(post_packet_data),
        .packet_valid(post_packet_valid),
        .frame_done(post_frame_done)
    );
endmodule