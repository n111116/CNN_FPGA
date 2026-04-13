// =============================================================================
// File Name   : layer21.vh
// Description : Auto-generated configuration parameters for CNN Layer: node_max_pool2d.
// =============================================================================

`ifndef LAYER21_VH
`define LAYER21_VH
    parameter int unsigned LAYER_NUM_LAYER21 = 21;

    // 1. 架构参数
    parameter int unsigned PE_PAGE_NUM_LAYER21      = 1;
    parameter int unsigned PE_COL_NUM_LAYER21       = 1;  
    parameter int unsigned PE_ROW_NUM_LAYER21       = 9;  
    parameter int unsigned KERNEL_COL_LAYER21       = 3;
    parameter int unsigned KERNEL_ROW_LAYER21       = 3;  
    parameter int unsigned CHANNEL_OUT_NUM_LAYER21  = 2;
    parameter int unsigned CHANNEL_IN_NUM_LAYER21   = 16;  
    parameter int unsigned MAX_POOL_LAYER21         = 1;
    parameter int unsigned WITH_RELU_LAYER21        = 0;
    parameter int unsigned STEP_ROW_LAYER21         = 2;
    parameter int unsigned STEP_COL_LAYER21         = 1;
    parameter USE_DSP_PE_LAYER21                    = "no";
  
    // 2. 位宽参数 (来自 MAT)  
    parameter int unsigned DATA_WIDTH_LAYER21       = 9;
    parameter int unsigned WEIGHT_WIDTH_LAYER21     = 1;
    parameter int unsigned BIAS_WIDTH_LAYER21       = 1;
    parameter int unsigned OUT_WIDTH_LAYER21        = 9;

    // 3. 周期与映射参数
    parameter int unsigned CYCLE_PERIOD_IN_LAYER21  = 16; 
    parameter int unsigned CYCLE_PERIOD_OUT_LAYER21 = 2;
    parameter int unsigned CYCLE_PERIOD_LAYER21     = CYCLE_PERIOD_IN_LAYER21 * CYCLE_PERIOD_OUT_LAYER21;
    parameter int unsigned SHIFT_KEY_LAYER21        = 0;

    // 4. 图像尺寸
    parameter int unsigned IMG_COL_LAYER21          = 72;
    parameter int unsigned IMG_ROW_LAYER21          = 40;

    // 5. 自动计算的中间位宽
    parameter int unsigned PE_PAGE_OUTPUT_WIDTH_LAYER21 = 14;
    parameter int unsigned ACC_WIDTH_LAYER21        = 18;

    /* Simulation Paths */
    localparam INPUT_FILE_PATH_LAYER21       = "C:/Users/Datou21/Desktop/PDS/cnn_usb_copy/conv_data_hex_pds/layer21_input_9bit.hex";
    localparam OUTPUT_FILE_PATH_LAYER21      = "sim_out/layer21_output.hex";

`endif // LAYER21_VH
