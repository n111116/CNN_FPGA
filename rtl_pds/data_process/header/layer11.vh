// =============================================================================
// File Name   : layer11.vh
// Description : Auto-generated configuration parameters for CNN Layer: node_conv2d_11.
// =============================================================================

`ifndef LAYER11_VH
`define LAYER11_VH
    parameter int unsigned LAYER_NUM_LAYER11 = 11;

    // 1. 架构参数
    parameter int unsigned PE_PAGE_NUM_LAYER11      = 2;
    parameter int unsigned PE_COL_NUM_LAYER11       = 1;  
    parameter int unsigned PE_ROW_NUM_LAYER11       = 1;  
    parameter int unsigned KERNEL_COL_LAYER11       = 1;
    parameter int unsigned KERNEL_ROW_LAYER11       = 1;  
    parameter int unsigned CHANNEL_OUT_NUM_LAYER11  = 32;
    parameter int unsigned CHANNEL_IN_NUM_LAYER11   = 32;  
    parameter int unsigned MAX_POOL_LAYER11         = 0;
    parameter int unsigned WITH_RELU_LAYER11        = 0;
    parameter int unsigned STEP_ROW_LAYER11         = 1;
    parameter int unsigned STEP_COL_LAYER11         = 1;
    parameter USE_DSP_PE_LAYER11                    = "no";
  
    // 2. 位宽参数 (来自 MAT)  
    parameter int unsigned DATA_WIDTH_LAYER11       = 8;
    parameter int unsigned WEIGHT_WIDTH_LAYER11     = 9;
    parameter int unsigned BIAS_WIDTH_LAYER11       = 14;
    parameter int unsigned OUT_WIDTH_LAYER11        = 9;

    // 3. 周期与映射参数
    parameter int unsigned CYCLE_PERIOD_IN_LAYER11  = 16; 
    parameter int unsigned CYCLE_PERIOD_OUT_LAYER11 = 32;
    parameter int unsigned CYCLE_PERIOD_LAYER11     = CYCLE_PERIOD_IN_LAYER11 * CYCLE_PERIOD_OUT_LAYER11;
    parameter int unsigned SHIFT_KEY_LAYER11        = 8;

    // 4. 图像尺寸
    parameter int unsigned IMG_COL_LAYER11          = 80;
    parameter int unsigned IMG_ROW_LAYER11          = 45;

    // 5. 自动计算的中间位宽
    parameter int unsigned PE_PAGE_OUTPUT_WIDTH_LAYER11 = 17;
    parameter int unsigned ACC_WIDTH_LAYER11        = 22;

    /* Simulation Paths */
    localparam INPUT_FILE_PATH_LAYER11       = "C:/Users/Datou21/Desktop/PDS/cnn_usb_copy/conv_data_hex/layer11_input_8bit.hex";
    localparam OUTPUT_FILE_PATH_LAYER11      = "sim_out/layer11_output.hex";

`endif // LAYER11_VH
