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
    // 2. Iprnet 子图相关数据 (同步于 clk_video)
    // ===================================
    output logic               start_crop_wr [0:MAX_BOX_NUM-1],
    output logic               end_crop_wr   [0:MAX_BOX_NUM-1],
    output logic [15:0]        crop_x_min   [0:MAX_BOX_NUM-1],
    output logic [15:0]        crop_y_min   [0:MAX_BOX_NUM-1],
    output logic               crop_wr_en   [0:MAX_BOX_NUM-1],
    output logic [23:0]        crop_rgb_out
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
    logic [15:0] x_acc       [0:MAX_BOX_NUM-1];
    logic [15:0] y_acc       [0:MAX_BOX_NUM-1];
    logic        y_valid_row [0:MAX_BOX_NUM-1];
    
    // 【新增标志位】：用于解决残缺框和半途crop的问题
    logic        crop_active [0:MAX_BOX_NUM-1]; // 标记当前正在进行一次从头开始的合法crop过程
    logic        crop_done   [0:MAX_BOX_NUM-1]; // 标记当前框已经完成了一次完整的crop
    
    // 数据打拍，用于对齐 crop_wr_en 的一级时序延迟
    logic [23:0] video_rgb_in_d1;
    assign crop_rgb_out = video_rgb_in_d1;
    // 碰撞检测流水线中间变量数组
    localparam PIPELINE_STAGES = (MAX_BOX_NUM + 1) / 2;
    logic       cur_hit ;
    logic [7:0] cur_conf;
    logic [7:0] cur_cls ;
    logic signed [15:0] pixel_x, pixel_y; // pixel_y实际上是当前行坐标+1，调用时需要注意
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
    assign fifo_rd_en = ~fifo_empty && (word_cnt < 4) && (&box_valid != 1);
    
    logic fifo_valid;
    always_ff @(posedge clk_video or negedge rst_n) begin
        if (!rst_n) fifo_valid <= 1'b0;
        else        fifo_valid <= fifo_rd_en;
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
            box_cnt  <= 0;
            vs_in_d  <= 0;
            for (idx = 0; idx < MAX_BOX_NUM; idx++) begin
                box_valid[idx] <= 1'b0;
            end
        end else begin
            vs_in_d <= video_vs_in;
            
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
                    if (box_cnt < MAX_BOX_NUM) begin
                        word_cnt <= 6;
                        // 寄存器锁存已算好的组合逻辑结果，并进行外扩
                        box_xmin[box_cnt] <= ((xmin_val - 10) > 1) ? (xmin_val - 10) : 1;
                        box_ymin[box_cnt] <= ((ymin_val -  5) > 1) ? (ymin_val -  5) : 1;
                        box_xmax[box_cnt] <= ((xmax_val + 10) <  IMG_WIDTH - 2) ? (xmax_val + 10) :  IMG_WIDTH - 2;
                        box_ymax[box_cnt] <= ((ymax_val +  5) < IMG_HEIGHT - 2) ? (ymax_val +  5) : IMG_HEIGHT - 2;

                        box_conf [box_cnt]  <= tmp_conf;
                        box_cls  [box_cnt]  <= tmp_cls;
                    end
                end
                // 剩余子图相关参数
                else if(word_cnt == 6) begin
                    word_cnt <= 0;
                    
                    box_w0[box_cnt]   <= box_xmax[box_cnt] - box_xmin[box_cnt];
                    box_h0[box_cnt]   <= box_ymax[box_cnt] - box_ymin[box_cnt];
                    // 如果原图过小（小于框大小，将原图扩展至与框一样大）
                    if(box_ymax[box_cnt] - box_ymin[box_cnt] < CROP_HEIGHT) begin
                        box_ymax[box_cnt] <= box_ymin[box_cnt] + CROP_HEIGHT;
                        box_h0[box_cnt] <= CROP_HEIGHT;
                    end
                    if(box_xmax[box_cnt] - box_xmin[box_cnt] < CROP_WIDTH) begin
                        box_xmax[box_cnt] <= box_xmin[box_cnt] + CROP_WIDTH;
                        box_w0[box_cnt] <= CROP_WIDTH;
                    end
                    box_valid[box_cnt] <= 1'b1;

                    if(box_cnt < MAX_BOX_NUM - 1) box_cnt <= box_cnt + 1;
                    else box_cnt <= 0;
                end
                else begin
                    for (idx = 0; idx < MAX_BOX_NUM; idx++) begin
                        // 【修改逻辑】只有当不仅超出边界，且已经成功经历过完整的crop，才释放框。避免半路生成的框被抛弃。
                        if(hs_falling && (pixel_y >= box_ymax[idx] + 1) && crop_done[idx]) begin
                            box_valid[idx] <= 1'b0;
                        end
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

    // =========================================================
    // F. DDA 映射与子图 FIFO 生成逻辑 
    // =========================================================
    generate
        for (i_gen = 0; i_gen < MAX_BOX_NUM; i_gen++) begin : gen_crop_fifo
            
            always_ff @(posedge clk_video or negedge rst_n) begin
                if (!rst_n) begin
                    y_acc[i_gen] <= 0;
                    y_valid_row[i_gen] <= 0;
                    start_crop_wr[i_gen] <= 1'b0;
                    end_crop_wr[i_gen] <= 1'b0;
                    crop_x_min[i_gen] <= 0;
                    crop_y_min[i_gen] <= 0;
                    crop_active[i_gen] <= 1'b0;
                    crop_done[i_gen]   <= 1'b0;
                end else begin 
                    start_crop_wr[i_gen] <= 1'b0;
                    end_crop_wr[i_gen] <= 1'b0;
                    if (box_valid[i_gen]) begin
                        if (hs_falling) begin
                            // 框外行
                            y_valid_row[i_gen] <= 1'b0;
                            
                            // 1. 只有碰到了真正的顶部，才触发开始写并激活 crop_active
                            if ((pixel_y) == box_ymin[i_gen]) begin
                                start_crop_wr[i_gen] <= 1'b1;
                                crop_active[i_gen]   <= 1'b1; // 激活：这是一次完整的crop开始
                                crop_x_min[i_gen] <= box_xmin[i_gen];
                                crop_y_min[i_gen] <= box_ymin[i_gen];
                                if (((box_h0[i_gen] >> 1) + CROP_HEIGHT) >= box_h0[i_gen]) begin
                                    y_valid_row[i_gen] <= 1'b1;
                                    y_acc[i_gen]       <= (box_h0[i_gen] >> 1) + CROP_HEIGHT - box_h0[i_gen];
                                end else begin
                                    y_valid_row[i_gen] <= 1'b0;
                                    y_acc[i_gen]       <= (box_h0[i_gen] >> 1) + CROP_HEIGHT;
                                end
                            end
                            // 2. 框内部的后续行：仅当当前处于 active 状态（代表开头被抓到了）才继续 crop 逻辑
                            else if ((pixel_y) > box_ymin[i_gen] && (pixel_y) < box_ymax[i_gen]) begin
                                if (crop_active[i_gen]) begin 
                                    if ((y_acc[i_gen] + CROP_HEIGHT) >= box_h0[i_gen]) begin
                                        y_valid_row[i_gen] <= 1'b1;           
                                        y_acc[i_gen]       <= y_acc[i_gen] + CROP_HEIGHT - box_h0[i_gen];
                                    end else begin 
                                        y_valid_row[i_gen] <= 1'b0;          
                                        y_acc[i_gen]       <= y_acc[i_gen] + CROP_HEIGHT;
                                    end
                                end
                            end 
                            // 3. 框结束行：仅当处在 active 状态时，才视为完成一次完整crop
                            else if(pixel_y == box_ymax[i_gen])begin
                                if (crop_active[i_gen]) begin
                                    end_crop_wr[i_gen] <= 1'b1;
                                    crop_active[i_gen] <= 1'b0; // 结束crop状态
                                    crop_done[i_gen]   <= 1'b1; // 标记一次完整crop已经完成
                                end
                            end
                        end
                    end else begin
                        y_valid_row[i_gen] <= 1'b0;  
                        crop_active[i_gen] <= 1'b0;   // 无效框时重置相关状态
                        crop_done[i_gen]   <= 1'b0;
                    end
                end
            end
            
            always_ff @(posedge clk_video or negedge rst_n) begin
                if (!rst_n) begin
                    x_acc[i_gen] <= 0;
                    crop_wr_en[i_gen] <= 0;
                end else if (box_valid[i_gen]) begin
                    if (hs_falling || vs_rising) begin
                        x_acc[i_gen] <= 0;
                        crop_wr_en[i_gen] <= 0;
                    end
                    else if (y_valid_row[i_gen] && video_de_in && pixel_x >= box_xmin[i_gen] && pixel_x < box_xmax[i_gen]) begin
                        
                        if (pixel_x == box_xmin[i_gen]) begin
                            if (((box_w0[i_gen] >> 1) + CROP_WIDTH) >= box_w0[i_gen]) begin
                                crop_wr_en[i_gen] <= 1'b1;
                                x_acc[i_gen]      <= (box_w0[i_gen] >> 1) + CROP_WIDTH - box_w0[i_gen];
                            end else begin
                                crop_wr_en[i_gen] <= 1'b0;
                                x_acc[i_gen]      <= (box_w0[i_gen] >> 1) + CROP_WIDTH;
                            end
                        end 
                        else begin
                            if ((x_acc[i_gen] + CROP_WIDTH) >= box_w0[i_gen]) begin
                                crop_wr_en[i_gen] <= 1'b1;
                                x_acc[i_gen]      <= x_acc[i_gen] + CROP_WIDTH - box_w0[i_gen];
                            end else begin
                                crop_wr_en[i_gen] <= 1'b0;
                                x_acc[i_gen]      <= x_acc[i_gen] + CROP_WIDTH;
                            end
                        end
                    end 
                    else begin
                        crop_wr_en[i_gen] <= 1'b0;
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