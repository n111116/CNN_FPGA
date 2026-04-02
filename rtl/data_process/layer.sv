// 单个层，根据不同的参数实现不同的功能
// MAX_POOL为1时是池化层，反之为卷积层

module layer #(
    parameter int unsigned LAYER_NUM        = 1,  
    parameter int unsigned PE_PAGE_NUM      = 3,   
    parameter int unsigned PE_ROW_NUM       = 9, 
    parameter int unsigned KERNEL_COL       = 3,  
    parameter int unsigned KERNEL_ROW       = 3,   
    parameter int unsigned PE_COL_NUM       = 4, 
    parameter int unsigned MAX_POOL         = 1,  
    parameter int unsigned WITH_RELU        = 1, 
    parameter int unsigned DATA_WIDTH       = 7,
    parameter int unsigned WEIGHT_WIDTH     = 9,
    parameter int unsigned CYCLE_PERIOD_OUT = 4,   
    parameter int unsigned CYCLE_PERIOD_IN  = 1, 
    parameter int unsigned CYCLE_PERIOD     = CYCLE_PERIOD_OUT * CYCLE_PERIOD_IN,   
    parameter int unsigned IMG_COL          = 128, 
    parameter int unsigned IMG_ROW          = 128,
    parameter int unsigned STEP_ROW         = 1,
    parameter int unsigned STEP_COL         = 1,
    // 偏置文件路径
    parameter string BIAS_FILE = $sformatf("bias_layer%0d.mem", LAYER_NUM),
    // parameter string WEIGHT_FILES [PE_PAGE_NUM-1:0] =  {{"weights_layer1_page2.mem"},
    //                                                     {"weights_layer1_page1.mem"},
    //                                                     {"weights_layer1_page0.mem"}},
    parameter        USE_DSP_PE          = "no",    
    parameter int unsigned SHIFT_KEY     = 9,    
    parameter int unsigned BIAS_WIDTH    = 14,  
    parameter int unsigned OUT_WIDTH     = 8, 
    
    parameter int unsigned PE_PAGE_OUTPUT_WIDTH = DATA_WIDTH + WEIGHT_WIDTH + $clog2(PE_ROW_NUM + 1),
    parameter int unsigned ACC_WIDTH   = PE_PAGE_OUTPUT_WIDTH + $clog2(PE_PAGE_NUM)
) (
    input  logic                     clk,
    input  logic                     clk_en,
    input  logic                     rst_n,        
    
    input  logic                     new_line_input_1,
    
    input  logic                     data_input_valid,
    input  logic [DATA_WIDTH-1:0]    data_input [PE_PAGE_NUM-1:0],
    
    
    output logic [OUT_WIDTH-1:0]     y_out [PE_COL_NUM-1:0],
    output logic                     new_line_out_1,
    output logic                     output_valid 
);

    // =============================================================
    // 1. 实例化 Input Layer
    // =============================================================
    logic [DATA_WIDTH-1:0] window_data [PE_ROW_NUM-1:0][PE_PAGE_NUM-1:0];
    logic window_valid;
    logic new_line_inner_1;

    // // [新增] 用于连接前置输入缓存与 input_layer 的中间信号
    // logic [DATA_WIDTH-1:0] buffered_data_input [PE_PAGE_NUM-1:0];
    // logic buffered_data_valid;
    // // 特殊情况，第20层和第21层的速度远快于第22层，我们增加第20层的行间隙并在22层输入前进行解耦
    // localparam BUFFER_DEPTH = LAYER_NUM == 22 ? CYCLE_PERIOD_IN*IMG_COL*3:CYCLE_PERIOD_IN + 1;
    // // [新增] 例化输入数据缓存模块
    // input_layer_buffer #(
    //     .PE_PAGE_NUM(PE_PAGE_NUM),
    //     .DATA_WIDTH(DATA_WIDTH),
    //     .DEPTH(BUFFER_DEPTH),
    //     .INTERVAL(CYCLE_PERIOD_OUT / STEP_ROW / STEP_COL)
    // ) u_input_buffer (
    //     .clk(clk),
    //     .clk_en(clk_en),
    //     .rst_n(rst_n),
    //     .data_input_valid(data_input_valid),
    //     .data_input(data_input),
    //     .data_out_valid(buffered_data_valid),
    //     .data_out(buffered_data_input)
    // );


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
        .new_line_input_1(new_line_input_1), // new_line_1 原样保持透传
        
        .data_input_valid(data_input_valid), // 接收缓冲后的 valid 信号
        .data_input(data_input),       // 接收缓冲后的数据
        .data_out(window_data),
        .data_out_valid(window_valid),
        .new_line_out_1(new_line_inner_1)
    );

    // =============================================================
    // 2. PE 计算阵列
    // =============================================================
    logic signed [PE_PAGE_OUTPUT_WIDTH-1:0] page_y_out [PE_PAGE_NUM-1:0][PE_COL_NUM-1:0];

    genvar p, r;
    generate
        if(MAX_POOL == 0) begin
            for (p = 0; p < PE_PAGE_NUM; p++) begin : gen_pages

                logic [DATA_WIDTH-1:0] data_in_for_page [PE_ROW_NUM-1:0];
                for (r = 0; r < PE_ROW_NUM; r++) begin : map_data
                    assign data_in_for_page[r] = window_data[r][p];
                end

                localparam string W_FILE = $sformatf("weight_layer%0d_page%0d.mem", LAYER_NUM, p);

                pe_page #(
                    .PE_ROW_NUM(PE_ROW_NUM),
                    .PE_COL_NUM(PE_COL_NUM), 
                    .DATA_WIDTH(DATA_WIDTH),
                    .USE_DSP_PE(USE_DSP_PE),
                    .WEIGHT_WIDTH(WEIGHT_WIDTH),
                    .CYCLE_PERIOD(CYCLE_PERIOD), 
                    .OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH),
                    .WEIGHT_FILE(W_FILE)
                ) u_pe_page (
                    .clk(clk),
                    .clk_en(clk_en), 
                    .new_line_1(new_line_inner_1),
                    .data(data_in_for_page),
                    .y_out(page_y_out[p])
                );
            end
            
            // =============================================================
            // 3. 实例化 Output Layer (累加、Bias、ReLU)
            // =============================================================
            // 中间信号：Output Layer -> Pooling Layer
            logic [OUT_WIDTH-1:0] conv_y_out [PE_COL_NUM-1:0];
            logic                 conv_new_line_1;
            logic                 conv_valid;

            output_layer #(
                .PE_PAGE_NUM(PE_PAGE_NUM),
                .PE_COL_NUM(PE_COL_NUM),
                .PE_ROW_NUM(PE_ROW_NUM),
                .WITH_RELU(WITH_RELU),
                .PE_OUT_WIDTH(PE_PAGE_OUTPUT_WIDTH),
                .BIAS_WIDTH(BIAS_WIDTH),        
                .ACC_WIDTH(ACC_WIDTH),         
                .SHIFT_KEY(SHIFT_KEY),
                .OUT_WIDTH(OUT_WIDTH),
                .IMG_COL (IMG_COL / STEP_COL),
                .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT),
                .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN),
                .CYCLE_PERIOD(CYCLE_PERIOD),
                .BIAS_FILE(BIAS_FILE)
            ) u_output_layer (
                .clk(clk),
                .clk_en(clk_en),
                .rst_n(rst_n),
                
                .new_line_in(new_line_inner_1),
                .page_y_out(page_y_out),
                
                .final_out(conv_y_out),
                .output_valid(conv_valid),
                .new_line_out_1(conv_new_line_1)
            );
            assign y_out = conv_y_out;
            assign output_valid = conv_valid;
            assign new_line_out_1 = conv_new_line_1;
        end else begin
            for (p = 0; p < PE_PAGE_NUM; p++) begin : gen_pages

                logic [DATA_WIDTH-1:0] data_in_for_page [PE_ROW_NUM-1:0];
                for (r = 0; r < PE_ROW_NUM; r++) begin : map_data
                    assign data_in_for_page[r] = window_data[r][p];
                end
                max_pool2d #(
                    .PE_ROW_NUM(PE_ROW_NUM),
                    .PE_COL_NUM(PE_COL_NUM), 
                    .DATA_WIDTH(DATA_WIDTH)
                ) u_max_pool2d (
                    .clk(clk),
                    .rst_n(rst_n), 
                    .clk_en(clk_en), 
                    .new_line_1(new_line_inner_1),
                    .input_valid(window_valid),
                    .data(data_in_for_page),
                    .new_line_out_1(new_line_out_1),
                    .output_valid(output_valid),
                    .y_out(y_out)
                );
            end
        end
    endgenerate




endmodule