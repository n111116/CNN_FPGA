module lprnet_spatial_sum #(
    parameter int unsigned PE_COL_NUM       = 4,
    parameter int unsigned CYCLE_PERIOD_OUT = 4,
    parameter int unsigned IMG_COL          = 128,
    parameter int unsigned IMG_ROW          = 128,
    parameter int unsigned DATA_WIDTH       = 8, 
    parameter int unsigned ACC_WIDTH        = 16 
) (
    input  logic                                clk,
    input  logic                                clk_en,
    input  logic                                rst_n,
    
    // 输入接口
    input  logic                                new_line_input_1,
    input  logic                                data_input_valid,
    input  logic signed [DATA_WIDTH-1:0]        data_input [PE_COL_NUM-1:0],
    
    // 输出接口
    output logic signed [ACC_WIDTH-1:0]         y_out [PE_COL_NUM-1:0],
    output logic                                new_line_out_1,
    output logic                                output_valid 
);

    localparam BRAM_DEPTH = CYCLE_PERIOD_OUT * IMG_COL;
    localparam ADDR_WIDTH = (BRAM_DEPTH > 1) ? $clog2(BRAM_DEPTH) : 1;
    localparam ROW_WIDTH  = (IMG_ROW > 1)    ? $clog2(IMG_ROW)    : 1;

    // =============================================================
    // 1. 状态维护 (行计数与行内计数)
    // =============================================================
    logic [ADDR_WIDTH-1:0] cnt_in_row;
    logic [ROW_WIDTH-1:0]  row_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_in_row        <= '0;
            row_cnt           <= IMG_ROW - 1;  // 初始定义为帧尾，第一行有效时将被置为0
        end else if (clk_en) begin
            if (new_line_input_1) begin
                if (row_cnt < IMG_ROW - 1) begin
                    row_cnt <= row_cnt + 1;
                end else begin
                    row_cnt <= 0;
                end
            end

            if (data_input_valid) begin
                if (cnt_in_row == BRAM_DEPTH - 1) begin
                    cnt_in_row <= '0;
                end else begin
                    cnt_in_row <= cnt_in_row + 1;
                end
            end
        end
    end

    // 当前周期（Stage 0）的状态
    logic is_first_row_s0;
    logic is_last_row_s0;
    assign is_first_row_s0 = (row_cnt == 0);
    assign is_last_row_s0  = (row_cnt == IMG_ROW - 1);


    // =============================================================
    // 2. 流水线信号定义
    // =============================================================
    // Stage 1
    logic                  valid_s1;
    logic [ADDR_WIDTH-1:0] cnt_in_row_s1;
    logic                  is_first_row_s1;
    logic                  is_last_row_s1;
    logic signed [DATA_WIDTH-1:0] data_input_s1 [PE_COL_NUM-1:0];
    
    // Stage 2
    logic                  valid_s2;
    logic [ADDR_WIDTH-1:0] cnt_in_row_s2;
    logic                  is_last_row_s2;
    logic signed [ACC_WIDTH-1:0]  add_op_a [PE_COL_NUM-1:0];
    logic signed [ACC_WIDTH-1:0]  add_op_b [PE_COL_NUM-1:0];

    // Stage 3
    logic                  valid_s3;
    logic [ADDR_WIDTH-1:0] cnt_in_row_s3;
    logic                  is_last_row_s3;
    logic signed [ACC_WIDTH-1:0]  sum_s3 [PE_COL_NUM-1:0];


    // =============================================================
    // 3. 例化 PE_COL_NUM 个 BRAM 并推进流水线
    // =============================================================
    logic signed [ACC_WIDTH-1:0] bram_q [PE_COL_NUM-1:0];

    genvar c;
    generate
        for (c = 0; c < PE_COL_NUM; c++) begin : gen_bram_cols
            
            // --- BRAM 实例化 ---
            // 读使能与地址在 Stage 0 给出，数据在 Stage 1 可用
            // 写使能与地址在 Stage 3 给出
            sdp_ram #(
                .WIDTH(ACC_WIDTH),
                .DEPTH(BRAM_DEPTH)
            ) u_row_buffer (
                .clk(clk),
                .clk_en(clk_en),
                .we(valid_s3),                 // Stage 3 写回
                .waddr(cnt_in_row_s3),
                .wdata(sum_s3[c]),
                .re(data_input_valid),         // Stage 0 读取
                .raddr(cnt_in_row),
                .q(bram_q[c])                  // Stage 1 获取
            );

            // --- 数据计算数据通路 (Data Path) ---
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    data_input_s1[c] <= '0;
                    add_op_a[c]      <= '0;
                    add_op_b[c]      <= '0;
                    sum_s3[c]        <= '0;
                    y_out[c]         <= '0;
                end else if (clk_en) begin
                    // Stage 1: 寄存输入数据
                    data_input_s1[c] <= data_input[c];
                    
                    // Stage 2: 准备累加操作数 (利用 is_first_row 隐式清零)
                    add_op_a[c] <= is_first_row_s1 ? '0 : bram_q[c];
                    add_op_b[c] <= signed'(data_input_s1[c]);

                    // Stage 3: 累加完成并锁存
                    sum_s3[c] <= add_op_a[c] + add_op_b[c];

                    // Output: 从 Stage 3 同步输出
                    y_out[c] <= sum_s3[c];
                end
            end
        end
    endgenerate

    // --- 控制信号通路 (Control Path) ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_s1 <= 1'b0; valid_s2 <= 1'b0; valid_s3 <= 1'b0;
            is_first_row_s1 <= 1'b0; 
            is_last_row_s1  <= 1'b0; is_last_row_s2 <= 1'b0; is_last_row_s3 <= 1'b0;
            cnt_in_row_s1   <= '0;   cnt_in_row_s2  <= '0;   cnt_in_row_s3  <= '0;
            new_line_out_1  <= 1'b0;
            output_valid    <= 1'b0;
        end else if (clk_en) begin
            // 推进 Valid 信号
            valid_s1 <= data_input_valid;
            valid_s2 <= valid_s1;
            valid_s3 <= valid_s2;

            // 推进边界标志
            is_first_row_s1 <= is_first_row_s0;
            is_last_row_s1  <= is_last_row_s0;
            is_last_row_s2  <= is_last_row_s1;
            is_last_row_s3  <= is_last_row_s2;

            // 推进地址信号
            cnt_in_row_s1 <= cnt_in_row;
            cnt_in_row_s2 <= cnt_in_row_s1;
            cnt_in_row_s3 <= cnt_in_row_s2;

            // 提前拉高 new_line_out_1 (Stage 2 触发)
            // 在计算最后一行首个通道的周期，拉高 new_line_out_1
            new_line_out_1 <= valid_s2 && is_last_row_s2 && (cnt_in_row_s2 == '0);

            // 拉高 output_valid (Stage 3 触发，比 new_line_out_1 晚一拍)
            output_valid <= valid_s3 && is_last_row_s3;
        end
    end

endmodule