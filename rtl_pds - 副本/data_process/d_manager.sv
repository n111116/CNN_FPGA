// D管理模块：将输入数据延迟后分配给PE列
// D[n]相对于data[n]延迟n+1个周期
module d_manager #(
    parameter int unsigned PE_ROW_NUM     = 9, // 列数/PE单元数
    parameter int unsigned DATA_WIDTH  = 7  // 数据位宽
) (
    input  logic                     clk,
    input  logic                     clk_en, // 时钟使能
    // 输入数据流
    input  logic [PE_ROW_NUM-1:0] [DATA_WIDTH-1:0]    data ,
    // 输出到PE列的数据
    output logic [PE_ROW_NUM-1:0] [DATA_WIDTH-1:0]    D 
);

    // 生成延迟逻辑
    for (genvar i = 0; i < PE_ROW_NUM; i++) begin : gen_delay
        if (i == 0) begin : gen_no_delay
            // D[0] 无额外延迟，但受clk_en控制
            always_ff @(posedge clk) begin
                if (clk_en) begin
                    D[i] <= data[i];
                end
            end
        end else begin : gen_delayed
            // D[i] 延迟 i+1 个周期
            logic [DATA_WIDTH-1:0] delay_pipe [i:0];
            // 第一级，受clk_en控制
            always_ff @(posedge clk) begin
                if (clk_en) begin
                    delay_pipe[0] <= data[i];
                end
            end
            // 中间级延迟
            for (genvar k = 1; k <= i; k++) begin : gen_pipe
                always_ff @(posedge clk) begin
                    if (clk_en) begin
                        delay_pipe[k] <= delay_pipe[k-1];
                    end
                end
            end
            assign D[i] = delay_pipe[i];
        end
    end

endmodule