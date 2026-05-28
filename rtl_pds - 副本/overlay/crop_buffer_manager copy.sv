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
    
    input  logic               start_crop_wr[0:MAX_BOX_NUM-1],
    input  logic               end_crop_wr  [0:MAX_BOX_NUM-1],
    input  logic               crop_wr_en   [0:MAX_BOX_NUM-1],
    input  logic [15:0]        x_min_in     [0:MAX_BOX_NUM-1],
    input  logic [15:0]        y_min_in     [0:MAX_BOX_NUM-1],
    input  logic [15:0]        crop_h0      [0:MAX_BOX_NUM-1],  // 未使用，暂时保留接口
    input  logic [15:0]        crop_w0      [0:MAX_BOX_NUM-1],  // 未使用，暂时保留接口
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
    localparam int ADDR_WIDTH     = $clog2(PIXELS_PER_BOX);
    
    genvar i_gen;
    int    idx;
    
    logic [15:0]        x_min_reg        [0:MAX_BOX_NUM-1];
    logic [15:0]        y_min_reg        [0:MAX_BOX_NUM-1];
    // 写端控制信号
    logic [0:MAX_BOX_NUM-1] box_ready_v; 
    logic [0:MAX_BOX_NUM-1] box_writing;  // [新增] 用于标记是否完整经历了起始写入
    
    // 跨时钟域同步信号 (clk_video -> clk_pe: 通知就绪)
    logic [0:MAX_BOX_NUM-1] box_ready_sync1 ;
    logic [0:MAX_BOX_NUM-1] box_ready_pe    ;

    // 跨时钟域同步信号 (clk_pe -> clk_video: 通知读完以释放缓存)
    logic [0:MAX_BOX_NUM]   box_read_toggle_pe ;  // PE端翻转标志
    logic [0:MAX_BOX_NUM-1] toggle_sync1       ; 
    logic [0:MAX_BOX_NUM-1] toggle_sync2       ; 
    logic [0:MAX_BOX_NUM-1] toggle_sync3       ; 
    logic [0:MAX_BOX_NUM-1] box_read_done_v    ; // Video端还原的完成脉冲
    
    // VS 信号上升沿检测

    // 读端控制信号与状态机
    logic [1:0] state;
    localparam IDLE = 0, READING = 1, WAIT_GAP = 2;
    
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

    // 维护每个框的写入状态机和“就绪”标志
    always_ff @(posedge clk_video or negedge rst_n) begin
        if (!rst_n) begin
            for (idx = 0; idx < MAX_BOX_NUM; idx++) begin
                box_ready_v[idx] <= 0;
                box_writing[idx] <= 0; // 初始化状态为不在写入中
            end
        end else begin
            for (idx = 0; idx < MAX_BOX_NUM; idx++) begin
                
                // 1. 检测到起始写入脉冲，将其标记为“处于合法写入区间”
                if (start_crop_wr[idx]) begin
                    box_writing[idx] <= 1'b1;
                end
                
                // 2. 状态判决：写完与读完处理
                // 如果刚好同时触发读完和写完，以最新写完的数据为准（优先拉高ready）
                if (end_crop_wr[idx]) begin
                    // [核心修改] 只有经历过 start_crop_wr 标记的框，才能真正将 ready 拉高
                    if (box_writing[idx]) begin
                        box_ready_v[idx] <= 1'b1;
                        box_writing[idx] <= 1'b0; // 写入完成，清除标记
                    end
                end else if (box_read_done_v[idx]) begin
                    // 接收到 PE 读完脉冲，释放该缓存以备后续写入
                    box_ready_v[idx] <= 1'b0;
                end

            end
        end
    end
    
    int i;
    always_ff @(posedge clk_video) begin
        // 写入开始时锁存x_min和y_min
        for (i = 0; i < MAX_BOX_NUM; i++) begin
            if (start_crop_wr[i]) begin
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
        for (ii = 0; ii < MAX_BOX_NUM; ii++) begin
            if (ii == read_box_idx) fifo_rd_en[ii] = rd_en_pulse;
            else                   fifo_rd_en[ii] = 1'b0;
        end
    end

    generate
        for (i_gen = 0; i_gen < MAX_BOX_NUM; i_gen++) begin : gen_box_fifos
            my_fifo #(
                .DATA_WIDTH(24),
                .FIFO_DEPTH(PIXELS_PER_BOX) 
            ) 
            // ip_fifo 
            u_crop_fifo (
                .rd_clk  (clk_pe),
                .wr_clk  (clk_video),
                .rst     ((start_crop_wr[i_gen] & (~box_ready_v[i_gen]) )),              
                .wr_en   ((crop_wr_en[i_gen] & (~box_ready_v[i_gen]) )),
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