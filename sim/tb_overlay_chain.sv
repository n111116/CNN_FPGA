`timescale 1ns / 1ps

module tb_overlay_chain();
    parameter IMG_WIDTH  = 256;
    parameter IMG_HEIGHT = 256;
    parameter GRID_STRIDE_CENTER = 16;
    parameter GRID_STRIDE_LTRB   = 1;
    parameter MAX_BOX_NUM = 3;
    parameter CROP_WIDTH  = 20;
    parameter CROP_HEIGHT = 12;

    logic clk_video = 0; logic clk_pe = 0; logic rst_n = 0;
    always #5 clk_video = ~clk_video;  
    always #3 clk_pe    = ~clk_pe;     
    
    logic        v_vs_in = 0, v_hs_in = 0, v_de_in = 0;
    logic [23:0] v_rgb_in = 0;
    logic        v_vs_mid, v_hs_mid, v_de_mid; logic [23:0] v_rgb_mid;
    logic        v_vs_out, v_hs_out, v_de_out; logic [23:0] v_rgb_out;

    logic        box_wr_en = 0; logic [31:0] box_wr_data = 0;
    logic        crop_wr_en   [0:MAX_BOX_NUM-1];
    logic        start_box_wr [0:MAX_BOX_NUM-1];
    logic        end_box_wr  [0:MAX_BOX_NUM-1];
    logic [15:0] crop_x_min   [0:MAX_BOX_NUM-1];
    logic [15:0] crop_y_min   [0:MAX_BOX_NUM-1];
    logic [23:0] crop_rgb_out ;

    logic        new_line_1, data_valid;
    logic [23:0] data_out;
    logic [15:0] x_min_out, y_min_out;   

    logic [6:0]  out_char = 0;
    logic        out_valid = 0, frame_start_out = 0;

    box_overlay_sync #(
        .IMG_WIDTH(IMG_WIDTH), .IMG_HEIGHT(IMG_HEIGHT),
        .GRID_STRIDE_CENTER(GRID_STRIDE_CENTER), .GRID_STRIDE_LTRB(GRID_STRIDE_LTRB),
        .CROP_WIDTH(CROP_WIDTH), .CROP_HEIGHT(CROP_HEIGHT),
        .LINE_WIDTH(1), .MAX_BOX_NUM(MAX_BOX_NUM)
    ) u_box_overlay (
        .clk_video(clk_video), .clk_pe(clk_pe), .rst_n(rst_n),
        .video_vs_in(v_vs_in), .video_hs_in(v_hs_in), .video_de_in(v_de_in), .video_rgb_in(v_rgb_in),
        .video_vs_out(v_vs_mid), .video_hs_out(v_hs_mid), .video_de_out(v_de_mid), .video_rgb_out(v_rgb_mid),
        .box_wr_en(box_wr_en), .box_wr_data(box_wr_data),
        .start_box_wr(start_box_wr), .end_box_wr(end_box_wr), .crop_x_min(crop_x_min), .crop_y_min(crop_y_min),
        .crop_wr_en(crop_wr_en), .crop_rgb_out(crop_rgb_out)
    );

    crop_buffer_manager #(
        .MAX_BOX_NUM(MAX_BOX_NUM), .CROP_WIDTH(CROP_WIDTH), .CROP_HEIGHT(CROP_HEIGHT), .CYCLE_PERIOD(4)
    ) u_crop_manager (
        .clk_video(clk_video), .rst_n(rst_n),
        .start_box_wr(start_box_wr), .end_box_wr(end_box_wr), .x_min_in(crop_x_min), .y_min_in(crop_y_min),
        .crop_wr_en(crop_wr_en), .crop_rgb_out(crop_rgb_out),
        .clk_pe(clk_pe), .x_min_out(x_min_out), .y_min_out(y_min_out),
        .new_line_1(new_line_1), .data_valid(data_valid), .data_out(data_out)
    );

    char_overlay #(
        .CROP_HEIGHT(CROP_HEIGHT),
        .FONT_FILE("chars_16x16.mem") 
    ) u_char_overlay (
        .clk_video(clk_video), .rst_n_video(rst_n),
        .video_vs_in(v_vs_mid), .video_hs_in(v_hs_mid), .video_de_in(v_de_mid), .video_rgb_in(v_rgb_mid),
        .video_vs_out(v_vs_out), .video_hs_out(v_hs_out), .video_de_out(v_de_out), .video_rgb_out(v_rgb_out),
        .clk_pe(clk_pe), .rst_n_pe(rst_n),
        .x_min_in(x_min_out), .y_min_in(y_min_out), .new_line_1(new_line_1),
        .out_char(out_char), .out_valid(out_valid), .frame_start_out(frame_start_out)
    );

    // =========================================================
    // LPRNet 检测延迟模拟 【修复：加入Semaphore互斥锁防踩踏】
    // =========================================================
    int line_tracker = 0;
    semaphore lprnet_sem = new(1); // 互斥锁，保证同时只有一个检测在写入总线

    always @(posedge clk_pe) begin
        if (rst_n) begin
            if (new_line_1) begin
                if (line_tracker == CROP_HEIGHT - 1) begin
                    line_tracker = 0;
                    fork send_lprnet_chars(); join_none
                end else line_tracker++;
            end
        end
    end

    // 使用 automatic 关键字确保多个后台进程变量不冲突
    task automatic send_lprnet_chars();
        int wait_cycles;
        wait_cycles = 3000 + $urandom_range(0, 2000);
        repeat (wait_cycles) @(posedge clk_pe);
        
        lprnet_sem.get(1); // 【加锁】获取总线写入权
        
        @(posedge clk_pe); frame_start_out <= 1; 
        @(posedge clk_pe); frame_start_out <= 0;
        
        // 1="沪", 51="A"
        out_valid <= 1; out_char <= 7'd1;  @(posedge clk_pe);
        out_valid <= 1; out_char <= 7'd51; @(posedge clk_pe);
        out_valid <= 0; out_char <= 0;
        $display("[%0t] Mock LPRNet '沪A' Sent to Overlay.", $time);
        
        lprnet_sem.put(1); // 【解锁】释放总线
    endtask

    // ---------------------------------------------------------
    // 以下测试激励和截图逻辑不变 (省略重复部分，保持与上一版相同)
    // ---------------------------------------------------------
    initial begin
        #100 rst_n = 1; #100;
        for (int frame = 0; frame < 3; frame++) generate_video_frame(frame);
        #2000 $finish;
    end

    task send_box_data(
        input [7:0] cls, input [7:0] x, input [7:0] y, input [7:0] conf,
        input [8:0] L, input [8:0] T, input [8:0] R, input [8:0] B
    );
    begin
        @(posedge clk_pe); box_wr_en <= 1; box_wr_data <= {cls, x, y, conf};
        @(posedge clk_pe); box_wr_data <= {23'd0, L};
        @(posedge clk_pe); box_wr_data <= {23'd0, T};
        @(posedge clk_pe); box_wr_data <= {23'd0, R};
        @(posedge clk_pe); box_wr_data <= {23'd0, B};
        @(posedge clk_pe); box_wr_en <= 0;
    end
    endtask

    task generate_video_frame(input int frame_no);
    begin
        @(posedge clk_video); v_vs_in <= 1; #200; v_vs_in <= 0; #100;
        for (int y = 0; y < IMG_HEIGHT; y++) begin
            if (frame_no == 1) begin
                if (y == 20) fork send_box_data(1, 4, 4, 99, 10, 10, 20, 20); join_none 
                if (y == 80) fork send_box_data(2, 6, 6, 99, 10, 10, 20, 20); join_none 
            end
            @(negedge clk_video); v_hs_in = 1; repeat(4) @(negedge clk_video); v_hs_in = 0; repeat(4) @(negedge clk_video);
            v_de_in = 1;
            for (int x = 0; x < IMG_WIDTH; x++) begin
                if ((x/10)%2 == (y/10)%2) v_rgb_in = {y[7:0], x[7:0], 8'h99};
                else                      v_rgb_in = {y[7:0], x[7:0], 8'h11};
                @(negedge clk_video);
            end
            v_de_in = 0; repeat(4) @(negedge clk_video);
        end
        repeat(5000) @(negedge clk_video);
    end
    endtask

    // (文件抓取保存部分同上一版，保持不变)
    int fd_video = 0; int current_video_frame = 0; logic video_vs_out_d;
    always_ff @(posedge clk_video) begin
        if (rst_n) begin
            video_vs_out_d <= v_vs_out;
            if (v_vs_out && !video_vs_out_d) begin
                automatic string filename;
                if (fd_video != 0) $fclose(fd_video);
                $sformat(filename, "sim_out/final_overlay_frame_%0d.ppm", current_video_frame);
                fd_video = $fopen(filename, "w");
                $fdisplay(fd_video, "P3\n%0d %0d\n255", IMG_WIDTH, IMG_HEIGHT);
                current_video_frame++;
            end
            if (v_de_out && fd_video != 0) $fdisplay(fd_video, "%0d %0d %0d", v_rgb_out[23:16], v_rgb_out[15:8], v_rgb_out[7:0]);
        end
    end

    int fd_crop = 0; int current_crop_box = 0; int pixel_cnt = 0;
    always_ff @(posedge clk_pe) begin
        if (rst_n) begin
            if (new_line_1 && pixel_cnt == 0) begin
                automatic string filename;
                if (fd_crop != 0) $fclose(fd_crop);
                $sformat(filename, "sim_out/crop_out_box_%0d_x%0d_y%0d.ppm", current_crop_box, x_min_out, y_min_out);
                fd_crop = $fopen(filename, "w");
                $fdisplay(fd_crop, "P3\n%0d %0d\n255", CROP_WIDTH, CROP_HEIGHT);
            end
            if (data_valid) begin
                $fdisplay(fd_crop, "%0d %0d %0d", data_out[23:16], data_out[15:8], data_out[7:0]);
                pixel_cnt++;
                if (pixel_cnt == CROP_WIDTH * CROP_HEIGHT) begin
                    $fclose(fd_crop); fd_crop = 0; pixel_cnt = 0; current_crop_box++;
                end
            end
        end
    end
endmodule