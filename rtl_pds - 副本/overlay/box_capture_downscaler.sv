module box_capture_downscaler #(
    parameter int IMG_WIDTH          = 1280,   
    parameter int IMG_HEIGHT         = 720,    
    parameter int GRID_STRIDE_CENTER = 16,     
    parameter int GRID_STRIDE_LTRB   = 1,      
    parameter int LINE_WIDTH         = 4,      
    parameter int MAX_BOX_NUM        = 10,     
    
    parameter int CROP_WIDTH         = 128,    
    parameter int CROP_HEIGHT        = 32      
)(
    input  logic               clk_video,
    input  logic               rst_n,
    
    input  logic               video_vs_in,
    input  logic               video_hs_in,
    input  logic               video_de_in,
    input  logic [23:0]        video_rgb_in,
    
    output logic               video_vs_out,
    output logic               video_hs_out,
    output logic               video_de_out,
    output logic [23:0]        video_rgb_out,
    
    input  logic               clk_pe,
    input  logic               box_wr_en,
    input  logic [31:0]        box_wr_data,
    
    output logic               box_locked [0:MAX_BOX_NUM-1], 
    output logic [15:0]        box_x_min  [0:MAX_BOX_NUM-1], 
    output logic [15:0]        box_y_min  [0:MAX_BOX_NUM-1],
    output logic [15:0]        bram_w     [0:MAX_BOX_NUM-1], 
    output logic [15:0]        bram_h     [0:MAX_BOX_NUM-1], 
    
    input  logic [11:0]        bram_rd_addr [0:MAX_BOX_NUM-1], 
    output logic [23:0]        bram_rd_data [0:MAX_BOX_NUM-1],
    
    input  logic               release_toggle_pe [0:MAX_BOX_NUM-1]
);

    // =========================================================
    // 独立循环变量声明，彻底避免 PDS 报错
    // =========================================================
    integer i_sync, i_parse, i_hit;

    // =========================================================
    // A. 视频射线与全局延迟打拍
    // =========================================================
    logic signed [15:0] pixel_x, pixel_y;
    logic video_de_in_d;
    wire  hs_falling = !video_de_in && video_de_in_d;
    wire  vs_rising  = video_vs_in;
    
    logic [23:0] rgb_delay; 
    always_ff @(posedge clk_video) rgb_delay <= video_rgb_in;
    
    // [时序修复 1] 建立视频同步信号的 1 拍延迟，与 rgb_delay 保持绝对一致
    logic vs_d1, hs_d1, de_d1;
    always_ff @(posedge clk_video) begin
        vs_d1 <= video_vs_in;
        hs_d1 <= video_hs_in;
        de_d1 <= video_de_in;
    end
    
    always_ff @(posedge clk_video or negedge rst_n) begin
        if (!rst_n) begin
            video_de_in_d <= 0;
            pixel_x <= 0; pixel_y <= 0;
        end else begin
            video_de_in_d <= video_de_in;
            if (vs_rising) begin
                pixel_x <= 0;
                pixel_y <= 0;
            end else if (video_de_in) begin
                pixel_x <= pixel_x + 1;
            end else if (hs_falling) begin
                pixel_x <= 0;
                pixel_y <= pixel_y + 1;
            end
        end
    end

    // =========================================================
    // B. YOLO FIFO 与框参数解析
    // =========================================================
    logic        fifo_rd_en, fifo_empty;
    logic [31:0] fifo_dout;
    logic [5:0]  word_cnt; 
    logic [7:0]  tmp_idx_x, tmp_idx_y, tmp_conf, tmp_cls;
    logic signed [8:0] tmp_L, tmp_T, tmp_B, tmp_R;

    my_fifo #(.DATA_WIDTH(32), .FIFO_DEPTH(64)) u_box_fifo (
        .rd_clk(clk_video), .wr_clk(clk_pe), .rst(~rst_n),
        .wr_en(box_wr_en), .din(box_wr_data), .rd_en(fifo_rd_en), .dout(fifo_dout),
        .full(), .empty(fifo_empty)
    );
    
    logic [15:0] box_w0 [0:MAX_BOX_NUM-1], box_h0 [0:MAX_BOX_NUM-1];
    logic [15:0] box_xmin [0:MAX_BOX_NUM-1], box_xmax [0:MAX_BOX_NUM-1];
    logic [15:0] box_ymin [0:MAX_BOX_NUM-1], box_ymax [0:MAX_BOX_NUM-1];
    logic [7:0]  box_cls [0:MAX_BOX_NUM-1];
    logic [MAX_BOX_NUM-1:0] box_valid;
    logic [7:0]  box_cnt;
    
    assign fifo_rd_en = ~fifo_empty && (word_cnt < 4) && (&box_valid != 1);
    logic fifo_valid; always_ff @(posedge clk_video) fifo_valid <= fifo_rd_en;

    // =========================================================
    // C. 视频端写锁与快到慢翻转同步器
    // =========================================================
    logic toggle_sync1 [0:MAX_BOX_NUM-1];
    logic toggle_sync2 [0:MAX_BOX_NUM-1];
    logic toggle_sync3 [0:MAX_BOX_NUM-1];
    logic release_pulse_v [0:MAX_BOX_NUM-1];

    always_ff @(posedge clk_video or negedge rst_n) begin
        if (!rst_n) begin
            for(i_sync=0; i_sync<MAX_BOX_NUM; i_sync=i_sync+1) begin
                toggle_sync1[i_sync] <= 0;
                toggle_sync2[i_sync] <= 0; 
                toggle_sync3[i_sync] <= 0;
                release_pulse_v[i_sync] <= 0;
            end
        end else begin
            for(i_sync=0; i_sync<MAX_BOX_NUM; i_sync=i_sync+1) begin
                toggle_sync1[i_sync] <= release_toggle_pe[i_sync];
                toggle_sync2[i_sync] <= toggle_sync1[i_sync];
                toggle_sync3[i_sync] <= toggle_sync2[i_sync];
                release_pulse_v[i_sync] <= toggle_sync2[i_sync] ^ toggle_sync3[i_sync];
                
                // [核心修复] 彻底移除在这里对 box_locked 的赋值，杜绝多驱动死锁！
            end
        end
    end

    always_ff @(posedge clk_video or negedge rst_n) begin
        if (!rst_n) begin
            word_cnt <= 0;
            box_cnt <= 0;
            for(i_parse=0; i_parse<MAX_BOX_NUM; i_parse=i_parse+1) box_valid[i_parse] <= 0;
        end else begin
            if (fifo_valid) begin
                if (word_cnt == 0) begin
                    tmp_cls <= fifo_dout[31:24];
                    tmp_idx_x <= fifo_dout[23:16]; 
                    tmp_idx_y <= fifo_dout[15:8]; word_cnt <= 1;
                end
                else if (word_cnt == 1) begin tmp_L <= fifo_dout[8:0]; word_cnt <= 2; end
                else if (word_cnt == 2) begin tmp_T <= fifo_dout[8:0]; word_cnt <= 3; end
                else if (word_cnt == 3) begin tmp_R <= fifo_dout[8:0]; word_cnt <= 4; end
                else if (word_cnt == 4) begin tmp_B <= fifo_dout[8:0]; word_cnt <= 5; end
            end else if (word_cnt == 5 && box_cnt < MAX_BOX_NUM) begin : gen_word_cnt5
                logic signed [15:0] cx, cy, x1, y1, x2, y2;
                word_cnt <= 6;
                cx = {1'b0, tmp_idx_x} * GRID_STRIDE_CENTER + GRID_STRIDE_CENTER/2;
                cy = {1'b0, tmp_idx_y} * GRID_STRIDE_CENTER + GRID_STRIDE_CENTER/2;
                x1 = cx - tmp_L * GRID_STRIDE_LTRB;
                y1 = cy - tmp_T * GRID_STRIDE_LTRB;
                x2 = cx + tmp_R * GRID_STRIDE_LTRB;
                y2 = cy + tmp_B * GRID_STRIDE_LTRB;
                
                box_xmin[box_cnt] <= (x1 > 10) ? x1 - 10 : 0;
                box_ymin[box_cnt] <= (y1 > 5)  ? y1 - 5  : 0;
                box_xmax[box_cnt] <= (x2 + 10 < IMG_WIDTH) ? x2 + 10 : IMG_WIDTH - 1;
                box_ymax[box_cnt] <= (y2 + 5  < IMG_HEIGHT) ? y2 + 5 : IMG_HEIGHT - 1;
                box_cls [box_cnt] <= tmp_cls;
            end else if (word_cnt == 6) begin
                word_cnt <= 0;
                box_w0[box_cnt] <= box_xmax[box_cnt] - box_xmin[box_cnt];
                box_h0[box_cnt] <= box_ymax[box_cnt] - box_ymin[box_cnt];
                box_valid[box_cnt] <= 1'b1;
                box_cnt <= (box_cnt < MAX_BOX_NUM - 1) ? box_cnt + 1 : 0;
            end
            
            for(i_parse=0; i_parse<MAX_BOX_NUM; i_parse=i_parse+1) begin
                if (release_pulse_v[i_parse]) box_valid[i_parse] <= 1'b0;
            end
        end
    end

    // =========================================================
    // D. 显存阵列 (BRAM) 实例化与 DDA 缩小写逻辑
    // =========================================================
    genvar i_gen;
    generate
        for (i_gen = 0; i_gen < MAX_BOX_NUM; i_gen = i_gen + 1) begin : gen_bram_capture
            
            (* ram_style = "block" *) logic [23:0] video_ram [0:(CROP_WIDTH*CROP_HEIGHT)-1];
            logic [11:0] wr_addr;
            logic        wr_en;
            
            always_ff @(posedge clk_video) begin
                if (wr_en) video_ram[wr_addr] <= rgb_delay;
            end
            
            always_ff @(posedge clk_pe) begin
                bram_rd_data[i_gen] <= video_ram[bram_rd_addr[i_gen]];
            end
            
            logic is_capturing;
            logic [15:0] x_acc, y_acc;
            logic keep_row;
            
            always_ff @(posedge clk_video or negedge rst_n) begin
                if (!rst_n) begin
                    is_capturing <= 0; wr_addr <= 0; wr_en <= 0;
                    box_locked[i_gen] <= 0;
                end else begin
                    wr_en <= 0;
                    
                    if (wr_en && wr_addr < (CROP_WIDTH * CROP_HEIGHT - 1)) begin
                        wr_addr <= wr_addr + 1;
                    end
                    
                    // [核心修复] 唯一允许修改 box_locked 的地方！保证单驱动合成安全！
                    if (release_pulse_v[i_gen]) begin
                        box_locked[i_gen] <= 1'b0;
                    end
                    else if (box_valid[i_gen] && !box_locked[i_gen]) begin
                        if (hs_falling && (pixel_y + 1 == box_ymin[i_gen])) begin
                            is_capturing <= 1'b1;
                            wr_addr      <= 0;
                            box_x_min[i_gen] <= box_xmin[i_gen];
                            box_y_min[i_gen] <= box_ymin[i_gen];
                            bram_w[i_gen]    <= (box_w0[i_gen] > CROP_WIDTH) ? CROP_WIDTH : box_w0[i_gen];
                            bram_h[i_gen]    <= (box_h0[i_gen] > CROP_HEIGHT) ? CROP_HEIGHT : box_h0[i_gen];
                            
                            x_acc <= box_w0[i_gen] >> 1;
                            if (box_h0[i_gen] > CROP_HEIGHT) begin
                                if ((box_h0[i_gen] >> 1) + CROP_HEIGHT >= box_h0[i_gen]) begin
                                    keep_row <= 1'b1; y_acc <= (box_h0[i_gen] >> 1) + CROP_HEIGHT - box_h0[i_gen];
                                end else begin
                                    keep_row <= 1'b0; y_acc <= (box_h0[i_gen] >> 1) + CROP_HEIGHT;
                                end
                            end else begin
                                keep_row <= 1'b1; 
                            end
                        end
                        
                        else if (is_capturing) begin
                            if (hs_falling) begin
                                if (pixel_y == box_ymax[i_gen]) begin
                                    is_capturing <= 1'b0;
                                    box_locked[i_gen] <= 1'b1; 
                                end else begin
                                    x_acc <= box_w0[i_gen] >> 1; 
                                    if (box_h0[i_gen] > CROP_HEIGHT) begin
                                        if (y_acc + CROP_HEIGHT >= box_h0[i_gen]) begin
                                            keep_row <= 1'b1; y_acc <= y_acc + CROP_HEIGHT - box_h0[i_gen];
                                        end else begin
                                            keep_row <= 1'b0; y_acc <= y_acc + CROP_HEIGHT;
                                        end
                                    end else begin
                                        keep_row <= 1'b1; 
                                    end
                                end
                            end
                            
                            if (video_de_in && pixel_x >= box_xmin[i_gen] && pixel_x < box_xmax[i_gen]) begin
                                if (keep_row) begin
                                    if (box_w0[i_gen] > CROP_WIDTH) begin
                                        if (x_acc + CROP_WIDTH >= box_w0[i_gen]) begin
                                            wr_en <= 1'b1; x_acc <= x_acc + CROP_WIDTH - box_w0[i_gen];
                                        end else begin
                                            wr_en <= 1'b0; x_acc <= x_acc + CROP_WIDTH;
                                        end
                                    end else begin
                                        wr_en <= 1'b1;
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    endgenerate

    // =========================================================
    // E. OSD 渲染层 (简单画框)
    // =========================================================
    logic cur_hit; 
    logic [7:0] cur_cls;
    
    always_ff @(posedge clk_video) begin
        cur_hit <= 0; cur_cls <= 0;
        for (i_hit = 0; i_hit < MAX_BOX_NUM; i_hit = i_hit + 1) begin
            // [时序修复 2] 强制加入 && video_de_in，严防在 Blanking 消隐区内瞎画框！
            if (box_valid[i_hit] && video_de_in && pixel_x >= box_xmin[i_hit] && pixel_x <= box_xmax[i_hit] &&
                (pixel_y - 1) >= box_ymin[i_hit] && (pixel_y - 1) <= box_ymax[i_hit]) begin
                if (pixel_x < box_xmin[i_hit] + LINE_WIDTH || pixel_x > box_xmax[i_hit] - LINE_WIDTH ||
                    (pixel_y - 1) < box_ymin[i_hit] + LINE_WIDTH || (pixel_y - 1) > box_ymax[i_hit] - LINE_WIDTH) begin
                    cur_hit <= 1'b1; cur_cls <= box_cls[i_hit];
                end
            end
        end
    end

    // 最终对齐输出！
    always_ff @(posedge clk_video or negedge rst_n) begin
        if (!rst_n) begin
            video_vs_out <= 0; video_hs_out <= 0; video_de_out <= 0; video_rgb_out <= 0;
        end else begin
            // 取打过 1 拍的同步信号，与 rgb_delay 和 cur_hit 形成完美对齐！
            video_vs_out <= vs_d1;
            video_hs_out <= hs_d1;
            video_de_out <= de_d1;
            
            if (cur_hit)      video_rgb_out <= (cur_cls==1) ? 24'h00_FF_00 : 24'h00_00_FF; 
            else              video_rgb_out <= rgb_delay;
        end
    end
endmodule