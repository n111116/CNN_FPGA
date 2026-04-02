`timescale 1ns / 1ps
`include "layer1.vh"
module tb_usb_to_pe_adapter_conv2d();

    // ============================================================
    // 1. 参数定义
    // ============================================================
    parameter int CLK_PERIOD         = 10; // 时钟周期 10ns (100MHz)
    parameter int DATA_WIDTH         = 8;
    parameter int CHANNEL_IN         = 3;
    parameter int OUT_WIDTH_POST_33  = 8;
    parameter int OUT_WIDTH_LAYER23  = 8;

    // ============================================================
    // 2. 信号声明
    // ============================================================
    logic clk;
    logic rst_n;

    // 下行 USB FIFO 接口
    logic [31:0] usb_fifo_data;
    logic        usb_fifo_empty;
    logic        usb_rd_en;
    logic        new_line_1;

    // 上行 USB FIFO 接口
    logic        usb_wr_en;
    logic [31:0] usb_wr_data;

    // 下行 PE 接口
    logic [DATA_WIDTH-1:0] pe_parallel_data [CHANNEL_IN-1:0];
    logic                  input_valid;

    // 上行 PE 接口
    logic [OUT_WIDTH_POST_33-1:0] packet_data;
    logic                         packet_valid;
    logic                         frame_done;
    logic [OUT_WIDTH_LAYER23-1:0] layer23_data;
    logic                         layer23_valid;

    // ============================================================
    // 3. 模块实例化 (DUT)
    // ============================================================
    usb_to_pe_adapter_conv2d #(
        .DATA_WIDTH        (DATA_WIDTH_LAYER1),
        .CHANNEL_IN        (CHANNEL_IN),
        .CYCLE_PERIOD_OUT  (CYCLE_PERIOD_OUT_LAYER1 / STEP_COL_LAYER1 / STEP_ROW_LAYER1),
        .OUT_WIDTH_POST_33 (OUT_WIDTH_POST_33),
        .OUT_WIDTH_LAYER23 (OUT_WIDTH_LAYER23)
    ) u_adapter (
        .clk              (clk),
        .rst_n            (rst_n),
        .usb_fifo_data    (usb_fifo_data),
        .usb_fifo_empty   (usb_fifo_empty),
        .usb_rd_en        (usb_rd_en),
        .new_line_1       (new_line_1),
        .usb_wr_en        (usb_wr_en),
        .usb_wr_data      (usb_wr_data),
        .pe_parallel_data (pe_parallel_data),
        .input_valid      (input_valid),
        .packet_data      (packet_data),
        .packet_valid     (packet_valid),
        .frame_done       (frame_done),
        .layer23_data     (layer23_data),
        .layer23_valid    (layer23_valid)
    );

    // ============================================================
    // 4. 时钟与复位生成
    // ============================================================
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // ============================================================
    // 5. 模拟 USB 下行 FIFO 行为
    // ============================================================
    // 定义一个深度为 16 的测试数据存储器
    logic [31:0] mock_fifo_mem [0:15];
    int fifo_rd_ptr = 0;
    int fifo_max_len = 8; // 测试时预先写入 8 个有效数据

    initial begin
        // 初始化测试数据
        // 格式: {Header[31:24], CH2[23:16], CH1[15:8], CH0[7:0]}
        mock_fifo_mem[0] = 32'hFF_00_00_00; // [新行标识]
        mock_fifo_mem[1] = 32'h00_03_02_01; // 数据 1 (CH2=3, CH1=2, CH0=1)
        mock_fifo_mem[2] = 32'h00_06_05_04; // 数据 2 (CH2=6, CH1=5, CH0=4)
        mock_fifo_mem[3] = 32'h00_09_08_07; // 数据 3
        mock_fifo_mem[4] = 32'hFF_00_00_00; // [新行标识]
        mock_fifo_mem[5] = 32'h00_13_12_11; // 数据 4
        mock_fifo_mem[6] = 32'h00_16_15_14; // 数据 5
        mock_fifo_mem[7] = 32'h00_19_18_17; // 数据 6
    end

    // 读延迟模拟: 当 DUT 发出 rd_en，FIFO 在下一个时钟沿给出数据
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            usb_fifo_data <= 32'd0;
            fifo_rd_ptr   <= 0;
        end else if (usb_rd_en && !usb_fifo_empty) begin
            usb_fifo_data <= mock_fifo_mem[fifo_rd_ptr];
            fifo_rd_ptr   <= fifo_rd_ptr + 1;
        end
    end

    // 空信号控制：当读指针达到最大长度时，拉高 empty 告诉 DUT 没有数据了
    assign usb_fifo_empty = (fifo_rd_ptr >= fifo_max_len);

    // ============================================================
    // 6. 激励产生与测试流程
    // ============================================================
    initial begin
        // (1) 初始化信号
        rst_n         = 1'b0;
        packet_valid  = 1'b0;
        packet_data   = 8'h00;
        frame_done    = 1'b0;
        layer23_valid = 1'b0;
        layer23_data  = 8'h00;

        // (2) 释放复位
        #(CLK_PERIOD * 10);
        rst_n = 1'b1;
        
        // (3) 等待下行数据解析完成 
        // DUT 读取到 FF 后会有 100 周期的 delay，我们需要等待足够长的时间
        #(CLK_PERIOD * 300);

        // (4) 触发上行数据回传 (测试你新增的发送逻辑)
        send_pe_results();

        // (5) 等待流水线写回完成 (66拍流水线延迟 + 64个数据写入)
        #(CLK_PERIOD * 200);
        
        $display("========================================");
        $display("           Simulation Finished          ");
        $display("========================================");
        $finish;
    end

    // ============================================================
    // 7. 模拟 PE 向上行发送结果的任务
    // ============================================================
    task send_pe_results();
        begin
            $display("[%0t] Starting PE Uplink Transmission...", $time);
            
            // a. 发送 packet_valid 和 packet_data (触发模块开始上行传输)
            @(posedge clk);
            packet_valid <= 1'b1;
            packet_data  <= 8'hAA; 
            
            @(posedge clk);
            packet_valid <= 1'b0;
            
            // b. 模拟产生 64 个连续的 layer23_data 结果
            for (int i = 0; i < 64; i++) begin
                layer23_valid <= 1'b1;
                layer23_data  <= 8'h10 + i; // 随便生成一些递增的规律数据
                @(posedge clk);
            end
            
            // 传输完毕，拉低有效信号
            layer23_valid <= 1'b0;
        end
    endtask

endmodule