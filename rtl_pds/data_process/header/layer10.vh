// =============================================================================
// File Name   : layer10.vh
// Description : Auto-generated configuration parameters for CNN Layer: node_conv2d_10.
// =============================================================================

`ifndef LAYER10_VH
`define LAYER10_VH
    parameter int unsigned LAYER_NUM_LAYER10 = 10;

    // 1. 架构参数
    parameter int unsigned PE_PAGE_NUM_LAYER10      = 1;
    parameter int unsigned PE_COL_NUM_LAYER10       = 2;  
    parameter int unsigned PE_ROW_NUM_LAYER10       = 9;  
    parameter int unsigned KERNEL_COL_LAYER10       = 3;
    parameter int unsigned KERNEL_ROW_LAYER10       = 3;  
    parameter int unsigned CHANNEL_OUT_NUM_LAYER10  = 32;
    parameter int unsigned CHANNEL_IN_NUM_LAYER10   = 32;  
    parameter int unsigned MAX_POOL_LAYER10         = 0;
    parameter int unsigned WITH_RELU_LAYER10        = 1;
    parameter int unsigned STEP_ROW_LAYER10         = 1;
    parameter int unsigned STEP_COL_LAYER10         = 1;
    parameter USE_DSP_PE_LAYER10                    = "no";
  
    // 2. 位宽参数 (来自 MAT)  
    parameter int unsigned DATA_WIDTH_LAYER10       = 8;
    parameter int unsigned WEIGHT_WIDTH_LAYER10     = 9;
    parameter int unsigned BIAS_WIDTH_LAYER10       = 14;
    parameter int unsigned OUT_WIDTH_LAYER10        = 8;

    // 3. 周期与映射参数
    parameter int unsigned CYCLE_PERIOD_IN_LAYER10  = 32; 
    parameter int unsigned CYCLE_PERIOD_OUT_LAYER10 = 16;
    parameter int unsigned CYCLE_PERIOD_LAYER10     = CYCLE_PERIOD_IN_LAYER10 * CYCLE_PERIOD_OUT_LAYER10;
    parameter int unsigned SHIFT_KEY_LAYER10        = 8;

    // 4. 图像尺寸
    parameter int unsigned IMG_COL_LAYER10          = 80;
    parameter int unsigned IMG_ROW_LAYER10          = 45;

    // 5. 自动计算的中间位宽
    parameter int unsigned PE_PAGE_OUTPUT_WIDTH_LAYER10 = 21;
    parameter int unsigned ACC_WIDTH_LAYER10        = 26;

    /* Simulation Paths */
    localparam INPUT_FILE_PATH_LAYER10       = "C:/Users/Datou21/Desktop/PDS/cnn_usb_copy/conv_data_hex/layer10_input_8bit.hex";
    localparam OUTPUT_FILE_PATH_LAYER10      = "sim_out/layer10_output.hex";

`endif // LAYER10_VH
