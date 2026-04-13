// =============================================================================
// File Name   : layer20.vh
// Description : Auto-generated configuration parameters for CNN Layer: node_conv2d.
// =============================================================================

`ifndef LAYER20_VH
`define LAYER20_VH
    parameter int unsigned LAYER_NUM_LAYER20 = 20;

    // 1. 架构参数
    parameter int unsigned PE_PAGE_NUM_LAYER20      = 3;
    parameter int unsigned PE_COL_NUM_LAYER20       = 1;  
    parameter int unsigned PE_ROW_NUM_LAYER20       = 9;  
    parameter int unsigned KERNEL_COL_LAYER20       = 3;
    parameter int unsigned KERNEL_ROW_LAYER20       = 3;  
    parameter int unsigned CHANNEL_OUT_NUM_LAYER20  = 16;
    parameter int unsigned CHANNEL_IN_NUM_LAYER20   = 3;  
    parameter int unsigned MAX_POOL_LAYER20         = 0;
    parameter int unsigned WITH_RELU_LAYER20        = 1;
    parameter int unsigned STEP_ROW_LAYER20         = 1;
    parameter int unsigned STEP_COL_LAYER20         = 2;
    parameter USE_DSP_PE_LAYER20                    = "no";
  
    // 2. 位宽参数 (来自 MAT)  
    parameter int unsigned DATA_WIDTH_LAYER20       = 8;
    parameter int unsigned WEIGHT_WIDTH_LAYER20     = 10;
    parameter int unsigned BIAS_WIDTH_LAYER20       = 16;
    parameter int unsigned OUT_WIDTH_LAYER20        = 9;

    // 3. 周期与映射参数
    parameter int unsigned CYCLE_PERIOD_IN_LAYER20  = 1; 
    parameter int unsigned CYCLE_PERIOD_OUT_LAYER20 = 16;
    parameter int unsigned CYCLE_PERIOD_LAYER20     = CYCLE_PERIOD_IN_LAYER20 * CYCLE_PERIOD_OUT_LAYER20;
    parameter int unsigned SHIFT_KEY_LAYER20        = 8;

    // 4. 图像尺寸
    parameter int unsigned IMG_COL_LAYER20          = 144;
    parameter int unsigned IMG_ROW_LAYER20          = 40;

    // 5. 自动计算的中间位宽
    parameter int unsigned PE_PAGE_OUTPUT_WIDTH_LAYER20 = 22;
    parameter int unsigned ACC_WIDTH_LAYER20        = 23;

    /* Simulation Paths */
    localparam INPUT_FILE_PATH_LAYER20       = "C:/Users/Datou21/Desktop/PDS/cnn_usb_copy/conv_data_hex_pds/layer20_input_8bit.hex";
    localparam OUTPUT_FILE_PATH_LAYER20      = "sim_out/layer20_output.hex";

`endif // LAYER20_VH
