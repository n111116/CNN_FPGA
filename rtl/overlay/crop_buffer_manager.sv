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
    
    input  logic               start_box_wr [0:MAX_BOX_NUM-1],
    input  logic               end_box_wr   [0:MAX_BOX_NUM-1],
    input  logic               crop_wr_en   [0:MAX_BOX_NUM-1],
    input  logic [15:0]        x_min_in     [0:MAX_BOX_NUM-1],
    input  logic [15:0]        y_min_in     [0:MAX_BOX_NUM-1],
    input  logic [23:0]        crop_rgb_out,
    
    // ===================================
    // 2. 读端：PE 网络时钟域 (clk_pe)
    // ===================================
    input  logic               clk_pe,
    output logic [15:0]        x_min_out,
    output logic [15:0]        y_min_out,
    output logic               new_line_1,
    output logic               data_valid,
    output logic [23:0]        data_out
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
    
    genvar i_gen;
    int    idx;
    
    logic [15:0]        x_min_reg        [0:MAX_BOX_NUM-1];
    logic [15:0]        y_min_reg        [0:MAX_BOX_NUM-1];
    // 写端控制信号
    logic [0:MAX_BOX_NUM-1] box_ready_v; 
    
    // 跨时钟域同步信号 (clk_video -> clk_pe: 通知就绪)
    logic [0:MAX_BOX_NUM-1] box_ready_sync1 ;
    logic [0:MAX_BOX_NUM-1] box_ready_pe    ;

    // [新增] 跨时钟域同步信号 (clk_pe -> clk_video: 通知读完以释放缓存)
    logic [0:MAX_BOX_NUM]   box_read_toggle_pe ;  // PE端翻转标志
    logic [0:MAX_BOX_NUM-1] toggle_sync1       ; 
    logic [0:MAX_BOX_NUM-1] toggle_sync2       ; 
    logic [0:MAX_BOX_NUM-1] toggle_sync3       ; 
    logic [0:MAX_BOX_NUM-1] box_read_done_v    ; // Video端还原的完成脉冲
    
    // VS 信号上升沿检测

    // 读端控制信号与状态机
    typedef enum logic [1:0] {IDLE, READING, WAIT_GAP} state_t;
    state_t state;
    
    logic [$clog2(MAX_BOX_NUM + 1):0]  read_box_idx;       // 当前正在处理的子图指针
    logic [15:0] r_row, r_col;       // 读出坐标 (用于计算 new_line_1 和结束条件)
    logic [15:0] cycle_cnt;          // 复用周期/间隙等待 计数器
    logic [15:0] cycle_cnt_gap;          // 复用周期/间隙等待 计数器
    
    logic        rd_en_pulse; 
    logic        rd_en_d1;
    
    // =========================================================
    // 1. 跨时钟域反馈接收与 Video 域控制 (clk_video)
    // =========================================================

    // 接收 PE 域的读取完毕反馈 (Toggle Synchronizer -> Edge Detector)
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
                // 异或取边沿，产生 1 个 clk_video 周期的读取完毕脉冲
                box_read_done_v[idx] <= toggle_sync2[idx] ^ toggle_sync3[idx]; 
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
            for (idx = 0; idx < MAX_BOX_NUM; idx++) begin
                // 接收到读完脉冲，立刻清空标志和计数器，释放该缓存以备覆盖写入！
                case ({box_read_done_v[idx], end_box_wr[idx]})
                    2'b00: box_ready_v[idx] <= box_ready_v[idx];
                    2'b10: box_ready_v[idx] <= 0;
                    2'b01: box_ready_v[idx] <= 1;
                    2'b11: box_ready_v[idx] <= 1;
                endcase

            end
        end
    end
    always_ff @(posedge clk_video) begin
        // 写入开始时锁存x_min和y_min
        for (int i = 0; i < MAX_BOX_NUM; i++) begin
            if (start_box_wr[i]) begin
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

    always_comb begin
        for (int i = 0; i < MAX_BOX_NUM; i++) begin
            if (i == read_box_idx) fifo_rd_en[i] = rd_en_pulse;
            else                   fifo_rd_en[i] = 1'b0;
        end
    end

    generate
        for (i_gen = 0; i_gen < MAX_BOX_NUM; i_gen++) begin : gen_box_fifos
            my_fifo #(
                .DATA_WIDTH(24),
                .FIFO_DEPTH(BOX_FIFO_DEPTH)
            ) 
            // ip_fifo 
            u_crop_fifo (
                .rd_clk  (clk_pe),
                .wr_clk  (clk_video),
                .rst     (start_box_wr[i_gen]),              
                .wr_en   (crop_wr_en[i_gen]),
                .din     (crop_rgb_out),
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
            for (idx = 0; idx < MAX_BOX_NUM + 1; idx++) box_read_toggle_pe[idx] <= 0;
        end else begin
            new_line_1 <= 1'b0;
            case (state)
                IDLE: begin
                    r_row     <= 0;
                    r_col     <= 0;
                    cycle_cnt <= 0;
                    cycle_cnt_gap <= 0;
                    // 当前box有效或第0个有效时进入开始读取对应缓冲区
                    if (box_ready_pe[read_box_idx]) begin
                        x_min_out <= x_min_reg[read_box_idx];
                        y_min_out <= y_min_reg[read_box_idx];
                        state <= READING;
                    end else if (box_ready_pe[0]) begin
                        x_min_out <= x_min_reg[0];
                        y_min_out <= y_min_reg[0];
                        state <= READING;
                        read_box_idx <= 0;
                    end
                end
                
                READING: begin
                    if (cycle_cnt == CYCLE_PERIOD - 1) cycle_cnt <= 0;
                    else                               cycle_cnt <= cycle_cnt + 1;
                    
                    if (cycle_cnt == 0) begin
                        // 触发 new_line_1 (提前一周期)
                        if (r_col == 0) new_line_1 <= 1'b1;
                        
                        // 坐标维护与结束判定
                        if (r_col == CROP_WIDTH - 1) begin
                            r_col     <= 0;
                            state     <= WAIT_GAP;
                            if (r_row == CROP_HEIGHT - 1) begin
                                
                                // 读完最后一个像素，翻转 Toggle，通知写端清空缓存
                                box_read_toggle_pe[read_box_idx] <= ~box_read_toggle_pe[read_box_idx];
                                
                            end
                        end else begin
                            r_col <= r_col + 1;
                        end
                    end
                end
                
                // 行尾间隙等待状态
                WAIT_GAP: begin
                    // 由于lprnet的前两层处理速度远快于后面的层，这里加大行间隔以匹配处理速度
                    if (cycle_cnt_gap == LINE_GAP - 1) begin
                        // 一个子图处理结束
                        if(r_row == CROP_HEIGHT - 1) begin
                            // 当没有有效子图时，读一个无效的框，推动流水线继续流动
                            if((box_ready_pe == 0) && (read_box_idx == MAX_BOX_NUM)) begin
                                state <= READING;
                                read_box_idx <= MAX_BOX_NUM;
                            end
                            // 每次进入IDLE时, read_box_idx循环自增1.
                            else begin
                                state     <= IDLE;
                                if (read_box_idx >= MAX_BOX_NUM - 1) 
                                    read_box_idx <= 0;
                                else 
                                    read_box_idx <= read_box_idx + 1;
                            end
                        end else begin
                            r_row <= r_row + 1;
                            state     <= READING;
                        end
                        cycle_cnt_gap <= 0;        // 重置给 READING 状态使用
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
    // rd_en_pulse 表明当前周期向 FIFO 发送了读请求
    assign rd_en_pulse = (state == READING) && (cycle_cnt == 0);

    always_ff @(posedge clk_pe or negedge rst_n) begin
        if (!rst_n) begin
            rd_en_d1   <= 0;
            data_valid <= 0;
            data_out   <= 0;
        end else begin
            // 匹配 FIFO 的 1 周期读出潜伏期
            rd_en_d1   <= rd_en_pulse;
            data_valid <= rd_en_d1;
            
            if (rd_en_d1) begin
                data_out <= (read_box_idx < MAX_BOX_NUM) ? ram_q[read_box_idx] : 24'd0;
            end
        end
    end

endmodule
