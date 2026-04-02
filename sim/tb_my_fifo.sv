`timescale 1ns / 1ps

module tb_my_fifo();

// ============================================================
// 参数定义
// ============================================================
parameter DATA_WIDTH = 8;           // 与FIFO实例匹配
parameter FIFO_DEPTH = 16;           // 深度（2的幂）

// 时钟周期（可调整以模拟不同速率）
parameter WR_CLK_PERIOD = 10;        // 写时钟周期 10ns (100MHz)
parameter RD_CLK_PERIOD = 15;        // 读时钟周期 15ns (~66.67MHz)

// ============================================================
// 信号声明
// ============================================================
reg                     wr_clk;
reg                     rd_clk;
reg                     rst;          // 高有效复位
reg                     wr_en;
reg  [DATA_WIDTH-1:0]   din;
reg                     rd_en;
wire [DATA_WIDTH-1:0]   dout;
wire                    full;
wire                    empty;

// 测试控制变量
reg  [DATA_WIDTH-1:0]   wr_count;     // 写入数据计数器（期望值）
reg  [DATA_WIDTH-1:0]   rd_count;     // 读出数据计数器（期望值）
integer                 wr_cnt;       // 写入总次数（用于统计）
integer                 rd_cnt;       // 读出总次数（用于统计）
integer                 error_cnt;    // 错误计数
reg                     test_finished;

// ============================================================
// 实例化待测模块
// ============================================================
my_fifo #(
    .DATA_WIDTH (DATA_WIDTH),
    .FIFO_DEPTH (FIFO_DEPTH)
) u_fifo (
    .rd_clk     (rd_clk),
    .wr_clk     (wr_clk),
    .rst        (rst),
    .wr_en      (wr_en),
    .din        (din),
    .rd_en      (rd_en),
    .dout       (dout),
    .full       (full),
    .empty      (empty)
);

// ============================================================
// 时钟生成
// ============================================================
initial begin
    wr_clk = 0;
    forever #(WR_CLK_PERIOD/2) wr_clk = ~wr_clk;
end

initial begin
    rd_clk = 0;
    forever #(RD_CLK_PERIOD/2) rd_clk = ~rd_clk;
end

// ============================================================
// 复位与测试主流程
// ============================================================
initial begin
    // 初始化信号
    rst           = 1;
    wr_en         = 0;
    din           = 0;
    rd_en         = 0;
    wr_count      = 0;
    rd_count      = 0;
    wr_cnt        = 0;
    rd_cnt        = 0;
    error_cnt     = 0;
    test_finished = 0;

    // 保持复位一段时间
    repeat (5) @(posedge wr_clk);
    @(negedge wr_clk) rst = 0;   // 释放复位
    $display(" [%0t] Reset released.", $time);

    // 等待时钟稳定
    repeat (10) @(posedge wr_clk);

    // -------------------- 测试1：基本写读 --------------------
    $display("\n=== Test 1: Basic write/read ===");
    test_basic();

    // -------------------- 测试2：写满读空 --------------------
    $display("\n=== Test 2: Full and empty ===");
    test_full_empty();

    // -------------------- 测试3：同时读写 --------------------
    $display("\n=== Test 3: Concurrent write/read ===");
    test_concurrent();

    // -------------------- 测试4：随机激励 --------------------
    $display("\n=== Test 4: Random stimulus ===");
    test_random();

    // 结束测试
    repeat (20) @(posedge wr_clk);
    test_finished = 1;
    $display("\n=== Simulation Finished ===  Total Errors: %0d", error_cnt);
    #100 $finish;
end

// ============================================================
// 读操作监控：在每个读时钟沿检查数据正确性
// ============================================================
always @(posedge rd_clk) begin
    if (rd_en && !empty) begin
        // 预期数据应为 rd_count
        if (dout !== rd_count) begin
            $error("[%0t] Read mismatch! Expected: %0d, Got: %0d", $time, rd_count, dout);
            error_cnt = error_cnt + 1;
        end else begin
            $display("[%0t] Read OK: data=%0d", $time, dout);
        end
        rd_count <= rd_count + 1;
        rd_cnt   <= rd_cnt + 1;
    end
end

// ============================================================
// 写操作任务：写入一个数据（自动递增计数）
// ============================================================
task write_data;
    input [DATA_WIDTH-1:0] data;
    begin
        @(posedge wr_clk);
        while (full) @(posedge wr_clk);   // 若满则等待
        wr_en <= 1;
        din   <= data;
        @(posedge wr_clk);
        wr_en <= 0;
        wr_cnt <= wr_cnt + 1;
        $display("[%0t] Write: data=%0d", $time, data);
    end
endtask

// ============================================================
// 读操作任务：尝试读取一个数据（空时等待）
// ============================================================
task read_data;
    begin
        @(posedge rd_clk);
        while (empty) @(posedge rd_clk);
        rd_en <= 1;
        @(posedge rd_clk);
        rd_en <= 0;
    end
endtask

// ============================================================
// 测试用例1：基本写读（先写几个数，再读几个数）
// ============================================================
task test_basic;
    integer i;
    begin
        // 写5个数
        for (i = 0; i < 5; i = i + 1) begin
            write_data(wr_count);
            wr_count <= wr_count + 1;
        end

        // 读5个数
        for (i = 0; i < 5; i = i + 1) begin
            read_data();
        end

        // 验证空标志
        repeat (5) @(posedge rd_clk);
        if (empty !== 1'b1)
            $error("Empty flag not asserted after reading all data.");
        else
            $display("Empty flag OK after reading all.");
    end
endtask

// ============================================================
// 测试用例2：写满FIFO，验证full；读空，验证empty
// ============================================================
task test_full_empty;
    integer i;
    begin
        // 写满FIFO（FIFO_DEPTH个数据）
        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
            write_data(wr_count);
            wr_count <= wr_count + 1;
        end

        // 检查full标志
        @(posedge wr_clk);
        if (full !== 1'b1)
            $error("Full flag not asserted after writing %0d words.", FIFO_DEPTH);
        else
            $display("Full flag asserted correctly.");

        // 尝试再写一个（应被忽略）
        write_data(wr_count);   // 该任务会等待满释放，但实际不应写入，我们强制写一次看是否被忽略
        // 为了测试忽略，我们手动尝试写，但full为高，任务中的while(full)会等待，因此需要调整：我们想测试写满后写入无效，但任务会等待直到不满，所以暂时不使用任务
        // 改为手动测试：在full为高时发送一个写使能，然后检查wr_count是否增加
        @(posedge wr_clk);
        if (full) begin
            wr_en <= 1;
            din   <= wr_count;
            @(posedge wr_clk);
            wr_en <= 0;
            // 预期FIFO未写入，wr_count不应增加
            // 但我们无法直接观察FIFO内部，可以通过后续读出来验证
        end

        // 读空FIFO
        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
            read_data();
        end

        // 检查empty标志
        @(posedge rd_clk);
        if (empty !== 1'b1)
            $error("Empty flag not asserted after reading all data.");
        else
            $display("Empty flag asserted correctly.");

        // 验证多写的那一个数据没有进入FIFO
        // 现在FIFO应该是空的，如果之前多写成功，那么读一个数据会得到那个值，但rd_count应该等于之前写入的最后一个值+1
        // 等待一段时间，然后尝试读一次，应该一直空
        @(posedge rd_clk);
        if (empty !== 1'b1) begin
            // 如果有数据，读出来看看
            rd_en <= 1;
            @(posedge rd_clk);
            rd_en <= 0;
            if (dout === wr_count)   // 如果读出的数据等于尝试写入的wr_count，说明写入成功
                $error("Write when full was not ignored!");
            else
                $display("Extra write correctly ignored.");
        end else
            $display("Extra write correctly ignored (empty remains high).");
    end
endtask

// ============================================================
// 测试用例3：同时读写（背对背）
// ============================================================
task test_concurrent;
    integer i;
    reg [DATA_WIDTH-1:0] last_wr;
    begin
        // 同时进行读写：连续写，同时连续读
        fork
            // 写线程：写入 2*FIFO_DEPTH 个数
            begin
                for (i = 0; i < 2*FIFO_DEPTH; i = i + 1) begin
                    write_data(wr_count);
                    wr_count <= wr_count + 1;
                end
            end
            // 读线程：读取 2*FIFO_DEPTH 个数
            begin
                for (i = 0; i < 2*FIFO_DEPTH; i = i + 1) begin
                    read_data();
                end
            end
        join

        // 最终FIFO应为空
        if (empty !== 1'b1) begin
            $error("FIFO not empty after concurrent test.");
            // 读空剩余的
            while (!empty) read_data();
        end else
            $display("Concurrent test passed, FIFO empty.");
    end
endtask

// ============================================================
// 测试用例4：随机激励（随机写/读，持续一段时间）
// ============================================================
task test_random;
    integer i;
    integer loop_count;
    integer op;
    begin
        loop_count = 200;
        for (i = 0; i < loop_count; i = i + 1) begin
            op = $random % 2;   // 0:写, 1:读
            if (op == 0) begin
                // 写操作（若不满）
                if (!full) begin
                    write_data(wr_count);
                    wr_count <= wr_count + 1;
                end
            end else begin
                // 读操作（若不空）
                if (!empty) begin
                    read_data();
                end
            end
            // 随机等待几个时钟
            repeat ($random % 5) @(posedge wr_clk);
        end

        // 最终将FIFO读空
        $display("Draining FIFO after random test...");
        while (!empty) read_data();
        $display("Random test completed, FIFO empty.");
    end
endtask

// ============================================================
// 监控波形结束
// ============================================================
initial begin
    $dumpfile("tb_my_fifo.vcd");
    $dumpvars(0, tb_my_fifo);
end

endmodule