// =============================================================================
// File Name   : layer6.vh
// Description : Auto-generated configuration parameters for CNN Layer: node_conv2d_6.
// =============================================================================

`ifndef LAYER6_VH
`define LAYER6_VH
    parameter int unsigned LAYER_NUM_LAYER6 = 6;

    // 1. 架构参数
    parameter int unsigned PE_PAGE_NUM_LAYER6      = 2;
    parameter int unsigned PE_COL_NUM_LAYER6       = 1;  
    parameter int unsigned PE_ROW_NUM_LAYER6       = 9;  
    parameter int unsigned KERNEL_COL_LAYER6       = 3;
    parameter int unsigned KERNEL_ROW_LAYER6       = 3;  
    parameter int unsigned CHANNEL_OUT_NUM_LAYER6  = 32;
    parameter int unsigned CHANNEL_IN_NUM_LAYER6   = 32;  
    parameter int unsigned MAX_POOL_LAYER6         = 0;
    parameter int unsigned WITH_RELU_LAYER6        = 1;
    parameter int unsigned STEP_ROW_LAYER6         = 1;
    parameter int unsigned STEP_COL_LAYER6         = 1;
    parameter USE_DSP_PE_LAYER6                    = "no";
  
    // 2. 位宽参数 (来自 MAT)  
    parameter int unsigned DATA_WIDTH_LAYER6       = 8;
    parameter int unsigned WEIGHT_WIDTH_LAYER6     = 9;
    parameter int unsigned BIAS_WIDTH_LAYER6       = 15;
    parameter int unsigned OUT_WIDTH_LAYER6        = 8;

    // 3. 周期与映射参数
    parameter int unsigned CYCLE_PERIOD_IN_LAYER6  = 16; 
    parameter int unsigned CYCLE_PERIOD_OUT_LAYER6 = 32;
    parameter int unsigned CYCLE_PERIOD_LAYER6     = CYCLE_PERIOD_IN_LAYER6 * CYCLE_PERIOD_OUT_LAYER6;
    parameter int unsigned SHIFT_KEY_LAYER6        = 7;

    // 4. 图像尺寸
    parameter int unsigned IMG_COL_LAYER6          = 80;
    parameter int unsigned IMG_ROW_LAYER6          = 45;

    // 5. 自动计算的中间位宽
    parameter int unsigned PE_PAGE_OUTPUT_WIDTH_LAYER6 = 21;
    parameter int unsigned ACC_WIDTH_LAYER6        = 26;

    /* Simulation Paths */
    localparam INPUT_FILE_PATH_LAYER6       = "C:/Users/Datou21/Desktop/PDS/cnn_usb_copy/conv_data_hex_pds/layer6_input_8bit.hex";
    localparam OUTPUT_FILE_PATH_LAYER6      = "sim_out/layer6_output.hex";

`endif // LAYER6_VH
