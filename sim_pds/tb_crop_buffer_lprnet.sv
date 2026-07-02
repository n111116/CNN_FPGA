`timescale 1ns/1ps

`include "layer20.vh"
`include "layer24.vh"
`include "layer31.vh"

module tb_crop_buffer_lprnet;

    localparam int MAX_BOX_NUM = 4;
    localparam int CROP_WIDTH  = IMG_COL_LAYER20;
    localparam int CROP_HEIGHT = IMG_ROW_LAYER20;
    localparam int MEM_DEPTH   = CROP_WIDTH * CROP_HEIGHT * PE_PAGE_NUM_LAYER20 * CYCLE_PERIOD_IN_LAYER20;
    localparam int INPUT_LINE_GAP = ((CYCLE_PERIOD_OUT_LAYER24 / STEP_COL_LAYER24 / STEP_ROW_LAYER24)
                                    * CYCLE_PERIOD_IN_LAYER24 * IMG_COL_LAYER24 / STEP_ROW_LAYER20);
    localparam int INPUT_PIXEL_PERIOD = CYCLE_PERIOD_OUT_LAYER20 / STEP_COL_LAYER20 / STEP_ROW_LAYER20;

    logic clk_video = 1'b0;
    logic clk_pe    = 1'b0;
    logic rst_n     = 1'b0;

    always #5 clk_video = ~clk_video;
    always #3 clk_pe    = ~clk_pe;

    logic [MAX_BOX_NUM-1:0] start_crop_wr;
    logic [MAX_BOX_NUM-1:0] end_crop_wr;
    logic [MAX_BOX_NUM-1:0] crop_wr_en;
    logic [MAX_BOX_NUM-1:0][15:0] x_min_in;
    logic [MAX_BOX_NUM-1:0][15:0] y_min_in;
    logic [MAX_BOX_NUM-1:0][23:0] crop_rgb_out;

    logic [15:0] x_min_out;
    logic [15:0] y_min_out;
    logic        lprnet_new_line;
    logic        lprnet_data_valid;
    logic [23:0] lprnet_rgb_data;
    logic [PE_PAGE_NUM_LAYER20-1:0][DATA_WIDTH_LAYER20-1:0] lprnet_data_in;

    logic [6:0] lprnet_out_char;
    logic       lprnet_out_valid;
    logic       lprnet_frame_start;

    logic [DATA_WIDTH_LAYER20-1:0] file_mem [0:MEM_DEPTH-1];
    int post_frame_count;
    int post_char_count;

    assign lprnet_data_in[0] = lprnet_rgb_data[23:16];
    assign lprnet_data_in[1] = lprnet_rgb_data[15:8];
    assign lprnet_data_in[2] = lprnet_rgb_data[7:0];

    crop_buffer_manager #(
        .MAX_BOX_NUM(MAX_BOX_NUM),
        .LINE_GAP(INPUT_LINE_GAP),
        .CROP_WIDTH(CROP_WIDTH),
        .CROP_HEIGHT(CROP_HEIGHT),
        .CYCLE_PERIOD(INPUT_PIXEL_PERIOD)
    ) u_crop_buffer_manager (
        .clk_video(clk_video),
        .rst_n(rst_n),
        .start_crop_wr(start_crop_wr),
        .end_crop_wr(end_crop_wr),
        .crop_wr_en(crop_wr_en),
        .x_min_in(x_min_in),
        .y_min_in(y_min_in),
        .crop_rgb_out(crop_rgb_out),
        .clk_pe(clk_pe),
        .x_min_out(x_min_out),
        .y_min_out(y_min_out),
        .new_line_1(lprnet_new_line),
        .data_valid(lprnet_data_valid),
        .data_out(lprnet_rgb_data)
    );

    lprnet_top #(
        .CONV_POSITIVE(1),
        .BLANK_CHAR(75)
    ) u_lprnet_top (
        .clk(clk_pe),
        .clk_en(1'b1),
        .rst_n(rst_n),
        .new_line_input_1(lprnet_new_line),
        .data_input_valid(lprnet_data_valid),
        .data_input(lprnet_data_in),
        .out_char(lprnet_out_char),
        .out_valid(lprnet_out_valid),
        .frame_start_out(lprnet_frame_start)
    );

    initial begin
        for (int i = 0; i < MEM_DEPTH; i++) file_mem[i] = '0;
        $readmemh(INPUT_FILE_PATH_LAYER20, file_mem);
        $display("Crop->LPRNet TB input: %s", INPUT_FILE_PATH_LAYER20);
        $display("CROP=%0dx%0d LINE_GAP=%0d PIXEL_PERIOD=%0d",
                 CROP_WIDTH, CROP_HEIGHT, INPUT_LINE_GAP, INPUT_PIXEL_PERIOD);
    end

    initial begin
        for (int i = 0; i < MAX_BOX_NUM; i++) begin
            start_crop_wr[i] = 1'b0;
            end_crop_wr[i]   = 1'b0;
            crop_wr_en[i]    = 1'b0;
            x_min_in[i]      = '0;
            y_min_in[i]      = '0;
            crop_rgb_out[i]  = '0;
        end

        repeat (20) @(posedge clk_video);
        rst_n = 1'b1;
        repeat (20) @(posedge clk_video);

        for (int box = 0; box < MAX_BOX_NUM; box++) begin
            send_crop(box);
            repeat (20) @(posedge clk_video);
        end

        for (int wait_idx = 0; wait_idx < 1_200_000; wait_idx++) begin
            @(posedge clk_pe);
            if (post_char_count >= 7) break;
        end

        $display("Crop->LPRNet finished: post_frames=%0d post_chars=%0d",
                 post_frame_count, post_char_count);
        if (post_char_count == 0) begin
            $error("No LPRNet post-process characters observed after crop_buffer_manager.");
        end
        $finish;
    end

    task automatic send_crop(input int box_idx);
        int addr;
        logic [7:0] ch0;
        logic [7:0] ch1;
        logic [7:0] ch2;
    begin
        @(posedge clk_video);
        x_min_in[box_idx] <= 16'(20 + box_idx * 40);
        y_min_in[box_idx] <= 16'(80 + box_idx * 20);
        start_crop_wr[box_idx] <= 1'b1;
        @(posedge clk_video);
        start_crop_wr[box_idx] <= 1'b0;
        repeat (2) @(posedge clk_video);

        for (int y = 0; y < CROP_HEIGHT; y++) begin
            for (int x = 0; x < CROP_WIDTH; x++) begin
                addr = (y * CROP_WIDTH + x) * PE_PAGE_NUM_LAYER20 * CYCLE_PERIOD_IN_LAYER20;
                ch0 = file_mem[addr + 0];
                ch1 = file_mem[addr + 1];
                ch2 = file_mem[addr + 2];
                crop_rgb_out[box_idx] <= {ch0, ch1, ch2};
                crop_wr_en[box_idx] <= 1'b1;
                @(posedge clk_video);
            end
        end

        crop_wr_en[box_idx] <= 1'b0;
        end_crop_wr[box_idx] <= 1'b1;
        @(posedge clk_video);
        end_crop_wr[box_idx] <= 1'b0;
        $display("[%0t] Wrote crop box %0d", $time, box_idx);
    end
    endtask

    always_ff @(posedge clk_pe or negedge rst_n) begin
        if (!rst_n) begin
            post_frame_count <= 0;
            post_char_count  <= 0;
        end else begin
            if (lprnet_frame_start) begin
                post_frame_count <= post_frame_count + 1;
                $display("Time %t: LPRNet frame start at crop coord x=%0d y=%0d",
                         $time, x_min_out, y_min_out);
            end
            if (lprnet_out_valid) begin
                post_char_count <= post_char_count + 1;
                $display("Time %t: LPRNet char = %0d (0x%0h)",
                         $time, lprnet_out_char, lprnet_out_char);
            end
        end
    end

endmodule
