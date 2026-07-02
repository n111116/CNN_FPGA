// =============================================================================
// File Name   : layer23.vh
// Description : Auto-generated configuration parameters for CNN Layer: node_conv2d_2.
// =============================================================================

`ifndef LAYER23_VH
`define LAYER23_VH
    parameter int unsigned LAYER_NUM_LAYER23 = 23;

    // 1. 架构参数
    parameter int unsigned PE_PAGE_NUM_LAYER23      = 2;
    parameter int unsigned PE_COL_NUM_LAYER23       = 2;  
    parameter int unsigned PE_ROW_NUM_LAYER23       = 9;  
    parameter int unsigned KERNEL_COL_LAYER23       = 3;
    parameter int unsigned KERNEL_ROW_LAYER23       = 3;  
    parameter int unsigned CHANNEL_OUT_NUM_LAYER23  = 16;
    parameter int unsigned CHANNEL_IN_NUM_LAYER23   = 16;  
    parameter int unsigned MAX_POOL_LAYER23         = 0;
    parameter int unsigned WITH_RELU_LAYER23        = 1;
    parameter int unsigned STEP_ROW_LAYER23         = 1;
    parameter int unsigned STEP_COL_LAYER23         = 1;
    parameter USE_DSP_PE_LAYER23                    = "no";
  
    // 2. 位宽参数 (来自 MAT)  
    parameter int unsigned DATA_WIDTH_LAYER23       = 9;
    parameter int unsigned WEIGHT_WIDTH_LAYER23     = 10;
    parameter int unsigned BIAS_WIDTH_LAYER23       = 19;
    parameter int unsigned OUT_WIDTH_LAYER23        = 9;

    // 3. 周期与映射参数
    parameter int unsigned CYCLE_PERIOD_IN_LAYER23  = 8; 
    parameter int unsigned CYCLE_PERIOD_OUT_LAYER23 = 8;
    parameter int unsigned CYCLE_PERIOD_LAYER23     = CYCLE_PERIOD_IN_LAYER23 * CYCLE_PERIOD_OUT_LAYER23;
    parameter int unsigned SHIFT_KEY_LAYER23        = 10;

    // 4. 图像尺寸
    parameter int unsigned IMG_COL_LAYER23          = 80;
    parameter int unsigned IMG_ROW_LAYER23          = 20;

    // 5. 自动计算的中间位宽
    parameter int unsigned PE_PAGE_OUTPUT_WIDTH_LAYER23 = 23;
    parameter int unsigned ACC_WIDTH_LAYER23        = 27;

    /* Simulation Paths */
    localparam INPUT_FILE_PATH_LAYER23       = "C:/Users/Datou21/Desktop/PDS/back1/cnn_usb_copy/conv_data_hex_pds/layer23_input_9bit.hex";
    localparam OUTPUT_FILE_PATH_LAYER23      = "sim_out/layer23_output.hex";

`endif // LAYER23_VH
