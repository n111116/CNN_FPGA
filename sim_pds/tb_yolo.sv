`timescale 1ns/1ps

// =========================================================
// 包含所有需要的头文件，以获取各层的参数宏定义
// =========================================================
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

module tb_yolo;

    // =========================================================
    // 1. TB 参数定义
    // =========================================================
    // 测试输出文件的保存路径 (建议自行修改为你的实际路径)
    localparam string OUTPUT_FILE_PATH = "yolo_post_result.txt";

    // 预估读取仿真图像的最大数据量
    localparam int MEM_DEPTH = IMG_COL_LAYER0 * IMG_ROW_LAYER0 * CYCLE_PERIOD_IN_LAYER0 * PE_PAGE_NUM_LAYER0;

    // =========================================================
    // 2. 信号定义 (严格采用压缩数组格式，与 top_yolo 完全对齐)
    // =========================================================
    // 全局控制
    logic clk;
    logic clk_en;
    logic rst_n;                 
    
    // 输入接口信号
    logic new_line_input_1;      
    logic data_input_valid;      
    // 【关键】：这里必须是压缩数组，方括号全在变量名左侧
    logic [PE_PAGE_NUM_LAYER0-1:0][DATA_WIDTH_LAYER0-1:0] data_input;
    
    // 输出接口 1 信号 (Layer 8 原始特征图)
    // 【关键】：这里必须是压缩数组
    logic [PE_COL_NUM_LAYER7-1:0][OUT_WIDTH_LAYER7-1:0] layer_y_out_layer7;
    logic out_valid_layer7;
    logic new_line_out_1_layer7;

    // 输出接口 2 信号 (Post Process 极值坐标与置信度)
    logic [31:0] post_packet_data;
    logic        post_packet_valid;
    logic        post_frame_done;

    // 仿真内存 (用于存放测试图片的 Hex 数据)
    logic [DATA_WIDTH_LAYER0-1:0] file_mem [0:MEM_DEPTH-1];

    // =========================================================
    // 3. 例化待测模块 (DUT)
    // =========================================================
    top_yolo #(
        .LUT_FILE("sigmoid_lut_9bit_to_8bit_h.mem"), // 请确保此路径下有对应的 LUT 文件
        .CONV_POSITIVE(1),
        .CONF_WIDTH(8),
        .CONF_THRESH(50)  // 调整阈值以过滤低置信度结果
    ) dut (
        .clk                    (clk),
        .clk_en                 (clk_en),
        .rst_n                  (rst_n),

        .new_line_input_1       (new_line_input_1),
        .data_input_valid       (data_input_valid),
        .data_input             (data_input),

        .layer_y_out_layer7     (layer_y_out_layer7),
        .out_valid_layer7       (out_valid_layer7),
        .new_line_out_1_layer7  (new_line_out_1_layer7),

        .post_packet_data       (post_packet_data),
        .post_packet_valid      (post_packet_valid),
        .post_frame_done        (post_frame_done)
    );

    // =========================================================
    // 4. 时钟生成 (100MHz)
    // =========================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // =========================================================
    // 5. 激励生成 (模拟 Adapter 送入数据流)
    // =========================================================
    
    // ----------------------------------------
    // Step 5.1: 加载测试图像数据
    // ----------------------------------------
    initial begin
        // 初始化内存为0
        for(int i=0; i<MEM_DEPTH; i++) file_mem[i] = 0;

        // 若有真实的 hex 图片数据，可取消下方注释并修改文件路径：
        // $readmemh("input_image.mem", file_mem);
        
        $display("------------------------------------------------");
        $display("YOLO Testbench Started.");
        $display("Resolution: %0d x %0d", IMG_COL_LAYER0, IMG_ROW_LAYER0);
        $display("------------------------------------------------");
    end

    // ----------------------------------------
    // Step 5.2: 驱动主逻辑
    // ----------------------------------------
    initial begin
        // --- 初始化 ---
        clk_en           = 0;
        rst_n            = 0;
        new_line_input_1 = 0;
        data_input_valid = 0;
        data_input       = '0;

        // --- 复位序列 ---
        repeat(10) @(posedge clk);
        rst_n = 1;              
        repeat(5) @(posedge clk);
        clk_en = 1;             

        // --- 模拟传输一帧完整的图像 ---
        for (int frame = 0; frame < 1; frame++) begin
            $display("\n---> Starting Frame %0d", frame);
            
            for (int index_y = 0; index_y < IMG_ROW_LAYER0; index_y++) begin 
                
                // 1. 行首同步 (发送 new_line_input_1 脉冲)
                @(posedge clk);
                new_line_input_1 = 1;
                data_input_valid = 0; 
                
                @(posedge clk);
                new_line_input_1 = 0;
                
                // 2. 输入一行像素
                for (int index_x = 0; index_x < IMG_COL_LAYER0; index_x++) begin                
                    for (int t=0; t<CYCLE_PERIOD_IN_LAYER0; t++) begin
                        // --- A. 发送有效数据 (持续 1 个周期) ---
                        data_input_valid <= 1;
                        
                        // 【赋值核心】直接对压缩数组的 Page 维度进行赋值
                        for(int p=0; p<PE_PAGE_NUM_LAYER0; p++) begin
                            int addr; 
                            addr = (index_y * IMG_COL_LAYER0 + index_x) * PE_PAGE_NUM_LAYER0 * CYCLE_PERIOD_IN_LAYER0 + p * CYCLE_PERIOD_IN_LAYER0 + t;
                            
                            // 若读取了真实图片数据，使用下一行：
                            data_input[p] <= file_mem[addr % MEM_DEPTH];
                            
                            // 这里采用模拟数据 (例如固定值 0x10) 驱动网络
                            // data_input[0] <= 'h10; 
                            // data_input[1] <= 'h10; 
                            // data_input[2] <= 'heb; 
                        end
                        @(posedge clk); 
                    end
                    
                    // --- B. 空闲等待间隔 ---
                    // 单像素总周期空闲控制
                    data_input_valid <= 0;
                    repeat((CYCLE_PERIOD_OUT_LAYER0 / STEP_COL_LAYER0 / STEP_ROW_LAYER0 - 1) * CYCLE_PERIOD_IN_LAYER0) @(posedge clk);
                end
                
                // 3. 行尾间隙 (模拟行与行之间的消隐期)
                data_input_valid = 0;
                repeat(50) @(posedge clk); 
                
                // 打印进度 (每 16 行打印一次，避免刷屏)
                if (index_y % 16 == 0) begin
                    $display("  Driving row %0d at time %t", index_y, $time);
                end
            end
            
            // 4. 帧尾间隙
            $display("Waiting for network pipeline to flush...");
            repeat(2000) @(posedge clk); 
        end

        // 结束仿真
        $display("------------------------------------------------");
        $display("Simulation Finished Successfully.");
        $display("------------------------------------------------");
        $stop;
    end

    // =========================================================
    // 6. 监控 Post Process 结果并写入文件
    // =========================================================
    integer out_file;
    logic [7:0]  pkt_conf;
    logic [7:0]  pkt_x;
    logic [7:0]  pkt_y;
    logic [7:0]  pkt_ch;

    // 解析打包出来的数据 (按照 post_cv3_conv2d 模块的规则定义)
    assign pkt_ch   = post_packet_data[31:24];
    assign pkt_x    = post_packet_data[23:16];
    assign pkt_y    = post_packet_data[15:8];
    assign pkt_conf = post_packet_data[7:0];

    initial begin
        out_file = $fopen(OUTPUT_FILE_PATH, "w");
        if (!out_file) begin
            $display("Error: Could not open output file: %s", OUTPUT_FILE_PATH);
        end else begin
            $display("Output file opened: %s", OUTPUT_FILE_PATH);
            $fwrite(out_file, "CH_OUT | IDX_X | IDX_Y | CONFIDENCE\n");
            $fwrite(out_file, "-------+-------+-------+-----------\n");
        end
    end

    final begin
        if (out_file) $fclose(out_file);
    end

    // 当后处理模块输出有效数据包时，抓取并写入文件
    always @(posedge clk) begin
        if (clk_en && post_packet_valid) begin
            // 终端实时打印检测结果
            $display(">>> [YOLO DETECT] Time %t | CH: %d | X: %0d | Y: %0d | Conf: %0d", 
                     $time, pkt_ch, pkt_x, pkt_y, pkt_conf);
            
            // 写入文本文件以便与 Python 模型输出做比对
            if (out_file) begin
                $fwrite(out_file, "  %3d  |  %3d  |  %3d  |    %3d\n", pkt_ch, pkt_x, pkt_y, pkt_conf);
            end
        end
        
        // 监控帧结束标志
        if (clk_en && post_frame_done) begin
            $display("--- Frame Done Triggered ---");
            if (out_file) $fwrite(out_file, "--- END OF FRAME ---\n");
        end
    end

endmodule