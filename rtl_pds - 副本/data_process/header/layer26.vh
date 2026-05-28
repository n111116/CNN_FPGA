// =============================================================================
// File Name   : layer26.vh
// Description : Auto-generated configuration parameters for CNN Layer: node_conv2d_3.
// =============================================================================

`ifndef LAYER26_VH
`define LAYER26_VH
    parameter int unsigned LAYER_NUM_LAYER26 = 26;

    // 1. 架构参数
    parameter int unsigned PE_PAGE_NUM_LAYER26      = 1;
    parameter int unsigned PE_COL_NUM_LAYER26       = 4;  
    parameter int unsigned PE_ROW_NUM_LAYER26       = 9;  
    parameter int unsigned KERNEL_COL_LAYER26       = 3;
    parameter int unsigned KERNEL_ROW_LAYER26       = 3;  
    parameter int unsigned CHANNEL_OUT_NUM_LAYER26  = 128;
    parameter int unsigned CHANNEL_IN_NUM_LAYER26   = 64;  
    parameter int unsigned MAX_POOL_LAYER26         = 0;
    parameter int unsigned WITH_RELU_LAYER26        = 1;
    parameter int unsigned STEP_ROW_LAYER26         = 1;
    parameter int unsigned STEP_COL_LAYER26         = 1;
    parameter USE_DSP_PE_LAYER26                    = "no";
  
    // 2. 位宽参数 (来自 MAT)  
    parameter int unsigned DATA_WIDTH_LAYER26       = 9;
    parameter int unsigned WEIGHT_WIDTH_LAYER26     = 10;
    parameter int unsigned BIAS_WIDTH_LAYER26       = 19;
    parameter int unsigned OUT_WIDTH_LAYER26        = 9;

    // 3. 周期与映射参数
    parameter int unsigned CYCLE_PERIOD_IN_LAYER26  = 64; 
    parameter int unsigned CYCLE_PERIOD_OUT_LAYER26 = 32;
    parameter int unsigned CYCLE_PERIOD_LAYER26     = CYCLE_PERIOD_IN_LAYER26 * CYCLE_PERIOD_OUT_LAYER26;
    parameter int unsigned SHIFT_KEY_LAYER26        = 10;

    // 4. 图像尺寸
    parameter int unsigned IMG_COL_LAYER26          = 20;
    parameter int unsigned IMG_ROW_LAYER26          = 5;

    // 5. 自动计算的中间位宽
    parameter int unsigned PE_PAGE_OUTPUT_WIDTH_LAYER26 = 23;
    parameter int unsigned ACC_WIDTH_LAYER26        = 29;

    /* Simulation Paths */
    localparam INPUT_FILE_PATH_LAYER26       = "C:/Users/Datou21/Desktop/PDS/back1/cnn_usb_copy/conv_data_hex_pds/layer26_input_9bit.hex";
    localparam OUTPUT_FILE_PATH_LAYER26      = "sim_out/layer26_output.hex";

`endif // LAYER26_VH
