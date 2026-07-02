//=============================================================
// 输出层模块 (Output Layer)
// 功能: 对来自 PE Page 的部分和进行累加，添加 Bias，经过 ReLU 激活函数
// 再把第r列延迟PE_COL_NUM-r个周期，输出最终结果
// 流水线延迟：5 + （CYCLE_PERIOD_IN-1）*CYCLE_PERIOD_OUT + PE_COL_NUM - 2。
// 从new_line_in到第一个pe分页输出，延迟为PE_ROW_NUM+3
// 从new_line_in到final_out输出，总延迟为流水线延迟与分页输出延迟之和
// 即PE_ROW_NUM+(CYCLE_PERIOD_IN-1)*CYCLE_PERIOD_OUT + 8 + PE_COL_NUM - 2
// new_line_out_1 相对每行第一个 final_out 提前1个周期
// new_line信号到达第一个pe分页输出时，Bias地址复位，bias地址与stage1结果对齐，读出的bias与stage2结果对齐
// index_in，index_out同样在此后1个周期复位。index_out计数满后，index_in加一。
// 用一个长度为CYCLE_PERIOD_OUT-1的移位寄存器寄存，stage3加法器（输入为移位寄存器的输出与stage2相加）的结果,由此构成一个累加器。
// 当index_in为0时，stage3中加法器的一个输入由移位寄存器的输出改为0，由此实现了累加器的清零且不打断流水线。
//=============================================================
module output_layer #(
    parameter PE_PAGE_NUM      = 3,
    parameter PE_COL_NUM       = 4,
    parameter PE_ROW_NUM       = 9,
    parameter PE_OUT_WIDTH     = 20, // PE 输出位宽
    parameter BIAS_WIDTH       = 32, // Bias 位宽
    parameter ACC_WIDTH        = 32, // 累加器位宽
    parameter SHIFT_KEY        = 0,  // 右移位数
    parameter OUT_WIDTH        = 8,  // 最终输出位宽
    parameter CYCLE_PERIOD_OUT = 4,
    parameter CYCLE_PERIOD_IN  = 3,
    parameter IMG_COL          = 128,
    parameter WITH_RELU        = 1,
    parameter CYCLE_PERIOD     = CYCLE_PERIOD_OUT * CYCLE_PERIOD_IN,
    parameter BIAS_FILE        = "biases_layer1.mem"
)(
    input  logic clk,
    input  logic clk_en,
    input  logic rst_n,
    
    // 来自 input_layer 的输入同步信号 (用于复位 Bias 地址)
    input  logic new_line_in,
    
    // 来自 PE Page 的部分和输入 (已修改为压缩数组)
    input  logic signed [PE_PAGE_NUM-1:0][PE_COL_NUM-1:0][PE_OUT_WIDTH-1:0] page_y_out,
    
    // 最终输出 (已修改为压缩数组)
    output logic [PE_COL_NUM-1:0][OUT_WIDTH-1:0] final_out,
    output logic output_valid                                    /* synthesis syn_preserve=1 */,
    output logic new_line_out_1                                  /* synthesis syn_preserve=1 */
);

    // =============================================================
    // 1. Bias Memory & Address Logic & New Line Pipeline
    // =============================================================
    localparam BIAS_DEPTH = CYCLE_PERIOD_OUT * PE_COL_NUM;
    localparam PE_OUT_DELAY = PE_ROW_NUM + 4; // PE 分页输出延迟（new_line信号到达第一个pe分页输出的延迟）
    localparam BIAS_ADDR_DELAY = PE_OUT_DELAY + 1; // Bias 地址复位延迟（new_line信号到达Bias地址的延迟）
    
    // 延迟计算: Stage1(1) + Stage2(1) + Stage3(1) + Stage4(1) + Stage5(1) + Accumulation wait
    localparam CAL_PIPE_DELAY = 5 + (CYCLE_PERIOD_IN-1) * CYCLE_PERIOD_OUT + PE_COL_NUM - 2; 
    localparam TOTAL_DELAY = PE_OUT_DELAY + CAL_PIPE_DELAY; // 总延迟

    localparam int unsigned CYCLE_PERIOD_IN_WIDTH  = (CYCLE_PERIOD_IN > 1)  ? $clog2(CYCLE_PERIOD_IN)  : 1;
    localparam int unsigned CYCLE_PERIOD_OUT_WIDTH = (CYCLE_PERIOD_OUT > 1) ? $clog2(CYCLE_PERIOD_OUT) : 1;

    logic signed [BIAS_WIDTH-1:0] bias_mem [0:BIAS_DEPTH-1];
    logic [CYCLE_PERIOD_OUT_WIDTH-1:0] bias_time_cnt;
    logic [CYCLE_PERIOD_IN_WIDTH-1:0]  index_in;
    logic [CYCLE_PERIOD_OUT_WIDTH-1:0] index_out;
    logic [TOTAL_DELAY-1:0] new_line_pipe                        /* synthesis syn_preserve=1 */;

    initial begin
        $readmemb(BIAS_FILE, bias_mem);
    end

    // 新行延迟流水线
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            new_line_pipe <= '0;
        end else if (clk_en) begin
            new_line_pipe <= {new_line_pipe[TOTAL_DELAY-2:0], new_line_in};
        end
    end

    assign new_line_out_1 = new_line_pipe[TOTAL_DELAY-1];


    // Bias 地址计数器
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bias_time_cnt <= 0;
        end else if (clk_en) begin
            if (new_line_pipe[BIAS_ADDR_DELAY - 1]) begin
                bias_time_cnt <= 0;
            end else begin
                if (bias_time_cnt == CYCLE_PERIOD_OUT - 1)
                    bias_time_cnt <= 0;
                else
                    bias_time_cnt <= bias_time_cnt + 1;
            end
        end
    end

    // Index 计数器逻辑 (Index In / Index Out)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            index_out <= 0;
            index_in <= 0;
        end else if (clk_en) begin
            if (new_line_pipe[BIAS_ADDR_DELAY - 2]) begin // 在 Bias 复位点的后一拍复位
                index_out <= 0;
                index_in <= 0;
            end else begin
                if (index_out == CYCLE_PERIOD_OUT - 1) begin
                    index_out <= 0;
                    if (index_in == CYCLE_PERIOD_IN - 1)
                        index_in <= 0;
                    else
                        index_in <= index_in + 1;
                end else begin
                    index_out <= index_out + 1;
                end
            end
        end
    end

    // =============================================================
    // 2. 累加 & Bias & 激活流水线信号定义 (移出 generate)
    // =============================================================
    logic signed [ACC_WIDTH-1:0]  sum_stage1_1[PE_COL_NUM-1:0];
    logic signed [ACC_WIDTH-1:0]  sum_stage1_2[PE_COL_NUM-1:0];
    logic signed [ACC_WIDTH-1:0]  sum_stage1_3[PE_COL_NUM-1:0];
    logic signed [ACC_WIDTH-1:0]  sum_stage2  [PE_COL_NUM-1:0];
    logic signed [BIAS_WIDTH-1:0] bias_val    [PE_COL_NUM-1:0];

    // Stage 3 累加器相关信号       
    logic signed [ACC_WIDTH-1:0]  sum_stage3  [PE_COL_NUM-1:0]; 
    logic signed [ACC_WIDTH-1:0]  acc_feedback[PE_COL_NUM-1:0]; 
    localparam int unsigned ACC_SHIFT_DEPTH = (CYCLE_PERIOD_OUT > 1) ? (CYCLE_PERIOD_OUT - 1) : 1;
    logic signed [ACC_WIDTH-1:0]  acc_shift_reg[PE_COL_NUM-1:0][ACC_SHIFT_DEPTH-1:0]; 

    logic signed [ACC_WIDTH-1:0]  sum_with_bias[PE_COL_NUM-1:0];
    
    // 移位后位宽为 ACC_WIDTH - SHIFT_KEY 位；边界参数也保持合法位宽/位移。
    localparam int unsigned SHIFT_OUT_WIDTH = (ACC_WIDTH > SHIFT_KEY) ? (ACC_WIDTH - SHIFT_KEY) : 1;
    localparam int unsigned SHIFT_ROUND_BIT = (SHIFT_KEY > 0) ? (SHIFT_KEY - 1) : 0;
    logic signed [SHIFT_OUT_WIDTH-1:0]  shifted_val[PE_COL_NUM-1:0]; 
    logic signed [SHIFT_OUT_WIDTH-1:0]  shifted_val_round[PE_COL_NUM-1:0]; 
    logic [OUT_WIDTH-1:0] stage5_result[PE_COL_NUM-1:0];
    
    // [新增] 累加器清零信号的延迟链
    // 第 c 列的清零信号需要延迟 c 个周期
    logic [PE_COL_NUM-1:0] acc_clear_pipe; 

    // [新增] Valid 门控信号，用于屏蔽首行到来前的无效输出
    logic valid_enable                                           /* synthesis syn_preserve=1 */; 
    // [新增] Valid 门控逻辑：当第一个新行到达计算核心时置 1
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) valid_enable <= 1'b0;
        else if (clk_en && new_line_pipe[BIAS_ADDR_DELAY]) valid_enable <= 1'b1;
    end

    // out_valid 通过循环来产生，并用new_line_out_1复位
    logic start_out                                              /* synthesis syn_preserve=1 */;
    logic [CYCLE_PERIOD_IN_WIDTH-1:0]  index_in_valid            /* synthesis syn_preserve=1 */;
    logic [CYCLE_PERIOD_OUT_WIDTH-1:0] index_out_valid           /* synthesis syn_preserve=1 */;
    logic [$clog2(IMG_COL)-1:0] index_col_valid                  /* synthesis syn_preserve=1 */;
    
    // Index 计数器逻辑 (Index In / Index Out)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            index_out_valid <= 0;
            index_in_valid  <= 0;
            index_col_valid <= 0;
            start_out <= 0;
        end else if (clk_en) begin
            if (new_line_out_1) begin // 输出new_line_1信号后，开始输出有效
                index_out_valid <= 0;
                index_in_valid <= 0;
                index_col_valid <= 0;
                start_out <= 1;
            end else begin
                if (index_out_valid == CYCLE_PERIOD_OUT - 1) begin
                    index_out_valid <= 0;
                    if (index_in_valid == CYCLE_PERIOD_IN - 1)begin
                        index_in_valid <= 0;
                        if (index_col_valid == IMG_COL - 1)begin
                            index_col_valid <= 0;
                            // 输出完一整行，停止输出
                            start_out <= 0;
                        end else begin
                            index_col_valid <= index_col_valid + 1;
                        end
                    end
                    else begin
                        index_in_valid <= index_in_valid + 1;
                    end
                end else begin
                    index_out_valid <= index_out_valid + 1;
                end
            end
        end
    end
    assign output_valid = (index_in_valid == 0) && start_out;

    integer k_pipe;
    // [新增] 累加器清零信号流水线 (Base: index_in == 0)
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) acc_clear_pipe <= '0;
        else if(clk_en) begin
            acc_clear_pipe[0] <= (index_in == 0); // 第0列无额外延迟 (Base)
            for(k_pipe = 1; k_pipe < PE_COL_NUM; k_pipe = k_pipe + 1) begin
                acc_clear_pipe[k_pipe] <= acc_clear_pipe[k_pipe-1]; // 后续列依次延迟
            end
        end
    end

    // =============================================================
    // 3. 流水线处理逻辑
    // =============================================================
    genvar c;
    generate
        for (c = 0; c < PE_COL_NUM; c = c + 1) begin : col_proc
            
            // --- Stage 1 & Stage 2 (保持不变) ---
            always_ff @(posedge clk) begin
                if (clk_en) begin
                    if(PE_PAGE_NUM == 0)
                        sum_stage1_1[c] <= '0;
                    else if(PE_PAGE_NUM == 1)
                        sum_stage1_1[c] <= $signed(page_y_out[0][c]);
                    else if(PE_PAGE_NUM == 2)
                        sum_stage1_1[c] <= $signed(page_y_out[0][c]) + $signed(page_y_out[1][c]);
                    else if(PE_PAGE_NUM >= 3)
                        sum_stage1_1[c] <= $signed(page_y_out[0][c]) + $signed(page_y_out[1][c]) + $signed(page_y_out[2][c]);
                    
                    if(PE_PAGE_NUM <= 3)
                        sum_stage1_2[c] <= '0;
                    else if(PE_PAGE_NUM == 4)
                        sum_stage1_2[c] <= $signed(page_y_out[3][c]);
                    else if(PE_PAGE_NUM == 5)
                        sum_stage1_2[c] <= $signed(page_y_out[3][c]) + $signed(page_y_out[4][c]);
                    else if(PE_PAGE_NUM >= 6)
                        sum_stage1_2[c] <= $signed(page_y_out[3][c]) + $signed(page_y_out[4][c]) + $signed(page_y_out[5][c]);

                    if(PE_PAGE_NUM <= 6)
                        sum_stage1_3[c] <= '0;
                    else if(PE_PAGE_NUM == 7)
                        sum_stage1_3[c] <= $signed(page_y_out[6][c]);
                    else if(PE_PAGE_NUM == 8)
                        sum_stage1_3[c] <= $signed(page_y_out[6][c]) + $signed(page_y_out[7][c]);
                    else if(PE_PAGE_NUM >= 9)
                        sum_stage1_3[c] <= $signed(page_y_out[6][c]) + $signed(page_y_out[7][c]) + $signed(page_y_out[8][c]);
                end
            end

            always_ff @(posedge clk) begin
                if (clk_en) begin
                    sum_stage2[c] <= sum_stage1_1[c] + sum_stage1_2[c] + sum_stage1_3[c];
                    bias_val[c] <= bias_mem[bias_time_cnt * PE_COL_NUM + c];
                end
            end

            // --- Stage 3: 累加器 (Accumulator) ---
            // [修改] 清零逻辑使用延迟后的 acc_clear_pipe[c]
            always_comb begin
                if (acc_clear_pipe[c] || (CYCLE_PERIOD_OUT <= 1)) // 使用对应列的延迟清零信号
                    acc_feedback[c] = '0; 
                else 
                    acc_feedback[c] = acc_shift_reg[c][ACC_SHIFT_DEPTH-1];
            end

            integer k_acc;
            always_ff @(posedge clk) begin
                if (clk_en) begin
                    sum_stage3[c] <= sum_stage2[c] + acc_feedback[c];
                    
                    if (CYCLE_PERIOD_OUT > 1) begin
                        acc_shift_reg[c][0] <= sum_stage3[c];
                        for (k_acc = 1; k_acc < ACC_SHIFT_DEPTH; k_acc = k_acc + 1) begin
                            acc_shift_reg[c][k_acc] <= acc_shift_reg[c][k_acc-1];
                        end
                    end else begin
                        acc_shift_reg[c][0] <= '0;
                    end
                end
            end

            // --- Stage 4 & Stage 5 (加偏置、激活) ---
            always_ff @(posedge clk) begin
                if (clk_en) begin
                    sum_with_bias[c] <= sum_stage3[c] + $signed(bias_val[c]);
                end
            end
            
            // stage5 移位结果计算（包含四舍五入）
            // 算数右移并四舍五入
            assign shifted_val[c] = (sum_with_bias[c] >>> SHIFT_KEY);
            if (SHIFT_KEY > 0) begin : gen_shift_round
                assign shifted_val_round[c] = shifted_val[c] + ((sum_with_bias[c] >>> SHIFT_ROUND_BIT) & 1); // 四舍五入
            end else begin : gen_no_shift_round
                assign shifted_val_round[c] = shifted_val[c];
            end
            
            // [新增] 最终输出对齐延迟链
            // 延迟量 = CYCLE_PERIOD_OUT - c - 1
            localparam DESKEW_DELAY = PE_COL_NUM - c - 1;
            
            always_ff @(posedge clk) begin
                if (clk_en) begin
                    if(WITH_RELU == 1) begin
                        if ($signed(shifted_val_round[c]) < 0) begin
                            stage5_result[c] <= 0;
                        end else begin
                            if ($signed(shifted_val_round[c]) >= (1<<OUT_WIDTH)-1) 
                                stage5_result[c] <= {(OUT_WIDTH){1'b1}};
                            else    
                                stage5_result[c] <= shifted_val_round[c][OUT_WIDTH-1:0];
                        end
                    end else begin
                        // 正向极值
                        if ($signed(shifted_val_round[c]) >= (1<<(OUT_WIDTH-1))-1) 
                            stage5_result[c] <= {1'b0, {(OUT_WIDTH-1){1'b1}}};
                        // 负向极值
                        else if ($signed(shifted_val_round[c]) <= -(1<<(OUT_WIDTH-1)))
                            stage5_result[c] <= {1'b1, {(OUT_WIDTH-1){1'b0}}};
                        // 中间值
                        else    
                            stage5_result[c] <= shifted_val_round[c][OUT_WIDTH-1:0];
                    end
                end 
            end
            
            // 输出对齐延迟逻辑
            if (DESKEW_DELAY == 0) begin
                assign final_out[c] = stage5_result[c];
            end else begin
                logic [DESKEW_DELAY-1:0][OUT_WIDTH-1:0] out_delay_pipe;
                integer k_delay;
                always_ff @(posedge clk) begin
                    if (clk_en) begin
                        out_delay_pipe[0] <= stage5_result[c];
                        for (k_delay = 1; k_delay < DESKEW_DELAY; k_delay = k_delay + 1) begin
                            out_delay_pipe[k_delay] <= out_delay_pipe[k_delay-1];
                        end
                    end
                end
                assign final_out[c] = out_delay_pipe[DESKEW_DELAY-1];
            end
        end
    endgenerate

endmodule
