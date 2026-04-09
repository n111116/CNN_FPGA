// =============================================================================
// File Name   : layer8.vh
// Description : Auto-generated configuration parameters for CNN Layer: node_conv2d_8.
// =============================================================================

`ifndef LAYER8_VH
`define LAYER8_VH
    parameter int unsigned LAYER_NUM_LAYER8 = 8;

    // 1. 架构参数
    parameter int unsigned PE_PAGE_NUM_LAYER8      = 2;
    parameter int unsigned PE_COL_NUM_LAYER8       = 1;  
    parameter int unsigned PE_ROW_NUM_LAYER8       = 1;  
    parameter int unsigned KERNEL_COL_LAYER8       = 1;
    parameter int unsigned KERNEL_ROW_LAYER8       = 1;  
    parameter int unsigned CHANNEL_OUT_NUM_LAYER8  = 32;
    parameter int unsigned CHANNEL_IN_NUM_LAYER8   = 32;  
    parameter int unsigned MAX_POOL_LAYER8         = 0;
    parameter int unsigned WITH_RELU_LAYER8        = 0;
    parameter int unsigned STEP_ROW_LAYER8         = 1;
    parameter int unsigned STEP_COL_LAYER8         = 1;
    parameter USE_DSP_PE_LAYER8                    = "no";
  
    // 2. 位宽参数 (来自 MAT)  
    parameter int unsigned DATA_WIDTH_LAYER8       = 8;
    parameter int unsigned WEIGHT_WIDTH_LAYER8     = 9;
    parameter int unsigned BIAS_WIDTH_LAYER8       = 16;
    parameter int unsigned OUT_WIDTH_LAYER8        = 9;

    // 3. 周期与映射参数
    parameter int unsigned CYCLE_PERIOD_IN_LAYER8  = 16; 
    parameter int unsigned CYCLE_PERIOD_OUT_LAYER8 = 32;
    parameter int unsigned CYCLE_PERIOD_LAYER8     = CYCLE_PERIOD_IN_LAYER8 * CYCLE_PERIOD_OUT_LAYER8;
    parameter int unsigned SHIFT_KEY_LAYER8        = 9;

    // 4. 图像尺寸
    parameter int unsigned IMG_COL_LAYER8          = 80;
    parameter int unsigned IMG_ROW_LAYER8          = 45;

    // 5. 自动计算的中间位宽
    parameter int unsigned PE_PAGE_OUTPUT_WIDTH_LAYER8 = 17;
    parameter int unsigned ACC_WIDTH_LAYER8        = 22;

    /* Simulation Paths */
    localparam INPUT_FILE_PATH_LAYER8       = "C:/Users/Datou21/Desktop/PDS/cnn_usb_copy/conv_data_hex/layer8_input_8bit.hex";
    localparam OUTPUT_FILE_PATH_LAYER8      = "sim_out/layer8_output.hex";

`endif // LAYER8_VH
