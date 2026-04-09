// =============================================================================
// File Name   : layer1.vh
// Description : Auto-generated configuration parameters for CNN Layer: node_conv2d_1.
// =============================================================================

`ifndef LAYER1_VH
`define LAYER1_VH
    parameter int unsigned LAYER_NUM_LAYER1 = 1;

    // 1. 架构参数
    parameter int unsigned PE_PAGE_NUM_LAYER1      = 2;
    parameter int unsigned PE_COL_NUM_LAYER1       = 4;  
    parameter int unsigned PE_ROW_NUM_LAYER1       = 9;  
    parameter int unsigned KERNEL_COL_LAYER1       = 3;
    parameter int unsigned KERNEL_ROW_LAYER1       = 3;  
    parameter int unsigned CHANNEL_OUT_NUM_LAYER1  = 16;
    parameter int unsigned CHANNEL_IN_NUM_LAYER1   = 16;  
    parameter int unsigned MAX_POOL_LAYER1         = 0;
    parameter int unsigned WITH_RELU_LAYER1        = 1;
    parameter int unsigned STEP_ROW_LAYER1         = 2;
    parameter int unsigned STEP_COL_LAYER1         = 2;
    parameter USE_DSP_PE_LAYER1                    = "yes";
  
    // 2. 位宽参数 (来自 MAT)  
    parameter int unsigned DATA_WIDTH_LAYER1       = 8;
    parameter int unsigned WEIGHT_WIDTH_LAYER1     = 9;
    parameter int unsigned BIAS_WIDTH_LAYER1       = 15;
    parameter int unsigned OUT_WIDTH_LAYER1        = 8;

    // 3. 周期与映射参数
    parameter int unsigned CYCLE_PERIOD_IN_LAYER1  = 8; 
    parameter int unsigned CYCLE_PERIOD_OUT_LAYER1 = 4;
    parameter int unsigned CYCLE_PERIOD_LAYER1     = CYCLE_PERIOD_IN_LAYER1 * CYCLE_PERIOD_OUT_LAYER1;
    parameter int unsigned SHIFT_KEY_LAYER1        = 8;

    // 4. 图像尺寸
    parameter int unsigned IMG_COL_LAYER1          = 640;
    parameter int unsigned IMG_ROW_LAYER1          = 360;

    // 5. 自动计算的中间位宽
    parameter int unsigned PE_PAGE_OUTPUT_WIDTH_LAYER1 = 21;
    parameter int unsigned ACC_WIDTH_LAYER1        = 25;

    /* Simulation Paths */
    localparam INPUT_FILE_PATH_LAYER1       = "C:/Users/Datou21/Desktop/PDS/cnn_usb_copy/conv_data_hex/layer1_input_8bit.hex";
    localparam OUTPUT_FILE_PATH_LAYER1      = "sim_out/layer1_output.hex";

`endif // LAYER1_VH
