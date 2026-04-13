// =============================================================================
// File Name   : layer28.vh
// Description : Auto-generated configuration parameters for CNN Layer: node_conv2d_5.
// =============================================================================

`ifndef LAYER28_VH
`define LAYER28_VH
    parameter int unsigned LAYER_NUM_LAYER28 = 28;

    // 1. 架构参数
    parameter int unsigned PE_PAGE_NUM_LAYER28      = 2;
    parameter int unsigned PE_COL_NUM_LAYER28       = 2;  
    parameter int unsigned PE_ROW_NUM_LAYER28       = 1;  
    parameter int unsigned KERNEL_COL_LAYER28       = 1;
    parameter int unsigned KERNEL_ROW_LAYER28       = 1;  
    parameter int unsigned CHANNEL_OUT_NUM_LAYER28  = 128;
    parameter int unsigned CHANNEL_IN_NUM_LAYER28   = 128;  
    parameter int unsigned MAX_POOL_LAYER28         = 0;
    parameter int unsigned WITH_RELU_LAYER28        = 0;
    parameter int unsigned STEP_ROW_LAYER28         = 1;
    parameter int unsigned STEP_COL_LAYER28         = 1;
    parameter USE_DSP_PE_LAYER28                    = "no";
  
    // 2. 位宽参数 (来自 MAT)  
    parameter int unsigned DATA_WIDTH_LAYER28       = 9;
    parameter int unsigned WEIGHT_WIDTH_LAYER28     = 10;
    parameter int unsigned BIAS_WIDTH_LAYER28       = 13;
    parameter int unsigned OUT_WIDTH_LAYER28        = 10;

    // 3. 周期与映射参数
    parameter int unsigned CYCLE_PERIOD_IN_LAYER28  = 64; 
    parameter int unsigned CYCLE_PERIOD_OUT_LAYER28 = 64;
    parameter int unsigned CYCLE_PERIOD_LAYER28     = CYCLE_PERIOD_IN_LAYER28 * CYCLE_PERIOD_OUT_LAYER28;
    parameter int unsigned SHIFT_KEY_LAYER28        = 11;

    // 4. 图像尺寸
    parameter int unsigned IMG_COL_LAYER28          = 18;
    parameter int unsigned IMG_ROW_LAYER28          = 5;

    // 5. 自动计算的中间位宽
    parameter int unsigned PE_PAGE_OUTPUT_WIDTH_LAYER28 = 19;
    parameter int unsigned ACC_WIDTH_LAYER28        = 26;

    /* Simulation Paths */
    localparam INPUT_FILE_PATH_LAYER28       = "C:/Users/Datou21/Desktop/PDS/cnn_usb_copy/conv_data_hex_pds/layer28_input_9bit.hex";
    localparam OUTPUT_FILE_PATH_LAYER28      = "sim_out/layer28_output.hex";

`endif // LAYER28_VH
