`timescale 1ns / 1ps

module tb_box_overlay_crop_buffer_manager();

    // =========================================================
    // 1. 参数定义 (为加速仿真，缩小图像与裁剪尺寸)
    // =========================================================
    parameter IMG_WIDTH  = 256;
    parameter IMG_HEIGHT = 256;
    parameter GRID_STRIDE_CENTER = 16;
    parameter GRID_STRIDE_LTRB   = 1;
    parameter MAX_BOX_NUM = 10;
    
    parameter CROP_WIDTH  = 40;
    parameter CROP_HEIGHT = 10;

    // =========================================================
    // 2. 时钟与复位生成
    // =========================================================
    logic clk_video = 0;
    logic clk_pe    = 0;
    logic rst_n     = 0;
    
    always #5 clk_video = ~clk_video;  // 100MHz 视频时钟
    always #3 clk_pe    = ~clk_pe;     // ~166MHz PE时钟
    
    // =========================================================
    // 3. DUT 互联信号定义
    // =========================================================
    // 视频主链路
    logic        video_vs_in = 0, video_hs_in = 0, video_de_in = 0;
    logic [23:0] video_rgb_in = 0;
    logic        video_vs_out, video_hs_out, video_de_out;
    logic [23:0] video_rgb_out;
    logic [23:0] input_image_mem [0:IMG_WIDTH*IMG_HEIGHT-1];

    // CNN 写框链路
    logic        box_wr_en = 0;
    logic [31:0] box_wr_data = 0;
    
    // 内部 Crop 数据链路 (Overlay -> Manager)
    logic        crop_wr_en    [0:MAX_BOX_NUM-1];
    logic        start_crop_wr [0:MAX_BOX_NUM-1];
    logic        end_crop_wr   [0:MAX_BOX_NUM-1];
    logic [15:0] crop_x_min    [0:MAX_BOX_NUM-1];  // [新增] 连接引脚
    logic [15:0] crop_y_min    [0:MAX_BOX_NUM-1];  // [新增] 连接引脚
    logic [15:0] crop_w0       [0:MAX_BOX_NUM-1];  // [新增] 连接引脚
    logic [15:0] crop_h0       [0:MAX_BOX_NUM-1];  // [新增] 连接引脚
    logic [23:0] crop_rgb_out  [0:MAX_BOX_NUM-1];

    // Manager 输出到 PE 的链路
    logic        new_line_1;
    logic        data_valid;
    logic [23:0] data_out;
    logic [15:0] x_min_out;   // [新增] 输出坐标
    logic [15:0] y_min_out;   // [新增] 输出坐标

    // =========================================================
    // 4. DUT 例化
    // =========================================================
    box_overlay_sync #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .GRID_STRIDE_CENTER(GRID_STRIDE_CENTER),
        .GRID_STRIDE_LTRB(GRID_STRIDE_LTRB),
        .CROP_WIDTH(CROP_WIDTH),
        .CROP_HEIGHT(CROP_HEIGHT),
        .LINE_WIDTH(1), 
        .MAX_BOX_NUM(MAX_BOX_NUM)
    ) u_overlay (
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
        .box_wr_data(box_wr_data),
        
        .start_crop_wr(start_crop_wr),
        .end_crop_wr(end_crop_wr),
        .crop_x_min(crop_x_min),     // [新增]
        .crop_y_min(crop_y_min),     // [新增]
        // .crop_w0(crop_w0),     // [新增]
        // .crop_h0(crop_h0),     // [新增]
        .crop_wr_en(crop_wr_en),
        .crop_rgb_out(crop_rgb_out)
    );

    crop_buffer_manager #(
        .MAX_BOX_NUM(MAX_BOX_NUM),
        .CROP_WIDTH(CROP_WIDTH),
        .CROP_HEIGHT(CROP_HEIGHT),
        .CYCLE_PERIOD(4)
    ) u_crop_manager (
        .clk_video(clk_video),
        .rst_n(rst_n),
        
        .start_crop_wr(start_crop_wr),
        .end_crop_wr(end_crop_wr),
        .x_min_in(crop_x_min),       // [新增]
        .y_min_in(crop_y_min),       // [新增]
        .crop_wr_en(crop_wr_en),
        .crop_rgb_out(crop_rgb_out),
        // .crop_w0(crop_w0),     // [新增]
        // .crop_h0(crop_h0),     // [新增]
        
        .clk_pe(clk_pe),
        .x_min_out(x_min_out),       // [新增]
        .y_min_out(y_min_out),       // [新增]
        .new_line_1(new_line_1),
        .data_valid(data_valid),
        .data_out(data_out)
    );

    // =========================================================
    // 5. 仿真测试流程
    // =========================================================
    initial begin
        $display("=================================================");
        $display("   Starting Simulation...");
        $display("=================================================");
        $readmemh("input_image.hex", input_image_mem);
        
        #100 rst_n = 1;
        #100;
        
        for (int frame = 0; frame < 6; frame++) begin
            $display("[%0t] Starting Frame %0d", $time, frame);
            generate_video_frame(frame);
        end
        
        #2000 $display("Simulation Finished Successfully!");
        $finish;
    end
    
    // =========================================================
    // 6. 抓取 OSD 视频流输出并保存为 PPM 图片
    // =========================================================
    int fd_video = 0;
    int current_video_frame = 0;
    logic video_vs_out_d;

    always_ff @(posedge clk_video) begin
        if (rst_n) begin
            video_vs_out_d <= video_vs_out;
            if (video_vs_out && !video_vs_out_d) begin
                automatic string filename;
                if (fd_video != 0) $fclose(fd_video);
                
                $sformat(filename, "sim_out/video_out_frame_%0d.ppm", current_video_frame);
                fd_video = $fopen(filename, "w");
                
                $fdisplay(fd_video, "P3");
                $fdisplay(fd_video, "%0d %0d", IMG_WIDTH, IMG_HEIGHT);
                $fdisplay(fd_video, "255");
                
                current_video_frame++;
            end
            
            if (video_de_out && fd_video != 0) begin
                int r, g, b;
                r = video_rgb_out[23:16];
                g = video_rgb_out[15:8];
                b = video_rgb_out[7:0];
                $fdisplay(fd_video, "%0d %0d %0d", r, g, b);
            end
        end
    end

    // =========================================================
    // 7. 抓取 PE 端子图输出并保存为 PPM 图片
    // =========================================================
    int fd_crop = 0;
    int current_crop_box = 0;
    int pixel_cnt = 0;
    
    logic vs_pe_d1 = 0;
    logic vs_pe_d2 = 0;

    always_ff @(posedge clk_pe) begin
        if (!rst_n) begin
            vs_pe_d1 <= 0;
            vs_pe_d2 <= 0;
        end else begin
            vs_pe_d1 <= video_vs_in;
            vs_pe_d2 <= vs_pe_d1;

            // 利用 new_line_1 的第一个有效周期来创建新文件
            // [新增] 将 x_min_out 和 y_min_out 格式化进文件名
            if (new_line_1 && pixel_cnt == 0) begin
                automatic string filename;
                if (fd_crop != 0) $fclose(fd_crop);
                
                // 文件名格式形如：crop_out_box_1_x24_y40.ppm
                $sformat(filename, "sim_out/crop_out_box_%0d_x%0d_y%0d.ppm", current_crop_box, x_min_out, y_min_out);
                fd_crop = $fopen(filename, "w");
                
                $fdisplay(fd_crop, "P3");
                $fdisplay(fd_crop, "%0d %0d", CROP_WIDTH, CROP_HEIGHT);
                $fdisplay(fd_crop, "255");
            end
            
            if (data_valid) begin
                int cr, cg, cb;
                cr = data_out[23:16];
                cg = data_out[15:8];
                cb = data_out[7:0];
                $fdisplay(fd_crop, "%0d %0d %0d", cr, cg, cb);
                
                pixel_cnt++;
                if (pixel_cnt == CROP_WIDTH * CROP_HEIGHT) begin
                    $fclose(fd_crop);
                    fd_crop = 0;
                    pixel_cnt = 0;
                    current_crop_box++;
                end
            end
        end
    end

    // =========================================================
    // Task: 注入包数据 (耗时 33 clk_pe 周期)
    // =========================================================
    task send_box_data(
        input [7:0] cls, input [7:0] x, input [7:0] y, input [7:0] conf,
        input [8:0] L, input [8:0] T, input [8:0] R, input [8:0] B
    );
    begin
        @(posedge clk_pe);
        box_wr_en <= 1;
        
        box_wr_data <= {cls, x, y, conf};
        @(posedge clk_pe);
        box_wr_data <= {23'd0, L};
        @(posedge clk_pe);
        box_wr_data <= {23'd0, T};
        @(posedge clk_pe);
        box_wr_data <= {23'd0, R};
        @(posedge clk_pe);
        box_wr_data <= {23'd0, B};
        @(posedge clk_pe);
        
        box_wr_en <= 0;
        $display("[%0t] -> Box Injected (cls=%0d, x=%0d, y=%0d, L=%0d, T=%0d, R=%0d, B=%0d)", 
                 $time, cls, x, y, L, T, R, B);
    end
    endtask

    // =========================================================
    // Task: 生成多帧视频
    // =========================================================
    task generate_video_frame(input int frame_no);
    begin
        @(posedge clk_video);
        video_vs_in <= 1;
        #200;
        video_vs_in <= 0;
        #100;
        
        for (int y = 0; y < IMG_HEIGHT; y++) begin
            if (frame_no == 0) begin
                // Frame 0: 空帧
            end
            else if (frame_no == 1) begin
                if (y == 100)  fork send_box_data(1, 1, 1, 99, 1, 1, 1, 1); join_none 
                if (y == 101) fork send_box_data(2, 13, 4, 90, 15, 15, 15, 15); join_none
                if (y == 102) fork send_box_data(3, 6, 7, 85, 10,  8, 10, 10); join_none
            end
            else if (frame_no == 2) begin
                if (y == 100) fork send_box_data(4, 2, 2, 95, 12, 12, 12, 12); join_none 
                if (y == 101) fork send_box_data(1, 12, 5, 88, 10,  5, 20, 10); join_none 
            end
            else if (frame_no == 3) begin
                if (y == 100) fork send_box_data(1, 1, 1, 99, 10, 10, 10, 10); join_none 
                if (y == 101) fork send_box_data(2, 2, 2, 99, 10, 10, 10, 10); join_none 
                if (y == 102) fork send_box_data(3, 3, 3, 99, 10, 10, 10, 10); join_none 
                if (y == 103) fork send_box_data(4, 6, 6, 99, 10, 10, 10, 10); join_none 
            end
            else if (frame_no == 4) begin
                if (y == 100)  fork send_box_data(1, 1, 1, 99, 10, 10, 10, 10); join_none 
                if (y == 101)  fork send_box_data(2, 2, 2, 99, 10, 10, 10, 10); join_none 
                if (y == 102)  fork send_box_data(3, 3, 3, 99, 25, 10, 25, 10); join_none 
                if (y == 103) fork send_box_data(1, 3, 12, 99, 10, 10, 10, 10); join_none 
                if (y == 104) fork send_box_data(2, 4, 12, 99, 30, 10, 30, 10); join_none 
                if (y == 105) fork send_box_data(3, 5, 12, 99, 25, 10, 25, 10); join_none 
            end

            @(negedge clk_video);
            video_hs_in = 1; 
            repeat(4) @(negedge clk_video);
            video_hs_in = 0;
            repeat(4) @(negedge clk_video);
            
            video_de_in = 1;
            for (int x = 0; x < IMG_WIDTH; x++) begin
                video_rgb_in = input_image_mem[y * IMG_WIDTH + x];
                @(negedge clk_video);
            end
            video_de_in = 0;
            repeat(4) @(negedge clk_video);
        end
        
        repeat(10000) @(negedge clk_video);
    end
    endtask

endmodule
