// =============================================================================
// File Name   : layer0.vh
// Description : Auto-generated configuration parameters for CNN Layer: node_conv2d.
// =============================================================================

`ifndef LAYER0_VH
`define LAYER0_VH
    parameter int unsigned LAYER_NUM_LAYER0 = 0;

    // 1. 架构参数
    parameter int unsigned PE_PAGE_NUM_LAYER0      = 3;
    parameter int unsigned PE_COL_NUM_LAYER0       = 2;  
    parameter int unsigned PE_ROW_NUM_LAYER0       = 9;  
    parameter int unsigned KERNEL_COL_LAYER0       = 3;
    parameter int unsigned KERNEL_ROW_LAYER0       = 3;  
    parameter int unsigned CHANNEL_OUT_NUM_LAYER0  = 16;
    parameter int unsigned CHANNEL_IN_NUM_LAYER0   = 3;  
    parameter int unsigned MAX_POOL_LAYER0         = 0;
    parameter int unsigned WITH_RELU_LAYER0        = 1;
    parameter int unsigned STEP_ROW_LAYER0         = 2;
    parameter int unsigned STEP_COL_LAYER0         = 2;
    parameter USE_DSP_PE_LAYER0                    = "yes";
  
    // 2. 位宽参数 (来自 MAT)  
    parameter int unsigned DATA_WIDTH_LAYER0       = 8;
    parameter int unsigned WEIGHT_WIDTH_LAYER0     = 9;
    parameter int unsigned BIAS_WIDTH_LAYER0       = 15;
    parameter int unsigned OUT_WIDTH_LAYER0        = 8;

    // 3. 周期与映射参数
    parameter int unsigned CYCLE_PERIOD_IN_LAYER0  = 1; 
    parameter int unsigned CYCLE_PERIOD_OUT_LAYER0 = 8;
    parameter int unsigned CYCLE_PERIOD_LAYER0     = CYCLE_PERIOD_IN_LAYER0 * CYCLE_PERIOD_OUT_LAYER0;
    parameter int unsigned SHIFT_KEY_LAYER0        = 8;

    // 4. 图像尺寸
    parameter int unsigned IMG_COL_LAYER0          = 1280;
    parameter int unsigned IMG_ROW_LAYER0          = 720;

    // 5. 自动计算的中间位宽
    parameter int unsigned PE_PAGE_OUTPUT_WIDTH_LAYER0 = 21;
    parameter int unsigned ACC_WIDTH_LAYER0        = 22;

    /* Simulation Paths */
    localparam INPUT_FILE_PATH_LAYER0       = "C:/Users/Datou21/Desktop/PDS/cnn_usb_copy/conv_data_hex/layer0_input_8bit.hex";
    localparam OUTPUT_FILE_PATH_LAYER0      = "sim_out/layer0_output.hex";

`endif // LAYER0_VH
