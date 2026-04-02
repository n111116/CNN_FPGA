// =============================================================================
// File Name   : layer3.vh
// Description : Auto-generated configuration parameters for CNN Layer: node_conv2d_3.
// =============================================================================

`ifndef LAYER3_VH
`define LAYER3_VH
    parameter int unsigned LAYER_NUM_LAYER3 = 3;

    // 1. 架构参数
    parameter int unsigned PE_PAGE_NUM_LAYER3      = 1;
    parameter int unsigned PE_COL_NUM_LAYER3       = 2;  
    parameter int unsigned PE_ROW_NUM_LAYER3       = 9;  
    parameter int unsigned KERNEL_COL_LAYER3       = 3;
    parameter int unsigned KERNEL_ROW_LAYER3       = 3;  
    parameter int unsigned CHANNEL_OUT_NUM_LAYER3  = 32;
    parameter int unsigned CHANNEL_IN_NUM_LAYER3   = 32;  
    parameter int unsigned MAX_POOL_LAYER3         = 0;
    parameter int unsigned WITH_RELU_LAYER3        = 1;
    parameter int unsigned STEP_ROW_LAYER3         = 2;
    parameter int unsigned STEP_COL_LAYER3         = 2;
    parameter USE_DSP_PE_LAYER3                    = "yes";
  
    // 2. 位宽参数 (来自 MAT)  
    parameter int unsigned DATA_WIDTH_LAYER3       = 8;
    parameter int unsigned WEIGHT_WIDTH_LAYER3     = 9;
    parameter int unsigned BIAS_WIDTH_LAYER3       = 16;
    parameter int unsigned OUT_WIDTH_LAYER3        = 8;

    // 3. 周期与映射参数
    parameter int unsigned CYCLE_PERIOD_IN_LAYER3  = 32; 
    parameter int unsigned CYCLE_PERIOD_OUT_LAYER3 = 16;
    parameter int unsigned CYCLE_PERIOD_LAYER3     = CYCLE_PERIOD_IN_LAYER3 * CYCLE_PERIOD_OUT_LAYER3;
    parameter int unsigned SHIFT_KEY_LAYER3        = 9;

    // 4. 图像尺寸
    parameter int unsigned IMG_COL_LAYER3          = 160;
    parameter int unsigned IMG_ROW_LAYER3          = 90;

    // 5. 自动计算的中间位宽
    parameter int unsigned PE_PAGE_OUTPUT_WIDTH_LAYER3 = 21;
    parameter int unsigned ACC_WIDTH_LAYER3        = 26;

    /* Simulation Paths */
    localparam INPUT_FILE_PATH_LAYER3       = "C:/Users/24455/Desktop/FPGA/prj/cnn_usb_copy_0323/cnn_usb_copy/conv_data_hex/layer3_input_8bit.hex";
    localparam OUTPUT_FILE_PATH_LAYER3      = "sim_out/layer3_output.hex";

`endif // LAYER3_VH
