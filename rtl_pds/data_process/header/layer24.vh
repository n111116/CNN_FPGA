// =============================================================================
// File Name   : layer24.vh
// Description : Auto-generated configuration parameters for CNN Layer: node_conv2d_2.
// =============================================================================

`ifndef LAYER24_VH
`define LAYER24_VH
    parameter int unsigned LAYER_NUM_LAYER24 = 24;

    // 1. 架构参数
    parameter int unsigned PE_PAGE_NUM_LAYER24      = 1;
    parameter int unsigned PE_COL_NUM_LAYER24       = 1;  
    parameter int unsigned PE_ROW_NUM_LAYER24       = 9;  
    parameter int unsigned KERNEL_COL_LAYER24       = 3;
    parameter int unsigned KERNEL_ROW_LAYER24       = 3;  
    parameter int unsigned CHANNEL_OUT_NUM_LAYER24  = 64;
    parameter int unsigned CHANNEL_IN_NUM_LAYER24   = 32;  
    parameter int unsigned MAX_POOL_LAYER24         = 0;
    parameter int unsigned WITH_RELU_LAYER24        = 1;
    parameter int unsigned STEP_ROW_LAYER24         = 1;
    parameter int unsigned STEP_COL_LAYER24         = 2;
    parameter USE_DSP_PE_LAYER24                    = "no";
  
    // 2. 位宽参数 (来自 MAT)  
    parameter int unsigned DATA_WIDTH_LAYER24       = 9;
    parameter int unsigned WEIGHT_WIDTH_LAYER24     = 10;
    parameter int unsigned BIAS_WIDTH_LAYER24       = 18;
    parameter int unsigned OUT_WIDTH_LAYER24        = 9;

    // 3. 周期与映射参数
    parameter int unsigned CYCLE_PERIOD_IN_LAYER24  = 32; 
    parameter int unsigned CYCLE_PERIOD_OUT_LAYER24 = 64;
    parameter int unsigned CYCLE_PERIOD_LAYER24     = CYCLE_PERIOD_IN_LAYER24 * CYCLE_PERIOD_OUT_LAYER24;
    parameter int unsigned SHIFT_KEY_LAYER24        = 10;

    // 4. 图像尺寸
    parameter int unsigned IMG_COL_LAYER24          = 36;
    parameter int unsigned IMG_ROW_LAYER24          = 10;

    // 5. 自动计算的中间位宽
    parameter int unsigned PE_PAGE_OUTPUT_WIDTH_LAYER24 = 23;
    parameter int unsigned ACC_WIDTH_LAYER24        = 28;

    /* Simulation Paths */
    localparam INPUT_FILE_PATH_LAYER24       = "C:/Users/Datou21/Desktop/PDS/cnn_usb_copy/conv_data_hex_pds/layer24_input_9bit.hex";
    localparam OUTPUT_FILE_PATH_LAYER24      = "sim_out/layer24_output.hex";

`endif // LAYER24_VH
