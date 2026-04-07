module input_layer #(
    parameter int unsigned DATA_WIDTH   = 7,
    parameter int unsigned PE_PAGE_NUM  = 3,
    parameter int unsigned PE_ROW_NUM   = 9,
    parameter int unsigned CYCLE_PERIOD_IN = 4,
    parameter int unsigned CYCLE_PERIOD_OUT = 4, 
    parameter int unsigned STEP_ROW = 2,
    parameter int unsigned STEP_COL = 2,
    parameter int unsigned KERNEL_ROW = 3,
    parameter int unsigned KERNEL_COL = 3,
    parameter int unsigned CYCLE_PERIOD = CYCLE_PERIOD_IN * CYCLE_PERIOD_OUT,
    parameter int unsigned IMG_COL      = 128,
    parameter int unsigned IMG_ROW      = 128
)(
    input  logic                     clk,
    input  logic                     clk_en,
    input  logic                     rst_n,
    
    input  logic                     new_line_input_1,  
    input  logic                     data_input_valid,
    input  logic [DATA_WIDTH-1:0]    data_input [PE_PAGE_NUM-1:0],
    
    output logic [DATA_WIDTH-1:0]    data_out [PE_ROW_NUM-1:0][PE_PAGE_NUM-1:0],
    output logic                     line_buf_full,
    output logic                     data_out_valid,
    output logic                     new_line_out_1
);

    // 每次读出STEP_ROW行，最少需要KENNEL - KERNEL_ROW/2行
    // KERNEL_ROW - KERNEL_ROW/2 - STEP_ROW > 0时，读出的值不能马上使用
    // 须屏蔽第前 KERNEL_ROW - KERNEL_ROW/2 - STEP_ROW行
    localparam INVALID_ROWS_START = KERNEL_ROW - KERNEL_ROW/2 - STEP_ROW;

    // =============================================================
    // 1. 数据打包
    // =============================================================
    localparam FIFO_WIDTH = DATA_WIDTH * PE_PAGE_NUM;
    logic [FIFO_WIDTH-1:0] flat_input;
    
    always_comb begin
        for (int i = 0; i < PE_PAGE_NUM; i++) begin
            flat_input[i*DATA_WIDTH +: DATA_WIDTH] = data_input[i];
        end
    end

    // =============================================================
    // 2. Ping-Pong 行缓存 (速率匹配逻辑) 
    // =============================================================
    localparam PP_DEPTH = IMG_COL * CYCLE_PERIOD_IN;
    logic [$clog2(PP_DEPTH)-1:0] pp_wr_cnt;
    logic [$clog2(PP_DEPTH)-1:0] pp_rd_cnt;
    logic [$clog2(CYCLE_PERIOD_OUT / STEP_COL)-1:0] pp_rd_cnt_cycle;
    logic [$clog2(STEP_ROW != 1 ? STEP_ROW : 2)-1:0] pp_wr_sel;    
    logic pp_rd_active; 
    
    logic [1:0] pending_rows; 
    logic we_line_ram [KERNEL_ROW-1:0] ;
    // 行读出有效与行读出信号
    logic line_out_valid;
    logic [FIFO_WIDTH-1:0] line_out[KERNEL_ROW-1:0];
    logic [FIFO_WIDTH-1:0] line_ram_out[KERNEL_ROW-1:0];

    localparam LB_DEPTH = IMG_COL*CYCLE_PERIOD_IN;
    logic [$clog2(LB_DEPTH)-1:0] lb_waddr;
    logic [$clog2(LB_DEPTH)-1:0] lb_raddr;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            line_out_valid <= 0;
        end else begin
            line_out_valid <= pp_rd_active; // 每读出一次，行数据即有效。
        end
    end

    generate
        // 前 KERNEL_ROW - STEP_ROW 行是普通的行缓存，写入来自上一行（间隔STEP_ROW）的输出
        for (genvar i = 0; i < KERNEL_ROW - STEP_ROW; i++) begin : gen_tops
            always_ff @(posedge clk)begin
                if(clk_en) begin
                    we_line_ram[i] <= pp_rd_active;
                end
            end
            assign line_out[i] = line_ram_out[i];
            sdp_ram #(.WIDTH(FIFO_WIDTH), .DEPTH(LB_DEPTH)) u_lb_ram (
                .clk(clk), .clk_en(clk_en), .we(we_line_ram[i]), .waddr(lb_waddr), .wdata(line_ram_out[i + STEP_ROW]), 
                .re(pp_rd_active), .raddr(lb_raddr), .q(line_ram_out[i])
            );
        end
        // 后 STEP_ROW 行是新的行缓存，写入来自输入数据，并且写入地址由 pp_wr_sel 和 pp_wr_cnt 共同控制
        for (genvar i = KERNEL_ROW - STEP_ROW; i < KERNEL_ROW; i++) begin : gen_bottoms

            assign we_line_ram[i] = data_input_valid && (i == pp_wr_sel + KERNEL_ROW - STEP_ROW) && (~line_buf_full);
            // always_ff @(posedge clk)begin
            //     if(clk_en) begin
            //         // BRAM 用作流水线缓存时，输出会多一级延迟。在非流水线缓存加一级寄存器以保持时序一致
            //         line_out[i] <= line_ram_out[i];
            //     end
            // end
            assign line_out[i] = line_ram_out[i];
            sdp_ram #(.WIDTH(FIFO_WIDTH), .DEPTH(PP_DEPTH)) u_pp_ram (
                .clk(clk), .clk_en(clk_en), .we(we_line_ram[i]), .waddr(pp_wr_cnt), .wdata(flat_input), 
                .re(pp_rd_active), .raddr(pp_rd_cnt), .q(line_ram_out[i])
            );

        end
    endgenerate

    logic row_written_flag;            // 写入地址达到最后一行的开头时，开始读取
    logic row_read_flag;                // 读取地址达到最后一个地址，读取完成
    
    always_comb begin
        row_written_flag = (pp_wr_cnt == 0) && data_input_valid && (pp_wr_sel == STEP_ROW - 1);
        row_read_flag    = pp_rd_active && (pp_rd_cnt == PP_DEPTH - 1);
    end

    assign pp_rd_active = (pending_rows > 0) && (pp_rd_cnt_cycle == 0);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pp_wr_cnt    <= 0;
            pp_rd_cnt    <= 0;
            pp_wr_sel    <= STEP_ROW - 1;   // 第一个new_line_input_1到来后，pp_wr_sel会变为0
            pending_rows <= 0;
            line_buf_full <= 0;
            pp_rd_cnt_cycle <= 1;   // 预设为1，保证每行开头时不会立即读取
        end else if (clk_en) begin
            // Write Logic
            if(new_line_input_1) begin
                pp_wr_cnt <= 0;
                line_buf_full <= 0;
                if (pp_wr_sel < STEP_ROW - 1) begin
                    pp_wr_sel <= pp_wr_sel + 1;
                end else begin
                    pp_wr_sel <= 0;
                end
            end
            else if (data_input_valid) begin
                if (pp_wr_cnt < PP_DEPTH - 1) begin
                    pp_wr_cnt <= pp_wr_cnt + 1;
                end
                else begin
                    line_buf_full <= 1;
                end
            end
            // Read Logic
            if(pp_rd_cnt_cycle == CYCLE_PERIOD_OUT / STEP_COL - 1) begin
                pp_rd_cnt_cycle <= 0;
            end else begin
                pp_rd_cnt_cycle <= pp_rd_cnt_cycle + 1;
            end
            if (pp_rd_active) begin
                if (pp_rd_cnt == PP_DEPTH - 1) begin
                    pp_rd_cnt <= 0;
                end else begin
                    pp_rd_cnt <= pp_rd_cnt + 1;
                end
            end
            // Pending Rows Logic
            case ({row_written_flag, row_read_flag})
                2'b10: pending_rows <= pending_rows + 1; 
                2'b01: pending_rows <= pending_rows - 1; 
                default: pending_rows <= pending_rows;   
            endcase
        end
    end

    logic pixel_valid, stream_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lb_waddr <= 0;
            lb_raddr <= 0;
        end
        else if (clk_en) begin
            if(pp_rd_active) begin
                if (lb_raddr == LB_DEPTH - 1) 
                    lb_raddr <= 0;
                else 
                    lb_raddr <= lb_raddr + 1;
            end
            lb_waddr <= lb_raddr;  // 写地址慢一拍，与写使能、写数据同步
        end
    end

    // =============================================================
    // 3. Index x, Index y & New Line Logic
    // =============================================================
    logic [$clog2(CYCLE_PERIOD_IN+1)-1:0] index_in;
    (* mark_debug = "true" *) logic [$clog2(IMG_COL)-1:0] index_x;
    (* mark_debug = "true" *) logic [$clog2(IMG_ROW)-1:0] index_y;
    logic [$clog2(INVALID_ROWS_START):0]invalid_rows;

    // Index in
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            index_in <= 0;
        end else if (clk_en && stream_valid) begin
            if (index_in >= CYCLE_PERIOD_IN - 1) index_in <= 0;
            else index_in <= index_in + 1;
        end
    end
    // Index X
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            index_x <= 0;
        end else if (clk_en && stream_valid) begin
            if (index_in == CYCLE_PERIOD_IN - 1) begin
                if (index_x >= IMG_COL - STEP_COL) index_x <= 0;
                else index_x <= index_x + STEP_COL;
            end
        end
    end

    // Index Y
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            index_y <= 0; 
        end else if (clk_en && stream_valid && (invalid_rows == 0)) begin
            if (index_x >= IMG_COL - STEP_COL && index_in == CYCLE_PERIOD_IN - 1) begin
                if (index_y >= IMG_ROW - STEP_ROW) index_y <= 0;
                else index_y <= index_y + STEP_ROW;
            end
        end
    end
    

    // Insufficient Row Flag Logic 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 
            if(INVALID_ROWS_START > 0) begin         
                invalid_rows <= INVALID_ROWS_START;
            end else begin
                invalid_rows <= 0;
            end
        end else if (clk_en) begin
            if(stream_valid && (index_x == IMG_COL - STEP_COL) && (index_in == CYCLE_PERIOD_IN - 1)) begin
                if (invalid_rows != 0) begin
                    invalid_rows <= invalid_rows - STEP_ROW; 
                end
            end
        end
    end
    // =============================================================
    // 4. [修改] 列（像素）缓存流水线 (对称于行缓存结构)
    // =============================================================
    localparam PIXEL_PP_DEPTH = CYCLE_PERIOD_IN;
    // 使用条件位宽避免STEP_COL为1时出现负数范围导致语法错误
    logic [$clog2(PIXEL_PP_DEPTH > 1 ? PIXEL_PP_DEPTH : 2)-1:0] pixel_pp_wr_cnt;
    logic [$clog2(PIXEL_PP_DEPTH > 1 ? PIXEL_PP_DEPTH : 2)-1:0] pixel_pp_rd_cnt;
    logic [$clog2(CYCLE_PERIOD_OUT > 1 ? CYCLE_PERIOD_OUT : 2)-1:0] pixel_pp_rd_cnt_cycle;
    logic [$clog2(STEP_COL > 1 ? STEP_COL : 2)-1:0] pixel_pp_wr_sel;
    logic pixel_pp_rd_active;
    logic [1:0] pending_pixels;
    
    logic we_pixel_ram [KERNEL_COL-1:0];
    logic re_pixel_ram [KERNEL_COL-1:0];
    logic [FIFO_WIDTH-1:0] pixel_ram_out [KERNEL_ROW-1:0][KERNEL_COL-1:0];
    logic [FIFO_WIDTH-1:0] pixel_out [KERNEL_ROW-1:0] [KERNEL_COL-1:0];
    localparam PIXEL_LB_DEPTH = CYCLE_PERIOD_IN;
    logic [$clog2(PIXEL_LB_DEPTH>1 ? PIXEL_LB_DEPTH : 2)-1:0] pixel_lb_waddr;
    logic [$clog2(PIXEL_LB_DEPTH>1 ? PIXEL_LB_DEPTH : 2)-1:0] pixel_lb_raddr;

    // 由移位寄存器来控制输出的有效，并补充BRAM移位寄存器的读写（即移位操作）。
    // 移位寄存器的长度由KERNEL_COL、STEP_COL和 CYCLE_PERIOD 共同决定。
    // STEP_COL-1 是第一个 pixel_out 输出的像素距右边缘的距离
    // KERNEL_COL/2 是卷积核中心距右边缘的距离
    // 二者相等时，卷积核的中心坐标就是有效图像的起始坐标
    // 不相等时则需要通过移位寄存器进行匹配
    localparam KERNEL_DELAY_LENGTH = (KERNEL_COL/2 - (STEP_COL - 1)) * CYCLE_PERIOD;
    logic [KERNEL_DELAY_LENGTH-1:0] pixel_pp_rd_active_shift_reg;
    
    // stream_valid 逻辑
    generate
        if(KERNEL_DELAY_LENGTH >= 1) begin
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    pixel_pp_rd_active_shift_reg <= 0;
                    stream_valid <= 0;
                end else if (clk_en) begin
                    if (KERNEL_DELAY_LENGTH == 1) begin
                        pixel_pp_rd_active_shift_reg[0] <= pixel_pp_rd_active;
                    end else begin
                        pixel_pp_rd_active_shift_reg <= {pixel_pp_rd_active_shift_reg[KERNEL_DELAY_LENGTH-2:0], pixel_pp_rd_active};
                    end
                    stream_valid <= pixel_pp_rd_active_shift_reg[KERNEL_DELAY_LENGTH-1];
                end
            end
        end else begin
            assign pixel_pp_rd_active_shift_reg = pixel_pp_rd_active;
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    stream_valid <= 0;
                end else if (clk_en) begin
                    stream_valid <= pixel_pp_rd_active;
                end
            end
        end
    endgenerate
    
    generate
        // =====================================================================
        // 1. 独立生成列控制信号 we_pixel_ram (只与列 c 有关，全局生成一次即可)
        // =====================================================================
        for (genvar c = 0; c < KERNEL_COL - STEP_COL; c++) begin : gen_we_left
            assign we_pixel_ram[c] = pixel_valid;
            if(KERNEL_DELAY_LENGTH >= 1) begin
                assign re_pixel_ram[c] = pixel_pp_rd_active_shift_reg[KERNEL_DELAY_LENGTH-1];
            end else begin
                assign re_pixel_ram[c] = pixel_pp_rd_active;
            end
        end
        for (genvar c = KERNEL_COL - STEP_COL; c < KERNEL_COL; c++) begin : gen_we_right

            assign we_pixel_ram[c] = line_out_valid && (c == pixel_pp_wr_sel + KERNEL_COL - STEP_COL);
            assign re_pixel_ram[c] = pixel_pp_rd_active;
        end
        // =====================================================================
        // 2. 例化二维的像素缓存 RAM 和数据打拍逻辑 (与行 r 和列 c 均有关)
        // =====================================================================
        for (genvar r = 0; r < KERNEL_ROW; r++) begin : gen_pixel_row
            // 前 KERNEL_COL - STEP_COL 列：普通的列缓存或移位寄存器
            for (genvar c = 0; c < KERNEL_COL - STEP_COL; c++) begin : gen_pixel_left
                if(PIXEL_LB_DEPTH >= 1) begin
                    sdp_ram #(.WIDTH(FIFO_WIDTH), .DEPTH(PIXEL_LB_DEPTH)) u_pixel_lb_ram (
                        .clk(clk), .clk_en(clk_en), 
                        .we(we_pixel_ram[c]), .waddr(pixel_lb_waddr), .wdata(pixel_ram_out[r][c + STEP_COL]), 
                        .re(re_pixel_ram[c]), .raddr(pixel_lb_raddr), .q(pixel_ram_out[r][c])
                    );
                end else begin
                    // 当像素行缓存深度为0时，直接用寄存器替代RAM
                    always_ff @(posedge clk) begin
                        if(clk_en) begin
                            if(pixel_pp_rd_active) begin
                                pixel_ram_out[r][c] <= pixel_ram_out[r][c + STEP_COL];
                            end
                        end
                    end
                end
                // BRAM 用作流水线缓存时，输出会多一级延迟。在非流水线缓存加一级寄存器以保持时序一致
                assign pixel_out[r][c] = pixel_ram_out[r][c];
            end
            
            // 后 STEP_COL 列：新的列缓存
            for (genvar c = KERNEL_COL - STEP_COL; c < KERNEL_COL; c++) begin : gen_pixel_right
            
                assign pixel_out[r][c] = pixel_ram_out[r][c];
                sdp_ram #(.WIDTH(FIFO_WIDTH), .DEPTH(PIXEL_PP_DEPTH)) u_pixel_pp_ram (
                    .clk(clk), .clk_en(clk_en), 
                    .we(we_pixel_ram[c]), .waddr(pixel_pp_wr_cnt), .wdata(line_out[r]), 
                    .re(pixel_pp_rd_active), .raddr(pixel_pp_rd_cnt), .q(pixel_ram_out[r][c])
                );
            end
        end
    endgenerate

    logic pixel_col_written_flag;
    logic pixel_col_read_flag;

    always_comb begin
        pixel_col_written_flag <= (pixel_pp_wr_cnt == 0) && line_out_valid && (pixel_pp_wr_sel == STEP_COL - 1);
        pixel_col_read_flag    <= pixel_pp_rd_active && (pixel_pp_rd_cnt == PIXEL_PP_DEPTH - 1);
    end 
    // 列（像素）缓存控制逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_pp_wr_cnt       <= 0;
            pixel_pp_rd_cnt       <= 0;
            pixel_pp_wr_sel       <= 0;
            pending_pixels        <= 0;
            pixel_pp_rd_cnt_cycle  <= 0;
            pixel_pp_rd_active    <= 0;
        end else if (clk_en) begin
            // 与数据完全同步的有效信号。
            pixel_valid <= pixel_pp_rd_active;
            // STEP_COL为1时，行输出的数据可以立即读取；否则需要用 pending 等逻辑判断
            if(STEP_COL == 1) begin
                pixel_pp_rd_active <= line_out_valid;
            end else begin
                if (line_out_valid) begin
                    if (pixel_pp_wr_cnt < PIXEL_PP_DEPTH - 1) begin
                        pixel_pp_wr_cnt <= pixel_pp_wr_cnt + 1;
                    end else begin
                        pixel_pp_wr_cnt <= 0;
                        // 写满后切换
                        if (pixel_pp_wr_sel < (STEP_COL * CYCLE_PERIOD_IN - 1)) begin
                            pixel_pp_wr_sel <= pixel_pp_wr_sel + 1;
                        end else begin
                            pixel_pp_wr_sel <= 0;
                        end
                    end
                end

                // 读取逻辑控制
                // 每 STEP_COL 个 line_out_valid 读取一次
                // **重要：第一个有效的 line_out_valid 与 pixel_col_written_flag 同步
                if(pixel_col_written_flag) begin
                    pixel_pp_rd_active <= 1;
                    pixel_pp_rd_cnt_cycle <= 1;
                end else begin
                    pixel_pp_rd_active <= (pending_pixels > 0) && (pixel_pp_rd_cnt_cycle == 0);
                    if (pixel_pp_rd_cnt_cycle == CYCLE_PERIOD_OUT - 1) begin
                        pixel_pp_rd_cnt_cycle <= 0;
                    end else begin
                        pixel_pp_rd_cnt_cycle <= pixel_pp_rd_cnt_cycle + 1;
                    end
                end

                // Pending Pixels Logic
                case ({pixel_col_written_flag, pixel_col_read_flag})
                    2'b10: pending_pixels <= pending_pixels + 1;
                    2'b01: pending_pixels <= pending_pixels - 1;
                    default: pending_pixels <= pending_pixels;
                endcase

                if (pixel_pp_rd_active) begin
                    if (pixel_pp_rd_cnt == PIXEL_PP_DEPTH - 1) begin
                        pixel_pp_rd_cnt <= 0;
                    end else begin
                        pixel_pp_rd_cnt <= pixel_pp_rd_cnt + 1;
                    end
                end
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_lb_waddr <= 0;
            pixel_lb_raddr <= 0;
        end else if (clk_en) begin
            // 若有非pp形式的 pixel_buffer ，则re_pixel_ram[0]一定这类 pixel_buffer 的读使能信号。
            if (we_pixel_ram[0]) begin
                if (pixel_lb_waddr == PIXEL_LB_DEPTH - 1) 
                    pixel_lb_waddr <= 0;
                else 
                    pixel_lb_waddr <= pixel_lb_waddr + 1;
            end
            if (re_pixel_ram[0]) begin
                if (pixel_lb_raddr == PIXEL_LB_DEPTH - 1) 
                    pixel_lb_raddr <= 0;
                else 
                    pixel_lb_raddr <= pixel_lb_raddr + 1;
            end
        end
    end

    // =============================================================
    // 5. 组装输出
    // =============================================================
    genvar idx_page, idx_pe;
    generate
        for (idx_page = 0; idx_page < PE_PAGE_NUM; idx_page++) begin : gen_pages
            for(idx_pe = 0; idx_pe < PE_ROW_NUM; idx_pe++) begin : gen_pe_rows
                always_ff @(posedge clk) begin
                    if(clk_en && stream_valid) begin
                        int idx_row_kernel, idx_col_kernel, idx_row_img, idx_col_img;
                        // 计算当前输出像素在卷积窗口中的位置    
                        idx_row_kernel = idx_pe / KERNEL_COL;
                        idx_col_kernel = idx_pe % KERNEL_COL;
                        
                        // 计算当前输出像素对应的输入图像行索引，用于判断是否需要进行 Padding
                        idx_row_img = index_y + idx_row_kernel - (KERNEL_ROW / 2);
                        idx_col_img = index_x + idx_col_kernel - (KERNEL_COL / 2);

                        if(idx_row_img < 0 || idx_row_img >= IMG_ROW || idx_col_img < 0 || idx_col_img >= IMG_COL) begin
                            data_out[idx_pe][idx_page] <= {DATA_WIDTH{1'b0}}; // Padding with zeros
                        end else begin
                            data_out[idx_pe][idx_page] <= pixel_out[idx_row_kernel][idx_col_kernel]
                                                                    [idx_page*DATA_WIDTH +: DATA_WIDTH];
                        end
                    end
                end
            end
        end
    endgenerate



    // 输出流水线 (延迟 2 周期 + Mask First Row)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out_valid <= 0;
            new_line_out_1 <= 0;
        end else if (clk_en) begin
            if (invalid_rows != 0) begin
                data_out_valid <= 0;
                new_line_out_1 <= 0;
            end else begin
                data_out_valid <= stream_valid;
                // CYCLE_PERIOD_OUT 为 1 的特殊情况， new_line_out_1可能会维持两周期，这里强制变为1周期
                if(CYCLE_PERIOD_OUT == 1 && new_line_out_1 == 1) begin
                    new_line_out_1 <= 0;
                end else if(KERNEL_DELAY_LENGTH >= 1) begin
                    new_line_out_1 <= pixel_pp_rd_active_shift_reg[KERNEL_DELAY_LENGTH-1] && (index_x == 0) && (index_in == 0);
                end else begin
                    new_line_out_1 <= pixel_pp_rd_active && (index_x == 0) && (index_in == 0);
                end
            end
        end
    end


endmodule