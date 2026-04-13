module box_overlay_sync #(
    parameter int IMG_WIDTH          = 1280,   // 图像总宽
    parameter int IMG_HEIGHT         = 720,    // 图像总高
    parameter int GRID_STRIDE_CENTER = 16,     // 中心点网格步长 (下采样率)
    parameter int GRID_STRIDE_LTRB   = 1,      // 边框相对偏移步长
    parameter int LINE_WIDTH         = 4,      // 画框的线宽(像素)
    parameter int MAX_BOX_NUM        = 10,     // 屏幕中最多同时展示的框数量。
    
    // 裁剪子图的目标尺寸 W1 x H1
    parameter int CROP_WIDTH         = 128,    // 裁剪出的子图宽度
    parameter int CROP_HEIGHT        = 128     // 裁剪出的子图高度
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
    // 3. Iprnet 子图相关数据 (同步于 clk_video)
    // ===================================
    output logic               start_box_wr [0:MAX_BOX_NUM-1],
    output logic               end_box_wr   [0:MAX_BOX_NUM-1],
    output logic [15:0]        crop_x_min   [0:MAX_BOX_NUM-1],
    output logic [15:0]        crop_y_min   [0:MAX_BOX_NUM-1],
    output logic               crop_wr_en   [0:MAX_BOX_NUM-1],
    
    // 【核心修改】：由于不同框的缓存读出时间可能会重叠，必须改为独立数据总线！
    output logic [23:0]        crop_rgb_out [0:MAX_BOX_NUM-1]
);     

    // =========================================================
    // 变量统一定义区
    // =========================================================
    genvar i_gen;
    int idx;
    
    logic signed [15:0] cx, cy;
    logic signed [15:0] xmin_val, ymin_val, xmax_val, ymax_val;

    logic       cur_hit ;
    logic [7:0] cur_conf;
    logic [7:0] cur_cls ;
    logic signed [15:0] pixel_x, pixel_y; 
    logic video_de_in_d;
    wire  hs_falling = !video_de_in && video_de_in_d;

    // =========================================================
    // A. 例化异步 FIFO (PE Domain -> Video Domain)
    // =========================================================
    logic        fifo_rd_en;
    logic [31:0] fifo_dout;
    logic        fifo_empty;
    logic        fifo_full;

    my_fifo  #(
        .DATA_WIDTH(32),
        .FIFO_DEPTH(64)
    ) u_box_fifo (
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
    // B. Video 域：读取 FIFO 与解析
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
    
    assign fifo_rd_en = ~fifo_empty && (word_cnt < 4) && (&box_valid != 1);
    
    logic fifo_valid;
    always_ff @(posedge clk_video or negedge rst_n) begin
        if (!rst_n) fifo_valid <= 1'b0;
        else        fifo_valid <= fifo_rd_en;
    end
    
    logic vs_in_d;
    wire  vs_rising = video_vs_in && !vs_in_d;

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
            box_cnt  <= 0;
            vs_in_d  <= 0;
            for (idx = 0; idx < MAX_BOX_NUM; idx++) box_valid[idx] <= 1'b0;
        end else begin
            vs_in_d <= video_vs_in;
            if (fifo_valid) begin
                if (word_cnt == 0) begin
                    tmp_cls   <= fifo_dout[31:24]; tmp_idx_x <= fifo_dout[23:16];
                    tmp_idx_y <= fifo_dout[15:8];  tmp_conf  <= fifo_dout[7:0];
                    word_cnt  <= 1;
                end
                else if (word_cnt == 1) begin tmp_L <= fifo_dout[8:0]; word_cnt <= 2; end
                else if (word_cnt == 2) begin tmp_T <= fifo_dout[8:0]; word_cnt <= 3; end
                else if (word_cnt == 3) begin tmp_R <= fifo_dout[8:0]; word_cnt <= 4; end
                else if (word_cnt == 4) begin tmp_B <= fifo_dout[8:0]; word_cnt <= 5; end
            end 
            else begin
                if (word_cnt == 5) begin
                    if (box_cnt < MAX_BOX_NUM) begin
                        word_cnt <= 6;
                        box_xmin[box_cnt] <= ((xmin_val - 10) > 0) ? (xmin_val - 10) : 0;
                        box_ymin[box_cnt] <= ((ymin_val -  5) > 0) ? (ymin_val -  5) : 0;
                        box_xmax[box_cnt] <= ((xmax_val + 10) <  IMG_WIDTH - 1) ? (xmax_val + 10) :  IMG_WIDTH - 1;
                        box_ymax[box_cnt] <= ((ymax_val +  5) < IMG_HEIGHT - 1) ? (ymax_val +  5) : IMG_HEIGHT - 1;
                        box_conf [box_cnt]<= tmp_conf;
                        box_cls  [box_cnt]<= tmp_cls;
                    end
                end
                else if(word_cnt == 6) begin
                    word_cnt <= 0;
                    box_w0[box_cnt]   <= box_xmax[box_cnt] - box_xmin[box_cnt];
                    box_h0[box_cnt]   <= box_ymax[box_cnt] - box_ymin[box_cnt];
                    box_valid[box_cnt] <= 1'b1;

                    if(box_cnt < MAX_BOX_NUM - 1) box_cnt <= box_cnt + 1;
                    else box_cnt <= 0;
                end
                for (idx = 0; idx < MAX_BOX_NUM; idx++) begin
                    if(hs_falling && (pixel_y - 1 == box_ymax[idx])) begin
                        box_valid[idx] <= 1'b0;
                    end else if(vs_rising && (box_ymax[idx] == IMG_HEIGHT - 1))begin
                        box_valid[idx] <= 1'b0;
                    end
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
        end else begin
            video_de_in_d <= video_de_in;
            if (vs_rising) begin
                pixel_x <= 0;
                pixel_y <= 0;
            end 
            else if (video_de_in) begin
                pixel_x <= pixel_x + 1;
            end 
            else if (hs_falling) begin
                pixel_x <= 0;
                pixel_y <= pixel_y + 1;
            end
        end
    end

    // =========================================================
    // F. DDA 行缓存与解耦输出状态机 (核心重构)
    // =========================================================
    // 状态机定义
    localparam S_IDLE = 2'd0;
    localparam S_BUF  = 2'd1;
    localparam S_READ = 2'd2;

    generate
        for (i_gen = 0; i_gen < MAX_BOX_NUM; i_gen++) begin : gen_crop_fifo
            
            // 物理行缓存 RAM 及指针
            logic [2:0]  ram_rep_x [0:255]; 
            logic [23:0] ram_rgb   [0:255];
            logic [7:0]  ram_wr_ptr;
            logic [7:0]  ram_rd_ptr;
            logic [7:0]  ram_max_ptr;

            logic [1:0]  state;
            logic [2:0]  cur_rep_y;
            logic [2:0]  rep_y_reg;
            logic [2:0]  cur_rep_x;
            logic        load_first;

            // 独立的 DDA 累加器
            logic [15:0] x_acc;
            logic [15:0] y_acc;
            
            // DDA 组合逻辑预测下一个状态的重复次数
            logic [2:0]  rep_y, rep_x;
            logic [15:0] nxt_y, nxt_x;
            logic [15:0] temp_y, temp_x;

            always_comb begin
                temp_y = y_acc + CROP_HEIGHT;
                if      (temp_y >= 4 * box_h0[i_gen]) begin rep_y = 4; nxt_y = temp_y - 4*box_h0[i_gen]; end
                else if (temp_y >= 3 * box_h0[i_gen]) begin rep_y = 3; nxt_y = temp_y - 3*box_h0[i_gen]; end
                else if (temp_y >= 2 * box_h0[i_gen]) begin rep_y = 2; nxt_y = temp_y - 2*box_h0[i_gen]; end
                else if (temp_y >=     box_h0[i_gen]) begin rep_y = 1; nxt_y = temp_y -   box_h0[i_gen]; end
                else                                  begin rep_y = 0; nxt_y = temp_y; end
                
                temp_x = x_acc + CROP_WIDTH;
                if      (temp_x >= 4 * box_w0[i_gen]) begin rep_x = 4; nxt_x = temp_x - 4*box_w0[i_gen]; end
                else if (temp_x >= 3 * box_w0[i_gen]) begin rep_x = 3; nxt_x = temp_x - 3*box_w0[i_gen]; end
                else if (temp_x >= 2 * box_w0[i_gen]) begin rep_x = 2; nxt_x = temp_x - 2*box_w0[i_gen]; end
                else if (temp_x >=     box_w0[i_gen]) begin rep_x = 1; nxt_x = temp_x -   box_w0[i_gen]; end
                else                                  begin rep_x = 0; nxt_x = temp_x; end
            end

            always_ff @(posedge clk_video or negedge rst_n) begin
                if (!rst_n) begin
                    state <= S_IDLE;
                    y_acc <= 0; x_acc <= 0;
                    ram_wr_ptr <= 0; ram_rd_ptr <= 0; ram_max_ptr <= 0;
                    crop_wr_en[i_gen] <= 0; crop_rgb_out[i_gen] <= 0;
                    start_box_wr[i_gen] <= 0; end_box_wr[i_gen] <= 0;
                    cur_rep_y <= 0; cur_rep_x <= 0; load_first <= 0; rep_y_reg <= 0;
                end else begin 
                    start_box_wr[i_gen] <= 1'b0;
                    end_box_wr[i_gen]   <= 1'b0;
                    crop_wr_en[i_gen]   <= 1'b0;

                    if (box_valid[i_gen]) begin
                        // ----------------------------------------------------
                        // 1. 行级 (Row Level) 同步与 Y 轴 DDA
                        // ----------------------------------------------------
                        if (hs_falling) begin
                            x_acc <= 0; // 每行开始前重置 X 累加器
                            if (pixel_y == box_ymin[i_gen]) begin
                                start_box_wr[i_gen] <= 1'b1;
                                crop_x_min[i_gen]   <= box_xmin[i_gen];
                                crop_y_min[i_gen]   <= box_ymin[i_gen];
                                y_acc               <= nxt_y;
                                cur_rep_y           <= rep_y;
                            end 
                            else if (pixel_y > box_ymin[i_gen] && pixel_y < box_ymax[i_gen]) begin
                                y_acc     <= nxt_y;
                                cur_rep_y <= rep_y;
                            end 
                            else if (pixel_y == box_ymax[i_gen]) begin
                                end_box_wr[i_gen] <= 1'b1;
                                cur_rep_y         <= 0;
                            end 
                            else begin
                                cur_rep_y <= 0;
                            end
                        end

                        // ----------------------------------------------------
                        // 2. 状态机：缓存 (Buffer) 与 异步解耦输出 (Readout)
                        // ----------------------------------------------------
                        case (state)
                            S_IDLE: begin
                                // 遇到框的左边界，且该行需要被读出时，启动缓存
                                if (video_de_in && (pixel_x == box_xmin[i_gen]) && (cur_rep_y > 0)) begin
                                    state <= S_BUF;
                                    ram_wr_ptr <= 0;
                                    ram_rep_x[0] <= rep_x;
                                    ram_rgb[0]   <= video_rgb_in;
                                    x_acc <= nxt_x;
                                    ram_wr_ptr <= 1;
                                    rep_y_reg <= cur_rep_y;
                                end
                            end
                            
                            S_BUF: begin
                                if (video_de_in) begin
                                    if (pixel_x < box_xmax[i_gen]) begin
                                        ram_rep_x[ram_wr_ptr] <= rep_x;
                                        ram_rgb[ram_wr_ptr]   <= video_rgb_in;
                                        x_acc <= nxt_x;
                                        ram_wr_ptr <= ram_wr_ptr + 1;
                                    end
                                    // 框结束，立即转入异步读取状态，此时无需考虑视频流时序
                                    if (pixel_x == box_xmax[i_gen]) begin
                                        state <= S_READ;
                                        ram_max_ptr <= ram_wr_ptr;
                                        ram_rd_ptr <= 0;
                                        load_first <= 1'b1;
                                    end
                                end
                            end
                            
                            S_READ: begin
                                // 第 1 个时钟周期：装载首个像素的 X 重复次数
                                if (load_first) begin
                                    cur_rep_x <= ram_rep_x[0];
                                    load_first <= 1'b0;
                                end 
                                else if (rep_y_reg > 0) begin
                                    // 如果当前像素还要输出 (rep_x > 0)
                                    if (cur_rep_x > 0) begin
                                        crop_wr_en[i_gen]   <= 1'b1;
                                        crop_rgb_out[i_gen] <= ram_rgb[ram_rd_ptr];
                                        
                                        if (cur_rep_x == 1) begin
                                            // 当前像素发完了，移动指针到下一个像素
                                            if (ram_rd_ptr == ram_max_ptr - 1) begin
                                                // 本行发完了，行重复计数减 1
                                                ram_rd_ptr <= 0;
                                                rep_y_reg <= rep_y_reg - 1;
                                                if (rep_y_reg == 1) begin
                                                    state <= S_IDLE; // 所有行重发完毕
                                                end else begin
                                                    cur_rep_x <= ram_rep_x[0]; // 重开一行
                                                end
                                            end else begin
                                                ram_rd_ptr <= ram_rd_ptr + 1;
                                                cur_rep_x <= ram_rep_x[ram_rd_ptr + 1];
                                            end
                                        end else begin
                                            cur_rep_x <= cur_rep_x - 1;
                                        end
                                    end 
                                    else begin
                                        // 这个像素被 DDA 判为丢弃 (缩小操作)，直接跳过不发
                                        crop_wr_en[i_gen] <= 1'b0;
                                        if (ram_rd_ptr == ram_max_ptr - 1) begin
                                            ram_rd_ptr <= 0;
                                            rep_y_reg <= rep_y_reg - 1;
                                            if (rep_y_reg == 1) begin
                                                state <= S_IDLE;
                                            end else begin
                                                cur_rep_x <= ram_rep_x[0];
                                            end
                                        end else begin
                                            ram_rd_ptr <= ram_rd_ptr + 1;
                                            cur_rep_x <= ram_rep_x[ram_rd_ptr + 1];
                                        end
                                    end
                                end else begin
                                    state <= S_IDLE;
                                end
                            end
                        endcase
                    end
                end
            end
        end
    endgenerate

    // =========================================================
    // D. 碰撞检测（并行架构） & E. 最终混叠输出 
    // =========================================================
    always_ff @(posedge clk_video) begin
        cur_hit  <= 1'b0; cur_conf <= 8'd0; cur_cls  <= 8'd0;
        for (idx = 0; idx < MAX_BOX_NUM; idx = idx + 1) begin
            if (box_valid[idx] && 
                pixel_x         >= box_xmin[idx] && pixel_x         <= box_xmax[idx] &&
                (pixel_y - 1)   >= box_ymin[idx] && (pixel_y - 1)   <= box_ymax[idx]) begin
                
                if (pixel_x         < box_xmin[idx] + LINE_WIDTH || pixel_x             > box_xmax[idx] - LINE_WIDTH ||
                    (pixel_y - 1)   < box_ymin[idx] + LINE_WIDTH || (pixel_y - 1)       > box_ymax[idx] - LINE_WIDTH) begin
                    cur_hit  <= 1'b1; cur_conf <= box_conf[idx] ; cur_cls  <= box_cls[idx] ;
                end
            end
        end
    end

    always_ff @(posedge clk_video or negedge rst_n) begin
        if (!rst_n) begin
            video_vs_out <= 0; video_hs_out <= 0; video_de_out <= 0; video_rgb_out <= 0;
        end else begin
            video_vs_out <= video_vs_in; video_hs_out <= video_hs_in; video_de_out <= video_de_in;
            if (cur_hit) begin
                if      (cur_cls == 0) video_rgb_out <= 24'h00_00_FF; 
                else if (cur_cls == 1) video_rgb_out <= 24'h00_FF_00; 
                else if (cur_cls == 2) video_rgb_out <= 24'hFF_FF_00; 
                else if (cur_cls == 3) video_rgb_out <= 24'h00_00_00; 
                else if (cur_cls == 4) video_rgb_out <= 24'hFF_FF_FF; 
                else                   video_rgb_out <= 24'hFF_00_FF; 
            end else begin
                video_rgb_out <= video_rgb_in; 
            end
        end
    end

endmodule