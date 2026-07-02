// =============================================================================
// File Name   : layer29.vh
// Description : Auto-generated configuration parameters for CNN Layer: node_conv2d_6.
// =============================================================================

`ifndef LAYER29_VH
`define LAYER29_VH
    parameter int unsigned LAYER_NUM_LAYER29 = 29;

    // 1. 架构参数
    parameter int unsigned PE_PAGE_NUM_LAYER29      = 2;
    parameter int unsigned PE_COL_NUM_LAYER29       = 4;  
    parameter int unsigned PE_ROW_NUM_LAYER29       = 9;  
    parameter int unsigned KERNEL_COL_LAYER29       = 3;
    parameter int unsigned KERNEL_ROW_LAYER29       = 3;  
    parameter int unsigned CHANNEL_OUT_NUM_LAYER29  = 128;
    parameter int unsigned CHANNEL_IN_NUM_LAYER29   = 64;  
    parameter int unsigned MAX_POOL_LAYER29         = 0;
    parameter int unsigned WITH_RELU_LAYER29        = 1;
    parameter int unsigned STEP_ROW_LAYER29         = 1;
    parameter int unsigned STEP_COL_LAYER29         = 1;
    parameter USE_DSP_PE_LAYER29                    = "no";
  
    // 2. 位宽参数 (来自 MAT)  
    parameter int unsigned DATA_WIDTH_LAYER29       = 9;
    parameter int unsigned WEIGHT_WIDTH_LAYER29     = 10;
    parameter int unsigned BIAS_WIDTH_LAYER29       = 20;
    parameter int unsigned OUT_WIDTH_LAYER29        = 9;

    // 3. 周期与映射参数
    parameter int unsigned CYCLE_PERIOD_IN_LAYER29  = 32; 
    parameter int unsigned CYCLE_PERIOD_OUT_LAYER29 = 32;
    parameter int unsigned CYCLE_PERIOD_LAYER29     = CYCLE_PERIOD_IN_LAYER29 * CYCLE_PERIOD_OUT_LAYER29;
    parameter int unsigned SHIFT_KEY_LAYER29        = 10;

    // 4. 图像尺寸
    parameter int unsigned IMG_COL_LAYER29          = 20;
    parameter int unsigned IMG_ROW_LAYER29          = 5;

    // 5. 自动计算的中间位宽
    parameter int unsigned PE_PAGE_OUTPUT_WIDTH_LAYER29 = 23;
    parameter int unsigned ACC_WIDTH_LAYER29        = 29;

    /* Simulation Paths */
    localparam INPUT_FILE_PATH_LAYER29       = "C:/Users/Datou21/Desktop/PDS/back1/cnn_usb_copy/conv_data_hex_pds/layer29_input_9bit.hex";
    localparam OUTPUT_FILE_PATH_LAYER29      = "sim_out/layer29_output.hex";

`endif // LAYER29_VH
