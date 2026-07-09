// =========================================================
// LPRNet v10 top module, layer20 to layer31 plus CTC post process
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
`include "data_process/header/layer29.vh"
`include "data_process/header/layer30.vh"
`include "data_process/header/layer31.vh"

module lprnet_top #(
    parameter bit CONV_POSITIVE = 1,
    parameter int BLANK_CHAR    = 75,
    parameter int VALID_CHAR_NUM = 76,
    parameter int POST_CH_OUT_NUM = CYCLE_PERIOD_OUT_LAYER31 * PE_COL_NUM_LAYER31,
    parameter int POST_CH_WIDTH   = $clog2(POST_CH_OUT_NUM)
) (
    input  logic clk,
    input  logic clk_en,
    input  logic rst_n,

    input  logic new_line_input_1,
    input  logic data_input_valid,
    input  logic [PE_PAGE_NUM_LAYER20-1:0][DATA_WIDTH_LAYER20-1:0] data_input,

    output logic [POST_CH_WIDTH-1:0] out_char         /* synthesis syn_preserve=1 */,
    output logic                     out_valid        /* synthesis syn_preserve=1 */,
    output logic                     frame_start_out  /* synthesis syn_preserve=1 */
);

    logic [PE_COL_NUM_LAYER20-1:0][OUT_WIDTH_LAYER20-1:0] layer_y_out_layer20/*synthesis PAP_MARK_DEBUG="1"*/;
    logic out_valid_layer20 /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;
    logic new_line_out_1_layer20 /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;

    logic [PE_COL_NUM_LAYER21-1:0][OUT_WIDTH_LAYER21-1:0] layer_y_out_layer21/*synthesis PAP_MARK_DEBUG="1"*/;
    logic out_valid_layer21 /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;
    logic new_line_out_1_layer21 /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;

    logic [PE_COL_NUM_LAYER22-1:0][OUT_WIDTH_LAYER22-1:0] layer_y_out_layer22/*synthesis PAP_MARK_DEBUG="1"*/;
    logic out_valid_layer22 /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;
    logic new_line_out_1_layer22 /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;

    logic [PE_COL_NUM_LAYER23-1:0][OUT_WIDTH_LAYER23-1:0] layer_y_out_layer23/*synthesis PAP_MARK_DEBUG="1"*/;
    logic out_valid_layer23 /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;
    logic new_line_out_1_layer23 /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;

    logic [PE_COL_NUM_LAYER24-1:0][OUT_WIDTH_LAYER24-1:0] layer_y_out_layer24/*synthesis PAP_MARK_DEBUG="1"*/;
    logic out_valid_layer24 /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;
    logic new_line_out_1_layer24 /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;

    logic [PE_COL_NUM_LAYER25-1:0][OUT_WIDTH_LAYER25-1:0] layer_y_out_layer25/*synthesis PAP_MARK_DEBUG="1"*/;
    logic out_valid_layer25 /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;
    logic new_line_out_1_layer25 /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;

    logic [PE_COL_NUM_LAYER26-1:0][OUT_WIDTH_LAYER26-1:0] layer_y_out_layer26/*synthesis PAP_MARK_DEBUG="1"*/;
    logic out_valid_layer26 /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;
    logic new_line_out_1_layer26 /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;

    logic [PE_COL_NUM_LAYER27-1:0][OUT_WIDTH_LAYER27-1:0] layer_y_out_layer27/*synthesis PAP_MARK_DEBUG="1"*/;
    logic out_valid_layer27 /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;
    logic new_line_out_1_layer27 /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;

    logic [PE_COL_NUM_LAYER28-1:0][OUT_WIDTH_LAYER28-1:0] layer_y_out_layer28/*synthesis PAP_MARK_DEBUG="1"*/;
    logic out_valid_layer28 /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;
    logic new_line_out_1_layer28 /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;

    logic [PE_COL_NUM_LAYER29-1:0][OUT_WIDTH_LAYER29-1:0] layer_y_out_layer29/*synthesis PAP_MARK_DEBUG="1"*/;
    logic out_valid_layer29 /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;
    logic new_line_out_1_layer29 /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;

    logic [PE_COL_NUM_LAYER30-1:0][OUT_WIDTH_LAYER30-1:0] layer_y_out_layer30/*synthesis PAP_MARK_DEBUG="1"*/;
    logic out_valid_layer30 /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;
    logic new_line_out_1_layer30 /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;

    logic [PE_COL_NUM_LAYER31-1:0][OUT_WIDTH_LAYER31-1:0] layer_y_out_layer31 /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;
    logic out_valid_layer31 /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;
    logic new_line_out_1_layer31 /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;

    logic [11:0] dbg_new_line_seen /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;
    logic [11:0] dbg_out_valid_seen /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;
    logic        dbg_input_new_line_seen /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;
    logic        dbg_input_valid_seen /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;
    logic        dbg_post_frame_seen /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;
    logic        dbg_post_char_seen /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;

    logic signed [PE_COL_NUM_LAYER31-1:0][OUT_WIDTH_LAYER31-1:0] layer31_y_out_signed /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;
    int idc;
    always_comb begin
        for (idc = 0; idc < PE_COL_NUM_LAYER31; idc = idc + 1) begin
            layer31_y_out_signed[idc] = $signed(layer_y_out_layer31[idc]);
        end
    end

    lprnet_layer_direct #(
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER20), .PE_ROW_NUM(PE_ROW_NUM_LAYER20),
        .PE_COL_NUM(PE_COL_NUM_LAYER20), .KERNEL_COL(KERNEL_COL_LAYER20), .KERNEL_ROW(KERNEL_ROW_LAYER20),
        .WITH_RELU(WITH_RELU_LAYER20), .MAX_POOL(MAX_POOL_LAYER20), .DATA_WIDTH(DATA_WIDTH_LAYER20),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER20), .USE_DSP_PE(USE_DSP_PE_LAYER20),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER20), .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER20),
        .IMG_COL(IMG_COL_LAYER20), .IMG_ROW(IMG_ROW_LAYER20), .STEP_COL(STEP_COL_LAYER20), .STEP_ROW(STEP_ROW_LAYER20),
        .SHIFT_KEY(SHIFT_KEY_LAYER20), .BIAS_WIDTH(BIAS_WIDTH_LAYER20), .OUT_WIDTH(OUT_WIDTH_LAYER20),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER20), .ACC_WIDTH(ACC_WIDTH_LAYER20),
        .WEIGHT_FILE0("mem_data/weight_layer20_page0.mem"), .WEIGHT_FILE1("mem_data/weight_layer20_page1.mem"),
        .WEIGHT_FILE2("mem_data/weight_layer20_page2.mem"), .WEIGHT_FILE3("mem_data/weight_layer20_page3.mem"),
        .BIAS_FILE("mem_data/bias_layer20.mem")
    ) u_layer20 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_input_1), .data_input_valid(data_input_valid), .data_input(data_input),
        .y_out(layer_y_out_layer20), .new_line_out_1(new_line_out_1_layer20), .output_valid(out_valid_layer20)
    );

    lprnet_layer_direct #(
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER21), .PE_ROW_NUM(PE_ROW_NUM_LAYER21),
        .PE_COL_NUM(PE_COL_NUM_LAYER21), .KERNEL_COL(KERNEL_COL_LAYER21), .KERNEL_ROW(KERNEL_ROW_LAYER21),
        .WITH_RELU(WITH_RELU_LAYER21), .MAX_POOL(MAX_POOL_LAYER21), .DATA_WIDTH(DATA_WIDTH_LAYER21),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER21), .USE_DSP_PE(USE_DSP_PE_LAYER21),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER21), .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER21),
        .IMG_COL(IMG_COL_LAYER21), .IMG_ROW(IMG_ROW_LAYER21), .STEP_COL(STEP_COL_LAYER21), .STEP_ROW(STEP_ROW_LAYER21),
        .SHIFT_KEY(SHIFT_KEY_LAYER21), .BIAS_WIDTH(BIAS_WIDTH_LAYER21), .OUT_WIDTH(OUT_WIDTH_LAYER21),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER21), .ACC_WIDTH(ACC_WIDTH_LAYER21),
        .WEIGHT_FILE0("mem_data/weight_layer21_page0.mem"), .WEIGHT_FILE1("mem_data/weight_layer21_page1.mem"),
        .WEIGHT_FILE2("mem_data/weight_layer21_page2.mem"), .WEIGHT_FILE3("mem_data/weight_layer21_page3.mem"),
        .BIAS_FILE("mem_data/bias_layer21.mem")
    ) u_layer21 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer20), .data_input_valid(out_valid_layer20), .data_input(layer_y_out_layer20),
        .y_out(layer_y_out_layer21), .new_line_out_1(new_line_out_1_layer21), .output_valid(out_valid_layer21)
    );

    lprnet_layer_direct #(
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER22), .PE_ROW_NUM(PE_ROW_NUM_LAYER22),
        .PE_COL_NUM(PE_COL_NUM_LAYER22), .KERNEL_COL(KERNEL_COL_LAYER22), .KERNEL_ROW(KERNEL_ROW_LAYER22),
        .WITH_RELU(WITH_RELU_LAYER22), .MAX_POOL(MAX_POOL_LAYER22), .DATA_WIDTH(DATA_WIDTH_LAYER22),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER22), .USE_DSP_PE(USE_DSP_PE_LAYER22),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER22), .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER22),
        .IMG_COL(IMG_COL_LAYER22), .IMG_ROW(IMG_ROW_LAYER22), .STEP_COL(STEP_COL_LAYER22), .STEP_ROW(STEP_ROW_LAYER22),
        .SHIFT_KEY(SHIFT_KEY_LAYER22), .BIAS_WIDTH(BIAS_WIDTH_LAYER22), .OUT_WIDTH(OUT_WIDTH_LAYER22),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER22), .ACC_WIDTH(ACC_WIDTH_LAYER22),
        .WEIGHT_FILE0("mem_data/weight_layer22_page0.mem"), .WEIGHT_FILE1("mem_data/weight_layer22_page1.mem"),
        .WEIGHT_FILE2("mem_data/weight_layer22_page2.mem"), .WEIGHT_FILE3("mem_data/weight_layer22_page3.mem"),
        .BIAS_FILE("mem_data/bias_layer22.mem")
    ) u_layer22 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer21), .data_input_valid(out_valid_layer21), .data_input(layer_y_out_layer21),
        .y_out(layer_y_out_layer22), .new_line_out_1(new_line_out_1_layer22), .output_valid(out_valid_layer22)
    );

    lprnet_layer_direct #(
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER23), .PE_ROW_NUM(PE_ROW_NUM_LAYER23),
        .PE_COL_NUM(PE_COL_NUM_LAYER23), .KERNEL_COL(KERNEL_COL_LAYER23), .KERNEL_ROW(KERNEL_ROW_LAYER23),
        .WITH_RELU(WITH_RELU_LAYER23), .MAX_POOL(MAX_POOL_LAYER23), .DATA_WIDTH(DATA_WIDTH_LAYER23),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER23), .USE_DSP_PE(USE_DSP_PE_LAYER23),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER23), .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER23),
        .IMG_COL(IMG_COL_LAYER23), .IMG_ROW(IMG_ROW_LAYER23), .STEP_COL(STEP_COL_LAYER23), .STEP_ROW(STEP_ROW_LAYER23),
        .SHIFT_KEY(SHIFT_KEY_LAYER23), .BIAS_WIDTH(BIAS_WIDTH_LAYER23), .OUT_WIDTH(OUT_WIDTH_LAYER23),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER23), .ACC_WIDTH(ACC_WIDTH_LAYER23),
        .WEIGHT_FILE0("mem_data/weight_layer23_page0.mem"), .WEIGHT_FILE1("mem_data/weight_layer23_page1.mem"),
        .WEIGHT_FILE2("mem_data/weight_layer23_page2.mem"), .WEIGHT_FILE3("mem_data/weight_layer23_page3.mem"),
        .BIAS_FILE("mem_data/bias_layer23.mem")
    ) u_layer23 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer22), .data_input_valid(out_valid_layer22), .data_input(layer_y_out_layer22),
        .y_out(layer_y_out_layer23), .new_line_out_1(new_line_out_1_layer23), .output_valid(out_valid_layer23)
    );

    lprnet_layer_direct #(
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER24), .PE_ROW_NUM(PE_ROW_NUM_LAYER24),
        .PE_COL_NUM(PE_COL_NUM_LAYER24), .KERNEL_COL(KERNEL_COL_LAYER24), .KERNEL_ROW(KERNEL_ROW_LAYER24),
        .WITH_RELU(WITH_RELU_LAYER24), .MAX_POOL(MAX_POOL_LAYER24), .DATA_WIDTH(DATA_WIDTH_LAYER24),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER24), .USE_DSP_PE(USE_DSP_PE_LAYER24),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER24), .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER24),
        .IMG_COL(IMG_COL_LAYER24), .IMG_ROW(IMG_ROW_LAYER24), .STEP_COL(STEP_COL_LAYER24), .STEP_ROW(STEP_ROW_LAYER24),
        .SHIFT_KEY(SHIFT_KEY_LAYER24), .BIAS_WIDTH(BIAS_WIDTH_LAYER24), .OUT_WIDTH(OUT_WIDTH_LAYER24),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER24), .ACC_WIDTH(ACC_WIDTH_LAYER24),
        .WEIGHT_FILE0("mem_data/weight_layer24_page0.mem"), .WEIGHT_FILE1("mem_data/weight_layer24_page1.mem"),
        .WEIGHT_FILE2("mem_data/weight_layer24_page2.mem"), .WEIGHT_FILE3("mem_data/weight_layer24_page3.mem"),
        .BIAS_FILE("mem_data/bias_layer24.mem")
    ) u_layer24 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer23), .data_input_valid(out_valid_layer23), .data_input(layer_y_out_layer23),
        .y_out(layer_y_out_layer24), .new_line_out_1(new_line_out_1_layer24), .output_valid(out_valid_layer24)
    );

    lprnet_layer_direct #(
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER25), .PE_ROW_NUM(PE_ROW_NUM_LAYER25),
        .PE_COL_NUM(PE_COL_NUM_LAYER25), .KERNEL_COL(KERNEL_COL_LAYER25), .KERNEL_ROW(KERNEL_ROW_LAYER25),
        .WITH_RELU(WITH_RELU_LAYER25), .MAX_POOL(MAX_POOL_LAYER25), .DATA_WIDTH(DATA_WIDTH_LAYER25),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER25), .USE_DSP_PE(USE_DSP_PE_LAYER25),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER25), .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER25),
        .IMG_COL(IMG_COL_LAYER25), .IMG_ROW(IMG_ROW_LAYER25), .STEP_COL(STEP_COL_LAYER25), .STEP_ROW(STEP_ROW_LAYER25),
        .SHIFT_KEY(SHIFT_KEY_LAYER25), .BIAS_WIDTH(BIAS_WIDTH_LAYER25), .OUT_WIDTH(OUT_WIDTH_LAYER25),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER25), .ACC_WIDTH(ACC_WIDTH_LAYER25),
        .WEIGHT_FILE0("mem_data/weight_layer25_page0.mem"), .WEIGHT_FILE1("mem_data/weight_layer25_page1.mem"),
        .WEIGHT_FILE2("mem_data/weight_layer25_page2.mem"), .WEIGHT_FILE3("mem_data/weight_layer25_page3.mem"),
        .BIAS_FILE("mem_data/bias_layer25.mem")
    ) u_layer25 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer24), .data_input_valid(out_valid_layer24), .data_input(layer_y_out_layer24),
        .y_out(layer_y_out_layer25), .new_line_out_1(new_line_out_1_layer25), .output_valid(out_valid_layer25)
    );

    lprnet_layer_direct #(
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER26), .PE_ROW_NUM(PE_ROW_NUM_LAYER26),
        .PE_COL_NUM(PE_COL_NUM_LAYER26), .KERNEL_COL(KERNEL_COL_LAYER26), .KERNEL_ROW(KERNEL_ROW_LAYER26),
        .WITH_RELU(WITH_RELU_LAYER26), .MAX_POOL(MAX_POOL_LAYER26), .DATA_WIDTH(DATA_WIDTH_LAYER26),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER26), .USE_DSP_PE(USE_DSP_PE_LAYER26),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER26), .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER26),
        .IMG_COL(IMG_COL_LAYER26), .IMG_ROW(IMG_ROW_LAYER26), .STEP_COL(STEP_COL_LAYER26), .STEP_ROW(STEP_ROW_LAYER26),
        .SHIFT_KEY(SHIFT_KEY_LAYER26), .BIAS_WIDTH(BIAS_WIDTH_LAYER26), .OUT_WIDTH(OUT_WIDTH_LAYER26),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER26), .ACC_WIDTH(ACC_WIDTH_LAYER26),
        .WEIGHT_FILE0("mem_data/weight_layer26_page0.mem"), .WEIGHT_FILE1("mem_data/weight_layer26_page1.mem"),
        .WEIGHT_FILE2("mem_data/weight_layer26_page2.mem"), .WEIGHT_FILE3("mem_data/weight_layer26_page3.mem"),
        .BIAS_FILE("mem_data/bias_layer26.mem")
    ) u_layer26 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer25), .data_input_valid(out_valid_layer25), .data_input(layer_y_out_layer25),
        .y_out(layer_y_out_layer26), .new_line_out_1(new_line_out_1_layer26), .output_valid(out_valid_layer26)
    );

    lprnet_layer_direct #(
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER27), .PE_ROW_NUM(PE_ROW_NUM_LAYER27),
        .PE_COL_NUM(PE_COL_NUM_LAYER27), .KERNEL_COL(KERNEL_COL_LAYER27), .KERNEL_ROW(KERNEL_ROW_LAYER27),
        .WITH_RELU(WITH_RELU_LAYER27), .MAX_POOL(MAX_POOL_LAYER27), .DATA_WIDTH(DATA_WIDTH_LAYER27),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER27), .USE_DSP_PE(USE_DSP_PE_LAYER27),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER27), .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER27),
        .IMG_COL(IMG_COL_LAYER27), .IMG_ROW(IMG_ROW_LAYER27), .STEP_COL(STEP_COL_LAYER27), .STEP_ROW(STEP_ROW_LAYER27),
        .SHIFT_KEY(SHIFT_KEY_LAYER27), .BIAS_WIDTH(BIAS_WIDTH_LAYER27), .OUT_WIDTH(OUT_WIDTH_LAYER27),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER27), .ACC_WIDTH(ACC_WIDTH_LAYER27),
        .WEIGHT_FILE0("mem_data/weight_layer27_page0.mem"), .WEIGHT_FILE1("mem_data/weight_layer27_page1.mem"),
        .WEIGHT_FILE2("mem_data/weight_layer27_page2.mem"), .WEIGHT_FILE3("mem_data/weight_layer27_page3.mem"),
        .BIAS_FILE("mem_data/bias_layer27.mem")
    ) u_layer27 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer26), .data_input_valid(out_valid_layer26), .data_input(layer_y_out_layer26),
        .y_out(layer_y_out_layer27), .new_line_out_1(new_line_out_1_layer27), .output_valid(out_valid_layer27)
    );

    lprnet_layer_direct #(
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER28), .PE_ROW_NUM(PE_ROW_NUM_LAYER28),
        .PE_COL_NUM(PE_COL_NUM_LAYER28), .KERNEL_COL(KERNEL_COL_LAYER28), .KERNEL_ROW(KERNEL_ROW_LAYER28),
        .WITH_RELU(WITH_RELU_LAYER28), .MAX_POOL(MAX_POOL_LAYER28), .DATA_WIDTH(DATA_WIDTH_LAYER28),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER28), .USE_DSP_PE(USE_DSP_PE_LAYER28),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER28), .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER28),
        .IMG_COL(IMG_COL_LAYER28), .IMG_ROW(IMG_ROW_LAYER28), .STEP_COL(STEP_COL_LAYER28), .STEP_ROW(STEP_ROW_LAYER28),
        .SHIFT_KEY(SHIFT_KEY_LAYER28), .BIAS_WIDTH(BIAS_WIDTH_LAYER28), .OUT_WIDTH(OUT_WIDTH_LAYER28),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER28), .ACC_WIDTH(ACC_WIDTH_LAYER28),
        .WEIGHT_FILE0("mem_data/weight_layer28_page0.mem"), .WEIGHT_FILE1("mem_data/weight_layer28_page1.mem"),
        .WEIGHT_FILE2("mem_data/weight_layer28_page2.mem"), .WEIGHT_FILE3("mem_data/weight_layer28_page3.mem"),
        .BIAS_FILE("mem_data/bias_layer28.mem")
    ) u_layer28 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer27), .data_input_valid(out_valid_layer27), .data_input(layer_y_out_layer27),
        .y_out(layer_y_out_layer28), .new_line_out_1(new_line_out_1_layer28), .output_valid(out_valid_layer28)
    );

    lprnet_layer_direct #(
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER29), .PE_ROW_NUM(PE_ROW_NUM_LAYER29),
        .PE_COL_NUM(PE_COL_NUM_LAYER29), .KERNEL_COL(KERNEL_COL_LAYER29), .KERNEL_ROW(KERNEL_ROW_LAYER29),
        .WITH_RELU(WITH_RELU_LAYER29), .MAX_POOL(MAX_POOL_LAYER29), .DATA_WIDTH(DATA_WIDTH_LAYER29),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER29), .USE_DSP_PE(USE_DSP_PE_LAYER29),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER29), .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER29),
        .IMG_COL(IMG_COL_LAYER29), .IMG_ROW(IMG_ROW_LAYER29), .STEP_COL(STEP_COL_LAYER29), .STEP_ROW(STEP_ROW_LAYER29),
        .SHIFT_KEY(SHIFT_KEY_LAYER29), .BIAS_WIDTH(BIAS_WIDTH_LAYER29), .OUT_WIDTH(OUT_WIDTH_LAYER29),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER29), .ACC_WIDTH(ACC_WIDTH_LAYER29),
        .WEIGHT_FILE0("mem_data/weight_layer29_page0.mem"), .WEIGHT_FILE1("mem_data/weight_layer29_page1.mem"),
        .WEIGHT_FILE2("mem_data/weight_layer29_page2.mem"), .WEIGHT_FILE3("mem_data/weight_layer29_page3.mem"),
        .BIAS_FILE("mem_data/bias_layer29.mem")
    ) u_layer29 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer28), .data_input_valid(out_valid_layer28), .data_input(layer_y_out_layer28),
        .y_out(layer_y_out_layer29), .new_line_out_1(new_line_out_1_layer29), .output_valid(out_valid_layer29)
    );

    lprnet_layer_direct #(
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER30), .PE_ROW_NUM(PE_ROW_NUM_LAYER30),
        .PE_COL_NUM(PE_COL_NUM_LAYER30), .KERNEL_COL(KERNEL_COL_LAYER30), .KERNEL_ROW(KERNEL_ROW_LAYER30),
        .WITH_RELU(WITH_RELU_LAYER30), .MAX_POOL(MAX_POOL_LAYER30), .DATA_WIDTH(DATA_WIDTH_LAYER30),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER30), .USE_DSP_PE(USE_DSP_PE_LAYER30),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER30), .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER30),
        .IMG_COL(IMG_COL_LAYER30), .IMG_ROW(IMG_ROW_LAYER30), .STEP_COL(STEP_COL_LAYER30), .STEP_ROW(STEP_ROW_LAYER30),
        .SHIFT_KEY(SHIFT_KEY_LAYER30), .BIAS_WIDTH(BIAS_WIDTH_LAYER30), .OUT_WIDTH(OUT_WIDTH_LAYER30),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER30), .ACC_WIDTH(ACC_WIDTH_LAYER30),
        .WEIGHT_FILE0("mem_data/weight_layer30_page0.mem"), .WEIGHT_FILE1("mem_data/weight_layer30_page1.mem"),
        .WEIGHT_FILE2("mem_data/weight_layer30_page2.mem"), .WEIGHT_FILE3("mem_data/weight_layer30_page3.mem"),
        .BIAS_FILE("mem_data/bias_layer30.mem")
    ) u_layer30 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer29), .data_input_valid(out_valid_layer29), .data_input(layer_y_out_layer29),
        .y_out(layer_y_out_layer30), .new_line_out_1(new_line_out_1_layer30), .output_valid(out_valid_layer30)
    );

    lprnet_layer_direct #(
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER31), .PE_ROW_NUM(PE_ROW_NUM_LAYER31),
        .PE_COL_NUM(PE_COL_NUM_LAYER31), .KERNEL_COL(KERNEL_COL_LAYER31), .KERNEL_ROW(KERNEL_ROW_LAYER31),
        .WITH_RELU(WITH_RELU_LAYER31), .MAX_POOL(MAX_POOL_LAYER31), .DATA_WIDTH(DATA_WIDTH_LAYER31),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER31), .USE_DSP_PE(USE_DSP_PE_LAYER31),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER31), .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER31),
        .IMG_COL(IMG_COL_LAYER31), .IMG_ROW(IMG_ROW_LAYER31), .STEP_COL(STEP_COL_LAYER31), .STEP_ROW(STEP_ROW_LAYER31),
        .SHIFT_KEY(SHIFT_KEY_LAYER31), .BIAS_WIDTH(BIAS_WIDTH_LAYER31), .OUT_WIDTH(OUT_WIDTH_LAYER31),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER31), .ACC_WIDTH(ACC_WIDTH_LAYER31),
        .WEIGHT_FILE0("mem_data/weight_layer31_page0.mem"), .WEIGHT_FILE1("mem_data/weight_layer31_page1.mem"),
        .WEIGHT_FILE2("mem_data/weight_layer31_page2.mem"), .WEIGHT_FILE3("mem_data/weight_layer31_page3.mem"),
        .BIAS_FILE("mem_data/bias_layer31.mem")
    ) u_layer31 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer30), .data_input_valid(out_valid_layer30), .data_input(layer_y_out_layer30),
        .y_out(layer_y_out_layer31), .new_line_out_1(new_line_out_1_layer31), .output_valid(out_valid_layer31)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dbg_new_line_seen  <= '0;
            dbg_out_valid_seen <= '0;
            dbg_input_new_line_seen <= 1'b0;
            dbg_input_valid_seen <= 1'b0;
            dbg_post_frame_seen <= 1'b0;
            dbg_post_char_seen  <= 1'b0;
        end else if (clk_en) begin
            dbg_input_new_line_seen <= dbg_input_new_line_seen | new_line_input_1;
            dbg_input_valid_seen <= dbg_input_valid_seen | data_input_valid;

            dbg_new_line_seen[0]  <= dbg_new_line_seen[0]  | new_line_out_1_layer20;
            dbg_new_line_seen[1]  <= dbg_new_line_seen[1]  | new_line_out_1_layer21;
            dbg_new_line_seen[2]  <= dbg_new_line_seen[2]  | new_line_out_1_layer22;
            dbg_new_line_seen[3]  <= dbg_new_line_seen[3]  | new_line_out_1_layer23;
            dbg_new_line_seen[4]  <= dbg_new_line_seen[4]  | new_line_out_1_layer24;
            dbg_new_line_seen[5]  <= dbg_new_line_seen[5]  | new_line_out_1_layer25;
            dbg_new_line_seen[6]  <= dbg_new_line_seen[6]  | new_line_out_1_layer26;
            dbg_new_line_seen[7]  <= dbg_new_line_seen[7]  | new_line_out_1_layer27;
            dbg_new_line_seen[8]  <= dbg_new_line_seen[8]  | new_line_out_1_layer28;
            dbg_new_line_seen[9]  <= dbg_new_line_seen[9]  | new_line_out_1_layer29;
            dbg_new_line_seen[10] <= dbg_new_line_seen[10] | new_line_out_1_layer30;
            dbg_new_line_seen[11] <= dbg_new_line_seen[11] | new_line_out_1_layer31;

            dbg_out_valid_seen[0]  <= dbg_out_valid_seen[0]  | out_valid_layer20;
            dbg_out_valid_seen[1]  <= dbg_out_valid_seen[1]  | out_valid_layer21;
            dbg_out_valid_seen[2]  <= dbg_out_valid_seen[2]  | out_valid_layer22;
            dbg_out_valid_seen[3]  <= dbg_out_valid_seen[3]  | out_valid_layer23;
            dbg_out_valid_seen[4]  <= dbg_out_valid_seen[4]  | out_valid_layer24;
            dbg_out_valid_seen[5]  <= dbg_out_valid_seen[5]  | out_valid_layer25;
            dbg_out_valid_seen[6]  <= dbg_out_valid_seen[6]  | out_valid_layer26;
            dbg_out_valid_seen[7]  <= dbg_out_valid_seen[7]  | out_valid_layer27;
            dbg_out_valid_seen[8]  <= dbg_out_valid_seen[8]  | out_valid_layer28;
            dbg_out_valid_seen[9]  <= dbg_out_valid_seen[9]  | out_valid_layer29;
            dbg_out_valid_seen[10] <= dbg_out_valid_seen[10] | out_valid_layer30;
            dbg_out_valid_seen[11] <= dbg_out_valid_seen[11] | out_valid_layer31;

            dbg_post_frame_seen <= dbg_post_frame_seen | frame_start_out;
            dbg_post_char_seen  <= dbg_post_char_seen  | out_valid;
        end
    end

    lprnet_post_process #(
        .PE_COL_NUM(PE_COL_NUM_LAYER31),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER31),
        .IMG_COL(IMG_COL_LAYER31),
        .IMG_ROW(IMG_ROW_LAYER31),
        .DATA_WIDTH(OUT_WIDTH_LAYER31),
        .ACC_WIDTH(OUT_WIDTH_LAYER31 + $clog2(IMG_ROW_LAYER31)),
        .CONV_POSITIVE(CONV_POSITIVE),
        .BLANK_CHAR(BLANK_CHAR),
        .VALID_CHAR_NUM(VALID_CHAR_NUM)
    ) u_post_process (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer31),
        .data_input_valid(out_valid_layer31),
        .data_input(layer31_y_out_signed),
        .out_char(out_char),
        .out_valid(out_valid),
        .frame_start_out(frame_start_out)
    );

endmodule
