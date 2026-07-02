// =============================================================================
// File Name   : layer31.vh
// Description : Auto-generated configuration parameters for CNN Layer: node_conv2d_8.
// =============================================================================

`ifndef LAYER31_VH
`define LAYER31_VH
    parameter int unsigned LAYER_NUM_LAYER31 = 31;

    // 1. 架构参数
    parameter int unsigned PE_PAGE_NUM_LAYER31      = 2;
    parameter int unsigned PE_COL_NUM_LAYER31       = 4;  
    parameter int unsigned PE_ROW_NUM_LAYER31       = 1;  
    parameter int unsigned KERNEL_COL_LAYER31       = 1;
    parameter int unsigned KERNEL_ROW_LAYER31       = 1;  
    parameter int unsigned CHANNEL_OUT_NUM_LAYER31  = 128;
    parameter int unsigned CHANNEL_IN_NUM_LAYER31   = 128;  
    parameter int unsigned MAX_POOL_LAYER31         = 0;
    parameter int unsigned WITH_RELU_LAYER31        = 0;
    parameter int unsigned STEP_ROW_LAYER31         = 1;
    parameter int unsigned STEP_COL_LAYER31         = 1;
    parameter USE_DSP_PE_LAYER31                    = "no";
  
    // 2. 位宽参数 (来自 MAT)  
    parameter int unsigned DATA_WIDTH_LAYER31       = 9;
    parameter int unsigned WEIGHT_WIDTH_LAYER31     = 10;
    parameter int unsigned BIAS_WIDTH_LAYER31       = 14;
    parameter int unsigned OUT_WIDTH_LAYER31        = 10;

    // 3. 周期与映射参数
    parameter int unsigned CYCLE_PERIOD_IN_LAYER31  = 64; 
    parameter int unsigned CYCLE_PERIOD_OUT_LAYER31 = 32;
    parameter int unsigned CYCLE_PERIOD_LAYER31     = CYCLE_PERIOD_IN_LAYER31 * CYCLE_PERIOD_OUT_LAYER31;
    parameter int unsigned SHIFT_KEY_LAYER31        = 10;

    // 4. 图像尺寸
    parameter int unsigned IMG_COL_LAYER31          = 20;
    parameter int unsigned IMG_ROW_LAYER31          = 5;

    // 5. 自动计算的中间位宽
    parameter int unsigned PE_PAGE_OUTPUT_WIDTH_LAYER31 = 19;
    parameter int unsigned ACC_WIDTH_LAYER31        = 26;

    /* Simulation Paths */
    localparam INPUT_FILE_PATH_LAYER31       = "C:/Users/Datou21/Desktop/PDS/back1/cnn_usb_copy/conv_data_hex_pds/layer31_input_9bit.hex";
    localparam OUTPUT_FILE_PATH_LAYER31      = "sim_out/layer31_output.hex";

`endif // LAYER31_VH
