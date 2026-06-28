`timescale 1ns/1ps

module tb_ddr_video_delay_sync;

    localparam int H_ACT   = 256;
    localparam int V_ACT   = 4;
    localparam int H_TOTAL = 320;
    localparam int H_SYNC  = 4;
    localparam int H_BP    = 8;
    localparam int H_FP    = H_TOTAL - H_SYNC - H_BP - H_ACT;
    localparam int V_TOTAL = 8;
    localparam int V_SYNC  = 1;
    localparam int V_BP    = 1;
    localparam int V_FP    = V_TOTAL - V_SYNC - V_BP - V_ACT;

    logic pix_clk = 1'b0;
    logic ddr_ref_clk = 1'b0;
    logic rst_n = 1'b0;
    logic video_vs_in = 1'b0;
    logic video_de_in = 1'b0;
    logic [23:0] video_rgb_in = 24'd0;
    logic read_start_toggle = 1'b0;

    logic video_vs_out;
    logic video_hs_out;
    logic video_de_out;
    logic [23:0] video_rgb_out;
    logic frame_start_out;
    logic ddr_init_done;

    logic mem_rst_n;
    logic mem_ck;
    logic mem_ck_n;
    logic mem_cke;
    logic mem_cs_n;
    logic mem_ras_n;
    logic mem_cas_n;
    logic mem_we_n;
    logic mem_odt;
    logic [14:0] mem_a;
    logic [2:0] mem_ba;
    wire [3:0] mem_dqs;
    wire [3:0] mem_dqs_n;
    wire [31:0] mem_dq;
    wire [3:0] mem_dm;

    int expected_frame_id;
    int capture_frame_id;
    int capture_x;
    int capture_y;
    int capture_count;
    int output_frames;
    int error_count;
    bit capture_active;

    always #5 pix_clk = ~pix_clk;
    always #4 ddr_ref_clk = ~ddr_ref_clk;

`ifdef USE_PDS_DDR3_MEMORY_MODEL
    logic grs_n = 1'b0;

    GTP_GRS GRS_INST (
        .GRS_N(grs_n)
    );

    initial begin
        #5 grs_n = 1'b1;
    end
`endif

    ddr_video_delay_sync #(
        .H_ACT   (H_ACT),
        .V_ACT   (V_ACT),
        .H_TOTAL (H_TOTAL),
        .H_SYNC  (H_SYNC),
        .H_BP    (H_BP),
        .H_FP    (H_FP),
        .V_TOTAL (V_TOTAL),
        .V_SYNC  (V_SYNC),
        .V_BP    (V_BP),
        .V_FP    (V_FP)
    ) dut (
        .pix_clk          (pix_clk),
        .ddr_ref_clk      (ddr_ref_clk),
        .rst_n            (rst_n),
        .video_vs_in      (video_vs_in),
        .video_de_in      (video_de_in),
        .video_rgb_in     (video_rgb_in),
        .read_start_toggle(read_start_toggle),
        .video_vs_out     (video_vs_out),
        .video_hs_out     (video_hs_out),
        .video_de_out     (video_de_out),
        .video_rgb_out    (video_rgb_out),
        .frame_start_out  (frame_start_out),
        .ddr_init_done    (ddr_init_done),
        .mem_rst_n        (mem_rst_n),
        .mem_ck           (mem_ck),
        .mem_ck_n         (mem_ck_n),
        .mem_cke          (mem_cke),
        .mem_cs_n         (mem_cs_n),
        .mem_ras_n        (mem_ras_n),
        .mem_cas_n        (mem_cas_n),
        .mem_we_n         (mem_we_n),
        .mem_odt          (mem_odt),
        .mem_a            (mem_a),
        .mem_ba           (mem_ba),
        .mem_dqs          (mem_dqs),
        .mem_dqs_n        (mem_dqs_n),
        .mem_dq           (mem_dq),
        .mem_dm           (mem_dm)
    );

`ifdef USE_PDS_DDR3_MEMORY_MODEL
    wire [1:0] ddr3_tdqs_n_lo;
    wire [1:0] ddr3_tdqs_n_hi;

    ddr3 u_ddr3_lo (
        .rst_n   (mem_rst_n),
        .ck      (mem_ck),
        .ck_n    (mem_ck_n),
        .cke     (mem_cke),
        .cs_n    (mem_cs_n),
        .ras_n   (mem_ras_n),
        .cas_n   (mem_cas_n),
        .we_n    (mem_we_n),
        .dm_tdqs (mem_dm[1:0]),
        .ba      (mem_ba),
        .addr    (mem_a),
        .dq      (mem_dq[15:0]),
        .dqs     (mem_dqs[1:0]),
        .dqs_n   (mem_dqs_n[1:0]),
        .tdqs_n  (ddr3_tdqs_n_lo),
        .odt     (mem_odt)
    );

    ddr3 u_ddr3_hi (
        .rst_n   (mem_rst_n),
        .ck      (mem_ck),
        .ck_n    (mem_ck_n),
        .cke     (mem_cke),
        .cs_n    (mem_cs_n),
        .ras_n   (mem_ras_n),
        .cas_n   (mem_cas_n),
        .we_n    (mem_we_n),
        .dm_tdqs (mem_dm[3:2]),
        .ba      (mem_ba),
        .addr    (mem_a),
        .dq      (mem_dq[31:16]),
        .dqs     (mem_dqs[3:2]),
        .dqs_n   (mem_dqs_n[3:2]),
        .tdqs_n  (ddr3_tdqs_n_hi),
        .odt     (mem_odt)
    );
`endif

    function automatic [15:0] rgb888_to_565(input logic [23:0] rgb);
        rgb888_to_565 = {rgb[23:19], rgb[15:10], rgb[7:3]};
    endfunction

    function automatic [23:0] rgb565_to_888(input logic [15:0] rgb);
        rgb565_to_888 = {
            rgb[15:11], rgb[15:13],
            rgb[10:5],  rgb[10:9],
            rgb[4:0],   rgb[4:2]
        };
    endfunction

    function automatic [23:0] src_pixel(input int frame_id, input int x, input int y);
        logic [7:0] r;
        logic [7:0] g;
        logic [7:0] b;
        begin
            r = frame_id * 53 + x;
            g = frame_id * 29 + y * 37 + x * 3;
            b = frame_id * 17 + y * 11 + x * 5;
            src_pixel = {r, g, b};
        end
    endfunction

    function automatic [23:0] expected_pixel(input int frame_id, input int x, input int y);
        expected_pixel = rgb565_to_888(rgb888_to_565(src_pixel(frame_id, x, y)));
    endfunction

    task automatic send_frame(input int frame_id);
        int x;
        int y;
        begin
            video_de_in  <= 1'b0;
            video_rgb_in <= 24'd0;
            video_vs_in  <= 1'b1;
            repeat (2) @(posedge pix_clk);
            video_vs_in  <= 1'b0;
            repeat (4) @(posedge pix_clk);

            for (y = 0; y < V_ACT; y = y + 1) begin
                video_de_in <= 1'b1;
                for (x = 0; x < H_ACT; x = x + 1) begin
                    video_rgb_in <= src_pixel(frame_id, x, y);
                    @(posedge pix_clk);
                end
                video_de_in  <= 1'b0;
                video_rgb_in <= 24'd0;
                repeat (8) @(posedge pix_clk);
            end

            repeat (40) @(posedge pix_clk);
        end
    endtask

    task automatic wait_output_frames(input int target_frames);
        int timeout;
        begin
            timeout = 0;
            while ((output_frames < target_frames) && (timeout < 200000)) begin
                @(posedge pix_clk);
                timeout = timeout + 1;
            end

            if (timeout >= 200000) begin
                $fatal(1, "[TB] Timeout waiting for output frame %0d", target_frames);
            end
        end
    endtask

    task automatic request_readback(input int frame_id);
        begin
            expected_frame_id = frame_id;
            read_start_toggle <= ~read_start_toggle;
            @(posedge pix_clk);
        end
    endtask

    always @(posedge pix_clk or negedge rst_n) begin
        logic [23:0] exp_rgb;

        if (!rst_n) begin
            capture_frame_id <= 0;
            capture_x        <= 0;
            capture_y        <= 0;
            capture_count    <= 0;
            output_frames    <= 0;
            error_count      <= 0;
            capture_active   <= 1'b0;
        end else begin
            if (frame_start_out) begin
                capture_active   <= 1'b1;
                capture_frame_id <= expected_frame_id;
                capture_x        <= 0;
                capture_y        <= 0;
                capture_count    <= 0;
            end

            if (capture_active && video_de_out) begin
                exp_rgb = expected_pixel(capture_frame_id, capture_x, capture_y);
                if (video_rgb_out !== exp_rgb) begin
                    error_count <= error_count + 1;
                    if (error_count < 16) begin
                        $display("[TB] Mismatch frame=%0d x=%0d y=%0d got=%06h exp=%06h",
                                 capture_frame_id, capture_x, capture_y, video_rgb_out, exp_rgb);
                    end
                end

                if (capture_x == H_ACT - 1) begin
                    capture_x <= 0;
                    capture_y <= capture_y + 1;
                end else begin
                    capture_x <= capture_x + 1;
                end

                if (capture_count == H_ACT * V_ACT - 1) begin
                    capture_active <= 1'b0;
                    output_frames  <= output_frames + 1;
                end
                capture_count <= capture_count + 1;
            end
        end
    end

    initial begin
        expected_frame_id = 0;
        repeat (20) @(posedge pix_clk);
        rst_n <= 1'b1;

        fork
            begin
                wait (ddr_init_done);
            end
            begin
                repeat (500000) @(posedge pix_clk);
                $fatal(1, "[TB] Timeout waiting for ddr_init_done");
            end
        join_any
        disable fork;

        repeat (10) @(posedge pix_clk);

        send_frame(0);
        repeat (200) @(posedge pix_clk);
        request_readback(0);
        wait_output_frames(1);

        send_frame(1);
        repeat (200) @(posedge pix_clk);
        request_readback(1);
        wait_output_frames(2);

        if (error_count == 0) begin
            $display("[TB] PASS: DDR video delay RGB565 round-trip matched expected pixels.");
            $finish;
        end else begin
            $fatal(1, "[TB] FAIL: %0d mismatched pixels", error_count);
        end
    end

endmodule
