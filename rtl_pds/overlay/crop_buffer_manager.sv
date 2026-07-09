module crop_buffer_manager #(
    parameter int MAX_BOX_NUM  = 10,
    parameter int LINE_GAP     = 20,
    parameter int CROP_WIDTH   = 128,
    parameter int CROP_HEIGHT  = 128,
    parameter int CYCLE_PERIOD = 4       // 子图向神经网络输出的复用周期
)(
    // ===================================
    // 1. 写端：视频流时钟域 (clk_video)
    // ===================================
    input  logic               clk_video,
    input  logic               rst_n,
    
    input  logic [MAX_BOX_NUM-1:0]        start_crop_wr,
    input  logic [MAX_BOX_NUM-1:0]        end_crop_wr,
    input  logic [MAX_BOX_NUM-1:0]        crop_wr_en,
    input  logic [MAX_BOX_NUM-1:0][15:0]  x_min_in,
    input  logic [MAX_BOX_NUM-1:0][15:0]  y_min_in,
    input  logic [MAX_BOX_NUM-1:0][23:0]  crop_rgb_out,
    
    // ===================================
    // 2. 读端：PE 网络时钟域 (clk_pe)
    // ===================================
    input  logic               clk_pe,
    output logic [15:0]        x_min_out                         /* synthesis syn_preserve=1 */,
    output logic [15:0]        y_min_out                         /* synthesis syn_preserve=1 */,
    output logic               new_line_1                        /* synthesis syn_preserve=1 */,
    output logic               data_valid                        /* synthesis syn_preserve=1 */,
    output logic [23:0]        data_out                          /* synthesis syn_preserve=1 */
);

    // =========================================================
    // 变量统一定义区
    // =========================================================
    localparam int PIXELS_PER_BOX = CROP_WIDTH * CROP_HEIGHT;
    // my_fifo 的指针/满空判断要求深度为 2 的幂；读写计数仍按 PIXELS_PER_BOX 结束。
    localparam int BOX_FIFO_DEPTH =
        (PIXELS_PER_BOX <= 2)     ? 2     :
        (PIXELS_PER_BOX <= 4)     ? 4     :
        (PIXELS_PER_BOX <= 8)     ? 8     :
        (PIXELS_PER_BOX <= 16)    ? 16    :
        (PIXELS_PER_BOX <= 32)    ? 32    :
        (PIXELS_PER_BOX <= 64)    ? 64    :
        (PIXELS_PER_BOX <= 128)   ? 128   :
        (PIXELS_PER_BOX <= 256)   ? 256   :
        (PIXELS_PER_BOX <= 512)   ? 512   :
        (PIXELS_PER_BOX <= 1024)  ? 1024  :
        (PIXELS_PER_BOX <= 2048)  ? 2048  :
        (PIXELS_PER_BOX <= 4096)  ? 4096  :
        (PIXELS_PER_BOX <= 8192)  ? 8192  :
        (PIXELS_PER_BOX <= 16384) ? 16384 :
        (PIXELS_PER_BOX <= 32768) ? 32768 : 65536;
    localparam int ADDR_WIDTH     = $clog2(BOX_FIFO_DEPTH);
    localparam [15:0] FLUSH_X_MIN = 16'd1279;
    localparam [15:0] FLUSH_Y_MIN = 16'd719;
    
    genvar i_gen;
    int    idx;
    
    logic [15:0]        x_min_reg        [0:MAX_BOX_NUM-1];
    logic [15:0]        y_min_reg        [0:MAX_BOX_NUM-1];
    
    // 写端控制信号
    logic [MAX_BOX_NUM-1:0] box_ready_v                          /* synthesis syn_preserve=1 */; 
    logic [MAX_BOX_NUM-1:0] writing_active                       /* synthesis syn_preserve=1 */; // [新增] 帧级写入许可锁，保证不写半截帧
    
    // 跨时钟域同步信号 (clk_video -> clk_pe: 通知就绪)
    logic [MAX_BOX_NUM-1:0] box_ready_sync1                      /* synthesis syn_preserve=1 */;
    logic [MAX_BOX_NUM-1:0] box_ready_pe                         /* synthesis syn_preserve=1 */;

    // 跨时钟域同步信号 (clk_pe -> clk_video: 通知读完以释放缓存)
    logic [MAX_BOX_NUM-1:0] box_read_toggle_pe                   /* synthesis syn_preserve=1 */;  
    logic [MAX_BOX_NUM-1:0] toggle_sync1                         /* synthesis syn_preserve=1 */; 
    logic [MAX_BOX_NUM-1:0] toggle_sync2                         /* synthesis syn_preserve=1 */; 
    logic [MAX_BOX_NUM-1:0] toggle_sync3                         /* synthesis syn_preserve=1 */; 
    logic [MAX_BOX_NUM-1:0] box_read_done_v                      /* synthesis syn_preserve=1 */; 
    
    // 读端控制信号与状态机
    logic [1:0] state                                             /* synthesis syn_preserve=1 */;
    localparam IDLE = 0, READING = 1, WAIT_GAP = 2;
    
    logic [$clog2(MAX_BOX_NUM + 1):0]  read_box_idx              /* synthesis syn_preserve=1 */;       
    logic [15:0] r_row                                           /* synthesis syn_preserve=1 */;
    logic [15:0] r_col                                           /* synthesis syn_preserve=1 */;       
    logic [15:0] cycle_cnt                                       /* synthesis syn_preserve=1 */;          
    logic [15:0] cycle_cnt_gap                                   /* synthesis syn_preserve=1 */;          
    logic        flush_pending                                   /* synthesis syn_preserve=1 */;
    logic [$clog2(MAX_BOX_NUM + 1):0] flush_scan_count           /* synthesis syn_preserve=1 */;
    
    logic        out_en_pulse                                    /* synthesis syn_keep=1 */;
    logic        rd_en_pulse                                     /* synthesis syn_keep=1 */; 
    logic        out_en_d1                                       /* synthesis syn_preserve=1 */;
    logic        black_read_d1                                   /* synthesis syn_preserve=1 */;
    logic        current_box_ready                               /* synthesis syn_preserve=1 */;
    logic [15:0] current_x_min                                   /* synthesis syn_preserve=1 */;
    logic [15:0] current_y_min                                   /* synthesis syn_preserve=1 */;
    logic [23:0] current_ram_q                                   /* synthesis syn_preserve=1 */;
    
    // =========================================================
    // 1. 跨时钟域反馈接收与 Video 域控制 (clk_video)
    // =========================================================

    // 接收 PE 域的读取完毕反馈
    always_ff @(posedge clk_video or negedge rst_n) begin
        if (!rst_n) begin
            for (idx = 0; idx < MAX_BOX_NUM; idx++) begin
                toggle_sync1[idx] <= 0;
                toggle_sync2[idx] <= 0;
                toggle_sync3[idx] <= 0;
                box_read_done_v[idx] <= 0;
            end
        end else begin
            for (idx = 0; idx < MAX_BOX_NUM; idx++) begin
                toggle_sync1[idx] <= box_read_toggle_pe[idx];
                toggle_sync2[idx] <= toggle_sync1[idx];
                toggle_sync3[idx] <= toggle_sync2[idx];
                box_read_done_v[idx] <= toggle_sync2[idx] ^ toggle_sync3[idx]; 
            end
        end
    end

    // [新增核心修复]：维护 writing_active 写入锁
    always_ff @(posedge clk_video or negedge rst_n) begin
        if (!rst_n) begin
            for (idx = 0; idx < MAX_BOX_NUM; idx++) begin
                writing_active[idx] <= 1'b0;
            end
        end else begin
            for (idx = 0; idx < MAX_BOX_NUM; idx++) begin
                // 只有在 start 脉冲到来且 FIFO 空闲时，才赋予这完整一帧的写入锁
                if (start_crop_wr[idx] && ~box_ready_v[idx]) begin
                    writing_active[idx] <= 1'b1;
                end
                // 当一帧结束时，无论是有效帧还是半截被遗弃的帧，一律清空状态
                else if (end_crop_wr[idx]) begin
                    writing_active[idx] <= 1'b0;
                end
            end
        end
    end

    // 维护每个框的写入计数器和“就绪”标志
    always_ff @(posedge clk_video or negedge rst_n) begin
        if (!rst_n) begin
            for (idx = 0; idx < MAX_BOX_NUM; idx++) begin
                box_ready_v[idx] <= 0;
            end
        end else begin
            for (idx = 0; idx < MAX_BOX_NUM; idx++) begin : gen_box_ready_v
                // [修复]: 只有真正在写完整帧 (writing_active) 且遇到 end_crop_wr，才说明产生了有效就绪数据！
                // 如果 writing_active 为 0，说明本帧是中途产生的残渣被抛弃了，不应置位 box_ready_v。
                logic valid_end_pulse;
                valid_end_pulse = end_crop_wr[idx] & writing_active[idx];

                case ({box_read_done_v[idx], valid_end_pulse})
                    2'b00: box_ready_v[idx] <= box_ready_v[idx];
                    2'b10: box_ready_v[idx] <= 0; // PE读取完成，清除Ready
                    2'b01: box_ready_v[idx] <= 1; // 完整帧写入完成，置位Ready
                    2'b11: box_ready_v[idx] <= 1; // 并发处理，新帧优先生效
                endcase
            end
        end
    end
    
    int i;
    always_ff @(posedge clk_video) begin
        for (i = 0; i < MAX_BOX_NUM; i++) begin
            if (start_crop_wr[i] && ~box_ready_v[i]) begin
                x_min_reg[i] <= x_min_in[i];
                y_min_reg[i] <= y_min_in[i];
            end
        end
    end
    
    // =========================================================
    // 2. 独立 FIFO 阵列生成
    // =========================================================
    logic fifo_rd_en [0:MAX_BOX_NUM-1];
    logic [23:0] ram_q [0:MAX_BOX_NUM-1];
    int ii;
    always_comb begin
        current_box_ready = 1'b0;
        current_x_min     = 16'd0;
        current_y_min     = 16'd0;
        current_ram_q     = 24'd0;
        for (ii = 0; ii < MAX_BOX_NUM; ii++) begin
            if ((read_box_idx < MAX_BOX_NUM) && (ii == read_box_idx)) fifo_rd_en[ii] = rd_en_pulse;
            else                                                       fifo_rd_en[ii] = 1'b0;

            if ((read_box_idx < MAX_BOX_NUM) && (ii == read_box_idx)) begin
                current_box_ready = box_ready_pe[ii];
                current_x_min     = x_min_reg[ii];
                current_y_min     = y_min_reg[ii];
                current_ram_q     = ram_q[ii];
            end
        end
    end

    generate
        for (i_gen = 0; i_gen < MAX_BOX_NUM; i_gen++) begin : gen_box_fifos
            logic safe_rst;
            logic safe_wr_en;

            // [修改]: 复位只发生在允许写入完整新帧的起始点
            assign safe_rst   = start_crop_wr[i_gen] & ~box_ready_v[i_gen];
            // [修改]: 写入使能严格被 writing_active 锁控制，无视中途 box_ready_v 的跳变
            assign safe_wr_en = crop_wr_en[i_gen]    & writing_active[i_gen];

            my_fifo #(
                .DATA_WIDTH(24),
                .FIFO_DEPTH(BOX_FIFO_DEPTH)
            ) 
            // ip_fifo 
            u_crop_fifo (
                .rd_clk  (clk_pe),
                .wr_clk  (clk_video),
                .rst     (safe_rst),              
                .wr_en   (safe_wr_en),
                .din     (crop_rgb_out[i_gen]),
                .rd_en   (fifo_rd_en[i_gen]),
                .dout    (ram_q[i_gen]),
                .full    (),
                .empty   ()
            );
        end
    endgenerate

    // =========================================================
    // 3. 跨时钟域同步 (Video -> PE)
    // =========================================================

    // 同步 box_ready 信号到 PE 时钟域 
    always_ff @(posedge clk_pe or negedge rst_n) begin
        if (!rst_n) begin
            for (idx = 0; idx < MAX_BOX_NUM; idx++) begin
                box_ready_sync1[idx] <= 0;
                box_ready_pe[idx]    <= 0;
            end
        end else begin
            for (idx = 0; idx < MAX_BOX_NUM; idx++) begin
                box_ready_sync1[idx] <= box_ready_v[idx];
                box_ready_pe[idx]    <= box_ready_sync1[idx];
            end
        end
    end
    
    // =========================================================
    // 4. 读端控制与状态机 (同步于 clk_pe)
    // =========================================================
    always_ff @(posedge clk_pe or negedge rst_n) begin
        if (!rst_n) begin
            state         <= IDLE;
            read_box_idx  <= 0;
            r_row         <= 0;
            r_col         <= 0;
            cycle_cnt     <= 0;
            cycle_cnt_gap <= 0;
            new_line_1    <= 0;
            flush_pending <= 1'b0;
            flush_scan_count <= 0;
            for (idx = 0; idx < MAX_BOX_NUM; idx++) box_read_toggle_pe[idx] <= 0;
        end else begin
            new_line_1 <= 1'b0;
            case (state)
                IDLE: begin
                    r_row     <= 0;
                    r_col     <= 0;
                    cycle_cnt <= 0;
                    cycle_cnt_gap <= 0;
                    
                    if (current_box_ready) begin
                        x_min_out <= current_x_min;
                        y_min_out <= current_y_min;
                        flush_pending <= 1'b0;
                        flush_scan_count <= 0;
                        state <= READING;
                    end else if (flush_pending && (flush_scan_count == MAX_BOX_NUM - 1)) begin
                        x_min_out <= FLUSH_X_MIN;
                        y_min_out <= FLUSH_Y_MIN;
                        read_box_idx <= MAX_BOX_NUM;
                        flush_pending <= 1'b0;
                        flush_scan_count <= 0;
                        state <= READING;
                    end else begin
                        read_box_idx <= (read_box_idx == MAX_BOX_NUM - 1) ? 0 : (read_box_idx + 1);
                        if (flush_pending) begin
                            flush_scan_count <= flush_scan_count + 1'b1;
                        end
                    end
                end
                
                READING: begin
                    if (cycle_cnt == CYCLE_PERIOD - 1) cycle_cnt <= 0;
                    else                               cycle_cnt <= cycle_cnt + 1;
                    
                    if (cycle_cnt == 0) begin
                        if (r_col == 0) new_line_1 <= 1'b1;
                        
                        if (r_col == CROP_WIDTH - 1) begin
                            r_col     <= 0;
                            state     <= WAIT_GAP;
                            if ((r_row == CROP_HEIGHT - 1) && (read_box_idx < MAX_BOX_NUM)) begin
                                box_read_toggle_pe[read_box_idx] <= ~box_read_toggle_pe[read_box_idx];
                            end
                        end else begin
                            r_col <= r_col + 1;
                        end
                    end
                end
                
                WAIT_GAP: begin
                    if (cycle_cnt_gap == LINE_GAP - 1) begin
                        if(r_row == CROP_HEIGHT - 1) begin
                            if (read_box_idx == MAX_BOX_NUM) begin
                                flush_pending <= 1'b0;
                                flush_scan_count <= 0;
                                state <= IDLE;
                                read_box_idx <= 0;
                            end else begin
                                // 真实子图读完后，先扫描一圈其它 box。
                                // 如果没有新的 ready 子图，IDLE 会用 read_box_idx == MAX_BOX_NUM 补一张黑图排空 LPRNet。
                                flush_pending <= 1'b1;
                                flush_scan_count <= 0;
                                state <= IDLE;
                                if (read_box_idx >= MAX_BOX_NUM - 1)
                                    read_box_idx <= 0;
                                else
                                    read_box_idx <= read_box_idx + 1;
                            end
                        end else begin
                            r_row <= r_row + 1;
                            state     <= READING;
                        end
                        cycle_cnt_gap <= 0;       
                    end else begin
                        cycle_cnt_gap <= cycle_cnt_gap + 1;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // =========================================================
    // 5. 提取数据与生成 Valid 延迟
    // =========================================================
    assign out_en_pulse = (state == READING) && (cycle_cnt == 0);
    assign rd_en_pulse  = out_en_pulse && (read_box_idx < MAX_BOX_NUM);

    always_ff @(posedge clk_pe or negedge rst_n) begin
        if (!rst_n) begin
            out_en_d1      <= 0;
            black_read_d1  <= 0;
            data_valid     <= 0;
            data_out       <= 0;
        end else begin
            out_en_d1     <= out_en_pulse;
            black_read_d1 <= (read_box_idx == MAX_BOX_NUM);
            data_valid    <= out_en_d1;
            
            if (out_en_d1) begin
                if (black_read_d1) begin
                    data_out <= 24'd0;
                end else begin
                    data_out <= current_ram_q;
                end
            end
        end
    end

endmodule
