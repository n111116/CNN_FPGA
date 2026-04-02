// =============================================================================
// File Name   : layer5.vh
// Description : Auto-generated configuration parameters for CNN Layer: node_conv2d_5.
// =============================================================================

`ifndef LAYER5_VH
`define LAYER5_VH
    parameter int unsigned LAYER_NUM_LAYER5 = 5;

    // 1. 架构参数
    parameter int unsigned PE_PAGE_NUM_LAYER5      = 2;
    parameter int unsigned PE_COL_NUM_LAYER5       = 4;  
    parameter int unsigned PE_ROW_NUM_LAYER5       = 9;  
    parameter int unsigned KERNEL_COL_LAYER5       = 3;
    parameter int unsigned KERNEL_ROW_LAYER5       = 3;  
    parameter int unsigned CHANNEL_OUT_NUM_LAYER5  = 64;
    parameter int unsigned CHANNEL_IN_NUM_LAYER5   = 64;  
    parameter int unsigned MAX_POOL_LAYER5         = 0;
    parameter int unsigned WITH_RELU_LAYER5        = 1;
    parameter int unsigned STEP_ROW_LAYER5         = 1;
    parameter int unsigned STEP_COL_LAYER5         = 1;
    parameter USE_DSP_PE_LAYER5                    = "no";
  
    // 2. 位宽参数 (来自 MAT)  
    parameter int unsigned DATA_WIDTH_LAYER5       = 8;
    parameter int unsigned WEIGHT_WIDTH_LAYER5     = 9;
    parameter int unsigned BIAS_WIDTH_LAYER5       = 19;
    parameter int unsigned OUT_WIDTH_LAYER5        = 8;

    // 3. 周期与映射参数
    parameter int unsigned CYCLE_PERIOD_IN_LAYER5  = 32; 
    parameter int unsigned CYCLE_PERIOD_OUT_LAYER5 = 16;
    parameter int unsigned CYCLE_PERIOD_LAYER5     = CYCLE_PERIOD_IN_LAYER5 * CYCLE_PERIOD_OUT_LAYER5;
    parameter int unsigned SHIFT_KEY_LAYER5        = 10;

    // 4. 图像尺寸
    parameter int unsigned IMG_COL_LAYER5          = 80;
    parameter int unsigned IMG_ROW_LAYER5          = 45;

    // 5. 自动计算的中间位宽
    parameter int unsigned PE_PAGE_OUTPUT_WIDTH_LAYER5 = 21;
    parameter int unsigned ACC_WIDTH_LAYER5        = 27;

    /* Simulation Paths */
    localparam INPUT_FILE_PATH_LAYER5       = "C:/Users/24455/Desktop/FPGA/prj/cnn_usb_copy_0323/cnn_usb_copy/conv_data_hex/layer5_input_8bit.hex";
    localparam OUTPUT_FILE_PATH_LAYER5      = "sim_out/layer5_output.hex";

`endif // LAYER5_VH
