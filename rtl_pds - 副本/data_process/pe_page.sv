// 卷积核分页模块，一个模块就是一页的卷积核
// 包含数据管理模块和多个列处理单元
// PE_ROW_NUM: 每个pe_col内部的PE数量（行数）
// PE_COL_NUM: 列处理单元数量（默认2，表示列数）
module pe_page #(
    // [修改]：去掉了 int unsigned 和 string 等强类型声明
    parameter PE_ROW_NUM   = 9,   // 每个pe_col内部的PE数量（行数）
    parameter PE_COL_NUM   = 2,   // 列处理单元数量（列数）
    parameter DATA_WIDTH   = 7,   // 数据位宽
    parameter WEIGHT_WIDTH = 8,   // 权重位宽
    parameter CYCLE_PERIOD = 2,   // 权重循环周期
    parameter OUTPUT_WIDTH = DATA_WIDTH + WEIGHT_WIDTH + $clog2(PE_ROW_NUM+1),  // 输出位宽
    parameter USE_DSP_PE   = "no",// 是否使用DSP资源进行乘法运算
    parameter WEIGHT_FILE  = "weights_precalc_bin.mem"  // 权重文件路径
) (
    input  logic                     clk,
    input  logic                     clk_en,
    input  logic                     new_line_1,  // 用于重置地址计数器的新行信号，相比每行的第一组data提前1个周期
    // [修改]：改为压缩数组
    input  logic [PE_ROW_NUM-1:0][DATA_WIDTH-1:0]    data,  // 一行输入数据
    // [修改]：改为压缩数组
    output logic signed [PE_COL_NUM-1:0][OUTPUT_WIDTH-1:0] y_out  // 每个pe_col的输出
);

    // 1. 数据管理模块：将输入数据延迟后分发给各列
    // [修改]：改为压缩数组
    logic [PE_ROW_NUM-1:0][DATA_WIDTH-1:0] D0;  // d_manager输出
    d_manager #(
        .PE_ROW_NUM(PE_ROW_NUM),
        .DATA_WIDTH(DATA_WIDTH)
    ) d_man (
        .clk(clk),
        .clk_en(clk_en),
        .data(data),
        .D(D0)
    );

    // 2. 延迟寄存器：将D0延迟n个周期，作为第n个pe_col的输入
    // [修改]：改为压缩数组
    logic [PE_COL_NUM-1:0][PE_ROW_NUM-1:0][DATA_WIDTH-1:0] D_delay;
    
    // 声明genvar
    genvar i; // j 没用到，去掉了
    
    // 使用generate块实现延迟寄存器
    generate
        for (i = 0; i < PE_COL_NUM; i = i + 1) begin : gen_delay
            if (i == 0) begin
                assign D_delay[i] = D0;
            end else begin
                // 延迟i个周期
                always_ff @(posedge clk) begin
                    if (clk_en) begin
                        D_delay[i] <= D_delay[i-1];
                    end
                end
            end
        end
    endgenerate

    // 3. 权重管理模块 (w_manager)
    // 替代了原有的固定权重生成逻辑，从 mem 文件读取预处理后的权重
    // [修改]：改为压缩数组
    logic signed [PE_COL_NUM-1:0][PE_ROW_NUM-1:0][WEIGHT_WIDTH-1:0] W_pe;

    w_manager #(
        .PE_ROW_NUM(PE_ROW_NUM),
        .PE_COL_NUM(PE_COL_NUM),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .WEIGHT_FILE(WEIGHT_FILE),
        .CYCLE_PERIOD(CYCLE_PERIOD)
    ) u_w_manager (
        .clk(clk),
        .clk_en(clk_en),
        .new_line_1(new_line_1),    // 用于重置地址计数器的新行信号, 相比每行的第一组data提前2个周期
        .W_out(W_pe)    // 输出权重连接到 W_pe
    );

    // 4. 实例化pe_col单元
    // [修改]：包在 generate 块内，并修改为 i = i + 1
    generate
        for (i = 0; i < PE_COL_NUM; i = i + 1) begin : pe_col_inst
            pe_col #(
                .PE_ROW_NUM(PE_ROW_NUM),
                .DATA_WIDTH(DATA_WIDTH),
                .WEIGHT_WIDTH(WEIGHT_WIDTH),
                .OUTPUT_WIDTH(OUTPUT_WIDTH),
                .USE_DSP_PE(USE_DSP_PE)
            ) u_pe_col (
                .clk(clk),
                .clk_en(clk_en),
                .D(D_delay[i]),
                .W(W_pe[i]),     // 连接来自 w_manager 的权重
                .y_out(y_out[i])
            );
        end
    endgenerate

endmodule