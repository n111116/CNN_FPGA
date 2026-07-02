`timescale 1ns/1ps

`include "layer31.vh"

module tb_lprnet_post_process;

    localparam int MEM_DEPTH = IMG_COL_LAYER31 * IMG_ROW_LAYER31 * CYCLE_PERIOD_IN_LAYER31 * PE_PAGE_NUM_LAYER31;
    localparam bit CONV_POSITIVE = 1;
    localparam int BLANK_CHAR    = 75;
    localparam string OUTPUT_FILE_PATH_POST = "sim_out/lprnet_post_process.hex";

    logic clk;
    logic clk_en;
    logic rst_n;

    logic new_line_input_1;
    logic data_input_valid;
    logic [PE_PAGE_NUM_LAYER31-1:0][DATA_WIDTH_LAYER31-1:0] data_input;

    logic [PE_COL_NUM_LAYER31-1:0][OUT_WIDTH_LAYER31-1:0] layer31_y_out;
    logic signed [PE_COL_NUM_LAYER31-1:0][OUT_WIDTH_LAYER31-1:0] layer31_y_out_signed;
    int idc;
    always_comb begin
        for (idc = 0; idc < PE_COL_NUM_LAYER31; idc = idc + 1) begin
            layer31_y_out_signed[idc] = $signed(layer31_y_out[idc]);
        end
    end

    logic layer31_new_line_out_1;
    logic layer31_output_valid;

    localparam int POST_CH_OUT_NUM = CYCLE_PERIOD_OUT_LAYER31 * PE_COL_NUM_LAYER31;
    localparam int POST_CH_WIDTH   = $clog2(POST_CH_OUT_NUM);

    logic [POST_CH_WIDTH-1:0] post_out_char;
    logic                     post_out_valid;
    logic                     post_frame_start_out;

    logic [DATA_WIDTH_LAYER31-1:0] file_mem [0:MEM_DEPTH-1];

    layer #(
        .LAYER_NUM(LAYER_NUM_LAYER31),
        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER31),
        .PE_ROW_NUM(PE_ROW_NUM_LAYER31),
        .PE_COL_NUM(PE_COL_NUM_LAYER31),
        .MAX_POOL(MAX_POOL_LAYER31),
        .WITH_RELU(WITH_RELU_LAYER31),
        .KERNEL_COL(KERNEL_COL_LAYER31),
        .KERNEL_ROW(KERNEL_ROW_LAYER31),
        .USE_DSP_PE(USE_DSP_PE_LAYER31),
        .DATA_WIDTH(DATA_WIDTH_LAYER31),
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER31),
        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER31),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER31),
        .STEP_COL(STEP_COL_LAYER31),
        .STEP_ROW(STEP_ROW_LAYER31),
        .IMG_COL(IMG_COL_LAYER31),
        .IMG_ROW(IMG_ROW_LAYER31),
        .SHIFT_KEY(SHIFT_KEY_LAYER31),
        .BIAS_WIDTH(BIAS_WIDTH_LAYER31),
        .OUT_WIDTH(OUT_WIDTH_LAYER31),
        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER31),
        .ACC_WIDTH(ACC_WIDTH_LAYER31)
    ) u_layer31 (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(rst_n),
        .new_line_input_1(new_line_input_1),
        .data_input_valid(data_input_valid),
        .data_input(data_input),
        .y_out(layer31_y_out),
        .new_line_out_1(layer31_new_line_out_1),
        .output_valid(layer31_output_valid)
    );

    lprnet_post_process #(
        .PE_COL_NUM(PE_COL_NUM_LAYER31),
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER31),
        .IMG_COL(IMG_COL_LAYER31),
        .IMG_ROW(IMG_ROW_LAYER31),
        .DATA_WIDTH(OUT_WIDTH_LAYER31),
        .ACC_WIDTH(OUT_WIDTH_LAYER31 + $clog2(IMG_ROW_LAYER31)),
        .CONV_POSITIVE(CONV_POSITIVE),
        .BLANK_CHAR(BLANK_CHAR)
    ) u_post_process (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(rst_n),
        .new_line_input_1(layer31_new_line_out_1),
        .data_input_valid(layer31_output_valid),
        .data_input(layer31_y_out_signed),
        .out_char(post_out_char),
        .out_valid(post_out_valid),
        .frame_start_out(post_frame_start_out)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        for (int i = 0; i < MEM_DEPTH; i++) file_mem[i] = 0;
        $readmemh(INPUT_FILE_PATH_LAYER31, file_mem);
        $display("------------------------------------------------");
        $display("File Read Check from: %s", INPUT_FILE_PATH_LAYER31);
        $display("Mem[0] (Pix0-Ch0): %h", file_mem[0]);
        $display("Mem[1] (Pix0-Ch1): %h", file_mem[1]);
        $display("------------------------------------------------");
    end

    initial begin
        clk_en = 0;
        rst_n = 0;
        new_line_input_1 = 0;
        data_input_valid = 0;
        data_input = '0;

        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        clk_en = 1;

        for (int index_y = 0; index_y < IMG_ROW_LAYER31 * 3; index_y++) begin
            @(posedge clk);
            new_line_input_1 = 1;
            data_input_valid = 0;

            @(posedge clk);
            new_line_input_1 = 0;

            for (int index_x = 0; index_x < IMG_COL_LAYER31; index_x++) begin
                for (int t = 0; t < CYCLE_PERIOD_IN_LAYER31; t++) begin
                    data_input_valid <= 1;
                    for (int p = 0; p < PE_PAGE_NUM_LAYER31; p++) begin
                        int addr;
                        addr = (index_y * IMG_COL_LAYER31 + index_x) * PE_PAGE_NUM_LAYER31
                             * CYCLE_PERIOD_IN_LAYER31 + p * CYCLE_PERIOD_IN_LAYER31 + t;
                        data_input[p] <= file_mem[addr % MEM_DEPTH];
                    end
                    @(posedge clk);
                end

                data_input_valid <= 0;
                repeat((CYCLE_PERIOD_OUT_LAYER31 / STEP_COL_LAYER31 / STEP_ROW_LAYER31 - 1)
                     * CYCLE_PERIOD_IN_LAYER31) @(posedge clk);
            end

            data_input_valid = 0;
            repeat((CYCLE_PERIOD_OUT_LAYER31 / STEP_COL_LAYER31 / STEP_ROW_LAYER31)
                 * CYCLE_PERIOD_IN_LAYER31) @(posedge clk);
            $display("Finished driving row %0d at time %t", index_y, $time);
        end

        data_input_valid = 0;
        repeat(10000) @(posedge clk);
        $display("Simulation Finished Successfully.");
        $stop;
    end

    integer out_file_post;

    initial begin
        out_file_post = $fopen(OUTPUT_FILE_PATH_POST, "w");
        if (!out_file_post) begin
            $display("Error: Could not open post-process output file: %s", OUTPUT_FILE_PATH_POST);
            $stop;
        end else begin
            $display("Post-process output file opened: %s", OUTPUT_FILE_PATH_POST);
        end
    end

    final begin
        if (out_file_post) $fclose(out_file_post);
    end

    always @(posedge clk or negedge rst_n) begin
        if (rst_n && clk_en) begin
            if (post_frame_start_out) begin
                $display("\nTime %t: Post Process Frame Start detected. Decoding sequence begins.", $time);
                $fwrite(out_file_post, "\n--- NEW FRAME ---\n");
            end

            if (post_out_valid) begin
                $fwrite(out_file_post, "%0h ", post_out_char);
                $display("Time %t: Decoded Char (Channel Index) = %0d", $time, post_out_char);
            end
        end
    end

endmodule
