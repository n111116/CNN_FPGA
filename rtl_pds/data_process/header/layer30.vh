// =============================================================================
// File Name   : layer30.vh
// Description : Auto-generated configuration parameters for CNN Layer: node_conv2d_7.
// =============================================================================

`ifndef LAYER30_VH
`define LAYER30_VH
    parameter int unsigned LAYER_NUM_LAYER30 = 30;

    // 1. 架构参数
    parameter int unsigned PE_PAGE_NUM_LAYER30      = 4;
    parameter int unsigned PE_COL_NUM_LAYER30       = 2;  
    parameter int unsigned PE_ROW_NUM_LAYER30       = 3;  
    parameter int unsigned KERNEL_COL_LAYER30       = 3;
    parameter int unsigned KERNEL_ROW_LAYER30       = 1;  
    parameter int unsigned CHANNEL_OUT_NUM_LAYER30  = 128;
    parameter int unsigned CHANNEL_IN_NUM_LAYER30   = 128;  
    parameter int unsigned MAX_POOL_LAYER30         = 0;
    parameter int unsigned WITH_RELU_LAYER30        = 1;
    parameter int unsigned STEP_ROW_LAYER30         = 1;
    parameter int unsigned STEP_COL_LAYER30         = 1;
    parameter USE_DSP_PE_LAYER30                    = "no";
  
    // 2. 位宽参数 (来自 MAT)  
    parameter int unsigned DATA_WIDTH_LAYER30       = 9;
    parameter int unsigned WEIGHT_WIDTH_LAYER30     = 10;
    parameter int unsigned BIAS_WIDTH_LAYER30       = 18;
    parameter int unsigned OUT_WIDTH_LAYER30        = 9;

    // 3. 周期与映射参数
    parameter int unsigned CYCLE_PERIOD_IN_LAYER30  = 32; 
    parameter int unsigned CYCLE_PERIOD_OUT_LAYER30 = 64;
    parameter int unsigned CYCLE_PERIOD_LAYER30     = CYCLE_PERIOD_IN_LAYER30 * CYCLE_PERIOD_OUT_LAYER30;
    parameter int unsigned SHIFT_KEY_LAYER30        = 10;

    // 4. 图像尺寸
    parameter int unsigned IMG_COL_LAYER30          = 20;
    parameter int unsigned IMG_ROW_LAYER30          = 5;

    // 5. 自动计算的中间位宽
    parameter int unsigned PE_PAGE_OUTPUT_WIDTH_LAYER30 = 21;
    parameter int unsigned ACC_WIDTH_LAYER30        = 28;

    /* Simulation Paths */
    localparam INPUT_FILE_PATH_LAYER30       = "C:/Users/Datou21/Desktop/PDS/back1/cnn_usb_copy/conv_data_hex_pds/layer30_input_9bit.hex";
    localparam OUTPUT_FILE_PATH_LAYER30      = "sim_out/layer30_output.hex";

`endif // LAYER30_VH
