module box_overlay_sync #(
    parameter int IMG_WIDTH          = 1280,   // 图像总宽
    parameter int IMG_HEIGHT         = 720,    // 图像总高
    parameter int GRID_STRIDE_CENTER = 16,     // 中心点网格步长 (下采样率)
    parameter int GRID_STRIDE_LTRB   = 1,      // 边框相对偏移步长
    parameter int LINE_WIDTH         = 4,      // 画框的线宽(像素)
    parameter int MAX_BOX_NUM        = 10,     // 屏幕中最多同时展示的框数量。
    
    // 裁剪子图的目标尺寸 W1 x H1
    parameter int CROP_WIDTH         = 40,     // 裁剪出的子图宽度
    parameter int CROP_HEIGHT        = 10      // 裁剪出的子图高度
)(
    input  logic               clk_video,
    input  logic               clk_pe,
    input  logic               rst_n,
    
    // ===================================
    // 1. 视频流输入输出 (同步于 clk_video)
    // ===================================
    input  logic               video_vs_in,
    input  logic               video_hs_in,
    input  logic               video_de_in,
    input  logic [23:0]        video_rgb_in,
    
    output logic               video_vs_out,
    output logic               video_hs_out,
    output logic               video_de_out,
    output logic [23:0]        video_rgb_out,
    
    // ===================================
    // 2. YOLO 检测数据 (同步于 clk_pe)
    // ===================================
    input  logic               box_wr_en,
    input  logic [31:0]        box_wr_data,
    
    // ===================================
    // 2. Iprnet 子图相关数据 (同步于 clk_video)
    // ===================================
    output logic [MAX_BOX_NUM-1:0]        start_crop_wr,
    output logic [MAX_BOX_NUM-1:0]        end_crop_wr,
    output logic [MAX_BOX_NUM-1:0][15:0]  crop_x_min,
    output logic [MAX_BOX_NUM-1:0][15:0]  crop_y_min,
    output logic [MAX_BOX_NUM-1:0]        crop_wr_en,
    output logic [MAX_BOX_NUM-1:0][23:0]  crop_rgb_out
);     

    // =========================================================
    // 变量统一定义区
    // =========================================================
    genvar i_gen;
    genvar s_gen;
    int idx;
    
    // 坐标计算中间变量 (改为供 always_comb 使用的纯组合逻辑)
    logic signed [15:0] cx, cy;
    logic signed [15:0] xmin_val, ymin_val, xmax_val, ymax_val;

    // DDA 累加器与写使能数组
    localparam int FRAC_BITS = 8;
    localparam int FRAC_ONE  = (1 << FRAC_BITS);
    localparam int FP_WIDTH  = 32;
    localparam int RECIP_BITS = 32;
    localparam longint unsigned CROP_WIDTH_RECIP  = ((64'd1 << RECIP_BITS) + CROP_WIDTH - 1) / CROP_WIDTH;
    localparam longint unsigned CROP_HEIGHT_RECIP = ((64'd1 << RECIP_BITS) + CROP_HEIGHT - 1) / CROP_HEIGHT;

    logic [FP_WIDTH-1:0] x_step       [0:MAX_BOX_NUM-1];
    logic [FP_WIDTH-1:0] y_step       [0:MAX_BOX_NUM-1];
    logic [FP_WIDTH-1:0] x_fp         [0:MAX_BOX_NUM-1];
    logic [FP_WIDTH-1:0] y_fp         [0:MAX_BOX_NUM-1];
    logic [15:0]         x_sample     [0:MAX_BOX_NUM-1];
    logic [15:0]         y_sample     [0:MAX_BOX_NUM-1];
    logic [FRAC_BITS-1:0] x_frac      [0:MAX_BOX_NUM-1];
    logic [FRAC_BITS-1:0] y_frac      [0:MAX_BOX_NUM-1];
    logic [15:0]         crop_col_idx [0:MAX_BOX_NUM-1];
    logic [15:0]         crop_row_idx [0:MAX_BOX_NUM-1];
    logic                y_valid_row  [0:MAX_BOX_NUM-1];
    
    // 【新增标志位】：用于解决残缺框和半途crop的问题
    logic        crop_active [0:MAX_BOX_NUM-1]; // 标记当前正在进行一次从头开始的合法crop过程
    logic        crop_done   [0:MAX_BOX_NUM-1]; // 标记当前框已经完成了一次完整的crop
    logic        crop_emit_done [0:MAX_BOX_NUM-1];
    
    // 数据打拍，用于对齐 crop_wr_en 的一级时序延迟
    logic [23:0] video_rgb_in_d1;
    logic [23:0] line_buf [0:IMG_WIDTH-1];
    logic [23:0] curr_rgb_left;
    logic [23:0] prev_row_left;

    function automatic [FP_WIDTH-1:0] calc_step(
        input logic [15:0]          src_size,
        input longint unsigned      dst_recip
    );
        logic [63:0] scaled;
        begin
            scaled    = ({48'd0, src_size} << FRAC_BITS) * dst_recip;
            calc_step = scaled >> RECIP_BITS;
        end
    endfunction

    function automatic [FP_WIDTH-1:0] calc_start_fp(input logic [FP_WIDTH-1:0] step);
        if (step > FRAC_ONE) calc_start_fp = (step >> 1) - (FRAC_ONE >> 1);
        else                 calc_start_fp = 0;
    endfunction

    function automatic [15:0] calc_sample(
        input logic [FP_WIDTH-1:0] fp,
        input logic [15:0]         src_size
    );
        logic [15:0] base;
        logic        has_frac;
        begin
            base        = fp[FP_WIDTH-1:FRAC_BITS];
            has_frac    = |fp[FRAC_BITS-1:0];
            calc_sample = base + has_frac;
            if (src_size != 0 && calc_sample >= src_size) calc_sample = src_size - 1;
        end
    endfunction

    function automatic [FRAC_BITS-1:0] calc_frac(input logic [FP_WIDTH-1:0] fp);
        calc_frac = fp[FRAC_BITS-1:0];
    endfunction

    function automatic [16:0] interp_horizontal(
        input logic [7:0]           c0,
        input logic [7:0]           c1,
        input logic [FRAC_BITS-1:0] frac
    );
        logic signed [9:0]  delta;
        logic signed [17:0] acc;
        begin
            delta = $signed({1'b0, c1}) - $signed({1'b0, c0});
            acc   = $signed({1'b0, c0, {FRAC_BITS{1'b0}}}) +
                    delta * $signed({1'b0, frac});
            interp_horizontal = acc[16:0];
        end
    endfunction

    function automatic [7:0] interp_vertical(
        input logic [16:0]          top,
        input logic [16:0]          bottom,
        input logic [FRAC_BITS-1:0] frac
    );
        logic signed [17:0] delta;
        logic signed [26:0] acc;
        begin
            delta = $signed({1'b0, bottom}) - $signed({1'b0, top});
            acc   = $signed({1'b0, top, {FRAC_BITS{1'b0}}}) +
                    delta * $signed({1'b0, frac}) +
                    (1 << (2 * FRAC_BITS - 1));
            interp_vertical = acc >> (2 * FRAC_BITS);
        end
    endfunction
    // 碰撞检测流水线中间变量数组
    localparam PIPELINE_STAGES = (MAX_BOX_NUM + 1) / 2;
    logic       cur_hit ;
    logic [7:0] cur_conf;
    logic [7:0] cur_cls ;
    logic signed [15:0] pixel_x, pixel_y; // pixel_y实际上是当前行坐标+1，调用时需要注意
    logic signed [15:0] pixel_y_curr;
    logic video_de_in_d;
    wire  hs_falling = !video_de_in && video_de_in_d;
    assign pixel_y_curr = pixel_y - 16'sd1;

    // =========================================================
    // A. 例化异步 FIFO (PE Domain -> Video Domain)
    // =========================================================
    logic        fifo_rd_en;
    logic [31:0] fifo_dout;
    logic        fifo_empty;
    logic        fifo_full;

    my_fifo  #(
        .DATA_WIDTH(32),
        .FIFO_DEPTH(128)
    ) 
    // ip_fifo 
    u_box_fifo (
        .rd_clk         (clk_video),
        .wr_clk         (clk_pe),
        .rst            (~rst_n),
        .wr_en          (box_wr_en),
        .din            (box_wr_data),
        .rd_en          (fifo_rd_en),
        .dout           (fifo_dout),
        .full           (fifo_full),
        .empty          (fifo_empty)
    );

    // =========================================================
    // B. Video 域：读取 FIFO 与 33 拍长包解析
    // =========================================================
    logic [5:0]  word_cnt; 

    logic [7:0]  tmp_idx_x, tmp_idx_y, tmp_conf, tmp_cls;
    logic signed [8:0] tmp_L, tmp_T, tmp_B, tmp_R;

    logic signed [15:0] box_xmin   [0:MAX_BOX_NUM-1];
    logic signed [15:0] box_xmax   [0:MAX_BOX_NUM-1];
    logic signed [15:0] box_ymin   [0:MAX_BOX_NUM-1];
    logic signed [15:0] box_ymax   [0:MAX_BOX_NUM-1];
    
    logic [15:0]        box_w0   [0:MAX_BOX_NUM-1];
    logic [15:0]        box_h0   [0:MAX_BOX_NUM-1];
    logic [7:0]         box_conf [0:MAX_BOX_NUM-1];
    logic [7:0]         box_cls  [0:MAX_BOX_NUM-1];
    logic [MAX_BOX_NUM-1 : 0] box_valid;
    logic [7:0]         box_cnt; 
    
    // word_cnt从0增长到4，总共读5次
    // box_valid不全为1，才可以读取缓存
    assign fifo_rd_en = ~fifo_empty && (word_cnt < 5) && (box_valid[box_cnt] != 1);
    
    logic fifo_valid;
    always_ff @(posedge clk_video or negedge rst_n) begin
        if (!rst_n) begin
            box_cnt <= 1'b0;
            fifo_valid <= 1'b0;
        end else begin
            fifo_valid <= fifo_rd_en;
            // if(word_cnt == 0) begin
            //     // 没在读并且rd_en为0时自增1（轮询），开始读后不再自增，在读取过程中保持稳定。
            //     if(~fifo_rd_en) begin
            //         if(box_cnt < MAX_BOX_NUM - 1)begin
            //             box_cnt <= box_cnt + 1;
            //         end else begin
            //             box_cnt <= 0;
            //         end
            //     end
            // end
            if(word_cnt == 6) begin
                if(box_cnt < MAX_BOX_NUM - 1)begin
                    box_cnt <= box_cnt + 1;
                end else begin
                    box_cnt <= 0;
                end
            end
        end
    end
    logic vs_in_d;
    wire  vs_rising = video_vs_in && !vs_in_d;

    // [修复1] 把坐标计算提取为纯组合逻辑
    always_comb begin
        cx = {1'b0, tmp_idx_x} * GRID_STRIDE_CENTER + GRID_STRIDE_CENTER/2;
        cy = {1'b0, tmp_idx_y} * GRID_STRIDE_CENTER + GRID_STRIDE_CENTER/2;
        xmin_val = cx - tmp_L * GRID_STRIDE_LTRB;
        ymin_val = cy - tmp_T * GRID_STRIDE_LTRB;
        xmax_val = cx + tmp_R * GRID_STRIDE_LTRB;
        ymax_val = cy + tmp_B * GRID_STRIDE_LTRB;
    end

    always_ff @(posedge clk_video or negedge rst_n) begin
        if (!rst_n) begin
            word_cnt <= 0;
            vs_in_d  <= 0;
            for (idx = 0; idx < MAX_BOX_NUM; idx++) begin
                box_valid[idx] <= 1'b0;
            end
        end else begin
            vs_in_d <= video_vs_in;
            
            for (idx = 0; idx < MAX_BOX_NUM; idx++) begin
                // 【修改逻辑】只有当不仅超出边界，且已经成功经历过完整的crop，才释放框。避免半路生成的框被抛弃。
                if((pixel_y > box_ymax[idx] + 1) && crop_done[idx]) begin
                    box_valid[idx] <= 1'b0;
                end
            end
            if (fifo_valid) begin
                if (word_cnt == 0) begin
                    tmp_cls   <= fifo_dout[31:24];
                    tmp_idx_x <= fifo_dout[23:16];
                    tmp_idx_y <= fifo_dout[15:8];
                    tmp_conf  <= fifo_dout[7:0];
                    word_cnt  <= 1;
                end
                else if (word_cnt == 1) begin
                    tmp_L <= fifo_dout[8:0];
                    word_cnt <= 2;
                end
                else if (word_cnt == 2) begin
                    tmp_T <= fifo_dout[8:0];
                    word_cnt <= 3;
                end
                else if (word_cnt == 3) begin
                    tmp_R <= fifo_dout[8:0];
                    word_cnt <= 4;
                end
                else if (word_cnt == 4) begin
                    tmp_B <= fifo_dout[8:0];
                    word_cnt <= 5;
                end
            end 
            // 无fifo_valid时
            else begin
                if (word_cnt == 5) begin
                    word_cnt <= 6;
                    // 寄存器锁存已算好的组合逻辑结果，并进行外扩
                    box_xmin[box_cnt] <= ((xmin_val - 10) > 1) ? (xmin_val - 10) : 1;
                    box_ymin[box_cnt] <= ((ymin_val -  5) > 1) ? (ymin_val -  5) : 1;
                    box_xmax[box_cnt] <= ((xmax_val + 10) <  IMG_WIDTH - 2) ? (xmax_val + 10) :  IMG_WIDTH - 2;
                    box_ymax[box_cnt] <= ((ymax_val +  5) < IMG_HEIGHT - 2) ? (ymax_val +  5) : IMG_HEIGHT - 2;

                    box_conf [box_cnt]  <= tmp_conf;
                    box_cls  [box_cnt]  <= tmp_cls;
                end
                // 剩余子图相关参数
                else if(word_cnt == 6) begin
                    word_cnt <= 0;
                    
                    box_w0[box_cnt]   <= box_xmax[box_cnt] - box_xmin[box_cnt];
                    box_h0[box_cnt]   <= box_ymax[box_cnt] - box_ymin[box_cnt];
                    // 如果原图过小（小于框大小，将原图扩展至与框一样大）
                    // 修复：Y轴子图扩展时防止超出屏幕下边界
                    if(box_ymax[box_cnt] - box_ymin[box_cnt] < CROP_HEIGHT) begin
                        if (box_ymin[box_cnt] + CROP_HEIGHT <= IMG_HEIGHT - 2) begin
                            box_ymax[box_cnt] <= box_ymin[box_cnt] + CROP_HEIGHT;
                        end else begin
                            // 如果往下扩展会越界，则顶住下边界，把 ymin 往上反推
                            box_ymax[box_cnt] <= IMG_HEIGHT - 2;
                            box_ymin[box_cnt] <= (IMG_HEIGHT - 2 >= CROP_HEIGHT) ? (IMG_HEIGHT - 2 - CROP_HEIGHT) : 1;
                        end
                        box_h0[box_cnt] <= CROP_HEIGHT;
                    end

                    // 修复：X轴子图扩展同理
                    if(box_xmax[box_cnt] - box_xmin[box_cnt] < CROP_WIDTH) begin
                        if (box_xmin[box_cnt] + CROP_WIDTH <= IMG_WIDTH - 2) begin
                            box_xmax[box_cnt] <= box_xmin[box_cnt] + CROP_WIDTH;
                        end else begin
                            box_xmax[box_cnt] <= IMG_WIDTH - 2;
                            box_xmin[box_cnt] <= (IMG_WIDTH - 2 >= CROP_WIDTH) ? (IMG_WIDTH - 2 - CROP_WIDTH) : 1;
                        end
                        box_w0[box_cnt] <= CROP_WIDTH;
                    end
                    box_valid[box_cnt] <= 1'b1;

                end
            end
        end
    end

    // =========================================================
    // C. 视频光栅扫描与坐标追踪
    // =========================================================
    
    always_ff @(posedge clk_video or negedge rst_n) begin
        if (!rst_n) begin
            video_de_in_d <= 0;
            pixel_x <= 0;
            pixel_y <= 0;
            video_rgb_in_d1 <= 0;
        end else begin
            video_de_in_d <= video_de_in;
            // [修复3]: 像素数据打一拍，用于对齐 crop_wr_en
            video_rgb_in_d1 <= video_rgb_in; 
            
            if (vs_rising) begin
                pixel_x <= 0;
                pixel_y <= 0;
            end 
            else if (video_de_in) begin
                pixel_x <= pixel_x + 1;
            end 
            // 这样生成的pixel_y实际上是当前行坐标+1，调用时需要注意
            else if (hs_falling) begin
                pixel_x <= 0;
                pixel_y <= pixel_y + 1;
            end
        end
    end

    always_ff @(posedge clk_video or negedge rst_n) begin
        if (!rst_n) begin
            curr_rgb_left <= 0;
            prev_row_left <= 0;
        end else if (video_de_in) begin
            line_buf[pixel_x] <= video_rgb_in;
            curr_rgb_left     <= video_rgb_in;
            prev_row_left     <= line_buf[pixel_x];
        end
    end

    // =========================================================
    // F. Bilinear resize mapping and crop FIFO write generation
    // =========================================================
    generate
        for (i_gen = 0; i_gen < MAX_BOX_NUM; i_gen++) begin : gen_crop_fifo
            logic [23:0] p00, p10, p01, p11;
            logic [FP_WIDTH-1:0] next_x_fp, next_y_fp;
            logic [FP_WIDTH-1:0] init_x_step, init_y_step;
            logic [FP_WIDTH-1:0] init_x_fp, init_y_fp;
            logic [15:0] init_y_sample;
            logic interp_valid_s1, interp_valid_s2;
            logic end_crop_s1, end_crop_s2;
            logic [16:0] top_r_s1, top_g_s1, top_b_s1;
            logic [16:0] bot_r_s1, bot_g_s1, bot_b_s1;
            logic [FRAC_BITS-1:0] y_frac_s1;
            logic [23:0] interp_rgb_s2;

            always_comb begin
                p00 = prev_row_left;
                p10 = (pixel_x >= IMG_WIDTH) ? line_buf[IMG_WIDTH - 1] : line_buf[pixel_x];
                p01 = curr_rgb_left;
                p11 = video_rgb_in;

                if (x_frac[i_gen] == 0) begin
                    p00 = p10;
                    p01 = p11;
                end
                if (y_frac[i_gen] == 0) begin
                    p00 = p01;
                    p10 = p11;
                end

                next_x_fp    = x_fp[i_gen] + x_step[i_gen];
                next_y_fp    = y_fp[i_gen] + y_step[i_gen];
                init_x_step  = calc_step(box_w0[i_gen], CROP_WIDTH_RECIP);
                init_y_step  = calc_step(box_h0[i_gen], CROP_HEIGHT_RECIP);
                init_x_fp    = calc_start_fp(init_x_step);
                init_y_fp    = calc_start_fp(init_y_step);
                init_y_sample = calc_sample(init_y_fp, box_h0[i_gen]);
            end

            always_ff @(posedge clk_video or negedge rst_n) begin
                if (!rst_n) begin
                    x_step[i_gen]        <= 0;
                    y_step[i_gen]        <= 0;
                    x_fp[i_gen]          <= 0;
                    y_fp[i_gen]          <= 0;
                    x_sample[i_gen]      <= 0;
                    y_sample[i_gen]      <= 0;
                    x_frac[i_gen]        <= 0;
                    y_frac[i_gen]        <= 0;
                    crop_col_idx[i_gen]  <= 0;
                    crop_row_idx[i_gen]  <= 0;
                    y_valid_row[i_gen]   <= 1'b0;
                    start_crop_wr[i_gen] <= 1'b0;
                    end_crop_wr[i_gen]   <= 1'b0;
                    crop_x_min[i_gen]    <= 0;
                    crop_y_min[i_gen]    <= 0;
                    crop_active[i_gen]   <= 1'b0;
                    crop_done[i_gen]     <= 1'b0;
                    crop_emit_done[i_gen] <= 1'b0;
                    crop_wr_en[i_gen]    <= 1'b0;
                    crop_rgb_out[i_gen]  <= 24'd0;
                    interp_valid_s1      <= 1'b0;
                    interp_valid_s2      <= 1'b0;
                    end_crop_s1          <= 1'b0;
                    end_crop_s2          <= 1'b0;
                    top_r_s1             <= 0;
                    top_g_s1             <= 0;
                    top_b_s1             <= 0;
                    bot_r_s1             <= 0;
                    bot_g_s1             <= 0;
                    bot_b_s1             <= 0;
                    y_frac_s1            <= 0;
                    interp_rgb_s2        <= 24'd0;
                end else begin
                    start_crop_wr[i_gen] <= 1'b0;
                    end_crop_wr[i_gen]   <= end_crop_s2;
                    crop_wr_en[i_gen]    <= interp_valid_s2;
                    if (interp_valid_s2) begin
                        crop_rgb_out[i_gen] <= interp_rgb_s2;
                    end

                    interp_valid_s2 <= interp_valid_s1;
                    end_crop_s2     <= end_crop_s1;
                    if (interp_valid_s1) begin
                        interp_rgb_s2[23:16] <= interp_vertical(top_r_s1, bot_r_s1, y_frac_s1);
                        interp_rgb_s2[15:8]  <= interp_vertical(top_g_s1, bot_g_s1, y_frac_s1);
                        interp_rgb_s2[7:0]   <= interp_vertical(top_b_s1, bot_b_s1, y_frac_s1);
                    end

                    interp_valid_s1 <= 1'b0;
                    end_crop_s1     <= 1'b0;

                    if (vs_rising) begin
                        y_valid_row[i_gen] <= 1'b0;
                        crop_active[i_gen] <= 1'b0;
                    end else if (box_valid[i_gen]) begin
                        if (hs_falling) begin
                            y_valid_row[i_gen] <= 1'b0;

                            if (pixel_y_curr == box_ymin[i_gen]) begin
                                x_step[i_gen]        <= init_x_step;
                                y_step[i_gen]        <= init_y_step;
                                x_fp[i_gen]          <= init_x_fp;
                                y_fp[i_gen]          <= init_y_fp;
                                x_sample[i_gen]      <= calc_sample(init_x_fp, box_w0[i_gen]);
                                y_sample[i_gen]      <= init_y_sample;
                                x_frac[i_gen]        <= calc_frac(init_x_fp);
                                y_frac[i_gen]        <= calc_frac(init_y_fp);
                                crop_col_idx[i_gen]  <= 0;
                                crop_row_idx[i_gen]  <= 0;
                                y_valid_row[i_gen]   <= (init_y_sample == 0);
                                start_crop_wr[i_gen] <= 1'b1;
                                crop_active[i_gen]   <= 1'b1;
                                crop_emit_done[i_gen] <= 1'b0;
                                crop_x_min[i_gen]    <= box_xmin[i_gen];
                                crop_y_min[i_gen]    <= box_ymin[i_gen];
                            end else if (crop_active[i_gen] &&
                                         !crop_emit_done[i_gen] &&
                                         !y_valid_row[i_gen] &&
                                         (pixel_y_curr >= box_ymin[i_gen] + y_sample[i_gen])) begin
                                y_valid_row[i_gen] <= 1'b1;
                            end

                            if ((pixel_y_curr == box_ymax[i_gen]) && crop_active[i_gen]) begin
                                crop_active[i_gen] <= 1'b0;
                                crop_done[i_gen]   <= 1'b1;
                            end
                        end

                        if (y_valid_row[i_gen] && video_de_in &&
                            (pixel_x >= box_xmin[i_gen] + x_sample[i_gen])) begin
                            interp_valid_s1 <= 1'b1;
                            top_r_s1        <= interp_horizontal(p00[23:16], p10[23:16], x_frac[i_gen]);
                            top_g_s1        <= interp_horizontal(p00[15:8],  p10[15:8],  x_frac[i_gen]);
                            top_b_s1        <= interp_horizontal(p00[7:0],   p10[7:0],   x_frac[i_gen]);
                            bot_r_s1        <= interp_horizontal(p01[23:16], p11[23:16], x_frac[i_gen]);
                            bot_g_s1        <= interp_horizontal(p01[15:8],  p11[15:8],  x_frac[i_gen]);
                            bot_b_s1        <= interp_horizontal(p01[7:0],   p11[7:0],   x_frac[i_gen]);
                            y_frac_s1       <= y_frac[i_gen];

                            if (crop_col_idx[i_gen] < CROP_WIDTH - 1) begin
                                crop_col_idx[i_gen] <= crop_col_idx[i_gen] + 1;
                                x_fp[i_gen]         <= next_x_fp;
                                x_sample[i_gen]     <= calc_sample(next_x_fp, box_w0[i_gen]);
                                x_frac[i_gen]       <= calc_frac(next_x_fp);
                            end else begin
                                y_valid_row[i_gen] <= 1'b0;
                                x_fp[i_gen]         <= calc_start_fp(x_step[i_gen]);
                                x_sample[i_gen]     <= calc_sample(calc_start_fp(x_step[i_gen]), box_w0[i_gen]);
                                x_frac[i_gen]       <= calc_frac(calc_start_fp(x_step[i_gen]));
                                crop_col_idx[i_gen] <= 0;

                                if (crop_row_idx[i_gen] < CROP_HEIGHT - 1) begin
                                    crop_row_idx[i_gen] <= crop_row_idx[i_gen] + 1;
                                    y_fp[i_gen]         <= next_y_fp;
                                    y_sample[i_gen]     <= calc_sample(next_y_fp, box_h0[i_gen]);
                                    y_frac[i_gen]       <= calc_frac(next_y_fp);
                                end else begin
                                    end_crop_s1          <= 1'b1;
                                    crop_emit_done[i_gen] <= 1'b1;
                                end
                            end
                        end
                    end else begin
                        y_valid_row[i_gen] <= 1'b0;
                        crop_active[i_gen] <= 1'b0;
                        crop_done[i_gen]   <= 1'b0;
                        crop_emit_done[i_gen] <= 1'b0;
                    end
                end
            end
        end
    endgenerate

    // =========================================================
    // D. 碰撞检测（并行架构）
    // =========================================================
    
    
    // [修复1] 把判定逻辑放入 always_comb 中
    always_ff @(posedge clk_video) begin
        cur_hit  <= 1'b0;
        cur_conf <= 8'd0;
        cur_cls  <= 8'd0;
        for (idx = 0; idx < MAX_BOX_NUM; idx = idx + 1) begin
            if (box_valid[idx] && 
                pixel_x         >= box_xmin[idx] && pixel_x         <= box_xmax[idx] &&
                (pixel_y - 1)   >= box_ymin[idx] && (pixel_y - 1)   <= box_ymax[idx]) begin
                
                if (pixel_x         < box_xmin[idx] + LINE_WIDTH || pixel_x             > box_xmax[idx] - LINE_WIDTH ||
                    (pixel_y - 1)   < box_ymin[idx] + LINE_WIDTH || (pixel_y - 1)       > box_ymax[idx] - LINE_WIDTH) begin
                    cur_hit  <= 1'b1;
                    cur_conf <= box_conf[idx] ;
                    cur_cls  <= box_cls[idx] ;
                end
            end
        end
    end

    // =========================================================
    // E. 最终混叠输出 
    // =========================================================
    always_ff @(posedge clk_video or negedge rst_n) begin
        if (!rst_n) begin
            video_vs_out <= 0; 
            video_hs_out <= 0; 
            video_de_out <= 0; 
            video_rgb_out <= 0;
        end else begin
            video_vs_out <= video_vs_in;
            video_hs_out <= video_hs_in;
            video_de_out <= video_de_in;
            
            if (cur_hit) begin
                if (cur_cls == 0) 
                    video_rgb_out <= 24'h00_00_FF; 
                else if(cur_cls == 1)
                    video_rgb_out <= 24'h00_FF_00; 
                else if(cur_cls == 2)
                    video_rgb_out <= 24'hFF_FF_00; 
                else if(cur_cls == 3)
                    video_rgb_out <= 24'h00_00_00; 
                else if(cur_cls == 4)
                    video_rgb_out <= 24'hFF_FF_FF; 
                else
                    video_rgb_out <= 24'hFF_00_FF; 
            end else begin
                video_rgb_out <= video_rgb_in; 
            end
        end
    end

endmodule
