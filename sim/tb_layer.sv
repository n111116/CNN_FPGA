// 要更换目标层数时，使用查找与替换功能，把所有 "_LAYER0" 替换成 "_LAYERn"即可。
`timescale 1ns/1ps
`include "layer0.vh"
`include "layer1.vh"
`include "layer2.vh"
`include "layer3.vh"
`include "layer4.vh"
`include "layer5.vh"
`include "layer6.vh"
`include "layer7.vh"
`include "layer8.vh"
`include "layer9.vh"
`include "layer10.vh"
`include "layer11.vh"
`include "layer20.vh"
`include "layer21.vh"
`include "layer22.vh"
`include "layer23.vh"
`include "layer24.vh"
`include "layer25.vh"
`include "layer26.vh"
`include "layer27.vh"
`include "layer28.vh"

module tb_layer;

    // 预估最大数据量
    localparam int MEM_DEPTH = IMG_COL_LAYER0 * IMG_ROW_LAYER0 * CYCLE_PERIOD_IN_LAYER0 * PE_PAGE_NUM_LAYER0;

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
    logic [DATA_WIDTH_LAYER0-1:0] data_input [PE_PAGE_NUM_LAYER0-1:0];
    
    // 输出数据
    logic [OUT_WIDTH_LAYER0-1:0] y_out [PE_COL_NUM_LAYER0-1:0];
    logic new_line_out_1;

    // 仿真内存
    logic [DATA_WIDTH_LAYER0-1:0] file_mem [0:MEM_DEPTH-1];

    // =========================================================
    // 3. 模块例化
    // =========================================================
    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER0),
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER0),
        .PE_ROW_NUM(PE_ROW_NUM_LAYER0),
        .PE_COL_NUM(PE_COL_NUM_LAYER0),
        .MAX_POOL(MAX_POOL_LAYER0),
        .WITH_RELU(WITH_RELU_LAYER0),
        .KERNEL_COL(KERNEL_COL_LAYER0),
        .KERNEL_ROW(KERNEL_ROW_LAYER0),
        .USE_DSP_PE(USE_DSP_PE_LAYER0),
        .DATA_WIDTH(DATA_WIDTH_LAYER0),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER0),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER0),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER0),
        .STEP_COL(STEP_COL_LAYER0),
        .STEP_ROW(STEP_ROW_LAYER0),
        .IMG_COL(IMG_COL_LAYER0),
        .IMG_ROW(IMG_ROW_LAYER0),
        .SHIFT_KEY(SHIFT_KEY_LAYER0),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER0),
        .OUT_WIDTH(OUT_WIDTH_LAYER0),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER0),
        .ACC_WIDTH(ACC_WIDTH_LAYER0)
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
        $readmemh(INPUT_FILE_PATH_LAYER0, file_mem);
        
        $display("------------------------------------------------");
        $display("File Read Check from: %s", INPUT_FILE_PATH_LAYER0);
        $display("%s",$sformatf("weights_layer%0d_page%0d.mem", LAYER_NUM_LAYER0, 0));
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
        
        for(int p=0; p<PE_PAGE_NUM_LAYER0; p++) begin
            data_input[p] = 0;
        end

        // --- 复位序列 ---
        repeat(10) @(posedge clk);
        rst_n = 1;              
        repeat(5) @(posedge clk);
        clk_en = 1;             

        for (int index_y = 0; index_y < IMG_ROW_LAYER0 * 2; index_y++) begin 
            
            // 1. 行首同步
            @(posedge clk);
            new_line_input_1 = 1;
            data_input_valid = 0; 
            
            @(posedge clk);
            new_line_input_1 = 0;
            
            // 2. 输入一行像素
            for (int index_x = 0; index_x < IMG_COL_LAYER0; index_x++) begin                
                for (int t=0; t<CYCLE_PERIOD_IN_LAYER0; t++) begin
                    // --- A. 发送数据 (持续 1 个周期) ---
                    data_input_valid <= 1;
                    for(int p=0; p<PE_PAGE_NUM_LAYER0; p++) begin
                        int addr; // 声明在循环内，先声明后赋值

                        // 地址计算
                        addr = (index_y * IMG_COL_LAYER0 + index_x) * PE_PAGE_NUM_LAYER0
                                 * CYCLE_PERIOD_IN_LAYER0 + p * CYCLE_PERIOD_IN_LAYER0 + t;
                        data_input[p] <= file_mem[addr % MEM_DEPTH];
                        // data_input[p] <= index_x * 16 + t + 1; // index_y*64 + 
                        // data_input[p] <= index_y*64 + index_x + 1;
                        // data_input[p] <= p * CYCLE_PERIOD_IN_LAYER0 + t;
                    end
                    // data_input[0] <= index_x;
                    // data_input[1] <= index_y[0];
                    // data_input[2] <= index_y[0];
                    @(posedge clk); // 推进 1 个周期，DUT 此时采样到有效数据

                end
                // --- B. 空闲等待 (持续 3 个周期) ---
                // 单像素总周期CYCLE_PERIOD / STEP_COL / STEP_ROW
                data_input_valid <= 0;
                repeat((CYCLE_PERIOD_OUT_LAYER0 / STEP_COL_LAYER0 / STEP_ROW_LAYER0-1)
                *CYCLE_PERIOD_IN_LAYER0) @(posedge clk);
            end
            
            // 3. 行尾间隙
            data_input_valid = 0;
            repeat((CYCLE_PERIOD_OUT_LAYER0 / STEP_COL_LAYER0 / STEP_ROW_LAYER0)
                *CYCLE_PERIOD_IN_LAYER0) @(posedge clk); 
            // if(index_y == IMG_ROW_LAYER0 - 1) begin
            //     repeat((CYCLE_PERIOD_OUT_LAYER0 / STEP_COL_LAYER0 / STEP_ROW_LAYER0)
            //     *CYCLE_PERIOD_IN_LAYER0) @(posedge clk);
            // end
            // repeat(1280*15) @(posedge clk); 

            $display("Finished driving row %0d at time %t", index_y, $time);
        end

        // 4. 结束
        data_input_valid = 0;
        repeat(300_000) @(posedge clk); 
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
        out_file = $fopen(OUTPUT_FILE_PATH_LAYER0, "w");
        if (!out_file) begin
            $display("Error: Could not open output file: %s", OUTPUT_FILE_PATH_LAYER0);
            $stop;
        end else begin
            $display("Output file opened: %s", OUTPUT_FILE_PATH_LAYER0);
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
            write_enable <= 0;
        end else if (clk_en) begin
            
            // 1. 启动/重置条件：当 new_line_out_1 有效时
            if (new_line_out_1) begin
                write_enable <= 1;  // 开启写入
                // write_cnt <= 0;     // 重置计数器
                $display("\nTime %t: New Line Out detected. Starting capture.", $time);
            end
            if (write_enable && output_valid) begin
            // 2. 写入条件：使能开启 且 输出有效
                
                // 格式化写入：一次写入 PE_COL_NUM_LAYER0 个数据
                for (int c = 0; c < PE_COL_NUM_LAYER0; c++) begin
                    $fwrite(out_file, "%6h ", y_out[c]);
                    // $display("Time %t: y_out = %2h .", $time, y_out[c]);
                end
                $fwrite(out_file, "\n"); // 换行

                write_cnt <= write_cnt + 1;
                    
                // end
            end
        end
    end

endmodule