// =============================================================================
// File Name   : layer25.vh
// Description : Auto-generated configuration parameters for CNN Layer: node_max_pool2d_2.
// =============================================================================

`ifndef LAYER25_VH
`define LAYER25_VH
    parameter int unsigned LAYER_NUM_LAYER25 = 25;

    // 1. 架构参数
    parameter int unsigned PE_PAGE_NUM_LAYER25      = 1;
    parameter int unsigned PE_COL_NUM_LAYER25       = 1;  
    parameter int unsigned PE_ROW_NUM_LAYER25       = 9;  
    parameter int unsigned KERNEL_COL_LAYER25       = 3;
    parameter int unsigned KERNEL_ROW_LAYER25       = 3;  
    parameter int unsigned CHANNEL_OUT_NUM_LAYER25  = 64;
    parameter int unsigned CHANNEL_IN_NUM_LAYER25   = 64;  
    parameter int unsigned MAX_POOL_LAYER25         = 1;
    parameter int unsigned WITH_RELU_LAYER25        = 0;
    parameter int unsigned STEP_ROW_LAYER25         = 2;
    parameter int unsigned STEP_COL_LAYER25         = 1;
    parameter USE_DSP_PE_LAYER25                    = "no";
  
    // 2. 位宽参数 (来自 MAT)  
    parameter int unsigned DATA_WIDTH_LAYER25       = 9;
    parameter int unsigned WEIGHT_WIDTH_LAYER25     = 1;
    parameter int unsigned BIAS_WIDTH_LAYER25       = 1;
    parameter int unsigned OUT_WIDTH_LAYER25        = 9;

    // 3. 周期与映射参数
    parameter int unsigned CYCLE_PERIOD_IN_LAYER25  = 64; 
    parameter int unsigned CYCLE_PERIOD_OUT_LAYER25 = 64;
    parameter int unsigned CYCLE_PERIOD_LAYER25     = CYCLE_PERIOD_IN_LAYER25 * CYCLE_PERIOD_OUT_LAYER25;
    parameter int unsigned SHIFT_KEY_LAYER25        = 0;

    // 4. 图像尺寸
    parameter int unsigned IMG_COL_LAYER25          = 20;
    parameter int unsigned IMG_ROW_LAYER25          = 10;

    // 5. 自动计算的中间位宽
    parameter int unsigned PE_PAGE_OUTPUT_WIDTH_LAYER25 = 14;
    parameter int unsigned ACC_WIDTH_LAYER25        = 20;

    /* Simulation Paths */
    localparam INPUT_FILE_PATH_LAYER25       = "C:/Users/24455/Desktop/FPGA/prj/cnn_usb_copy_0323/cnn_usb_copy/conv_data_hex/layer25_input_9bit.hex";
    localparam OUTPUT_FILE_PATH_LAYER25      = "sim_out/layer25_output.hex";

`endif // LAYER25_VH
