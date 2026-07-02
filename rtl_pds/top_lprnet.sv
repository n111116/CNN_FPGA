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

    logic signed [PE_COL_NUM_LAYER31-1:0][OUT_WIDTH_LAYER31-1:0] layer31_y_out_signed /* synthesis PAP_MARK_DEBUG="1" syn_preserve=1 */;
    int idc;
    always_comb begin
        for (idc = 0; idc < PE_COL_NUM_LAYER31; idc = idc + 1) begin
            layer31_y_out_signed[idc] = $signed(layer_y_out_layer31[idc]);
        end
    end

`define LPRNET_LAYER_INST(N, PREV_NEW_LINE, PREV_VALID, PREV_DATA) \
    layer #( \
        .LAYER_NUM(LAYER_NUM_LAYER``N), .PE_PAGE_NUM(PE_PAGE_NUM_LAYER``N), .PE_ROW_NUM(PE_ROW_NUM_LAYER``N), \
        .PE_COL_NUM(PE_COL_NUM_LAYER``N), .KERNEL_COL(KERNEL_COL_LAYER``N), .KERNEL_ROW(KERNEL_ROW_LAYER``N), \
        .WITH_RELU(WITH_RELU_LAYER``N), .MAX_POOL(MAX_POOL_LAYER``N), .DATA_WIDTH(DATA_WIDTH_LAYER``N), \
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER``N), .USE_DSP_PE(USE_DSP_PE_LAYER``N), .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER``N), \
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER``N), .IMG_COL(IMG_COL_LAYER``N), .IMG_ROW(IMG_ROW_LAYER``N), \
        .STEP_COL(STEP_COL_LAYER``N), .STEP_ROW(STEP_ROW_LAYER``N), .SHIFT_KEY(SHIFT_KEY_LAYER``N), \
        .BIAS_WIDTH(BIAS_WIDTH_LAYER``N), .OUT_WIDTH(OUT_WIDTH_LAYER``N), .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER``N), \
        .ACC_WIDTH(ACC_WIDTH_LAYER``N) \
    ) u_layer``N ( \
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n), \
        .new_line_input_1(PREV_NEW_LINE), .data_input_valid(PREV_VALID), .data_input(PREV_DATA), \
        .y_out(layer_y_out_layer``N), .new_line_out_1(new_line_out_1_layer``N), .output_valid(out_valid_layer``N) \
    )

    `LPRNET_LAYER_INST(20, new_line_input_1,       data_input_valid, data_input);
    `LPRNET_LAYER_INST(21, new_line_out_1_layer20, out_valid_layer20, layer_y_out_layer20);
    `LPRNET_LAYER_INST(22, new_line_out_1_layer21, out_valid_layer21, layer_y_out_layer21);
    `LPRNET_LAYER_INST(23, new_line_out_1_layer22, out_valid_layer22, layer_y_out_layer22);
    `LPRNET_LAYER_INST(24, new_line_out_1_layer23, out_valid_layer23, layer_y_out_layer23);
    `LPRNET_LAYER_INST(25, new_line_out_1_layer24, out_valid_layer24, layer_y_out_layer24);
    `LPRNET_LAYER_INST(26, new_line_out_1_layer25, out_valid_layer25, layer_y_out_layer25);
    `LPRNET_LAYER_INST(27, new_line_out_1_layer26, out_valid_layer26, layer_y_out_layer26);
    `LPRNET_LAYER_INST(28, new_line_out_1_layer27, out_valid_layer27, layer_y_out_layer27);
    `LPRNET_LAYER_INST(29, new_line_out_1_layer28, out_valid_layer28, layer_y_out_layer28);
    `LPRNET_LAYER_INST(30, new_line_out_1_layer29, out_valid_layer29, layer_y_out_layer29);
    `LPRNET_LAYER_INST(31, new_line_out_1_layer30, out_valid_layer30, layer_y_out_layer30);

`undef LPRNET_LAYER_INST

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
