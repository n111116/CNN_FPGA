module post_cv3_conv2d #(
    // 数据流参数
    parameter int unsigned DATA_WIDTH       = 13, // Layer33 输出位宽
    parameter int unsigned OUT_WIDTH        = 32, // 打包输出位宽
    parameter int unsigned SHIFT_KEY        = 7,
    parameter int unsigned PE_COL_NUM       = 4,
    parameter int unsigned CYCLE_PERIOD_OUT = 4,
    parameter int unsigned CHANNEL_OUT_NUM  = CYCLE_PERIOD_OUT * PE_COL_NUM,
    parameter string LUT_FILE   = "sigmoid_lut_9bit_to_8bit_h.mem",
    
    // 图像参数
    parameter int unsigned IMG_COL          = 32, // Layer33 的输出分辨率宽
    parameter int unsigned IMG_ROW          = 32, // Layer33 的输出分辨率高
    
    // 后处理参数
    parameter bit unsigned CONV_POSITIVE    = 1,  // 1=Max, 0=Min
    parameter int unsigned CONF_WIDTH       = 8,  // 置信度位宽
    parameter int unsigned CONF_THRESH      = 128 // 阈值 (0-255)
)(
    input  logic                    clk,
    input  logic                    rst_n,
    
    // 来自 Layer33 的输入
    input  logic                    new_line_in_1,
    input  logic                    data_input_valid,
    input  logic [DATA_WIDTH-1:0]   data_in [PE_COL_NUM-1:0],
    
    // 打包后的输出
    // 格式: {padding(若需), index_y, index_x, confidence}
    output logic [OUT_WIDTH-1:0]    packet_data, 
    output logic                    packet_valid,
    output logic                    frame_done    // 一帧处理完成标志
);

    // =============================================================
    // 1. 极值查找
    // =============================================================
    (* mark_debug = "true"*) logic signed [DATA_WIDTH-1:0] raw_extrema;
    logic [DATA_WIDTH-1:0] raw_extrema_unsigned;
    assign raw_extrema_unsigned = raw_extrema;
    logic [$clog2(CHANNEL_OUT_NUM)-1:0] val_out_channel;
    logic [$clog2(CHANNEL_OUT_NUM)-1:0] val_out_channel_d1;
    (* mark_debug = "true"*) logic                  extrema_valid;
    logic signed [DATA_WIDTH-1:0]   data_in_signed [PE_COL_NUM-1:0];
    int idc;
    always_comb begin
        for(idc = 0; idc < PE_COL_NUM; idc = idc + 1) begin
            data_in_signed[idc] = $signed(data_in[idc]);
        end
    end

    extrema_finder #(
        .DATA_WIDTH(DATA_WIDTH),
        .PE_COL_NUM(PE_COL_NUM),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT),
        .CHANNEL_OUT_NUM(CHANNEL_OUT_NUM),
        .CONV_POSITIVE(CONV_POSITIVE)
    ) u_finder (
        .clk(clk),
        .rst_n(rst_n),
        .clk_en(1'b1),
        .data_input_valid(data_input_valid),
        .new_line_1(new_line_in_1),
        .data_in(data_in_signed),
        .val_out(raw_extrema),
        .val_out_channel(val_out_channel),
        .val_valid(extrema_valid)
    );

    // =============================================================
    // 2. 坐标计数 (跟随 extrema_valid)
    // =============================================================
    // 坐标计数器需要在 extrema_valid 有效时才递增，代表处理完一个像素
    // 注意：extrema_valid 出来的时刻，当前像素刚刚处理完
    
    logic [$clog2(IMG_COL)-1:0] idx_x;
    logic [$clog2(IMG_ROW)-1:0] idx_y;
    
    // 延迟一拍的坐标，用于和 Activation 输出对齐 (因为 LUT 有 1 拍延迟)
    logic [$clog2(IMG_COL)-1:0] idx_x_d1;
    logic [$clog2(IMG_ROW)-1:0] idx_y_d1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            idx_x <= 0;
            idx_y <= 0;
            frame_done <= 0;
        end else begin
            frame_done <= 0; // Pulse
            if (new_line_in_1) begin
                idx_x <= 0;
            end else if (extrema_valid) begin
                if (idx_x == IMG_COL - 1) begin
                    idx_x <= 0;
                    if (idx_y == IMG_ROW - 1) begin
                        idx_y <= 0;
                        frame_done <= 1; // 整个 Feature Map 扫描结束
                    end else begin
                        idx_y <= idx_y + 1;
                    end
                end else begin
                    idx_x <= idx_x + 1;
                end
            end
        end
    end

    // 坐标打拍 (对齐 LUT 延迟)
    always_ff @(posedge clk) begin
        if (extrema_valid) begin
            idx_x_d1 <= idx_x;
            idx_y_d1 <= idx_y;
            val_out_channel_d1 <= val_out_channel;
        end
    end

    // =============================================================
    // 3. 置信度转换 (LUT)
    // =============================================================
    (* mark_debug = "true"*)logic [CONF_WIDTH-1:0] confidence;
    logic                  conf_valid;

    activation_lut #(
        .INPUT_WIDTH(DATA_WIDTH),
        .OUTPUT_WIDTH(CONF_WIDTH),
        .LUT_FILE(LUT_FILE),
        .CONV_POSITIVE(CONV_POSITIVE)
    ) u_lut (
        .clk(clk),
        .in_valid(extrema_valid),
        .val_in(raw_extrema_unsigned),
        .out_valid(conf_valid),
        .confidence_out(confidence)
    );

    // =============================================================
    // 4. 阈值过滤与打包输出
    // =============================================================
    // 输出格式定义: [31:24] Reserved/0, [23:16] Y, [15:8] X, [7:0] Confidence
    // 假设坐标和置信度都在 8-bit 范围内，如果坐标超过255，需要调整位宽分配
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            packet_valid <= 0;
            packet_data  <= 0;
        end else begin
            packet_valid <= 0; // Default
            
            if (conf_valid) begin
                if (confidence >= CONF_THRESH) begin
                    packet_valid <= 1;
                    packet_data[31:24]  <= val_out_channel_d1;   // c_out
                    packet_data[23:16]  <= idx_x_d1;             // Index X
                    packet_data[15: 8]  <= idx_y_d1;             // Index Y
                    packet_data[ 7: 0]  <= confidence;           // Confidence
                end
            end
        end
    end

endmodule