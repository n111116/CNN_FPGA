// 适配器模块：完成 32位数据解析、串并转换（3个通道）
// [新增功能] 完成 PE 结果数据的打包 (4x8bit -> 32bit) 并发送给 USB 上行 FIFO
module layer_data_adapter #(
    parameter int DATA_WIDTH     = 8, // 通常为8bit，如果是7bit会自动截断
    parameter int CHANNEL_IN     = 3, // 对应输入通道数 3
    
    // [新增参数] 用于上行数据控制
    parameter int CYCLE_PERIOD_OUT  = 4,
    parameter int OUT_WIDTH_POST_33 = 8,
    parameter int OUT_WIDTH_LAYER23 = 8
) (
    input  logic                     clk,
    input  logic                     rst_n,
    
    // USB 控制接口 (下行)
    input  logic [31:0]              usb_fifo_data,  
    input  logic                     usb_fifo_empty, 
    output logic                     usb_rd_en,      
    output logic                     new_line_1,
    
    // USB 控制接口 (上行) [新增]
    output logic                     usb_wr_en,
    output logic [31:0]              usb_wr_data,
    
    // PE 接口 (给 PE 的输入)
    output logic [DATA_WIDTH-1:0]    pe_parallel_data [CHANNEL_IN-1:0], 
    output logic                     input_valid,

    // PE 接口 (来自 PE 的输出结果) [新增]
    input  logic [OUT_WIDTH_POST_33-1:0]        packet_data,
    input  logic                                packet_valid,
    input  logic                                frame_done,
    input  logic [OUT_WIDTH_LAYER23-1:0]        layer23_data,
    input  logic                                layer23_valid
);

    logic [$clog2(CYCLE_PERIOD_OUT) - 1:0] cycle_cnt;           // 4周期计数器
    logic       data_latch_valid;    // 用于标记 Cycle 0 是否成功发起了读请求
    logic [10:0] new_line_delay_cnt;  // 用于控制 new_line 的延迟输出

    // ============================================================
    // 1. 周期计数器 (0 -> 1 -> 2 -> 3)
    // ============================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_cnt <= 2'd0;
        end 
        else if(cycle_cnt < CYCLE_PERIOD_OUT - 1) begin
            cycle_cnt <= cycle_cnt + 1'b1;
        end
        else begin
            cycle_cnt <= 1'b0;
        end
    end

    // ============================================================
    // 2. 读取控制 (仅在 Cycle 0 发起读取)
    // ============================================================
    // 组合逻辑产生读使能，确保在时钟沿到来时被 FIFO 采样
    assign usb_rd_en = (new_line_delay_cnt == 0) && (cycle_cnt == 2'd0) && (!usb_fifo_empty);

    // ============================================================
    // 3. 数据解析与输出逻辑
    // ============================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            input_valid      <= 1'b0;
            new_line_1       <= 1'b0;
            data_latch_valid <= 1'b0;
            new_line_delay_cnt <= 4'd0;
            for (int i = 0; i < CHANNEL_IN; i++) pe_parallel_data[i] <= '0;
        end else begin
            // 默认拉低脉冲信号
            input_valid <= 1'b0;
            new_line_1  <= (new_line_delay_cnt == 10'd1);
            data_latch_valid <= usb_rd_en; 

            // -----------------------------------------------------
            // New Line 延迟计数逻辑
            // -----------------------------------------------------
            // 如果计数器正在倒数
            if (new_line_delay_cnt > 0) begin
                new_line_delay_cnt <= new_line_delay_cnt - 1'b1;
            end

            // -----------------------------------------------------
            // Cycle 1: 数据到达 (假设 FIFO Read Latency = 1 cycle)
            // -----------------------------------------------------
            if (data_latch_valid) begin
                
                // 情况 A: 帧头/新行 (High 8 bits == FF)
                // 每当读取到新行时，经过一定延迟再进行下一步
                if (usb_fifo_data[31:24] == 8'hFF) begin
                    new_line_delay_cnt <= 10'd100; 
                    // 忽略后 24 位数据
                end 
                
                // 情况 B: 有效数据 (High 8 bits == 00)
                //  if (usb_fifo_data[31:24] == 8'h00)
                else begin
                    for(int ch = 0; ch < CHANNEL_IN; ch++) begin
                        pe_parallel_data[ch] = usb_fifo_data[ch * 8 +: 8];
                    end

                    // 在"读取到数据的下一周期" (即 Cycle 2) 拉高 input_valid
                    input_valid <= 1'b1; 
                end
            end
        end
    end

    // ============================================================
    // 4. [新增] 上行数据写入逻辑 (仿照 TB)
    // ============================================================
    
    // 最大写入次数 = 1（packet_data）+ 4（layer8输出）
    localparam int MAX_WRITES_PER_PIXEL = 5;
    logic [7:0] write_cnt;
    (* mark_debug = "true"*)logic write_enable;

    logic [OUT_WIDTH_LAYER23-1:0]        layer23_data_pipe[35:0];
    logic                                layer23_valid_pipe[35:0];
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            layer23_data_pipe <= '{default: '0};
            layer23_valid_pipe <= '{default: 1'b0};
        end else begin
            layer23_data_pipe[0] <= layer23_data;
            layer23_valid_pipe[0] <= layer23_valid;
            
            for (int i = 1; i <= 35; i++) begin
                layer23_data_pipe[i] <= layer23_data_pipe[i-1];
                layer23_valid_pipe[i] <= layer23_valid_pipe[i-1];
            end
        end
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_cnt    <= 0;
            write_enable <= 0;
            usb_wr_en    <= 0;
            usb_wr_data  <= 0;
        end else begin
            // 默认拉低写使能
            usb_wr_en <= 0;
            
            // 1. 启动/重置条件：当 packet_valid 有效时
            if (packet_valid) begin
                write_enable <= 1;  // 开启写入
                write_cnt    <= 1;  // 重置计数器，因为此时要写入packet的数据，所以已写入一个
                usb_wr_data <= packet_data;
                usb_wr_en   <= 1; // 触发 USB 写
            end
            // 2. 写入条件：使能开启 且 输出有效
            else if (write_enable) begin
                if (layer23_valid_pipe[35]) begin
                    usb_wr_data <= layer23_data_pipe[35];
                    write_cnt <= write_cnt + 1;
                    usb_wr_en <= 1;
                    if(write_cnt == MAX_WRITES_PER_PIXEL-1) begin
                        write_enable <= 0;
                    end
                end
            end
        end
    end

endmodule