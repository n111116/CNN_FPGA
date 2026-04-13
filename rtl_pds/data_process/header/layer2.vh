// =============================================================================
// File Name   : layer2.vh
// Description : Auto-generated configuration parameters for CNN Layer: node_conv2d_2.
// =============================================================================

`ifndef LAYER2_VH
`define LAYER2_VH
    parameter int unsigned LAYER_NUM_LAYER2 = 2;

    // 1. 架构参数
    parameter int unsigned PE_PAGE_NUM_LAYER2      = 4;
    parameter int unsigned PE_COL_NUM_LAYER2       = 1;  
    parameter int unsigned PE_ROW_NUM_LAYER2       = 9;  
    parameter int unsigned KERNEL_COL_LAYER2       = 3;
    parameter int unsigned KERNEL_ROW_LAYER2       = 3;  
    parameter int unsigned CHANNEL_OUT_NUM_LAYER2  = 32;
    parameter int unsigned CHANNEL_IN_NUM_LAYER2   = 16;  
    parameter int unsigned MAX_POOL_LAYER2         = 0;
    parameter int unsigned WITH_RELU_LAYER2        = 1;
    parameter int unsigned STEP_ROW_LAYER2         = 2;
    parameter int unsigned STEP_COL_LAYER2         = 2;
    parameter USE_DSP_PE_LAYER2                    = "yes";
  
    // 2. 位宽参数 (来自 MAT)  
    parameter int unsigned DATA_WIDTH_LAYER2       = 8;
    parameter int unsigned WEIGHT_WIDTH_LAYER2     = 9;
    parameter int unsigned BIAS_WIDTH_LAYER2       = 16;
    parameter int unsigned OUT_WIDTH_LAYER2        = 8;

    // 3. 周期与映射参数
    parameter int unsigned CYCLE_PERIOD_IN_LAYER2  = 4; 
    parameter int unsigned CYCLE_PERIOD_OUT_LAYER2 = 32;
    parameter int unsigned CYCLE_PERIOD_LAYER2     = CYCLE_PERIOD_IN_LAYER2 * CYCLE_PERIOD_OUT_LAYER2;
    parameter int unsigned SHIFT_KEY_LAYER2        = 8;

    // 4. 图像尺寸
    parameter int unsigned IMG_COL_LAYER2          = 320;
    parameter int unsigned IMG_ROW_LAYER2          = 180;

    // 5. 自动计算的中间位宽
    parameter int unsigned PE_PAGE_OUTPUT_WIDTH_LAYER2 = 21;
    parameter int unsigned ACC_WIDTH_LAYER2        = 25;

    /* Simulation Paths */
    localparam INPUT_FILE_PATH_LAYER2       = "C:/Users/Datou21/Desktop/PDS/cnn_usb_copy/conv_data_hex_pds/layer2_input_8bit.hex";
    localparam OUTPUT_FILE_PATH_LAYER2      = "sim_out/layer2_output.hex";

`endif // LAYER2_VH
