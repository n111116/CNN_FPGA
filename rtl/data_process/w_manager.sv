/*
 * 模块名称: w_manager
 * 功能: 支持参数化资源推断的权重管理
 */
module w_manager #(
    parameter int unsigned PE_ROW_NUM   = 9,
    parameter int unsigned PE_COL_NUM   = 2, 
    parameter int unsigned WEIGHT_WIDTH = 8,
    parameter int unsigned CYCLE_PERIOD = 2,
    parameter string WEIGHT_FILE = "weights_layer1_page0.mem"
)(
    input  logic clk,
    input  logic clk_en,
    input  logic new_line_1,
    // 输出: [列][行]
    output logic signed [WEIGHT_WIDTH-1:0] W_out [PE_COL_NUM-1:0][PE_ROW_NUM-1:0]
);



    // 1. 资源类型自动判定逻辑
    // 根据要求：CYCLE_PERIOD <= 2 使用 distributed，否则使用 block
    // localparam SELECTED_RAM_STYLE = (CYCLE_PERIOD <= 2) ? "distributed" : "block";
    //  (* ram_style = SELECTED_RAM_STYLE *) 
    localparam COL_WEIGHT_WIDTH = PE_ROW_NUM * WEIGHT_WIDTH;
    localparam MEM_DEPTH = CYCLE_PERIOD * PE_COL_NUM;
    localparam ADDR_WIDTH = $clog2(MEM_DEPTH);
    logic [COL_WEIGHT_WIDTH-1:0] mem [0:MEM_DEPTH-1];
    

    initial begin
        $readmemb(WEIGHT_FILE, mem);
    end

    // 2. 时间步计数器
    logic [$clog2(CYCLE_PERIOD)-1:0] time_idx; 

    always_ff @(posedge clk) begin
        if (clk_en) begin
            if(new_line_1) begin
                time_idx <= '0;
            end
            else if(time_idx == CYCLE_PERIOD - 1) begin
                time_idx <= '0;
            end
            else begin
                time_idx <= time_idx + 1'b1;
            end
        end
    end

    // 3. 并行读取逻辑
    logic [COL_WEIGHT_WIDTH-1:0] raw_data_per_col_reg [PE_COL_NUM-1:0];
    
    genvar c, r;
    generate
        for (c = 0; c < PE_COL_NUM; c++) begin : gen_mem_read
            logic [ADDR_WIDTH-1:0] rd_addr;
            assign rd_addr = time_idx * PE_COL_NUM + c;

            // 综合建议：
            // 当使用 "distributed" 时，通常为了性能会避免在读取端加多余寄存器，
            // 但为了保持时序一致性（与 BRAM 行为统一），这里保留时钟驱动的读取。
            always_ff @(posedge clk) begin
                if (clk_en) begin
                    raw_data_per_col_reg[c] <= mem[rd_addr];
                end
            end
        end
    endgenerate

    // 4. 数据切分
    generate
        for (c = 0; c < PE_COL_NUM; c++) begin : gen_col_out
            for (r = 0; r < PE_ROW_NUM; r++) begin : gen_row_out
                always_comb begin
                    W_out[c][r] = raw_data_per_col_reg[c][(r * WEIGHT_WIDTH) +: WEIGHT_WIDTH];
                end
            end
        end
    endgenerate

endmodule