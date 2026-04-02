`timescale 1ns / 1ps

module tb_pe_page;

    // 参数设置
    parameter int unsigned PE_ROW_NUM = 9;
    parameter int unsigned PE_COL_NUM = 2;
    parameter int unsigned DATA_WIDTH = 7;
    parameter int unsigned WEIGHT_WIDTH = 8;
    parameter int unsigned OUTPUT_WIDTH = DATA_WIDTH + WEIGHT_WIDTH + $clog2(PE_ROW_NUM+1);

    // 信号声明
    logic clk, clk_en, h_sync;
    logic [DATA_WIDTH-1:0] data [PE_ROW_NUM-1:0];
    logic signed [OUTPUT_WIDTH-1:0] y_out [PE_COL_NUM-1:0];

    // 实例化被测模块
    pe_page #(
        .PE_ROW_NUM(PE_ROW_NUM),
        .PE_COL_NUM(PE_COL_NUM),
        .DATA_WIDTH(DATA_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH)
    ) uut (
        .clk(clk),
        .clk_en(clk_en),
        .h_sync(h_sync),
        .data(data),
        .y_out(y_out)
    );

    // 时钟生成
    always #5 clk = ~clk;

    initial begin
        // 初始化
        clk = 0;
        clk_en = 1;
        h_sync = 0;
        $monitor("Time=%0t | y_out[0]=%d, y_out[1]=%d", $time, y_out[0], y_out[1]);

        // 测试用例1: 全1输入 (保持10ns)
        $display("===== Test Case 1: All Ones =====");
        for (int i = 0; i < PE_ROW_NUM; i++) begin
            data[i] = {DATA_WIDTH{1'd1}};  // 创建DATA_WIDTH位的全1
        end
        #10;  // 保持10ns (1个时钟周期)
        $display("Input: %p", data);
        $display("Output: y_out[0]=%d, y_out[1]=%d", y_out[0], y_out[1]);

        // 测试用例2: 全0输入 (保持10ns)
        $display("\n===== Test Case 2: All Zeros =====");
        for (int i = 0; i < PE_ROW_NUM; i++) begin
            data[i] = {DATA_WIDTH{1'd0}};  // 创建DATA_WIDTH位的全0
        end
        #10;  // 保持10ns
        $display("Input: %p", data);
        $display("Output: y_out[0]=%d, y_out[1]=%d", y_out[0], y_out[1]);

        // 测试用例3: 1:PE_ROW_NUM (保持10ns)
        $display("\n===== Test Case 3: 1 to %0d =====", PE_ROW_NUM);
        for (int i = 0; i < PE_ROW_NUM; i++) begin
            data[i] = i + 1;  // 1,2,3,...,9
        end
        #10;  // 保持10ns
        $display("Input: %p", data);
        $display("Output: y_out[0]=%d, y_out[1]=%d", y_out[0], y_out[1]);

        // 测试用例4: PE_ROW_NUM:1 (保持10ns)
        $display("\n===== Test Case 4: %0d to 1 =====", PE_ROW_NUM);
        for (int i = 0; i < PE_ROW_NUM; i++) begin
            data[i] = PE_ROW_NUM - i;  // 9,8,7,...,1
        end
        #10;  // 保持10ns
        $display("Input: %p", data);
        $display("Output: y_out[0]=%d, y_out[1]=%d", y_out[0], y_out[1]);

        // 测试用例5: 交替0/1模式 (保持10ns)
        $display("\n===== Test Case 5: Alternating 0/1 =====");
        for (int i = 0; i < PE_ROW_NUM; i++) begin
            data[i] = (i % 2) ? 1 : 0;  // 0,1,0,1,...
        end
        #10;  // 保持10ns
        $display("Input: %p", data);
        $display("Output: y_out[0]=%d, y_out[1]=%d", y_out[0], y_out[1]);

        // 测试用例6: 递增模式 (保持10ns)
        $display("\n===== Test Case 6: Incrementing Pattern =====");
        for (int i = 0; i < PE_ROW_NUM; i++) begin
            data[i] = i * 2;  // 0,2,4,6,8,10,12,14,16
        end
        #10;  // 保持10ns
        $display("Input: %p", data);
        $display("Output: y_out[0]=%d, y_out[1]=%d", y_out[0], y_out[1]);

        $display("\n===== Test Complete =====");
        $finish;
    end

endmodule