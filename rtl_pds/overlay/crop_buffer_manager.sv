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
    
    input  logic               start_crop_wr [0:MAX_BOX_NUM-1],
    input  logic               end_crop_wr   [0:MAX_BOX_NUM-1],
    input  logic               crop_wr_en   [0:MAX_BOX_NUM-1],
    input  logic [15:0]        x_min_in     [0:MAX_BOX_NUM-1],
    input  logic [15:0]        y_min_in     [0:MAX_BOX_NUM-1],
    input  logic [23:0]        crop_rgb_out [0:MAX_BOX_NUM-1],
    
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
    logic [0:MAX_BOX_NUM-1] writing_active; // [新增] 帧级写入许可锁，保证不写半截帧
    
    // 跨时钟域同步信号 (clk_video -> clk_pe: 通知就绪)
    logic [0:MAX_BOX_NUM-1] box_ready_sync1 ;
    logic [0:MAX_BOX_NUM-1] box_ready_pe    ;

    // 跨时钟域同步信号 (clk_pe -> clk_video: 通知读完以释放缓存)
    logic [0:MAX_BOX_NUM]   box_read_toggle_pe ;  
    logic [0:MAX_BOX_NUM-1] toggle_sync1       ; 
    logic [0:MAX_BOX_NUM-1] toggle_sync2       ; 
    logic [0:MAX_BOX_NUM-1] toggle_sync3       ; 
    logic [0:MAX_BOX_NUM-1] box_read_done_v    ; 
    
    // 读端控制信号与状态机
    logic [1:0] state;
    localparam IDLE = 0, READING = 1, WAIT_GAP = 2;
    
    logic [$clog2(MAX_BOX_NUM + 1):0]  read_box_idx;       
    logic [15:0] r_row, r_col;       
    logic [15:0] cycle_cnt;          
    logic [15:0] cycle_cnt_gap;          
    
    logic        rd_en_pulse; 
    logic        rd_en_d1;
    
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
        for (ii = 0; ii < MAX_BOX_NUM; ii++) begin
            if (ii == read_box_idx) fifo_rd_en[ii] = rd_en_pulse;
            else                    fifo_rd_en[ii] = 1'b0;
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
                .FIFO_DEPTH(PIXELS_PER_BOX) 
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
            for (idx = 0; idx < MAX_BOX_NUM + 1; idx++) box_read_toggle_pe[idx] <= 0;
        end else begin
            new_line_1 <= 1'b0;
            case (state)
                IDLE: begin
                    r_row     <= 0;
                    r_col     <= 0;
                    cycle_cnt <= 0;
                    cycle_cnt_gap <= 0;
                    
                    if (box_ready_pe[read_box_idx]) begin
                        x_min_out <= x_min_reg[read_box_idx];
                        y_min_out <= y_min_reg[read_box_idx];
                        state <= READING;
                    end else begin
                        read_box_idx <= (read_box_idx == MAX_BOX_NUM - 1) ? 0 : (read_box_idx + 1);
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
                            if (r_row == CROP_HEIGHT - 1) begin
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
                            state     <= IDLE;
                            if (read_box_idx >= MAX_BOX_NUM - 1) 
                                read_box_idx <= 0;
                            else 
                                read_box_idx <= read_box_idx + 1;
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
    assign rd_en_pulse = (state == READING) && (cycle_cnt == 0);

    always_ff @(posedge clk_pe or negedge rst_n) begin
        if (!rst_n) begin
            rd_en_d1   <= 0;
            data_valid <= 0;
            data_out   <= 0;
        end else begin
            rd_en_d1   <= rd_en_pulse;
            data_valid <= rd_en_d1; 
            
            if (rd_en_d1) begin
                data_out <= (read_box_idx < MAX_BOX_NUM) ? ram_q[read_box_idx] : 24'd0;
            end
        end
    end

endmodule
