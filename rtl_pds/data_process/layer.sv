// 单个层，根据不同的参数实现不同的功能
// MAX_POOL为1时是池化层，反之为卷积层

module layer #(
    parameter LAYER_NUM        = 1,  
    parameter PE_PAGE_NUM      = 3,   
    parameter PE_ROW_NUM       = 9, 
    parameter KERNEL_COL       = 3,  
    parameter KERNEL_ROW       = 3,   
    parameter PE_COL_NUM       = 4, 
    parameter MAX_POOL         = 1,  
    parameter WITH_RELU        = 1, 
    parameter DATA_WIDTH       = 7,
    parameter WEIGHT_WIDTH     = 9,
    parameter CYCLE_PERIOD_OUT = 4,   
    parameter CYCLE_PERIOD_IN  = 1, 
    parameter CYCLE_PERIOD     = CYCLE_PERIOD_OUT * CYCLE_PERIOD_IN,   
    parameter IMG_COL          = 128, 
    parameter IMG_ROW          = 128,
    parameter STEP_ROW         = 1,
    parameter STEP_COL         = 1,
    parameter BIAS_FILE        = "",      // 保留接口兼容，内部不再使用
    parameter USE_DSP_PE       = "no",    
    parameter SHIFT_KEY        = 9,    
    parameter BIAS_WIDTH       = 14,  
    parameter OUT_WIDTH        = 8, 
    
    parameter PE_PAGE_OUTPUT_WIDTH = DATA_WIDTH + WEIGHT_WIDTH + $clog2(PE_ROW_NUM + 1),
    parameter ACC_WIDTH   = PE_PAGE_OUTPUT_WIDTH + $clog2(PE_PAGE_NUM)
) (
    input  logic                     clk,
    input  logic                     clk_en,
    input  logic                     rst_n,        
    
    input  logic                     new_line_input_1,
    
    input  logic                     data_input_valid,
    input  logic [PE_PAGE_NUM-1:0][DATA_WIDTH-1:0]    data_input,
    
    output logic [PE_COL_NUM-1:0][OUT_WIDTH-1:0]      y_out,
    output logic                     new_line_out_1,
    output logic                     output_valid 
);

    // =============================================================
    // 0. 终极兼容宏定义：将纯正的字符串常量直接硬编码送入子模块
    // 彻底避开 PDS 所有的字符串推断 Bug
    // =============================================================
    `define INST_PE(L, P, F) \
        if (LAYER_NUM == L && p == P) begin : pe_inst \
            pe_page #( \
                .PE_ROW_NUM(PE_ROW_NUM), .PE_COL_NUM(PE_COL_NUM), .DATA_WIDTH(DATA_WIDTH), \
                .USE_DSP_PE(USE_DSP_PE), .WEIGHT_WIDTH(WEIGHT_WIDTH), .CYCLE_PERIOD(CYCLE_PERIOD), \
                .OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH), .WEIGHT_FILE(F) \
            ) u_pe_page ( \
                .clk(clk), .clk_en(clk_en), .new_line_1(new_line_inner_1), \
                .data(data_in_for_page), .y_out(page_y_out[p]) \
            ); \
        end else

    `define INST_OUT(L, F) \
        if (LAYER_NUM == L) begin : out_inst \
            output_layer #( \
                .PE_PAGE_NUM(PE_PAGE_NUM), .PE_COL_NUM(PE_COL_NUM), .PE_ROW_NUM(PE_ROW_NUM), \
                .WITH_RELU(WITH_RELU), .PE_OUT_WIDTH(PE_PAGE_OUTPUT_WIDTH), .BIAS_WIDTH(BIAS_WIDTH), \
                .ACC_WIDTH(ACC_WIDTH), .SHIFT_KEY(SHIFT_KEY), .OUT_WIDTH(OUT_WIDTH), \
                .IMG_COL(IMG_COL / STEP_COL), .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT), \
                .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN), .CYCLE_PERIOD(CYCLE_PERIOD), .BIAS_FILE(F) \
            ) u_output_layer ( \
                .clk(clk), .clk_en(clk_en), .rst_n(rst_n), \
                .new_line_in(new_line_inner_1), .page_y_out(page_y_out), \
                .final_out(conv_y_out), .output_valid(conv_valid), .new_line_out_1(conv_new_line_1) \
            ); \
        end else

    // =============================================================
    // 1. 实例化 Input Layer
    // =============================================================
    logic [PE_ROW_NUM-1:0][PE_PAGE_NUM-1:0][DATA_WIDTH-1:0] window_data;
    logic window_valid;
    logic new_line_inner_1;

    logic new_line_input_1_d;
    always @(posedge clk) begin
        new_line_input_1_d <= new_line_input_1;
    end
    
    input_layer #(
        .DATA_WIDTH(DATA_WIDTH),
        .PE_PAGE_NUM(PE_PAGE_NUM),
        .PE_ROW_NUM(PE_ROW_NUM),
        .KERNEL_COL(KERNEL_COL),
        .KERNEL_ROW(KERNEL_ROW),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT),
        .STEP_COL(STEP_COL),
        .STEP_ROW(STEP_ROW),
        .IMG_COL(IMG_COL),
        .IMG_ROW(IMG_ROW)
    ) u_input_layer (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(rst_n),
        .new_line_input_1(new_line_input_1), 
        
        .data_input_valid(data_input_valid), 
        .data_input(data_input),             
        .data_out(window_data),
        .line_buf_full(),
        .data_out_valid(window_valid),
        .new_line_out_1(new_line_inner_1)
    );

    // =============================================================
    // 2. PE 计算阵列
    // =============================================================
    logic signed [PE_PAGE_NUM-1:0][PE_COL_NUM-1:0][PE_PAGE_OUTPUT_WIDTH-1:0] page_y_out;

    genvar p, r;
    generate
        if(MAX_POOL == 0) begin
            for (p = 0; p < PE_PAGE_NUM; p = p + 1) begin : gen_pages

                logic [PE_ROW_NUM-1:0][DATA_WIDTH-1:0] data_in_for_page;
                for (r = 0; r < PE_ROW_NUM; r = r + 1) begin : map_data
                    assign data_in_for_page[r] = window_data[r][p];
                end

                // 强制将静态字符串塞入 pe_page 模块（涵盖了常见网络的所有可能组合）
                `INST_PE( 0,  0, "mem_data/weight_layer0_page0.mem")   `INST_PE( 0,  1, "mem_data/weight_layer0_page1.mem")
                `INST_PE( 0,  2, "mem_data/weight_layer0_page2.mem")   `INST_PE( 0,  3, "mem_data/weight_layer0_page3.mem")
                
                `INST_PE( 1,  0, "mem_data/weight_layer1_page0.mem")   `INST_PE( 1,  1, "mem_data/weight_layer1_page1.mem")
                `INST_PE( 1,  2, "mem_data/weight_layer1_page2.mem")   `INST_PE( 1,  3, "mem_data/weight_layer1_page3.mem")
                
                `INST_PE( 2,  0, "mem_data/weight_layer2_page0.mem")   `INST_PE( 2,  1, "mem_data/weight_layer2_page1.mem")
                `INST_PE( 2,  2, "mem_data/weight_layer2_page2.mem")   `INST_PE( 2,  3, "mem_data/weight_layer2_page3.mem")
                
                `INST_PE( 3,  0, "mem_data/weight_layer3_page0.mem")   `INST_PE( 3,  1, "mem_data/weight_layer3_page1.mem")
                `INST_PE( 3,  2, "mem_data/weight_layer3_page2.mem")   `INST_PE( 3,  3, "mem_data/weight_layer3_page3.mem")
                
                `INST_PE( 4,  0, "mem_data/weight_layer4_page0.mem")   `INST_PE( 4,  1, "mem_data/weight_layer4_page1.mem")
                `INST_PE( 4,  2, "mem_data/weight_layer4_page2.mem")   `INST_PE( 4,  3, "mem_data/weight_layer4_page3.mem")
                
                `INST_PE( 5,  0, "mem_data/weight_layer5_page0.mem")   `INST_PE( 5,  1, "mem_data/weight_layer5_page1.mem")
                `INST_PE( 5,  2, "mem_data/weight_layer5_page2.mem")   `INST_PE( 5,  3, "mem_data/weight_layer5_page3.mem")
                
                `INST_PE( 6,  0, "mem_data/weight_layer6_page0.mem")   `INST_PE( 6,  1, "mem_data/weight_layer6_page1.mem")
                `INST_PE( 6,  2, "mem_data/weight_layer6_page2.mem")   `INST_PE( 6,  3, "mem_data/weight_layer6_page3.mem")
                `INST_PE( 6,  4, "mem_data/weight_layer6_page4.mem")   `INST_PE( 6,  5, "mem_data/weight_layer6_page5.mem")
                
                `INST_PE( 7,  0, "mem_data/weight_layer7_page0.mem")   `INST_PE( 7,  1, "mem_data/weight_layer7_page1.mem")
                `INST_PE( 7,  2, "mem_data/weight_layer7_page2.mem")   `INST_PE( 7,  3, "mem_data/weight_layer7_page3.mem")
                `INST_PE( 7,  4, "mem_data/weight_layer7_page4.mem")   `INST_PE( 7,  5, "mem_data/weight_layer7_page5.mem")
                
                `INST_PE( 8,  0, "mem_data/weight_layer8_page0.mem")   `INST_PE( 8,  1, "mem_data/weight_layer8_page1.mem")
                `INST_PE( 8,  2, "mem_data/weight_layer8_page2.mem")   `INST_PE( 8,  3, "mem_data/weight_layer8_page3.mem")
                `INST_PE( 8,  4, "mem_data/weight_layer8_page4.mem")   `INST_PE( 8,  5, "mem_data/weight_layer8_page5.mem")

                `INST_PE( 9,  0, "mem_data/weight_layer9_page0.mem")   `INST_PE( 9,  1, "mem_data/weight_layer9_page1.mem")
                `INST_PE( 9,  2, "mem_data/weight_layer9_page2.mem")   `INST_PE( 9,  3, "mem_data/weight_layer9_page3.mem")
                
                `INST_PE(10,  0, "mem_data/weight_layer10_page0.mem")  `INST_PE(10,  1, "mem_data/weight_layer10_page1.mem")
                `INST_PE(10,  2, "mem_data/weight_layer10_page2.mem")  `INST_PE(10,  3, "mem_data/weight_layer10_page3.mem")
                
                `INST_PE(11,  0, "mem_data/weight_layer11_page0.mem")  `INST_PE(11,  1, "mem_data/weight_layer11_page1.mem")
                `INST_PE(11,  2, "mem_data/weight_layer11_page2.mem")  `INST_PE(11,  3, "mem_data/weight_layer11_page3.mem")
                `INST_PE(11,  4, "mem_data/weight_layer11_page4.mem")  `INST_PE(11,  5, "mem_data/weight_layer11_page5.mem")
                `INST_PE(11,  6, "mem_data/weight_layer11_page6.mem")  `INST_PE(11,  7, "mem_data/weight_layer11_page7.mem")
                `INST_PE(11,  8, "mem_data/weight_layer11_page8.mem")  `INST_PE(11,  9, "mem_data/weight_layer11_page9.mem")
                
                `INST_PE(20,  0, "mem_data/weight_layer20_page0.mem")  `INST_PE(20,  1, "mem_data/weight_layer20_page1.mem")
                `INST_PE(21,  0, "mem_data/weight_layer21_page0.mem")  `INST_PE(21,  1, "mem_data/weight_layer21_page1.mem")
                `INST_PE(22,  0, "mem_data/weight_layer22_page0.mem")  `INST_PE(22,  1, "mem_data/weight_layer22_page1.mem")
                `INST_PE(23,  0, "mem_data/weight_layer23_page0.mem")  `INST_PE(23,  1, "mem_data/weight_layer23_page1.mem")
                `INST_PE(24,  0, "mem_data/weight_layer24_page0.mem")  `INST_PE(24,  1, "mem_data/weight_layer24_page1.mem")
                `INST_PE(25,  0, "mem_data/weight_layer25_page0.mem")  `INST_PE(25,  1, "mem_data/weight_layer25_page1.mem")
                `INST_PE(26,  0, "mem_data/weight_layer26_page0.mem")  `INST_PE(26,  1, "mem_data/weight_layer26_page1.mem")
                `INST_PE(27,  0, "mem_data/weight_layer27_page0.mem")  `INST_PE(27,  1, "mem_data/weight_layer27_page1.mem")
                `INST_PE(28,  0, "mem_data/weight_layer28_page0.mem")  `INST_PE(28,  1, "mem_data/weight_layer28_page1.mem")
                `INST_PE(29,  0, "mem_data/weight_layer29_page0.mem")  `INST_PE(29,  1, "mem_data/weight_layer29_page1.mem")
                `INST_PE(30,  0, "mem_data/weight_layer30_page0.mem")  `INST_PE(30,  1, "mem_data/weight_layer30_page1.mem")
                `INST_PE(31,  0, "mem_data/weight_layer31_page0.mem")  `INST_PE(31,  1, "mem_data/weight_layer31_page1.mem")
                
                `INST_PE(20,  2, "mem_data/weight_layer20_page2.mem")  `INST_PE(20,  3, "mem_data/weight_layer20_page3.mem")
                `INST_PE(21,  2, "mem_data/weight_layer21_page2.mem")  `INST_PE(21,  3, "mem_data/weight_layer21_page3.mem")
                `INST_PE(22,  2, "mem_data/weight_layer22_page2.mem")  `INST_PE(22,  3, "mem_data/weight_layer22_page3.mem")
                `INST_PE(23,  2, "mem_data/weight_layer23_page2.mem")  `INST_PE(23,  3, "mem_data/weight_layer23_page3.mem")
                `INST_PE(24,  2, "mem_data/weight_layer24_page2.mem")  `INST_PE(24,  3, "mem_data/weight_layer24_page3.mem")
                `INST_PE(25,  2, "mem_data/weight_layer25_page2.mem")  `INST_PE(25,  3, "mem_data/weight_layer25_page3.mem")
                `INST_PE(26,  2, "mem_data/weight_layer26_page2.mem")  `INST_PE(26,  3, "mem_data/weight_layer26_page3.mem")
                `INST_PE(27,  2, "mem_data/weight_layer27_page2.mem")  `INST_PE(27,  3, "mem_data/weight_layer27_page3.mem")
                `INST_PE(28,  2, "mem_data/weight_layer28_page2.mem")  `INST_PE(28,  3, "mem_data/weight_layer28_page3.mem")
                `INST_PE(29,  2, "mem_data/weight_layer29_page2.mem")  `INST_PE(29,  3, "mem_data/weight_layer29_page3.mem")
                `INST_PE(30,  2, "mem_data/weight_layer30_page2.mem")  `INST_PE(30,  3, "mem_data/weight_layer30_page3.mem")
                `INST_PE(31,  2, "mem_data/weight_layer31_page2.mem")  `INST_PE(31,  3, "mem_data/weight_layer31_page3.mem")
                
                `INST_PE(21,  4, "mem_data/weight_layer21_page4.mem")  `INST_PE(21,  5, "mem_data/weight_layer21_page5.mem")
                `INST_PE(22,  4, "mem_data/weight_layer22_page4.mem")  `INST_PE(22,  5, "mem_data/weight_layer22_page5.mem")
                `INST_PE(23,  4, "mem_data/weight_layer23_page4.mem")  `INST_PE(23,  5, "mem_data/weight_layer23_page5.mem")
                `INST_PE(24,  4, "mem_data/weight_layer24_page4.mem")  `INST_PE(24,  5, "mem_data/weight_layer24_page5.mem")
                `INST_PE(25,  4, "mem_data/weight_layer25_page4.mem")  `INST_PE(25,  5, "mem_data/weight_layer25_page5.mem")
                `INST_PE(26,  4, "mem_data/weight_layer26_page4.mem")  `INST_PE(26,  5, "mem_data/weight_layer26_page5.mem")
                `INST_PE(27,  4, "mem_data/weight_layer27_page4.mem")  `INST_PE(27,  5, "mem_data/weight_layer27_page5.mem")
                `INST_PE(28,  4, "mem_data/weight_layer28_page4.mem")  `INST_PE(28,  5, "mem_data/weight_layer28_page5.mem")
                
                `INST_PE(21,  6, "mem_data/weight_layer21_page6.mem")  `INST_PE(21,  7, "mem_data/weight_layer21_page7.mem")
                `INST_PE(22,  6, "mem_data/weight_layer22_page6.mem")  `INST_PE(22,  7, "mem_data/weight_layer22_page7.mem")
                `INST_PE(23,  6, "mem_data/weight_layer23_page6.mem")  `INST_PE(23,  7, "mem_data/weight_layer23_page7.mem")
                `INST_PE(24,  6, "mem_data/weight_layer24_page6.mem")  `INST_PE(24,  7, "mem_data/weight_layer24_page7.mem")
                `INST_PE(25,  6, "mem_data/weight_layer25_page6.mem")  `INST_PE(25,  7, "mem_data/weight_layer25_page7.mem")
                `INST_PE(26,  6, "mem_data/weight_layer26_page6.mem")  `INST_PE(26,  7, "mem_data/weight_layer26_page7.mem")
                `INST_PE(27,  6, "mem_data/weight_layer27_page6.mem")  `INST_PE(27,  7, "mem_data/weight_layer27_page7.mem")
                `INST_PE(28,  6, "mem_data/weight_layer28_page6.mem")  `INST_PE(28,  7, "mem_data/weight_layer28_page7.mem")

                begin : dummy_pe
                    // 托底保护，防综合器报错
                end
            end
            
            // =============================================================
            // 3. 实例化 Output Layer (累加、Bias、ReLU)
            // =============================================================
            logic [PE_COL_NUM-1:0][OUT_WIDTH-1:0] conv_y_out;
            logic                 conv_new_line_1;
            logic                 conv_valid;

            // 强制将静态偏置字符串塞入 output_layer 模块。
            // PDS 对较长的 generate if/else 链在尾部层号上偶尔会过度优化；
            // LPRNet V10 的层号整体提前匹配，避免后端只展开前几层。
            `INST_OUT(20, "mem_data/bias_layer20.mem")
            `INST_OUT(21, "mem_data/bias_layer21.mem")
            `INST_OUT(22, "mem_data/bias_layer22.mem")
            `INST_OUT(23, "mem_data/bias_layer23.mem")
            `INST_OUT(24, "mem_data/bias_layer24.mem")
            `INST_OUT(25, "mem_data/bias_layer25.mem")
            `INST_OUT(26, "mem_data/bias_layer26.mem")
            `INST_OUT(27, "mem_data/bias_layer27.mem")
            `INST_OUT(28, "mem_data/bias_layer28.mem")
            `INST_OUT(29, "mem_data/bias_layer29.mem")
            `INST_OUT(30, "mem_data/bias_layer30.mem")
            `INST_OUT(31, "mem_data/bias_layer31.mem")

            `INST_OUT( 0, "mem_data/bias_layer0.mem")
            `INST_OUT( 1, "mem_data/bias_layer1.mem")
            `INST_OUT( 2, "mem_data/bias_layer2.mem")
            `INST_OUT( 3, "mem_data/bias_layer3.mem")
            `INST_OUT( 4, "mem_data/bias_layer4.mem")
            `INST_OUT( 5, "mem_data/bias_layer5.mem")
            `INST_OUT( 6, "mem_data/bias_layer6.mem")
            `INST_OUT( 7, "mem_data/bias_layer7.mem")
            `INST_OUT( 8, "mem_data/bias_layer8.mem")
            `INST_OUT( 9, "mem_data/bias_layer9.mem")
            `INST_OUT(10, "mem_data/bias_layer10.mem")
            `INST_OUT(11, "mem_data/bias_layer11.mem")
            begin : dummy_out
            end
            
            assign y_out = conv_y_out;
            assign output_valid = conv_valid;
            assign new_line_out_1 = conv_new_line_1;
            
        end else begin
            for (p = 0; p < PE_PAGE_NUM; p = p + 1) begin : gen_pages

                logic [PE_ROW_NUM-1:0][DATA_WIDTH-1:0] data_in_for_page;
                for (r = 0; r < PE_ROW_NUM; r = r + 1) begin : map_data
                    assign data_in_for_page[r] = window_data[r][p];
                end
                
                logic [OUT_WIDTH-1:0] pool_y_out;
                logic                 pool_new_line_1;
                logic                 pool_valid;
                max_pool2d #(
                    .PE_ROW_NUM(PE_ROW_NUM),
                    .DATA_WIDTH(DATA_WIDTH)
                ) u_max_pool2d (
                    .clk(clk),
                    .rst_n(rst_n), 
                    .clk_en(clk_en), 
                    .new_line_1(new_line_inner_1),
                    .input_valid(window_valid),
                    .data(data_in_for_page),
                    .new_line_out_1(pool_new_line_1),
                    .output_valid(pool_valid),
                    .y_out(pool_y_out)
                );
                if(p == 0) begin
                    assign output_valid = pool_valid;
                    assign new_line_out_1 = pool_new_line_1;
                end
                // 列数等于page数
                assign y_out[p] = pool_y_out;
            end
        end
    endgenerate

endmodule

// LPRNet 专用直接例化层。
// 与 layer 的计算结构相同，但权重和 bias 文件由上层直接传入，
// 避免 PDS 在很长的 LAYER_NUM generate if/else 链中错展开。
module lprnet_layer_direct #(
    parameter PE_PAGE_NUM      = 3,
    parameter PE_ROW_NUM       = 9,
    parameter KERNEL_COL       = 3,
    parameter KERNEL_ROW       = 3,
    parameter PE_COL_NUM       = 4,
    parameter MAX_POOL         = 0,
    parameter WITH_RELU        = 1,
    parameter DATA_WIDTH       = 7,
    parameter WEIGHT_WIDTH     = 9,
    parameter CYCLE_PERIOD_OUT = 4,
    parameter CYCLE_PERIOD_IN  = 1,
    parameter CYCLE_PERIOD     = CYCLE_PERIOD_OUT * CYCLE_PERIOD_IN,
    parameter IMG_COL          = 128,
    parameter IMG_ROW          = 128,
    parameter STEP_ROW         = 1,
    parameter STEP_COL         = 1,
    parameter USE_DSP_PE       = "no",
    parameter SHIFT_KEY        = 9,
    parameter BIAS_WIDTH       = 14,
    parameter OUT_WIDTH        = 8,
    parameter PE_PAGE_OUTPUT_WIDTH = DATA_WIDTH + WEIGHT_WIDTH + $clog2(PE_ROW_NUM + 1),
    parameter ACC_WIDTH        = PE_PAGE_OUTPUT_WIDTH + $clog2(PE_PAGE_NUM),
    parameter WEIGHT_FILE0     = "mem_data/weight_layer20_page0.mem",
    parameter WEIGHT_FILE1     = "mem_data/weight_layer20_page1.mem",
    parameter WEIGHT_FILE2     = "mem_data/weight_layer20_page2.mem",
    parameter WEIGHT_FILE3     = "mem_data/weight_layer20_page3.mem",
    parameter BIAS_FILE        = "mem_data/bias_layer20.mem"
) (
    input  logic                     clk,
    input  logic                     clk_en,
    input  logic                     rst_n,
    input  logic                     new_line_input_1,
    input  logic                     data_input_valid,
    input  logic [PE_PAGE_NUM-1:0][DATA_WIDTH-1:0] data_input,
    output logic [PE_COL_NUM-1:0][OUT_WIDTH-1:0]   y_out,
    output logic                     new_line_out_1,
    output logic                     output_valid
);

    logic [PE_ROW_NUM-1:0][PE_PAGE_NUM-1:0][DATA_WIDTH-1:0] window_data;
    logic window_valid;
    logic new_line_inner_1;

    input_layer #(
        .DATA_WIDTH(DATA_WIDTH),
        .PE_PAGE_NUM(PE_PAGE_NUM),
        .PE_ROW_NUM(PE_ROW_NUM),
        .KERNEL_COL(KERNEL_COL),
        .KERNEL_ROW(KERNEL_ROW),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT),
        .STEP_COL(STEP_COL),
        .STEP_ROW(STEP_ROW),
        .IMG_COL(IMG_COL),
        .IMG_ROW(IMG_ROW)
    ) u_input_layer (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(rst_n),
        .new_line_input_1(new_line_input_1),
        .data_input_valid(data_input_valid),
        .data_input(data_input),
        .data_out(window_data),
        .line_buf_full(),
        .data_out_valid(window_valid),
        .new_line_out_1(new_line_inner_1)
    );

    genvar p, r;
    generate
        if (MAX_POOL == 0) begin : gen_conv
            logic signed [PE_PAGE_NUM-1:0][PE_COL_NUM-1:0][PE_PAGE_OUTPUT_WIDTH-1:0] page_y_out;
            logic [PE_COL_NUM-1:0][OUT_WIDTH-1:0] conv_y_out;
            logic conv_new_line_1;
            logic conv_valid;

            for (p = 0; p < PE_PAGE_NUM; p = p + 1) begin : gen_pages
                logic [PE_ROW_NUM-1:0][DATA_WIDTH-1:0] data_in_for_page;

                for (r = 0; r < PE_ROW_NUM; r = r + 1) begin : map_data
                    assign data_in_for_page[r] = window_data[r][p];
                end

                if (p == 0) begin : page0
                    pe_page #(
                        .PE_ROW_NUM(PE_ROW_NUM), .PE_COL_NUM(PE_COL_NUM), .DATA_WIDTH(DATA_WIDTH),
                        .USE_DSP_PE(USE_DSP_PE), .WEIGHT_WIDTH(WEIGHT_WIDTH), .CYCLE_PERIOD(CYCLE_PERIOD),
                        .OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH), .WEIGHT_FILE(WEIGHT_FILE0)
                    ) u_pe_page (
                        .clk(clk), .clk_en(clk_en), .new_line_1(new_line_inner_1),
                        .data(data_in_for_page), .y_out(page_y_out[p])
                    );
                end else if (p == 1) begin : page1
                    pe_page #(
                        .PE_ROW_NUM(PE_ROW_NUM), .PE_COL_NUM(PE_COL_NUM), .DATA_WIDTH(DATA_WIDTH),
                        .USE_DSP_PE(USE_DSP_PE), .WEIGHT_WIDTH(WEIGHT_WIDTH), .CYCLE_PERIOD(CYCLE_PERIOD),
                        .OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH), .WEIGHT_FILE(WEIGHT_FILE1)
                    ) u_pe_page (
                        .clk(clk), .clk_en(clk_en), .new_line_1(new_line_inner_1),
                        .data(data_in_for_page), .y_out(page_y_out[p])
                    );
                end else if (p == 2) begin : page2
                    pe_page #(
                        .PE_ROW_NUM(PE_ROW_NUM), .PE_COL_NUM(PE_COL_NUM), .DATA_WIDTH(DATA_WIDTH),
                        .USE_DSP_PE(USE_DSP_PE), .WEIGHT_WIDTH(WEIGHT_WIDTH), .CYCLE_PERIOD(CYCLE_PERIOD),
                        .OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH), .WEIGHT_FILE(WEIGHT_FILE2)
                    ) u_pe_page (
                        .clk(clk), .clk_en(clk_en), .new_line_1(new_line_inner_1),
                        .data(data_in_for_page), .y_out(page_y_out[p])
                    );
                end else begin : page3
                    pe_page #(
                        .PE_ROW_NUM(PE_ROW_NUM), .PE_COL_NUM(PE_COL_NUM), .DATA_WIDTH(DATA_WIDTH),
                        .USE_DSP_PE(USE_DSP_PE), .WEIGHT_WIDTH(WEIGHT_WIDTH), .CYCLE_PERIOD(CYCLE_PERIOD),
                        .OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH), .WEIGHT_FILE(WEIGHT_FILE3)
                    ) u_pe_page (
                        .clk(clk), .clk_en(clk_en), .new_line_1(new_line_inner_1),
                        .data(data_in_for_page), .y_out(page_y_out[p])
                    );
                end
            end

            output_layer #(
                .PE_PAGE_NUM(PE_PAGE_NUM), .PE_COL_NUM(PE_COL_NUM), .PE_ROW_NUM(PE_ROW_NUM),
                .WITH_RELU(WITH_RELU), .PE_OUT_WIDTH(PE_PAGE_OUTPUT_WIDTH), .BIAS_WIDTH(BIAS_WIDTH),
                .ACC_WIDTH(ACC_WIDTH), .SHIFT_KEY(SHIFT_KEY), .OUT_WIDTH(OUT_WIDTH),
                .IMG_COL(IMG_COL / STEP_COL), .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT),
                .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN), .CYCLE_PERIOD(CYCLE_PERIOD), .BIAS_FILE(BIAS_FILE)
            ) u_output_layer (
                .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
                .new_line_in(new_line_inner_1), .page_y_out(page_y_out),
                .final_out(conv_y_out), .output_valid(conv_valid), .new_line_out_1(conv_new_line_1)
            );

            assign y_out          = conv_y_out;
            assign output_valid   = conv_valid;
            assign new_line_out_1 = conv_new_line_1;
        end else begin : gen_pool
            for (p = 0; p < PE_PAGE_NUM; p = p + 1) begin : gen_pages
                logic [PE_ROW_NUM-1:0][DATA_WIDTH-1:0] data_in_for_page;
                logic [OUT_WIDTH-1:0] pool_y_out;
                logic pool_new_line_1;
                logic pool_valid;

                for (r = 0; r < PE_ROW_NUM; r = r + 1) begin : map_data
                    assign data_in_for_page[r] = window_data[r][p];
                end

                max_pool2d #(
                    .PE_ROW_NUM(PE_ROW_NUM),
                    .DATA_WIDTH(DATA_WIDTH)
                ) u_max_pool2d (
                    .clk(clk),
                    .rst_n(rst_n),
                    .clk_en(clk_en),
                    .new_line_1(new_line_inner_1),
                    .input_valid(window_valid),
                    .data(data_in_for_page),
                    .new_line_out_1(pool_new_line_1),
                    .output_valid(pool_valid),
                    .y_out(pool_y_out)
                );

                if (p == 0) begin : valid_page
                    assign output_valid   = pool_valid;
                    assign new_line_out_1 = pool_new_line_1;
                end

                assign y_out[p] = pool_y_out;
            end
        end
    endgenerate

endmodule
