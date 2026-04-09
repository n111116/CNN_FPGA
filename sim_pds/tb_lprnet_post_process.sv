`timescale 1ns/1ps

// 包含必要层的宏定义
`include "layer28.vh"

module tb_lprnet_post_process;

    // =========================================================
    // 1. 参数与局部常量定义
    // =========================================================
    // 预估最大数据量 (用于读取输入激励)
    localparam int MEM_DEPTH = IMG_COL_LAYER28 * IMG_ROW_LAYER28 * CYCLE_PERIOD_IN_LAYER28 * PE_PAGE_NUM_LAYER28;

    // 后处理模块的固定参数
    localparam bit CONV_POSITIVE     = 1; // 寻找最大激活通道
    localparam int BLANK_CHAR        = 75; // 空白符

    // 输出结果文件路径
    localparam string OUTPUT_FILE_PATH_POST = "sim_out/lprnet_post_process.hex";

    // =========================================================
    // 2. 信号定义
    // =========================================================
    // ---------------- 全局信号 ----------------
    logic clk;
    logic clk_en;
    logic rst_n;                 
    
    // ---------------- Layer 28 输入信号 ----------------
    logic new_line_input_1;      
    logic data_input_valid;      
    logic [PE_PAGE_NUM_LAYER28-1:0] [DATA_WIDTH_LAYER28-1:0] data_input ;
    
    // ---------------- Layer 28 -> Post Process 连接信号 ----------------
    logic [PE_COL_NUM_LAYER28-1:0] [OUT_WIDTH_LAYER28-1:0] layer28_y_out;
    logic signed [PE_COL_NUM_LAYER28-1:0] [OUT_WIDTH_LAYER28-1:0] layer28_y_out_signed ;
    assign layer28_y_out_signed = $signed(layer28_y_out);

    logic                         layer28_new_line_out_1;
    logic                         layer28_output_valid;

    // ---------------- Post Process 输出信号 ----------------
    localparam int POST_CH_OUT_NUM = CYCLE_PERIOD_OUT_LAYER28 * PE_COL_NUM_LAYER28;
    localparam int POST_CH_WIDTH   = $clog2(POST_CH_OUT_NUM);
    
    logic [POST_CH_WIDTH-1:0]     post_out_char;
    logic                         post_out_valid;
    logic                         post_frame_start_out;

    // 仿真内存 (用于存放 Layer28 的输入激励)
    logic [DATA_WIDTH_LAYER28-1:0] file_mem [0:MEM_DEPTH-1];

    // =========================================================
    // 3. 模块例化
    // =========================================================
    
    // --- 3.1 例化卷积最后层 (Layer 28) ---
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER28),
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER28),
        .PE_ROW_NUM(PE_ROW_NUM_LAYER28),
        .PE_COL_NUM(PE_COL_NUM_LAYER28),
        .MAX_POOL(MAX_POOL_LAYER28),
        .WITH_RELU(WITH_RELU_LAYER28),
        .KERNEL_COL(KERNEL_COL_LAYER28),
        .KERNEL_ROW(KERNEL_ROW_LAYER28),
        .USE_DSP_PE(USE_DSP_PE_LAYER28),
        .DATA_WIDTH(DATA_WIDTH_LAYER28),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER28),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER28),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER28),
        .STEP_COL(STEP_COL_LAYER28),
        .STEP_ROW(STEP_ROW_LAYER28),
        .IMG_COL(IMG_COL_LAYER28),
        .IMG_ROW(IMG_ROW_LAYER28),
        .SHIFT_KEY(SHIFT_KEY_LAYER28),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER28),
        .OUT_WIDTH(OUT_WIDTH_LAYER28),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER28),
        .ACC_WIDTH(ACC_WIDTH_LAYER28)
    ) u_layer28 (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(rst_n),                           
        .new_line_input_1(new_line_input_1), 
        .data_input_valid(data_input_valid), 
        .data_input(data_input),             
        
        // 输出连接到中间信号
        .y_out(layer28_y_out),
        .new_line_out_1(layer28_new_line_out_1),
        .output_valid(layer28_output_valid)
    );
    // --- 3.2 例化后处理模块 (LPRNet Post Process) ---
    lprnet_post_process #(
        .PE_COL_NUM(PE_COL_NUM_LAYER28),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER28),
        .IMG_COL(IMG_COL_LAYER28),
        .IMG_ROW(IMG_ROW_LAYER28),
        .DATA_WIDTH(OUT_WIDTH_LAYER28), // 输入位宽为上一层的输出位宽
        .ACC_WIDTH(OUT_WIDTH_LAYER28 + $clog2(IMG_ROW_LAYER28)),  // 累加器位宽，防止溢出
        .CONV_POSITIVE(CONV_POSITIVE),
        .BLANK_CHAR(BLANK_CHAR)
    ) u_post_process (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(rst_n),
        
        // 接收来自 Layer 28 的输出
        .new_line_input_1(layer28_new_line_out_1),
        .data_input_valid(layer28_output_valid),
        .data_input(layer28_y_out_signed),
        
        // 最终结果输出
        .out_char(post_out_char),
        .out_valid(post_out_valid),
        .frame_start_out(post_frame_start_out)
    );

    // =========================================================
    // 4. 时钟生成
    // =========================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz
    end

    // =========================================================
    // 5. 激励生成 (驱动 Layer 28)
    // =========================================================
    
    // ----------------------------------------
    // Step 5.1: 读取 hex 文件到内存
    // ----------------------------------------
    initial begin
        // 初始化内存为0
        for(int i=0; i<MEM_DEPTH; i++) file_mem[i] = 0;

        // 读取文件
        $readmemh(INPUT_FILE_PATH_LAYER28, file_mem);
        
        $display("------------------------------------------------");
        $display("File Read Check from: %s", INPUT_FILE_PATH_LAYER28);
        $display("Mem[0] (Pix0-Ch0): %h", file_mem[0]);
        $display("Mem[1] (Pix0-Ch1): %h", file_mem[1]);
        $display("------------------------------------------------");
    end

    // ----------------------------------------
    // Step 5.2: 驱动逻辑
    // ----------------------------------------
    initial begin
        // --- 初始化 ---
        clk_en = 0;
        rst_n = 0;
        new_line_input_1 = 0;
        data_input_valid = 0;
        
        for(int p=0; p<PE_PAGE_NUM_LAYER28; p++) begin
            data_input[p] = 0;
        end

        // --- 复位序列 ---
        repeat(10) @(posedge clk);
        rst_n = 1;              
        repeat(5) @(posedge clk);
        clk_en = 1;             

        for (int index_y = 0; index_y < IMG_ROW_LAYER28 * 3; index_y++) begin 
            
            // 1. 行首同步
            @(posedge clk);
            new_line_input_1 = 1;
            data_input_valid = 0; 
            
            @(posedge clk);
            new_line_input_1 = 0;
            
            // 2. 输入一行像素
            for (int index_x = 0; index_x < IMG_COL_LAYER28; index_x++) begin                
                for (int t=0; t<CYCLE_PERIOD_IN_LAYER28; t++) begin
                    // --- A. 发送数据 (持续 1 个周期) ---
                    data_input_valid <= 1;
                    for(int p=0; p<PE_PAGE_NUM_LAYER28; p++) begin
                        int addr; 
                        // 地址计算
                        addr = (index_y * IMG_COL_LAYER28 + index_x) * PE_PAGE_NUM_LAYER28
                                 * CYCLE_PERIOD_IN_LAYER28 + p * CYCLE_PERIOD_IN_LAYER28 + t;
                        data_input[p] <= file_mem[addr % MEM_DEPTH];
                    end
                    @(posedge clk); // 推进 1 个周期，DUT 此时采样到有效数据
                end
                
                // --- B. 空闲等待 (维持步幅所需的间隔周期) ---
                data_input_valid <= 0;
                repeat((CYCLE_PERIOD_OUT_LAYER28 / STEP_COL_LAYER28 / STEP_ROW_LAYER28 - 1) * CYCLE_PERIOD_IN_LAYER28) @(posedge clk);
            end
            
            // 3. 行尾间隙
            data_input_valid = 0;
            repeat((CYCLE_PERIOD_OUT_LAYER28 / STEP_COL_LAYER28 / STEP_ROW_LAYER28) * CYCLE_PERIOD_IN_LAYER28) @(posedge clk); 

            $display("Finished driving row %0d at time %t", index_y, $time);
        end

        // 4. 等待所有流水线（Layer28 + Post Process）排空
        data_input_valid = 0;
        // 给予足够的时间让后处理完成（包含 BRAM 读取、极端值搜索和 CTC 解码延迟）
        repeat(10000) @(posedge clk); 
        $display("Simulation Finished Successfully.");
        $stop;
    end

    // =========================================================
    // 6. 监控后处理输出并写入文件
    // =========================================================
    integer out_file_post;

    // 打开文件
    initial begin
        out_file_post = $fopen(OUTPUT_FILE_PATH_POST, "w");
        if (!out_file_post) begin
            $display("Error: Could not open post-process output file: %s", OUTPUT_FILE_PATH_POST);
            $stop;
        end else begin
            $display("Post-process output file opened: %s", OUTPUT_FILE_PATH_POST);
        end
    end

    // 仿真结束时关闭文件
    final begin
        if (out_file_post) $fclose(out_file_post);
    end

    // 写入控制逻辑 (监控最终的 CTC 输出)
    always @(posedge clk or negedge rst_n) begin
        if (rst_n && clk_en) begin
            
            // 监控帧起始脉冲
            if (post_frame_start_out) begin
                $display("\nTime %t: Post Process Frame Start detected. Decoding sequence begins.", $time);
                $fwrite(out_file_post, "\n--- NEW FRAME ---\n");
            end

            // 监控有效输出字符
            if (post_out_valid) begin
                $fwrite(out_file_post, "%0h ", post_out_char); // 以十六进制格式写入通道号（字符索引）
                $display("Time %t: Decoded Char (Channel Index) = %0d", $time, post_out_char);
            end
        end
    end

endmodule