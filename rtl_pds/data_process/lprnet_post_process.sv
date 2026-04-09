module lprnet_post_process #(
    // --- LPRNet 整体参数 ---
    parameter int unsigned PE_COL_NUM       = 4,
    parameter int unsigned CYCLE_PERIOD_OUT = 4,
    parameter int unsigned IMG_COL          = 128,
    parameter int unsigned IMG_ROW          = 128,
    parameter int unsigned DATA_WIDTH       = 8,   // 卷积输出位宽
    parameter int unsigned ACC_WIDTH        = 16,  // 累加器位宽
    
    // --- Extrema Finder 参数 ---
    parameter bit unsigned CONV_POSITIVE    = 1,   // 1: 找最大值, 0: 找最小值
    
    // --- CTC 参数 ---
    parameter int unsigned BLANK_CHAR       = 75   // 空白符对应的通道索引
) (
    input  logic                                clk,
    input  logic                                clk_en,
    input  logic                                rst_n,
    
    // 输入接口 (来自最后一层卷积)
    input  logic                                new_line_input_1,
    input  logic                                data_input_valid,
    input  logic signed [PE_COL_NUM-1:0] [DATA_WIDTH-1:0]        data_input ,
    
    // 最终 CTC 解码输出
    output logic [$clog2(CYCLE_PERIOD_OUT * PE_COL_NUM)-1:0] out_char,
    output logic                                out_valid,
    output logic                                frame_start_out // 提前 out_valid 一个周期
);

    localparam int unsigned CHANNEL_OUT_NUM = CYCLE_PERIOD_OUT * PE_COL_NUM;
    localparam int unsigned CH_WIDTH        = $clog2(CHANNEL_OUT_NUM);

    // =============================================================
    // 1. 例化 Spatial Sum (同列通道累加)
    // =============================================================
    logic signed [PE_COL_NUM-1:0] [ACC_WIDTH-1:0] ss_y_out ;
    logic                        ss_new_line_out_1;
    logic                        ss_output_valid;

    lprnet_spatial_sum #(
        .PE_COL_NUM(PE_COL_NUM),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT),
        .IMG_COL(IMG_COL),
        .IMG_ROW(IMG_ROW),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) u_spatial_sum (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(rst_n),
        .new_line_input_1(new_line_input_1),
        .data_input_valid(data_input_valid),
        .data_input(data_input),
        
        .y_out(ss_y_out),
        .new_line_out_1(ss_new_line_out_1),
        .output_valid(ss_output_valid)
    );


    // =============================================================
    // 2. 例化 Extrema Finder (寻找极值通道)
    // =============================================================
    logic [ACC_WIDTH-1:0] ef_val_out;
    logic [CH_WIDTH-1:0]          ef_val_out_channel;
    logic                         ef_val_valid;

    extrema_finder #(
        .DATA_WIDTH(ACC_WIDTH),         // 输入为累加器位宽
        .PE_COL_NUM(PE_COL_NUM),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT),
        .CHANNEL_OUT_NUM(CHANNEL_OUT_NUM),
        .CONV_POSITIVE(CONV_POSITIVE)
    ) u_extrema_finder (
        .clk(clk),
        .rst_n(rst_n),
        .clk_en(clk_en),
        .data_input_valid(ss_output_valid), 
        .new_line_1(ss_new_line_out_1), 
        .data_in(ss_y_out),
        
        .val_out(ef_val_out),
        .val_out_channel(ef_val_out_channel),
        .val_valid(ef_val_valid)
    );


    // =============================================================
    // 3. CTC 前向编码与流水线输出 (Greedy Decoder)
    // =============================================================
    logic                new_frame_flag;
    logic                frame_started_ctc;
    logic [CH_WIDTH-1:0] prefix_char;
    
    // 用于打拍分离 frame_start_out 和 out_valid 的中间寄存器
    logic                ctc_match_reg;
    logic [CH_WIDTH-1:0] ctc_char_reg;

    // 捕获新一帧的起始标志
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            new_frame_flag <= 1'b0;
        end else if (clk_en) begin
            if (ss_new_line_out_1) begin
                new_frame_flag <= 1'b1;
            end else if (ef_val_valid) begin
                // 当收到 Extrema Finder 吐出的第一个结果时，清除挂起的标志
                new_frame_flag <= 1'b0; 
            end
        end
    end

    // CTC 判定组合逻辑
    logic ctc_match;
    assign ctc_match = ef_val_valid && 
                       (ef_val_out_channel != BLANK_CHAR) && 
                       (new_frame_flag || (ef_val_out_channel != prefix_char));

    // CTC 状态更新与流水线延迟
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prefix_char       <= BLANK_CHAR[CH_WIDTH-1:0];
            frame_started_ctc <= 1'b0;
            frame_start_out   <= 1'b0;
            ctc_match_reg     <= 1'b0;
            ctc_char_reg      <= '0;
            out_valid         <= 1'b0;
            out_char          <= '0;
        end else if (clk_en) begin
            
            // --- 默认拉低脉冲 ---
            frame_start_out <= 1'b0;

            if (ef_val_valid) begin
                if (new_frame_flag) begin
                    // ---- 当前帧的第一个通道数据 ----
                    if (ctc_match) begin
                        prefix_char       <= ef_val_out_channel;
                        frame_started_ctc <= 1'b1;
                        frame_start_out   <= 1'b1; // 发出帧起点脉冲
                    end else begin
                        prefix_char       <= BLANK_CHAR[CH_WIDTH-1:0]; // 隐式复位
                        frame_started_ctc <= 1'b0;
                    end
                end else begin
                    // ---- 当前帧的后续数据 ----
                    if(ef_val_valid) begin
                        prefix_char <= ef_val_out_channel;
                    end
                    if (ctc_match) begin
                        // 如果这是该帧中第一次成功匹配，发出脉冲
                        if (!frame_started_ctc) begin
                            frame_start_out   <= 1'b1;
                            frame_started_ctc <= 1'b1;
                        end
                    end
                end
            end
            
            // --- Stage 1: 延迟 CTC 结果 ---
            ctc_match_reg <= ctc_match;
            ctc_char_reg  <= ef_val_out_channel;

            // --- Stage 2: 最终输出 (比 frame_start_out 晚一拍) ---
            out_valid <= ctc_match_reg;
            out_char  <= ctc_char_reg;

        end
    end

endmodule