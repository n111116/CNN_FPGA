// =============================================================================
// File Name   : layer27.vh
// Description : Auto-generated configuration parameters for CNN Layer: node_conv2d_4.
// =============================================================================

`ifndef LAYER27_VH
`define LAYER27_VH
    parameter int unsigned LAYER_NUM_LAYER27 = 27;

    // 1. 架构参数
    parameter int unsigned PE_PAGE_NUM_LAYER27      = 2;
    parameter int unsigned PE_COL_NUM_LAYER27       = 2;  
    parameter int unsigned PE_ROW_NUM_LAYER27       = 3;  
    parameter int unsigned KERNEL_COL_LAYER27       = 3;
    parameter int unsigned KERNEL_ROW_LAYER27       = 1;  
    parameter int unsigned CHANNEL_OUT_NUM_LAYER27  = 128;
    parameter int unsigned CHANNEL_IN_NUM_LAYER27   = 128;  
    parameter int unsigned MAX_POOL_LAYER27         = 0;
    parameter int unsigned WITH_RELU_LAYER27        = 1;
    parameter int unsigned STEP_ROW_LAYER27         = 1;
    parameter int unsigned STEP_COL_LAYER27         = 1;
    parameter USE_DSP_PE_LAYER27                    = "no";
  
    // 2. 位宽参数 (来自 MAT)  
    parameter int unsigned DATA_WIDTH_LAYER27       = 9;
    parameter int unsigned WEIGHT_WIDTH_LAYER27     = 10;
    parameter int unsigned BIAS_WIDTH_LAYER27       = 16;
    parameter int unsigned OUT_WIDTH_LAYER27        = 9;

    // 3. 周期与映射参数
    parameter int unsigned CYCLE_PERIOD_IN_LAYER27  = 64; 
    parameter int unsigned CYCLE_PERIOD_OUT_LAYER27 = 64;
    parameter int unsigned CYCLE_PERIOD_LAYER27     = CYCLE_PERIOD_IN_LAYER27 * CYCLE_PERIOD_OUT_LAYER27;
    parameter int unsigned SHIFT_KEY_LAYER27        = 10;

    // 4. 图像尺寸
    parameter int unsigned IMG_COL_LAYER27          = 20;
    parameter int unsigned IMG_ROW_LAYER27          = 5;

    // 5. 自动计算的中间位宽
    parameter int unsigned PE_PAGE_OUTPUT_WIDTH_LAYER27 = 21;
    parameter int unsigned ACC_WIDTH_LAYER27        = 28;

    /* Simulation Paths */
    localparam INPUT_FILE_PATH_LAYER27       = "C:/Users/Datou21/Desktop/PDS/cnn_usb_copy/conv_data_hex/layer27_input_9bit.hex";
    localparam OUTPUT_FILE_PATH_LAYER27      = "sim_out/layer27_output.hex";

`endif // LAYER27_VH
