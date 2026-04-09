`timescale 1ns/1ps

// =========================================================
// 头文件 Include (Layer 20 ~ 28)
// =========================================================
`include "layer20.vh"
`include "layer21.vh"
`include "layer22.vh"
`include "layer23.vh"
`include "layer24.vh"
`include "layer25.vh"
`include "layer26.vh"
`include "layer27.vh"
`include "layer28.vh"

module tb_lprnet;

    // =========================================================
    // 1. 参数与局部常量定义
    // =========================================================
    // 预估最大数据量 (用于读取 Layer 20 输入激励)
    localparam int MEM_DEPTH = IMG_COL_LAYER20 * IMG_ROW_LAYER20 * CYCLE_PERIOD_IN_LAYER20 * PE_PAGE_NUM_LAYER20;

    // 后处理模块的固定参数
    localparam bit CONV_POSITIVE     = 1;  // 寻找最大激活通道
    localparam int BLANK_CHAR        = 75; // 空白符

    // 输出结果文件路径
    localparam string OUTPUT_FILE_PATH_POST = "sim_out/lprnet_full_output.hex";

    // =========================================================
    // 2. 全局信号定义
    // =========================================================
    logic clk;
    logic clk_en;
    logic rst_n;                 
    
    // =========================================================
    // 3. 各层连线定义
    // =========================================================
    // ---------------- Layer 20 输入信号 ----------------
    logic new_line_input_1;      
    logic data_input_valid;      
    logic [PE_PAGE_NUM_LAYER20-1:0] [DATA_WIDTH_LAYER20-1:0] data_input;

    // ---------------- 层间互联信号 ----------------
    
    // Layer 20 -> Layer 21
    logic [PE_COL_NUM_LAYER20-1:0] [OUT_WIDTH_LAYER20-1:0] layer_y_out_layer20;
    logic out_valid_layer20;
    logic new_line_out_1_layer20;

    // Layer 21 -> Layer 22
    logic [PE_COL_NUM_LAYER21-1:0] [OUT_WIDTH_LAYER21-1:0] layer_y_out_layer21 ;
    logic out_valid_layer21;
    logic new_line_out_1_layer21;

    // Layer 22 -> Layer 23
    logic [PE_COL_NUM_LAYER22-1:0] [OUT_WIDTH_LAYER22-1:0] layer_y_out_layer22 ;
    logic out_valid_layer22;
    logic new_line_out_1_layer22;

    // Layer 23 -> Layer 24
    logic [PE_COL_NUM_LAYER23-1:0] [OUT_WIDTH_LAYER23-1:0] layer_y_out_layer23 ;
    logic out_valid_layer23;
    logic new_line_out_1_layer23;

    // Layer 24 -> Layer 25
    logic [PE_COL_NUM_LAYER24-1:0] [OUT_WIDTH_LAYER24-1:0] layer_y_out_layer24 ;
    logic out_valid_layer24;
    logic new_line_out_1_layer24;

    // Layer 25 -> Layer 26
    logic [PE_COL_NUM_LAYER25-1:0] [OUT_WIDTH_LAYER25-1:0] layer_y_out_layer25 ;
    logic out_valid_layer25;
    logic new_line_out_1_layer25;

    // Layer 26 -> Layer 27
    logic [PE_COL_NUM_LAYER26-1:0] [OUT_WIDTH_LAYER26-1:0] layer_y_out_layer26 ;
    logic out_valid_layer26;
    logic new_line_out_1_layer26;

    // Layer 27 -> Layer 28
    logic [PE_COL_NUM_LAYER27-1:0] [OUT_WIDTH_LAYER27-1:0] layer_y_out_layer27 ;
    logic out_valid_layer27;
    logic new_line_out_1_layer27;

    // Layer 28 -> Post Process
    logic [PE_COL_NUM_LAYER28-1:0] [OUT_WIDTH_LAYER28-1:0] layer_y_out_layer28 ;
    logic out_valid_layer28;
    logic new_line_out_1_layer28;
    
    // 无符号转有符号 (针对 Post Process 的要求)
    logic signed [PE_COL_NUM_LAYER28-1:0] [OUT_WIDTH_LAYER28-1:0] layer28_y_out_signed ;
    int idc;
    always_comb begin
        for(idc = 0; idc < PE_COL_NUM_LAYER28; idc = idc + 1) begin
            layer28_y_out_signed[idc] = $signed(layer_y_out_layer28[idc]);
        end
    end


    // ---------------- Post Process 输出信号 ----------------
    localparam int POST_CH_OUT_NUM = CYCLE_PERIOD_OUT_LAYER28 * PE_COL_NUM_LAYER28;
    localparam int POST_CH_WIDTH   = $clog2(POST_CH_OUT_NUM);
    
    logic [POST_CH_WIDTH-1:0]     post_out_char;
    logic                         post_out_valid;
    logic                         post_frame_start_out;

    // 仿真内存
    logic [DATA_WIDTH_LAYER20-1:0] file_mem [0:MEM_DEPTH-1];


    // =========================================================
    // 4. 网络层级例化 (Layer 20 ~ 28 + Post Process)
    // =========================================================
    
    // Layer 20 (Top layer in this TB)
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER20), .PE_PAGE_NUM(PE_PAGE_NUM_LAYER20), .PE_ROW_NUM(PE_ROW_NUM_LAYER20),
        .PE_COL_NUM(PE_COL_NUM_LAYER20), .KERNEL_COL(KERNEL_COL_LAYER20), .KERNEL_ROW(KERNEL_ROW_LAYER20),
        .WITH_RELU(WITH_RELU_LAYER20), .MAX_POOL(MAX_POOL_LAYER20), .DATA_WIDTH(DATA_WIDTH_LAYER20),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER20), .USE_DSP_PE(USE_DSP_PE_LAYER20), .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER20),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER20), .IMG_COL(IMG_COL_LAYER20), .IMG_ROW(IMG_ROW_LAYER20),
        .STEP_COL(STEP_COL_LAYER20), .STEP_ROW(STEP_ROW_LAYER20), .SHIFT_KEY(SHIFT_KEY_LAYER20),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER20), .OUT_WIDTH(OUT_WIDTH_LAYER20), .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER20),
        .ACC_WIDTH(ACC_WIDTH_LAYER20)
    ) u_layer20 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_input_1), .data_input_valid(data_input_valid), .data_input(data_input),
        .y_out(layer_y_out_layer20), .new_line_out_1(new_line_out_1_layer20), .output_valid(out_valid_layer20)
    );

    // Layer 21
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER21), .PE_PAGE_NUM(PE_PAGE_NUM_LAYER21), .PE_ROW_NUM(PE_ROW_NUM_LAYER21),
        .PE_COL_NUM(PE_COL_NUM_LAYER21), .KERNEL_COL(KERNEL_COL_LAYER21), .KERNEL_ROW(KERNEL_ROW_LAYER21),
        .WITH_RELU(WITH_RELU_LAYER21), .MAX_POOL(MAX_POOL_LAYER21), .DATA_WIDTH(DATA_WIDTH_LAYER21),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER21), .USE_DSP_PE(USE_DSP_PE_LAYER21), .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER21),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER21), .IMG_COL(IMG_COL_LAYER21), .IMG_ROW(IMG_ROW_LAYER21),
        .STEP_COL(STEP_COL_LAYER21), .STEP_ROW(STEP_ROW_LAYER21), .SHIFT_KEY(SHIFT_KEY_LAYER21),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER21), .OUT_WIDTH(OUT_WIDTH_LAYER21), .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER21),
        .ACC_WIDTH(ACC_WIDTH_LAYER21)
    ) u_layer21 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer20), .data_input_valid(out_valid_layer20), .data_input(layer_y_out_layer20),
        .y_out(layer_y_out_layer21), .new_line_out_1(new_line_out_1_layer21), .output_valid(out_valid_layer21)
    );

    // Layer 22
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER22), .PE_PAGE_NUM(PE_PAGE_NUM_LAYER22), .PE_ROW_NUM(PE_ROW_NUM_LAYER22),
        .PE_COL_NUM(PE_COL_NUM_LAYER22), .KERNEL_COL(KERNEL_COL_LAYER22), .KERNEL_ROW(KERNEL_ROW_LAYER22),
        .WITH_RELU(WITH_RELU_LAYER22), .MAX_POOL(MAX_POOL_LAYER22), .DATA_WIDTH(DATA_WIDTH_LAYER22),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER22), .USE_DSP_PE(USE_DSP_PE_LAYER22), .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER22),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER22), .IMG_COL(IMG_COL_LAYER22), .IMG_ROW(IMG_ROW_LAYER22),
        .STEP_COL(STEP_COL_LAYER22), .STEP_ROW(STEP_ROW_LAYER22), .SHIFT_KEY(SHIFT_KEY_LAYER22),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER22), .OUT_WIDTH(OUT_WIDTH_LAYER22), .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER22),
        .ACC_WIDTH(ACC_WIDTH_LAYER22)
    ) u_layer22 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer21), .data_input_valid(out_valid_layer21), .data_input(layer_y_out_layer21),
        .y_out(layer_y_out_layer22), .new_line_out_1(new_line_out_1_layer22), .output_valid(out_valid_layer22)
    );

    // Layer 23
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER23), .PE_PAGE_NUM(PE_PAGE_NUM_LAYER23), .PE_ROW_NUM(PE_ROW_NUM_LAYER23),
        .PE_COL_NUM(PE_COL_NUM_LAYER23), .KERNEL_COL(KERNEL_COL_LAYER23), .KERNEL_ROW(KERNEL_ROW_LAYER23),
        .WITH_RELU(WITH_RELU_LAYER23), .MAX_POOL(MAX_POOL_LAYER23), .DATA_WIDTH(DATA_WIDTH_LAYER23),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER23), .USE_DSP_PE(USE_DSP_PE_LAYER23), .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER23),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER23), .IMG_COL(IMG_COL_LAYER23), .IMG_ROW(IMG_ROW_LAYER23),
        .STEP_COL(STEP_COL_LAYER23), .STEP_ROW(STEP_ROW_LAYER23), .SHIFT_KEY(SHIFT_KEY_LAYER23),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER23), .OUT_WIDTH(OUT_WIDTH_LAYER23), .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER23),
        .ACC_WIDTH(ACC_WIDTH_LAYER23)
    ) u_layer23 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer22), .data_input_valid(out_valid_layer22), .data_input(layer_y_out_layer22),
        .y_out(layer_y_out_layer23), .new_line_out_1(new_line_out_1_layer23), .output_valid(out_valid_layer23)
    );

    // Layer 24
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER24), .PE_PAGE_NUM(PE_PAGE_NUM_LAYER24), .PE_ROW_NUM(PE_ROW_NUM_LAYER24),
        .PE_COL_NUM(PE_COL_NUM_LAYER24), .KERNEL_COL(KERNEL_COL_LAYER24), .KERNEL_ROW(KERNEL_ROW_LAYER24),
        .WITH_RELU(WITH_RELU_LAYER24), .MAX_POOL(MAX_POOL_LAYER24), .DATA_WIDTH(DATA_WIDTH_LAYER24),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER24), .USE_DSP_PE(USE_DSP_PE_LAYER24), .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER24),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER24), .IMG_COL(IMG_COL_LAYER24), .IMG_ROW(IMG_ROW_LAYER24),
        .STEP_COL(STEP_COL_LAYER24), .STEP_ROW(STEP_ROW_LAYER24), .SHIFT_KEY(SHIFT_KEY_LAYER24),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER24), .OUT_WIDTH(OUT_WIDTH_LAYER24), .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER24),
        .ACC_WIDTH(ACC_WIDTH_LAYER24)
    ) u_layer24 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer23), .data_input_valid(out_valid_layer23), .data_input(layer_y_out_layer23),
        .y_out(layer_y_out_layer24), .new_line_out_1(new_line_out_1_layer24), .output_valid(out_valid_layer24)
    );

    // Layer 25
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER25), .PE_PAGE_NUM(PE_PAGE_NUM_LAYER25), .PE_ROW_NUM(PE_ROW_NUM_LAYER25),
        .PE_COL_NUM(PE_COL_NUM_LAYER25), .KERNEL_COL(KERNEL_COL_LAYER25), .KERNEL_ROW(KERNEL_ROW_LAYER25),
        .WITH_RELU(WITH_RELU_LAYER25), .MAX_POOL(MAX_POOL_LAYER25), .DATA_WIDTH(DATA_WIDTH_LAYER25),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER25), .USE_DSP_PE(USE_DSP_PE_LAYER25), .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER25),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER25), .IMG_COL(IMG_COL_LAYER25), .IMG_ROW(IMG_ROW_LAYER25),
        .STEP_COL(STEP_COL_LAYER25), .STEP_ROW(STEP_ROW_LAYER25), .SHIFT_KEY(SHIFT_KEY_LAYER25),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER25), .OUT_WIDTH(OUT_WIDTH_LAYER25), .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER25),
        .ACC_WIDTH(ACC_WIDTH_LAYER25)
    ) u_layer25 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer24), .data_input_valid(out_valid_layer24), .data_input(layer_y_out_layer24),
        .y_out(layer_y_out_layer25), .new_line_out_1(new_line_out_1_layer25), .output_valid(out_valid_layer25)
    );

    // Layer 26
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER26), .PE_PAGE_NUM(PE_PAGE_NUM_LAYER26), .PE_ROW_NUM(PE_ROW_NUM_LAYER26),
        .PE_COL_NUM(PE_COL_NUM_LAYER26), .KERNEL_COL(KERNEL_COL_LAYER26), .KERNEL_ROW(KERNEL_ROW_LAYER26),
        .WITH_RELU(WITH_RELU_LAYER26), .MAX_POOL(MAX_POOL_LAYER26), .DATA_WIDTH(DATA_WIDTH_LAYER26),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER26), .USE_DSP_PE(USE_DSP_PE_LAYER26), .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER26),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER26), .IMG_COL(IMG_COL_LAYER26), .IMG_ROW(IMG_ROW_LAYER26),
        .STEP_COL(STEP_COL_LAYER26), .STEP_ROW(STEP_ROW_LAYER26), .SHIFT_KEY(SHIFT_KEY_LAYER26),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER26), .OUT_WIDTH(OUT_WIDTH_LAYER26), .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER26),
        .ACC_WIDTH(ACC_WIDTH_LAYER26)
    ) u_layer26 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer25), .data_input_valid(out_valid_layer25), .data_input(layer_y_out_layer25),
        .y_out(layer_y_out_layer26), .new_line_out_1(new_line_out_1_layer26), .output_valid(out_valid_layer26)
    );

    // Layer 27
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER27), .PE_PAGE_NUM(PE_PAGE_NUM_LAYER27), .PE_ROW_NUM(PE_ROW_NUM_LAYER27),
        .PE_COL_NUM(PE_COL_NUM_LAYER27), .KERNEL_COL(KERNEL_COL_LAYER27), .KERNEL_ROW(KERNEL_ROW_LAYER27),
        .WITH_RELU(WITH_RELU_LAYER27), .MAX_POOL(MAX_POOL_LAYER27), .DATA_WIDTH(DATA_WIDTH_LAYER27),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER27), .USE_DSP_PE(USE_DSP_PE_LAYER27), .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER27),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER27), .IMG_COL(IMG_COL_LAYER27), .IMG_ROW(IMG_ROW_LAYER27),
        .STEP_COL(STEP_COL_LAYER27), .STEP_ROW(STEP_ROW_LAYER27), .SHIFT_KEY(SHIFT_KEY_LAYER27),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER27), .OUT_WIDTH(OUT_WIDTH_LAYER27), .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER27),
        .ACC_WIDTH(ACC_WIDTH_LAYER27)
    ) u_layer27 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer26), .data_input_valid(out_valid_layer26), .data_input(layer_y_out_layer26),
        .y_out(layer_y_out_layer27), .new_line_out_1(new_line_out_1_layer27), .output_valid(out_valid_layer27)
    );

    // Layer 28
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER28), .PE_PAGE_NUM(PE_PAGE_NUM_LAYER28), .PE_ROW_NUM(PE_ROW_NUM_LAYER28),
        .PE_COL_NUM(PE_COL_NUM_LAYER28), .KERNEL_COL(KERNEL_COL_LAYER28), .KERNEL_ROW(KERNEL_ROW_LAYER28),
        .WITH_RELU(WITH_RELU_LAYER28), .MAX_POOL(MAX_POOL_LAYER28), .DATA_WIDTH(DATA_WIDTH_LAYER28),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER28), .USE_DSP_PE(USE_DSP_PE_LAYER28), .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER28),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER28), .IMG_COL(IMG_COL_LAYER28), .IMG_ROW(IMG_ROW_LAYER28),
        .STEP_COL(STEP_COL_LAYER28), .STEP_ROW(STEP_ROW_LAYER28), .SHIFT_KEY(SHIFT_KEY_LAYER28),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER28), .OUT_WIDTH(OUT_WIDTH_LAYER28), .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER28),
        .ACC_WIDTH(ACC_WIDTH_LAYER28)
    ) u_layer28 (
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n),
        .new_line_input_1(new_line_out_1_layer27), .data_input_valid(out_valid_layer27), .data_input(layer_y_out_layer27),
        .y_out(layer_y_out_layer28), .new_line_out_1(new_line_out_1_layer28), .output_valid(out_valid_layer28)
    );

    // LPRNet Post Process (CTC Decoder)
    lprnet_post_process #(
        .PE_COL_NUM(PE_COL_NUM_LAYER28),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER28),
        .IMG_COL(IMG_COL_LAYER28),
        .IMG_ROW(IMG_ROW_LAYER28),
        .DATA_WIDTH(OUT_WIDTH_LAYER28), 
        .ACC_WIDTH(OUT_WIDTH_LAYER28 + $clog2(IMG_ROW_LAYER28)), 
        .CONV_POSITIVE(CONV_POSITIVE),
        .BLANK_CHAR(BLANK_CHAR)
    ) u_post_process (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(rst_n),
        
        .new_line_input_1(new_line_out_1_layer28),
        .data_input_valid(out_valid_layer28),
        .data_input(layer28_y_out_signed),   // 接入经过 $signed() 转换的数据
        
        .out_char(post_out_char),
        .out_valid(post_out_valid),
        .frame_start_out(post_frame_start_out)
    );

    // =========================================================
    // 5. 时钟生成
    // =========================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz
    end

    // =========================================================
    // 6. 激励生成 (驱动 Layer 20)
    // =========================================================
    
    // 读取 hex 文件到内存
    initial begin
        for(int i=0; i<MEM_DEPTH; i++) file_mem[i] = 0;
        $readmemh(INPUT_FILE_PATH_LAYER20, file_mem);
        
        $display("------------------------------------------------");
        $display("File Read Check from: %s", INPUT_FILE_PATH_LAYER20);
        $display("Mem[0] (Pix0-Ch0): %h", file_mem[0]);
        $display("------------------------------------------------");
    end

    // 驱动逻辑
    initial begin
        // --- 初始化 ---
        clk_en = 0;
        rst_n = 0;
        new_line_input_1 = 0;
        data_input_valid = 0;
        
        for(int p=0; p<PE_PAGE_NUM_LAYER20; p++) begin
            data_input[p] = 0;
        end

        // --- 复位序列 ---
        repeat(10) @(posedge clk);
        rst_n = 1;              
        repeat(5) @(posedge clk);
        clk_en = 1;             

        // --- 开始喂入 Layer 20 激励 ---
        for (int index_y = 0; index_y < IMG_ROW_LAYER20 * 2; index_y++) begin 
            
            // 行首同步
            @(posedge clk);
            new_line_input_1 = 1;
            data_input_valid = 0; 
            
            @(posedge clk);
            new_line_input_1 = 0;
            
            // 输入一行像素
            for (int index_x = 0; index_x < IMG_COL_LAYER20; index_x++) begin                
                for (int t=0; t<CYCLE_PERIOD_IN_LAYER20; t++) begin
                    data_input_valid <= 1;
                    for(int p=0; p<PE_PAGE_NUM_LAYER20; p++) begin
                        int addr; 
                        addr = (index_y * IMG_COL_LAYER20 + index_x) * PE_PAGE_NUM_LAYER20
                                 * CYCLE_PERIOD_IN_LAYER20 + p * CYCLE_PERIOD_IN_LAYER20 + t;
                        data_input[p] <= file_mem[addr % MEM_DEPTH];
                    end
                    @(posedge clk); 
                end
                
                // 空闲等待 (维持步幅所需的间隔周期)
                data_input_valid <= 0;
                repeat((CYCLE_PERIOD_OUT_LAYER20 / STEP_COL_LAYER20 / STEP_ROW_LAYER20 - 1) * CYCLE_PERIOD_IN_LAYER20) @(posedge clk);
            end
            
            // 行尾间隙拉长，增大 layer20 的两行间隔，使得行输出速度能匹配 layer22 的处理速度
            data_input_valid = 0;
            repeat(((CYCLE_PERIOD_OUT_LAYER22 / STEP_COL_LAYER22 / STEP_ROW_LAYER22)) * CYCLE_PERIOD_IN_LAYER22 
                * IMG_COL_LAYER22
            ) @(posedge clk); 

            $display("Finished driving row %0d at time %t, gap_time %d @posedge clk", index_y, $time, 
            ((CYCLE_PERIOD_OUT_LAYER22 / STEP_COL_LAYER22 / STEP_ROW_LAYER22) - 1) * CYCLE_PERIOD_IN_LAYER22 * IMG_COL_LAYER22);
        end

        // 等待所有流水线（Layer20 ~ 28 + Post Process）排空
        data_input_valid = 0;
        // 因为级联了 9 个 Layer 以及复杂的后处理模块，所以这里的排空周期设置得比较长
        repeat(300_000_000) @(posedge clk); 
        $display("Simulation Finished Successfully.");
        $stop;
    end

    // =========================================================
    // 6. 监控各层输出并分别写入文件
    // =========================================================

    // --- 6.1 文件句柄与控制信号定义 ---
    integer out_file_layer20, out_file_layer21, out_file_layer22, out_file_layer23;
    integer out_file_layer24, out_file_layer25, out_file_layer26, out_file_layer27, out_file_layer28;
    integer out_file_post;

    int write_cnt_layer20, write_cnt_layer21, write_cnt_layer22, write_cnt_layer23;
    int write_cnt_layer24, write_cnt_layer25, write_cnt_layer26, write_cnt_layer27, write_cnt_layer28;

    bit write_enable_layer20, write_enable_layer21, write_enable_layer22, write_enable_layer23;
    bit write_enable_layer24, write_enable_layer25, write_enable_layer26, write_enable_layer27, write_enable_layer28;

    // --- 6.2 打开文件 (Initial) ---
    initial begin
        // Layer 20 ~ 28
        out_file_layer20 = $fopen(OUTPUT_FILE_PATH_LAYER20, "w");
        out_file_layer21 = $fopen(OUTPUT_FILE_PATH_LAYER21, "w");
        out_file_layer22 = $fopen(OUTPUT_FILE_PATH_LAYER22, "w");
        out_file_layer23 = $fopen(OUTPUT_FILE_PATH_LAYER23, "w");
        out_file_layer24 = $fopen(OUTPUT_FILE_PATH_LAYER24, "w");
        out_file_layer25 = $fopen(OUTPUT_FILE_PATH_LAYER25, "w");
        out_file_layer26 = $fopen(OUTPUT_FILE_PATH_LAYER26, "w");
        out_file_layer27 = $fopen(OUTPUT_FILE_PATH_LAYER27, "w");
        out_file_layer28 = $fopen(OUTPUT_FILE_PATH_LAYER28, "w");
        
        // Post Process
        out_file_post = $fopen(OUTPUT_FILE_PATH_POST, "w");

        // 简单错误检查（可选，防止某层文件路径未定义）
        if (!out_file_layer28) $display("Error: Could not open output file for Layer 28!");
        if (!out_file_post) $display("Error: Could not open output file for Post Process!");
    end

    // --- 6.3 关闭文件 (Final) ---
    final begin
        if (out_file_layer20) $fclose(out_file_layer20);
        if (out_file_layer21) $fclose(out_file_layer21);
        if (out_file_layer22) $fclose(out_file_layer22);
        if (out_file_layer23) $fclose(out_file_layer23);
        if (out_file_layer24) $fclose(out_file_layer24);
        if (out_file_layer25) $fclose(out_file_layer25);
        if (out_file_layer26) $fclose(out_file_layer26);
        if (out_file_layer27) $fclose(out_file_layer27);
        if (out_file_layer28) $fclose(out_file_layer28);
        if (out_file_post)    $fclose(out_file_post);
    end

    // --- 6.4 写入控制逻辑 (Always 块) ---
    // 为了代码结构清晰，我们将 CNN 各层的写入逻辑放在同一个 always 块中
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_cnt_layer20 <= 0; write_enable_layer20 <= 0;
            write_cnt_layer21 <= 0; write_enable_layer21 <= 0;
            write_cnt_layer22 <= 0; write_enable_layer22 <= 0;
            write_cnt_layer23 <= 0; write_enable_layer23 <= 0;
            write_cnt_layer24 <= 0; write_enable_layer24 <= 0;
            write_cnt_layer25 <= 0; write_enable_layer25 <= 0;
            write_cnt_layer26 <= 0; write_enable_layer26 <= 0;
            write_cnt_layer27 <= 0; write_enable_layer27 <= 0;
            write_cnt_layer28 <= 0; write_enable_layer28 <= 0;
        end else if (clk_en) begin
            
            // ================= Layer 20 =================
            if (new_line_out_1_layer20) write_enable_layer20 <= 1;
            if (write_enable_layer20 && out_valid_layer20) begin
                for (int c = 0; c < PE_COL_NUM_LAYER20; c++) begin
                    $fwrite(out_file_layer20, "%6h ", layer_y_out_layer20[c]);
                end
                $fwrite(out_file_layer20, "\n");
                write_cnt_layer20 <= write_cnt_layer20 + 1;
            end

            // ================= Layer 21 =================
            if (new_line_out_1_layer21) write_enable_layer21 <= 1;
            if (write_enable_layer21 && out_valid_layer21) begin
                for (int c = 0; c < PE_COL_NUM_LAYER21; c++) begin
                    $fwrite(out_file_layer21, "%6h ", layer_y_out_layer21[c]);
                end
                $fwrite(out_file_layer21, "\n");
                write_cnt_layer21 <= write_cnt_layer21 + 1;
            end

            // ================= Layer 22 =================
            if (new_line_out_1_layer22) write_enable_layer22 <= 1;
            if (write_enable_layer22 && out_valid_layer22) begin
                for (int c = 0; c < PE_COL_NUM_LAYER22; c++) begin
                    $fwrite(out_file_layer22, "%6h ", layer_y_out_layer22[c]);
                end
                $fwrite(out_file_layer22, "\n");
                write_cnt_layer22 <= write_cnt_layer22 + 1;
            end

            // ================= Layer 23 =================
            if (new_line_out_1_layer23) write_enable_layer23 <= 1;
            if (write_enable_layer23 && out_valid_layer23) begin
                for (int c = 0; c < PE_COL_NUM_LAYER23; c++) begin
                    $fwrite(out_file_layer23, "%6h ", layer_y_out_layer23[c]);
                end
                $fwrite(out_file_layer23, "\n");
                write_cnt_layer23 <= write_cnt_layer23 + 1;
            end

            // ================= Layer 24 =================
            if (new_line_out_1_layer24) write_enable_layer24 <= 1;
            if (write_enable_layer24 && out_valid_layer24) begin
                for (int c = 0; c < PE_COL_NUM_LAYER24; c++) begin
                    $fwrite(out_file_layer24, "%6h ", layer_y_out_layer24[c]);
                end
                $fwrite(out_file_layer24, "\n");
                write_cnt_layer24 <= write_cnt_layer24 + 1;
            end

            // ================= Layer 25 =================
            if (new_line_out_1_layer25) write_enable_layer25 <= 1;
            if (write_enable_layer25 && out_valid_layer25) begin
                for (int c = 0; c < PE_COL_NUM_LAYER25; c++) begin
                    $fwrite(out_file_layer25, "%6h ", layer_y_out_layer25[c]);
                end
                $fwrite(out_file_layer25, "\n");
                write_cnt_layer25 <= write_cnt_layer25 + 1;
            end

            // ================= Layer 26 =================
            if (new_line_out_1_layer26) write_enable_layer26 <= 1;
            if (write_enable_layer26 && out_valid_layer26) begin
                for (int c = 0; c < PE_COL_NUM_LAYER26; c++) begin
                    $fwrite(out_file_layer26, "%6h ", layer_y_out_layer26[c]);
                end
                $fwrite(out_file_layer26, "\n");
                write_cnt_layer26 <= write_cnt_layer26 + 1;
            end

            // ================= Layer 27 =================
            if (new_line_out_1_layer27) write_enable_layer27 <= 1;
            if (write_enable_layer27 && out_valid_layer27) begin
                for (int c = 0; c < PE_COL_NUM_LAYER27; c++) begin
                    $fwrite(out_file_layer27, "%6h ", layer_y_out_layer27[c]);
                end
                $fwrite(out_file_layer27, "\n");
                write_cnt_layer27 <= write_cnt_layer27 + 1;
            end

            // ================= Layer 28 =================
            if (new_line_out_1_layer28) write_enable_layer28 <= 1;
            if (write_enable_layer28 && out_valid_layer28) begin
                for (int c = 0; c < PE_COL_NUM_LAYER28; c++) begin
                    $fwrite(out_file_layer28, "%6h ", layer_y_out_layer28[c]);
                end
                $fwrite(out_file_layer28, "\n");
                write_cnt_layer28 <= write_cnt_layer28 + 1;
            end

            // ================= Post Process =================
            if (post_frame_start_out) begin
                $display("\nTime %t: Post Process Frame Start detected. Decoding sequence begins.", $time);
                $fwrite(out_file_post, "\n--- NEW FRAME ---\n");
            end

            if (post_out_valid) begin
                $fwrite(out_file_post, "%0h ", post_out_char);
                $display("Time %t: Decoded Char (Channel Index) = %0h", $time, post_out_char);
            end
        end
    end

endmodule