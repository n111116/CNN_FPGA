`timescale 1ns/1ps
`include "layer11.vh"

module tb_post_cv3_conv2d;

    parameter LUT_FILE   = "sigmoid_lut_9bit_to_8bit_h.mem";
    // 预估最大数据量
    localparam int MEM_DEPTH = IMG_COL_LAYER11 * IMG_ROW_LAYER11 * CYCLE_PERIOD_IN_LAYER11 * PE_PAGE_NUM_LAYER11;
    parameter int POST_DATA_WIDTH = OUT_WIDTH_LAYER11;
    parameter int CONF_WIDTH = 8;
    parameter bit CONV_POSITIVE = 1;
    parameter int CONF_THRESH = 128;
    // =========================================================
    // 2. 信号定义
    // =========================================================
    logic clk;
    logic clk_en;
    logic rst_n;                 
    logic new_line_input_1;      
    logic data_input_valid;      
    logic output_valid;
    // 输入数据
    logic [DATA_WIDTH_LAYER11-1:0] data_input [PE_PAGE_NUM_LAYER11-1:0];
    logic [OUT_WIDTH_LAYER11-1:0] y_out [PE_COL_NUM_LAYER11-1:0];
    logic new_line_out_1;
    
    // 输出数据
    logic [31:0] packet_data;
    logic packet_valid;
    logic frame_done;
    // 仿真内存
    logic [DATA_WIDTH_LAYER11-1:0] file_mem [0:MEM_DEPTH-1];

    // =========================================================
    // 3. 模块例化
    // =========================================================
    
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER11),
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER11),
        .PE_ROW_NUM(PE_ROW_NUM_LAYER11),
        .PE_COL_NUM(PE_COL_NUM_LAYER11),
        .MAX_POOL(MAX_POOL_LAYER11),
        .WITH_RELU(WITH_RELU_LAYER11),
        .KERNEL_COL(KERNEL_COL_LAYER11),
        .KERNEL_ROW(KERNEL_ROW_LAYER11),
        .USE_DSP_PE(USE_DSP_PE_LAYER11),
        .DATA_WIDTH(DATA_WIDTH_LAYER11),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER11),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER11),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER11),
        .STEP_COL(STEP_COL_LAYER11),
        .STEP_ROW(STEP_ROW_LAYER11),
        .IMG_COL(IMG_COL_LAYER11),
        .IMG_ROW(IMG_ROW_LAYER11),
        .SHIFT_KEY(SHIFT_KEY_LAYER11),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER11),
        .OUT_WIDTH(OUT_WIDTH_LAYER11),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER11),
        .ACC_WIDTH(ACC_WIDTH_LAYER11)
    ) u_layer (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(rst_n),                           
        .new_line_input_1(new_line_input_1), 
        .data_input_valid(data_input_valid), 
        .data_input(data_input),             
        .y_out(y_out),
        .new_line_out_1(new_line_out_1),
        .output_valid(output_valid)
    );
    post_cv3_conv2d #(
        .DATA_WIDTH(POST_DATA_WIDTH),
        .OUT_WIDTH(32),
        .LUT_FILE(LUT_FILE),
        .PE_COL_NUM(PE_COL_NUM_LAYER11),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER11),
        .CHANNEL_OUT_NUM(CHANNEL_OUT_NUM_LAYER11),
        .IMG_COL(IMG_COL_LAYER11),
        .IMG_ROW(IMG_ROW_LAYER11),
        .CONV_POSITIVE(CONV_POSITIVE),
        .CONF_WIDTH(CONF_WIDTH),
        .CONF_THRESH(CONF_THRESH)
    ) u_post_process (
        .clk(clk),
        .rst_n(rst_n),
        .new_line_in_1(new_line_out_1),
        .data_input_valid(output_valid),
        .data_in(y_out),
        
        .packet_data(packet_data),
        .packet_valid(packet_valid),
        .frame_done(frame_done)
    );


    // =========================================================
    // 4. 时钟生成
    // =========================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz
    end

    // =========================================================
    // 5. 激励生成 (读取文件 + 固定 4 周期模式)
    // =========================================================
    
    // ----------------------------------------
    // Step 5.1: 读取 hex 文件到内存
    // ----------------------------------------
    initial begin
        // 初始化内存为0
        for(int i=0; i<MEM_DEPTH; i++) file_mem[i] = 0;

        // 读取文件
        $readmemh(INPUT_FILE_PATH_LAYER11, file_mem);
        
        $display("------------------------------------------------");
        $display("File Read Check from: %s", INPUT_FILE_PATH_LAYER11);
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
        
        for(int p=0; p<PE_PAGE_NUM_LAYER11; p++) begin
            data_input[p] = 0;
        end

        // --- 复位序列 ---
        repeat(10) @(posedge clk);
        rst_n = 1;              
        repeat(5) @(posedge clk);
        clk_en = 1;             

        for (int index_y = 0; index_y < IMG_ROW_LAYER11 * 3; index_y++) begin 
            
            // 1. 行首同步
            @(posedge clk);
            new_line_input_1 = 1;
            data_input_valid = 0; 
            
            @(posedge clk);
            new_line_input_1 = 0;
            
            // 2. 输入一行像素
            for (int index_x = 0; index_x < IMG_COL_LAYER11; index_x++) begin
                
                
                for (int t=0; t<CYCLE_PERIOD_IN_LAYER11; t++) begin
                    // --- A. 发送数据 (持续 1 个周期) ---
                    data_input_valid <= 1;
                    for(int p=0; p<PE_PAGE_NUM_LAYER11; p++) begin
                        int addr; // 声明在循环内，先声明后赋值

                        // 地址计算
                        addr = (index_y * IMG_COL_LAYER11 + index_x) * PE_PAGE_NUM_LAYER11
                                 * CYCLE_PERIOD_IN_LAYER11 + p * CYCLE_PERIOD_IN_LAYER11 + t;
                        data_input[p] <= file_mem[addr % MEM_DEPTH];
                        // // data_input[p] <= p * CYCLE_PERIOD_IN_LAYER11 + t;
                        // // data_input[p] <= index_y*64+index_x+t + 1;
                    end
                    // data_input[0] <= index_x;
                    // data_input[1] <= index_y[0];
                    // data_input[2] <= index_y[0];
                    @(posedge clk); // 推进 1 个周期，DUT 此时采样到有效数据

                    // --- B. 空闲等待 (持续 3 个周期) ---
                    // 总周期 = 1 (Active) + 3 (Idle) = 4 Cycles
                    data_input_valid <= 0;
                    repeat(CYCLE_PERIOD_OUT_LAYER11-1) @(posedge clk);
                end
            end
            
            // 3. 行尾间隙
            data_input_valid = 0;
            repeat(10) @(posedge clk); 

            $display("Finished driving row %0d at time %t", index_y, $time);
        end

        // 4. 结束
        data_input_valid = 0;
        repeat(3000) @(posedge clk); 
        $stop;
    end

    // =========================================================
    // 6. 监控输出并写入文件 [新增逻辑]
    // =========================================================
    integer out_file;
    int write_cnt;
    bit write_enable;
    
    // 打开/关闭文件
    initial begin
        out_file = $fopen("out_post_conv_33.hex", "w");
        if (!out_file) begin
            $display("Error: Could not open output file: %s", OUTPUT_FILE_PATH_LAYER11);
            $stop;
        end else begin
            $display("Output file opened: %s", OUTPUT_FILE_PATH_LAYER11);
        end
    end

    // 仿真结束时关闭文件
    final begin
        if (out_file) $fclose(out_file);
    end

    // 写入控制逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_cnt <= 0;
        end else if (clk_en) begin

            // 2. 写入条件：输出有效
            if (packet_valid) begin
                $display("\npacket_data:%h:", packet_data);
                $display("\nc_out:%h:", packet_data[31:24]);
                $display("\nindex_x:%h:", packet_data[23:16]);
                $display("\nindex_y:%h:", packet_data[15:8]);
                $display("\nconf:%h:", packet_data[7:0]);
            end
        end
    end

endmodule