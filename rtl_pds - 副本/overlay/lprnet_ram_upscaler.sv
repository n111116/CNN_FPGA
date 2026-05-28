module lprnet_ram_upscaler #(
    parameter int MAX_BOX_NUM  = 10,
    parameter int LINE_GAP     = 20,       
    parameter int CROP_WIDTH   = 128,      
    parameter int CROP_HEIGHT  = 32,      // 修改为 32
    parameter int CYCLE_PERIOD = 4         
)(
    input  logic               clk_pe,
    input  logic               rst_n,
    
    // 来自 Downscaler 的握手与元数据
    input  logic               box_locked [0:MAX_BOX_NUM-1],
    input  logic [15:0]        box_x_min  [0:MAX_BOX_NUM-1],
    input  logic [15:0]        box_y_min  [0:MAX_BOX_NUM-1],
    input  logic [15:0]        bram_w     [0:MAX_BOX_NUM-1],
    input  logic [15:0]        bram_h     [0:MAX_BOX_NUM-1],
    
    // 读 BRAM 地址接口 (12位地址)
    output logic [11:0]        bram_rd_addr [0:MAX_BOX_NUM-1],
    input  logic [23:0]        bram_rd_data [0:MAX_BOX_NUM-1],
    
    // [核心重构] 发给 Downscaler 的电平翻转信号
    output logic               release_toggle_pe  [0:MAX_BOX_NUM-1],
    
    // LPRNet 输出
    output logic [15:0]        x_min_out, 
    output logic [15:0]        y_min_out,
    output logic               new_line_1,
    output logic               data_valid,
    output logic [23:0]        data_out
);

    // =========================================================
    // 1. 跨时钟域接收 Locked 信号 (Video -> PE, 电平安全同步)
    // =========================================================
    logic locked_sync1 [0:MAX_BOX_NUM-1];
    logic locked_sync2 [0:MAX_BOX_NUM-1];
    int i;
    always_ff @(posedge clk_pe or negedge rst_n) begin
        if (!rst_n) begin
            for(i=0; i<MAX_BOX_NUM; i++) begin
                locked_sync1[i] <= 0; locked_sync2[i] <= 0;
            end
        end else begin
            for(i=0; i<MAX_BOX_NUM; i++) begin
                locked_sync1[i] <= box_locked[i];
                locked_sync2[i] <= locked_sync1[i];
            end
        end
    end

    // =========================================================
    // 2. 主状态机：2D DDA 随机寻址魔法
    // =========================================================
    logic [2:0]  state;
    localparam IDLE = 0, READING = 1, WAIT_GAP = 2, RELEASE = 3;
    
    logic [$clog2(MAX_BOX_NUM):0] cur_box;
    logic release_sent; // 控制翻转信号单次触发的标志
    
    logic [15:0] out_x, out_y; 
    logic [15:0] cycle_cnt, gap_cnt;
    
    logic [15:0] src_x, src_y;
    logic [15:0] acc_x, acc_y;
    logic [15:0] cur_w, cur_h;
    
    logic [15:0] row_start_addr; 

    always_ff @(posedge clk_pe or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; cur_box <= 0; release_sent <= 0;
            for(i=0; i<MAX_BOX_NUM; i++) release_toggle_pe[i] <= 0;
            out_x <= 0; out_y <= 0; cycle_cnt <= 0; gap_cnt <= 0;
            data_valid <= 0; new_line_1 <= 0; data_out <= 0;
            x_min_out <= 0; y_min_out <= 0;
        end else begin
            data_valid <= 0; new_line_1 <= 0;
            
            case (state)
                IDLE: begin
                    if (locked_sync2[cur_box]) begin
                        state     <= READING;
                        cur_w     <= bram_w[cur_box];
                        cur_h     <= bram_h[cur_box];
                        x_min_out <= box_x_min[cur_box];
                        y_min_out <= box_y_min[cur_box];
                        
                        out_x <= 0; out_y <= 0; cycle_cnt <= 0;
                        src_x <= 0; src_y <= 0; row_start_addr <= 0;
                        acc_x <= CROP_WIDTH / 2; acc_y <= CROP_HEIGHT / 2;
                    end else begin
                        cur_box <= (cur_box == MAX_BOX_NUM - 1) ? 0 : cur_box + 1;
                    end
                end
                
                READING: begin
                    if (cycle_cnt == 0) begin
                        cycle_cnt <= cycle_cnt + 1; // 给一拍时间让 BRAM 地址稳定提取数据
                    end
                    else if (cycle_cnt == 1) begin
                        data_out   <= bram_rd_data[cur_box];
                        data_valid <= 1'b1;
                        if (out_x == 0) new_line_1 <= 1'b1;
                        cycle_cnt  <= cycle_cnt + 1;
                    end
                    else if (cycle_cnt == CYCLE_PERIOD - 1) begin
                        cycle_cnt <= 0;
                        if (out_x == CROP_WIDTH - 1) begin
                            state <= WAIT_GAP;
                            out_x <= 0;
                        end else begin
                            out_x <= out_x + 1;
                            if (acc_x + cur_w >= CROP_WIDTH) begin
                                acc_x <= acc_x + cur_w - CROP_WIDTH;
                                src_x <= src_x + 1;
                            end else begin
                                acc_x <= acc_x + cur_w;
                            end
                        end
                    end
                    else begin
                        cycle_cnt <= cycle_cnt + 1;
                    end
                end
                
                WAIT_GAP: begin
                    if (gap_cnt == LINE_GAP - 1) begin
                        gap_cnt <= 0;
                        if (out_y == CROP_HEIGHT - 1) begin
                            state <= RELEASE; 
                            release_sent <= 1'b0; // 初始化释放状态
                        end else begin
                            out_y <= out_y + 1;
                            state <= READING;
                            
                            out_x <= 0; src_x <= 0; acc_x <= CROP_WIDTH / 2;
                            if (acc_y + cur_h >= CROP_HEIGHT) begin
                                acc_y <= acc_y + cur_h - CROP_HEIGHT;
                                src_y <= src_y + 1;
                                row_start_addr <= row_start_addr + cur_w; 
                            end else begin
                                acc_y <= acc_y + cur_h;
                            end
                        end
                    end else begin
                        gap_cnt <= gap_cnt + 1;
                    end
                end
                
                RELEASE: begin
                    // [核心] 使用无懈可击的 Toggle Handshake
                    if (!release_sent) begin
                        // 1. 发送翻转电平
                        release_toggle_pe[cur_box] <= ~release_toggle_pe[cur_box];
                        release_sent <= 1'b1;
                    end else begin
                        // 2. 阻塞死等，直到视频域成功清除 Locked 信号！
                        if (!locked_sync2[cur_box]) begin
                            state <= IDLE;
                            cur_box <= (cur_box == MAX_BOX_NUM - 1) ? 0 : cur_box + 1;
                        end
                    end
                end
            endcase
        end
    end
    int ii;
    always_comb begin
        for (ii = 0; ii < MAX_BOX_NUM; ii++) begin
            if (ii == cur_box) bram_rd_addr[ii] = row_start_addr + src_x;
            else              bram_rd_addr[ii] = 12'd0;
        end
    end

endmodule