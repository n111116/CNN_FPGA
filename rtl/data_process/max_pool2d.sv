module max_pool2d #(
    parameter int unsigned PE_ROW_NUM = 9,
    parameter int unsigned PE_COL_NUM = 4, 
    parameter int unsigned DATA_WIDTH = 7
) (
    input  logic                  clk,
    input  logic                  clk_en,
    input  logic                  rst_n,
    
    // 控制信号输入
    input  logic                  new_line_1,
    input  logic                  input_valid,
    
    // 数据输入 (针对单个 page 传入的 PE_ROW_NUM 个数据)
    input  logic   [DATA_WIDTH-1:0] data [PE_ROW_NUM-1:0],
    
    // 数据与控制信号输出
    output logic   [DATA_WIDTH-1:0] y_out [PE_COL_NUM-1:0],
    output logic                  new_line_out_1,
    output logic                  output_valid
);

    // =============================================================
    // 1. 控制信号打两拍 (2-Cycle Delay)
    // =============================================================
    logic [1:0] new_line_delay;
    logic [1:0] valid_delay;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            new_line_delay <= '0;
            valid_delay    <= '0;
        end else if (clk_en) begin
            new_line_delay <= {new_line_delay[0], new_line_1};
            valid_delay    <= {valid_delay[0], input_valid};
        end
    end

    assign new_line_out_1 = new_line_delay[1];
    assign output_valid      = valid_delay[1];

    // =============================================================
    // 2. 第一级流水线：将数据分为两半，分别求最大值并寄存 (Cycle 1)
    // =============================================================
    localparam HALF_ROW = PE_ROW_NUM / 2;
    
    logic [DATA_WIDTH-1:0] comb_max_half0;
    logic [DATA_WIDTH-1:0] comb_max_half1;
    
    // 组合逻辑求两半区最大值
    always_comb begin
        // 前半区
        comb_max_half0 = data[0];
        for (int i = 1; i < HALF_ROW; i++) begin
            if (data[i] > comb_max_half0) begin
                comb_max_half0 = data[i];
            end
        end
        
        // 后半区 (兼容 PE_ROW_NUM == 1 的特殊情况)
        if (PE_ROW_NUM > 1) begin
            comb_max_half1 = data[HALF_ROW];
            for (int i = HALF_ROW + 1; i < PE_ROW_NUM; i++) begin
                if (data[i] > comb_max_half1) begin
                    comb_max_half1 = data[i];
                end
            end
        end else begin
            comb_max_half1 = data[0]; // 如果只有1个元素，两半相等
        end
    end

    logic [DATA_WIDTH-1:0] reg_max_half0;
    logic [DATA_WIDTH-1:0] reg_max_half1;

    // 第一级寄存器
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_max_half0 <= '0;
            reg_max_half1 <= '0;
        end else if (clk_en) begin
            reg_max_half0 <= comb_max_half0;
            reg_max_half1 <= comb_max_half1;
        end
    end

    // =============================================================
    // 3. 第二级流水线：比较两个半区的最大值，输出最终结果 (Cycle 2)
    // =============================================================
    logic [DATA_WIDTH-1:0] reg_max_final;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_max_final <= '0;
        end else if (clk_en) begin
            if (reg_max_half0 > reg_max_half1) begin
                reg_max_final <= reg_max_half0;
            end else begin
                reg_max_final <= reg_max_half1;
            end
        end
    end

    // =============================================================
    // 4. 输出分发：将计算结果分配给所有的 PE_COL
    // =============================================================
    genvar c;
    generate
        for (c = 0; c < PE_COL_NUM; c++) begin : gen_y_out
            assign y_out[c] = reg_max_final;
        end
    endgenerate

endmodule