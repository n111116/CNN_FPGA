`timescale 1ns / 1ps

module tb_box_overlay();

    // 1. 参数定义 (为加速仿真缩小图像尺寸)
    parameter IMG_WIDTH = 100;
    parameter IMG_HEIGHT = 100;
    parameter GRID_STRIDE_CENTER = 16;
    parameter GRID_STRIDE_LTRB = 1;
    
    // 2. 时钟与复位
    logic clk_video = 0;
    logic clk_pe = 0;
    logic rst_n = 0;
    
    always #5 clk_video = ~clk_video; // 100MHz 视频时钟
    always #3 clk_pe    = ~clk_pe;    // ~167MHz PE时钟 (特意错开频率测试跨时钟域)
    
    // 3. DUT 信号
    logic video_vs_in = 0, video_hs_in = 0, video_de_in = 0;
    logic [23:0] video_rgb_in = 0;
    logic video_vs_out, video_hs_out, video_de_out;
    logic [23:0] video_rgb_out;
    
    logic box_wr_en = 0;
    logic [31:0] box_wr_data = 0;
    
    // 4. DUT 例化
    box_overlay_sync #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .GRID_STRIDE_CENTER(GRID_STRIDE_CENTER),
        .GRID_STRIDE_LTRB(GRID_STRIDE_LTRB),
        .CROP_HEIGHT(3),
        .CROP_WIDTH(7),
        .LINE_WIDTH(2), // 测试时线宽设小一点
        .MAX_BOX_NUM(10)
    ) dut (
        .clk_video(clk_video),
        .clk_pe(clk_pe),
        .rst_n(rst_n),
        .video_vs_in(video_vs_in),
        .video_hs_in(video_hs_in),
        .video_de_in(video_de_in),
        .video_rgb_in(video_rgb_in),
        .video_vs_out(video_vs_out),
        .video_hs_out(video_hs_out),
        .video_de_out(video_de_out),
        .video_rgb_out(video_rgb_out),
        .box_wr_en(box_wr_en),
        .box_wr_data(box_wr_data)
    );
    
    // 5. 测试激励
    initial begin
        // 复位
        #100 rst_n = 1;
        
        // 模拟 PE 写入一个检测框
        // 假设网格坐标 X=3, Y=3 (中心点约在 56, 56)
        // 边距: L=10, T=10, B=20, R=20
        #50;
        send_box_data(
            8'd0,   // cls = 0 (Blue)
            8'd3,   // x_idx
            8'd3,   // y_idx
            8'd99,  // conf
            9'd10,  // L
            9'd10,  // T
            9'd20,  // B
            9'd20   // R
        );
        #1000;
        send_box_data(
            8'd1,   // cls = 1 (green)
            8'd5,   // x_idx
            8'd5,   // y_idx
            8'd99,  // conf
            9'd6,  // L
            9'd6,  // T
            9'd6,  // B
            9'd6   // R
        );
        
        // 模拟生成一帧视频扫描
        #100;
        generate_video_frame();
        #1000;
        generate_video_frame();
        send_box_data(
            8'd1,   // cls = 1 (green)
            8'd5,   // x_idx
            8'd5,   // y_idx
            8'd99,  // conf
            9'd9,  // L
            9'd9,  // T
            9'd9,  // B
            9'd9   // R
        );
        #1000;
        generate_video_frame();
        
        #1000;
        generate_video_frame();
        
        #1000;
        generate_video_frame();
        
        #1000;
        generate_video_frame();
        
        #1000;
        generate_video_frame();
        
        #200 $display("Simulation Finished!");
        $finish;
    end
    
    // 发送一个 33-word 数据包的 Task
    task send_box_data(
        input [7:0] cls, input [7:0] x, input [7:0] y, input [7:0] conf,
        input [8:0] L, input [8:0] T, input [8:0] B, input [8:0] R
    );
    begin
        @(posedge clk_pe);
        box_wr_en <= 1;
        // Word 0: Header
        box_wr_data <= {cls, x, y, conf};
        @(posedge clk_pe);
        // Word 1: L
        box_wr_data <= {23'd0, L};
        @(posedge clk_pe);
        // Word 2: T
        box_wr_data <= {23'd0, T};
        @(posedge clk_pe);
        // Word 3: B
        box_wr_data <= {23'd0, B};
        @(posedge clk_pe);
        // Word 4: R
        box_wr_data <= {23'd0, R};
        @(posedge clk_pe);
        
        // Word 5~32: 28 个 Padding
        box_wr_data <= 32'd0;
        for (int i=0; i<28; i++) begin
            @(posedge clk_pe);
        end
        box_wr_en <= 0;
    end
    endtask

    // 模拟简易视频时序 Task
    task generate_video_frame();
    begin
        // 产生 VS 上升沿 (帧起始)
        @(posedge clk_video);
        video_vs_in <= 1;
        #100;
        video_vs_in <= 0;
        #50;
        
        for (int y = 0; y < IMG_HEIGHT; y++) begin
            // 行首消隐
            video_hs_in <= 1;
            #20 video_hs_in <= 0;
            #20;
            
            // 数据有效区
            video_de_in <= 1;
            for (int x = 0; x < IMG_WIDTH; x++) begin
                video_rgb_in <= {8'h33, x[7:0], y[7:0]};
                @(posedge clk_video);
            end
            video_de_in <= 0;
            #20;
        end
    end
    endtask

endmodule

// =========================================================
// 简易异步 FIFO 模型 (用于使 Testbench 闭环编译)
// 放到同一个文件里就行
// =========================================================
module fifo_adapter_to_hdmi (
    input  wire        rd_clk,
    input  wire        wr_clk,
    input  wire        rst,
    input  wire        wr_en,
    input  wire [31:0] din,
    input  wire        rd_en,
    output reg  [31:0] dout,
    output wire        full,
    output wire        empty
);
    // 简易 64 深度模拟 FIFO
    reg [31:0] mem [0:63];
    int wr_ptr = 0;
    int rd_ptr = 0;
    int count = 0;

    assign empty = (count == 0);
    assign full  = (count == 64);

    always @(posedge wr_clk) begin
        if (rst) begin
            wr_ptr <= 0;
        end else if (wr_en && !full) begin
            mem[wr_ptr % 64] <= din;
            wr_ptr <= wr_ptr + 1;
        end
    end

    always @(posedge rd_clk) begin
        if (rst) begin
            rd_ptr <= 0;
            dout <= 0;
        end else if (rd_en && !empty) begin
            dout <= mem[rd_ptr % 64];
            rd_ptr <= rd_ptr + 1;
        end
    end

    always @(*) begin
        count = wr_ptr - rd_ptr;
    end
endmodule