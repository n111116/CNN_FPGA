`timescale 1ns / 1ps

module char_overlay #(
    // [修改] 去掉了 int
    parameter CROP_HEIGHT = 128,
    parameter FONT_FILE   = "chars_16x16.mem"
)(
    // [修改] 移除了 wire，直接使用 logic
    input  logic               clk_video,
    input  logic               rst_n_video,
    input  logic               video_vs_in,
    input  logic               video_hs_in,
    input  logic               video_de_in,
    input  logic [23:0]        video_rgb_in,
    output logic               video_vs_out,
    output logic               video_hs_out,
    output logic               video_de_out,
    output logic [23:0]        video_rgb_out,

    input  logic               clk_pe,
    input  logic               rst_n_pe,
    input  logic [15:0]        x_min_in,
    input  logic [15:0]        y_min_in,
    input  logic               new_line_1,

    input  logic [6:0]         out_char,
    input  logic               out_valid,
    input  logic               frame_start_out
);

    // =========================================================
    // A. 坐标同步 FIFO
    // =========================================================
    logic [15:0] line_cnt;
    logic        coord_fifo_wr;
    logic [31:0] coord_fifo_din;
    logic        coord_fifo_rd;
    logic [31:0] coord_fifo_dout;
    logic        coord_fifo_empty;

    always_ff @(posedge clk_pe or negedge rst_n_pe) begin
        if (!rst_n_pe) begin
            line_cnt      <= 0;
            coord_fifo_wr <= 0;
        end else begin
            coord_fifo_wr <= 0;
            if (new_line_1) begin
                if (line_cnt == 0) begin
                    coord_fifo_wr  <= 1'b1;
                    coord_fifo_din <= {x_min_in, y_min_in};
                end
                if (line_cnt == CROP_HEIGHT - 1) line_cnt <= 0;
                else                             line_cnt <= line_cnt + 1;
            end
        end
    end

    // 内部小型 FIFO (深度 16)，作为标准的 Memory 推断，保留非压缩形式
    logic [31:0] coord_fifo [0:15];
    logic [3:0]  coord_wr_ptr, coord_rd_ptr;
    logic [4:0]  coord_count;

    assign coord_fifo_empty = (coord_count == 0);
    assign coord_fifo_dout  = coord_fifo[coord_rd_ptr];

    always_ff @(posedge clk_pe or negedge rst_n_pe) begin
        if (!rst_n_pe) begin
            coord_wr_ptr <= 0; coord_rd_ptr <= 0; coord_count  <= 0;
        end else begin
            if (coord_fifo_wr && !coord_fifo_rd) begin
                coord_fifo[coord_wr_ptr] <= coord_fifo_din;
                coord_wr_ptr <= coord_wr_ptr + 1;
                coord_count  <= coord_count + 1;
            end else if (!coord_fifo_wr && coord_fifo_rd) begin
                coord_rd_ptr <= coord_rd_ptr + 1;
                coord_count  <= coord_count - 1;
            end else if (coord_fifo_wr && coord_fifo_rd) begin
                coord_fifo[coord_wr_ptr] <= coord_fifo_din;
                coord_wr_ptr <= coord_wr_ptr + 1;
                coord_rd_ptr <= coord_rd_ptr + 1;
            end
        end
    end

    // =========================================================
    // B. 字符拼装与跨时钟域推入
    // =========================================================
    logic [15:0] current_x_min, current_y_min;
    logic [15:0] char_offset;

    always_ff @(posedge clk_pe or negedge rst_n_pe) begin
        if (!rst_n_pe) begin
            coord_fifo_rd <= 0;
            char_offset   <= 0;
            current_x_min <= 0;
            current_y_min <= 0;
        end else begin
            coord_fifo_rd <= 0;
            if (frame_start_out) begin
                if (!coord_fifo_empty) begin
                    coord_fifo_rd <= 1'b1;
                    current_x_min <= coord_fifo_dout[31:16];
                    current_y_min <= coord_fifo_dout[15:0];
                end
                char_offset <= 0; 
            end else if (out_valid) begin
                char_offset <= char_offset + 16; 
            end
        end
    end
    
    // =========================================================
    // 组装发往视频域的数据包：7位字符码 + 16位X + 16位Y = 39 bits
    // =========================================================
    logic        async_fifo_wr;
    logic [38:0] async_fifo_din;
    logic        async_fifo_rd;
    logic [38:0] async_fifo_dout;
    logic        async_fifo_empty;

    // 独立计算坐标，自带明确的 16-bit 截断与保护
    logic [15:0] target_x;
    logic [15:0] target_y;

    assign target_x = current_x_min + char_offset;
    assign target_y = (current_y_min >= 16'd16) ? (current_y_min - 16'd16) : 16'd0;

    always_ff @(posedge clk_pe or negedge rst_n_pe) begin
        if (!rst_n_pe) begin
            async_fifo_wr <= 0;
            async_fifo_din <= 0;
        end else begin
            async_fifo_wr <= 0;
            if (out_valid) begin
                async_fifo_wr  <= 1'b1;
                // 拼接时全是干净、标准的变量，彻底杜绝位宽推断错误
                async_fifo_din <= {out_char, target_x, target_y};
            end
        end
    end

    // 实例化异步 FIFO
    my_fifo #(
        .DATA_WIDTH(39),
        .FIFO_DEPTH(64) 
    ) u_char_async_fifo (
        .wr_clk(clk_pe),      .rd_clk(clk_video), .rst(~rst_n_video),
        .wr_en(async_fifo_wr),.din(async_fifo_din),
        .rd_en(async_fifo_rd),.dout(async_fifo_dout),
        .full(),              .empty(async_fifo_empty)
    );
    assign async_fifo_rd = !async_fifo_empty;
    
    // =========================================================
    // C. 视频光栅扫描坐标追踪
    // =========================================================
    logic [15:0] pixel_x, pixel_y;
    logic        de_d1, vs_in_d;
    wire         hs_falling = !video_de_in && de_d1;
    wire         vs_rising  = video_vs_in && !vs_in_d;

    always_ff @(posedge clk_video) begin
        de_d1   <= video_de_in;
        vs_in_d <= video_vs_in;
        if (vs_rising) begin
            pixel_x <= 0; pixel_y <= 0;
        end else if (video_de_in) begin
            pixel_x <= pixel_x + 1;
        end else if (hs_falling) begin
            pixel_x <= 0; pixel_y <= pixel_y + 1;
        end
    end

    // =========================================================
    // D. 视频域 OSD 简易缓存阵列
    // =========================================================
    localparam MAX_CHARS = 32; 
    
    // [修改] 将内部缓存转为压缩数组
    logic [MAX_CHARS-1:0]        c_valid;
    logic [6:0]   c_code[MAX_CHARS-1:0];
    logic [15:0]  c_x[MAX_CHARS-1:0];
    logic [15:0]  c_y[MAX_CHARS-1:0];
    logic [4:0]  wr_ptr; 

    logic async_fifo_rd_d1;
    always_ff @(posedge clk_video) async_fifo_rd_d1 <= async_fifo_rd;

    logic [15:0] new_x, new_y;
    logic [6:0]  new_code;
    assign new_code = async_fifo_dout[38:32];
    assign new_x    = async_fifo_dout[31:16];
    assign new_y    = async_fifo_dout[15:0];

    // [修改] 提取循环变量到块外部
    integer i_char;
    always_ff @(posedge clk_video or negedge rst_n_video) begin
        if (!rst_n_video) begin
            wr_ptr <= 0;
            c_valid <= '0; // 压缩数组可直接赋 0 清零
        end else begin
            if (async_fifo_rd_d1) begin
                c_code[wr_ptr]  <= new_code;
                c_x[wr_ptr]     <= new_x;
                c_y[wr_ptr]     <= new_y;
                c_valid[wr_ptr] <= 1'b1;
                wr_ptr          <= wr_ptr + 1;
            end

            for (i_char=0; i_char<MAX_CHARS; i_char=i_char+1) begin
                // 去掉 pixel_y - 1，防止欠载溢出导致第0行误判
                if (c_valid[i_char] && hs_falling && pixel_y == (c_y[i_char] + 15)) begin
                    c_valid[i_char] <= 1'b0;
                end
            end
        end
    end

    // =========================================================
    // E. 视频 ROM 渲染流水线
    // =========================================================
    logic       s1_hit;
    logic [6:0] s1_char;
    logic [3:0] s1_row, s1_col;

    // [修改] 提取循环变量到块外部
    integer j_char;
    always_ff @(posedge clk_video) begin
        s1_hit <= 0;
        for (j_char=0; j_char<MAX_CHARS; j_char=j_char+1) begin
            if (c_valid[j_char] && video_de_in) begin
                if (pixel_x >= c_x[j_char] && pixel_x < c_x[j_char] + 16 &&
                    pixel_y >= c_y[j_char] && pixel_y < c_y[j_char] + 16) begin
                    s1_hit  <= 1'b1;
                    s1_char <= c_code[j_char];
                    s1_col  <= pixel_x - c_x[j_char];
                    s1_row  <= pixel_y - c_y[j_char];
                end
            end
        end
    end

    logic [10:0] rom_addr; 
    logic        s2_hit;
    logic [3:0]  s2_col;

    always_ff @(posedge clk_video) begin
        s2_hit   <= s1_hit;
        s2_col   <= s1_col;
        rom_addr <= s1_char * 16 + s1_row;
    end

    // ROM 读取需要严格的一维非压缩数组，这是 $readmemb 规定的
    logic [15:0] font_rom [0:2047];
    initial $readmemb(FONT_FILE, font_rom);

    logic [15:0] rom_data;
    always_ff @(posedge clk_video) rom_data <= font_rom[rom_addr];

    logic s3_hit;
    logic [3:0] s3_col;
    always_ff @(posedge clk_video) begin
        s3_hit <= s2_hit;
        s3_col <= s2_col;
    end

    logic char_pixel;
    assign char_pixel = s3_hit ? rom_data[15 - s3_col] : 1'b0;
    
    // =========================================================
    // F. 延迟补偿与混色输出 (完美对齐)
    // =========================================================
    logic [3:0]  vs_delay, hs_delay, de_delay;
    
    // [修改] 把 RGB 缓存也修改为压缩数组
    logic [2:0][23:0] rgb_delay; 

    always_ff @(posedge clk_video) begin
        vs_delay <= {vs_delay[2:0], video_vs_in};
        hs_delay <= {hs_delay[2:0], video_hs_in};
        de_delay <= {de_delay[2:0], video_de_in};

        rgb_delay[0] <= video_rgb_in;
        rgb_delay[1] <= rgb_delay[0];
        rgb_delay[2] <= rgb_delay[1];
    end

    // 纯连线输出控制信号，绝对延迟 4 拍
    assign video_vs_out = vs_delay[3];
    assign video_hs_out = hs_delay[3];
    assign video_de_out = de_delay[3];
    
    always_ff @(posedge clk_video) begin
        if (char_pixel) 
            video_rgb_out <= 24'hFF_00_FF; // 粉色文字
        else            
            // 取 T-3 时刻的数据进寄存器，输出正好是绝对延迟 4 拍！严格与 DE 信号对齐。
            video_rgb_out <= rgb_delay[2]; 
    end

endmodule