module extrema_finder #(
    parameter int unsigned DATA_WIDTH       = 16,
    parameter int unsigned PE_COL_NUM       = 4,
    parameter int unsigned CYCLE_PERIOD_OUT = 4,
    parameter int unsigned CHANNEL_OUT_NUM  = CYCLE_PERIOD_OUT * PE_COL_NUM,
    parameter bit unsigned CONV_POSITIVE    = 1 // 1: 找最大值 (正相关), 0: 找最小值 (负相关)
)(
    input  logic                            clk,
    input  logic                            rst_n,
    input  logic                            clk_en,
    input  logic                            data_input_valid,
    input  logic                            new_line_1, // 用于重置周期计数器
    input  logic signed    [PE_COL_NUM-1:0] [DATA_WIDTH-1:0] data_in,
    
    output logic signed    [DATA_WIDTH-1:0] val_out,            
    output logic [$clog2(CHANNEL_OUT_NUM)-1:0] val_out_channel, // 最优通道索引
    output logic                            val_valid
);

    logic [$clog2(CYCLE_PERIOD_OUT)-1:0] cycle_cnt;
    
    // 值缓存
    logic signed [DATA_WIDTH-1:0]        current_best;
    logic signed [DATA_WIDTH-1:0]        cycle_best; 
    
    // 索引缓存
    // Total Channels = PE_COL_NUM * CYCLE_PERIOD_OUT
    localparam int CHANNEL_IDX_WIDTH = $clog2(CHANNEL_OUT_NUM);
    
    logic [CHANNEL_IDX_WIDTH-1:0]        current_best_channel;
    logic [$clog2(PE_COL_NUM)-1:0]       cycle_best_pe_idx; // 当前周期内哪个PE最优

    // 初始极值定义
    localparam signed [DATA_WIDTH-1:0] temp_min = {1'b1, {(DATA_WIDTH-1){1'b0}}}; // Min Signed Int
    localparam signed [DATA_WIDTH-1:0] temp_max = {1'b0, {(DATA_WIDTH-1){1'b1}}};  // Max Signed Int
    localparam signed [DATA_WIDTH-1:0] INIT_VAL = CONV_POSITIVE ? 
                                                  temp_min :
                                                  temp_max;

    // =========================================================
    // 1. 组合逻辑：找出当前周期并行输入中的极值及其 PE 索引
    // =========================================================

    int i;
    always_comb begin
        cycle_best = $signed(data_in[0]);
        cycle_best_pe_idx = 0;
        
        for (i = 1; i < PE_COL_NUM; i++) begin
            if (CONV_POSITIVE) begin
                if ($signed(data_in[i]) > cycle_best) begin
                    cycle_best = data_in[i];
                    cycle_best_pe_idx = i;
                end
            end else begin
                if ($signed(data_in[i]) < cycle_best) begin
                    cycle_best = $signed(data_in[i]);
                    cycle_best_pe_idx = i;
                end
            end
        end
    end

    // =========================================================
    // 2. 时序逻辑：跨周期累积极值
    // =========================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_cnt            <= 0;
            current_best         <= INIT_VAL;
            current_best_channel <= 0;
            val_valid            <= 0;
            val_out              <= 0;
            val_out_channel      <= 0;
        end else begin
            if(clk_en) begin
                val_valid <= 0; // 默认拉低
                if (new_line_1) begin
                    cycle_cnt            <= 0;
                    current_best         <= INIT_VAL;
                    current_best_channel <= 0;
                end else if (data_input_valid) begin : if_compare
                    
                    // 计算当前周期的全局通道索引 : cycle_cnt + cycle_best_pe_idx * CYCLE_PERIOD_OUT
                    logic [CHANNEL_IDX_WIDTH-1:0] current_cycle_global_idx;
                    current_cycle_global_idx = cycle_cnt + cycle_best_pe_idx * CYCLE_PERIOD_OUT;
    
                    // --- 更新当前最佳值与索引 ---
                    if (cycle_cnt == 0) begin
                        // 第一个周期，直接取当前周期的最佳值
                        current_best         <= cycle_best;
                        current_best_channel <= current_cycle_global_idx;
                    end else begin
                        // 后续周期，与累积值比较
                        if (CONV_POSITIVE) begin
                            if (cycle_best > current_best) begin
                                current_best         <= cycle_best;
                                current_best_channel <= current_cycle_global_idx;
                            end
                        end else begin
                            if (cycle_best < current_best) begin
                                current_best         <= cycle_best;
                                current_best_channel <= current_cycle_global_idx;
                            end
                        end
                    end
    
                    // --- 计数器与最终输出逻辑 ---
                    if (cycle_cnt == CYCLE_PERIOD_OUT - 1) begin
                        cycle_cnt <= 0;
                        val_valid <= 1;
                        
                        // 最后一拍需要比较 "历史累积值" vs "当前周期值"
                        if (CONV_POSITIVE) begin
                            if (cycle_best > current_best) begin
                                val_out         <= cycle_best;
                                val_out_channel <= current_cycle_global_idx;
                            end else begin
                                val_out         <= current_best;
                                val_out_channel <= current_best_channel;
                            end
                        end else begin
                            if (cycle_best < current_best) begin
                                val_out         <= cycle_best;
                                val_out_channel <= current_cycle_global_idx;
                            end else begin
                                val_out         <= current_best;
                                val_out_channel <= current_best_channel;
                            end
                        end
                        
                    end else begin
                        cycle_cnt <= cycle_cnt + 1;
                    end
                end
            end
        end
    end

endmodule