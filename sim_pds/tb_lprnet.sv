`timescale 1ns/1ps

`include "layer20.vh"
`include "layer21.vh"
`include "layer22.vh"
`include "layer23.vh"
`include "layer24.vh"
`include "layer25.vh"
`include "layer26.vh"
`include "layer27.vh"
`include "layer28.vh"
`include "layer29.vh"
`include "layer30.vh"
`include "layer31.vh"

module tb_lprnet;

    localparam int MEM_DEPTH = IMG_COL_LAYER20 * IMG_ROW_LAYER20 * CYCLE_PERIOD_IN_LAYER20 * PE_PAGE_NUM_LAYER20;
    localparam bit CONV_POSITIVE = 1;
    localparam int BLANK_CHAR    = 75;
    localparam string OUTPUT_FILE_PATH_POST = "sim_out/lprnet_full_output.hex";
    localparam int INPUT_LINE_GAP = ((CYCLE_PERIOD_OUT_LAYER24 / STEP_COL_LAYER24 / STEP_ROW_LAYER24)
                                    * CYCLE_PERIOD_IN_LAYER24 * IMG_COL_LAYER24 / STEP_ROW_LAYER20);
    bit capture_intermediate;

    logic clk;
    logic clk_en;
    logic rst_n;

    logic new_line_input_1;
    logic data_input_valid;
    logic [PE_PAGE_NUM_LAYER20-1:0][DATA_WIDTH_LAYER20-1:0] data_input;

    logic [PE_COL_NUM_LAYER20-1:0][OUT_WIDTH_LAYER20-1:0] layer_y_out_layer20;
    logic out_valid_layer20;
    logic new_line_out_1_layer20;

    logic [PE_COL_NUM_LAYER21-1:0][OUT_WIDTH_LAYER21-1:0] layer_y_out_layer21;
    logic out_valid_layer21;
    logic new_line_out_1_layer21;

    logic [PE_COL_NUM_LAYER22-1:0][OUT_WIDTH_LAYER22-1:0] layer_y_out_layer22;
    logic out_valid_layer22;
    logic new_line_out_1_layer22;

    logic [PE_COL_NUM_LAYER23-1:0][OUT_WIDTH_LAYER23-1:0] layer_y_out_layer23;
    logic out_valid_layer23;
    logic new_line_out_1_layer23;

    logic [PE_COL_NUM_LAYER24-1:0][OUT_WIDTH_LAYER24-1:0] layer_y_out_layer24;
    logic out_valid_layer24;
    logic new_line_out_1_layer24;

    logic [PE_COL_NUM_LAYER25-1:0][OUT_WIDTH_LAYER25-1:0] layer_y_out_layer25;
    logic out_valid_layer25;
    logic new_line_out_1_layer25;

    logic [PE_COL_NUM_LAYER26-1:0][OUT_WIDTH_LAYER26-1:0] layer_y_out_layer26;
    logic out_valid_layer26;
    logic new_line_out_1_layer26;

    logic [PE_COL_NUM_LAYER27-1:0][OUT_WIDTH_LAYER27-1:0] layer_y_out_layer27;
    logic out_valid_layer27;
    logic new_line_out_1_layer27;

    logic [PE_COL_NUM_LAYER28-1:0][OUT_WIDTH_LAYER28-1:0] layer_y_out_layer28;
    logic out_valid_layer28;
    logic new_line_out_1_layer28;

    logic [PE_COL_NUM_LAYER29-1:0][OUT_WIDTH_LAYER29-1:0] layer_y_out_layer29;
    logic out_valid_layer29;
    logic new_line_out_1_layer29;

    logic [PE_COL_NUM_LAYER30-1:0][OUT_WIDTH_LAYER30-1:0] layer_y_out_layer30;
    logic out_valid_layer30;
    logic new_line_out_1_layer30;

    logic [PE_COL_NUM_LAYER31-1:0][OUT_WIDTH_LAYER31-1:0] layer_y_out_layer31;
    logic out_valid_layer31;
    logic new_line_out_1_layer31;

    logic signed [PE_COL_NUM_LAYER31-1:0][OUT_WIDTH_LAYER31-1:0] layer31_y_out_signed;
    int idc;
    always_comb begin
        for (idc = 0; idc < PE_COL_NUM_LAYER31; idc = idc + 1) begin
            layer31_y_out_signed[idc] = $signed(layer_y_out_layer31[idc]);
        end
    end

    localparam int POST_CH_OUT_NUM = CYCLE_PERIOD_OUT_LAYER31 * PE_COL_NUM_LAYER31;
    localparam int POST_CH_WIDTH   = $clog2(POST_CH_OUT_NUM);

    logic [POST_CH_WIDTH-1:0] post_out_char;
    logic                     post_out_valid;
    logic                     post_frame_start_out;
    int                       post_frame_count;
    int                       post_char_count;

    logic [DATA_WIDTH_LAYER20-1:0] file_mem [0:MEM_DEPTH-1];

`define TB_LPRNET_LAYER_INST(N, PREV_NEW_LINE, PREV_VALID, PREV_DATA) \
    layer #( \
        .LAYER_NUM(LAYER_NUM_LAYER``N), .PE_PAGE_NUM(PE_PAGE_NUM_LAYER``N), .PE_ROW_NUM(PE_ROW_NUM_LAYER``N), \
        .PE_COL_NUM(PE_COL_NUM_LAYER``N), .KERNEL_COL(KERNEL_COL_LAYER``N), .KERNEL_ROW(KERNEL_ROW_LAYER``N), \
        .WITH_RELU(WITH_RELU_LAYER``N), .MAX_POOL(MAX_POOL_LAYER``N), .DATA_WIDTH(DATA_WIDTH_LAYER``N), \
        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER``N), .USE_DSP_PE(USE_DSP_PE_LAYER``N), .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER``N), \
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER``N), .IMG_COL(IMG_COL_LAYER``N), .IMG_ROW(IMG_ROW_LAYER``N), \
        .STEP_COL(STEP_COL_LAYER``N), .STEP_ROW(STEP_ROW_LAYER``N), .SHIFT_KEY(SHIFT_KEY_LAYER``N), \
        .BIAS_WIDTH(BIAS_WIDTH_LAYER``N), .OUT_WIDTH(OUT_WIDTH_LAYER``N), .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER``N), \
        .ACC_WIDTH(ACC_WIDTH_LAYER``N) \
    ) u_layer``N ( \
        .clk(clk), .clk_en(clk_en), .rst_n(rst_n), \
        .new_line_input_1(PREV_NEW_LINE), .data_input_valid(PREV_VALID), .data_input(PREV_DATA), \
        .y_out(layer_y_out_layer``N), .new_line_out_1(new_line_out_1_layer``N), .output_valid(out_valid_layer``N) \
    )

    `TB_LPRNET_LAYER_INST(20, new_line_input_1,       data_input_valid, data_input);
    `TB_LPRNET_LAYER_INST(21, new_line_out_1_layer20, out_valid_layer20, layer_y_out_layer20);
    `TB_LPRNET_LAYER_INST(22, new_line_out_1_layer21, out_valid_layer21, layer_y_out_layer21);
    `TB_LPRNET_LAYER_INST(23, new_line_out_1_layer22, out_valid_layer22, layer_y_out_layer22);
    `TB_LPRNET_LAYER_INST(24, new_line_out_1_layer23, out_valid_layer23, layer_y_out_layer23);
    `TB_LPRNET_LAYER_INST(25, new_line_out_1_layer24, out_valid_layer24, layer_y_out_layer24);
    `TB_LPRNET_LAYER_INST(26, new_line_out_1_layer25, out_valid_layer25, layer_y_out_layer25);
    `TB_LPRNET_LAYER_INST(27, new_line_out_1_layer26, out_valid_layer26, layer_y_out_layer26);
    `TB_LPRNET_LAYER_INST(28, new_line_out_1_layer27, out_valid_layer27, layer_y_out_layer27);
    `TB_LPRNET_LAYER_INST(29, new_line_out_1_layer28, out_valid_layer28, layer_y_out_layer28);
    `TB_LPRNET_LAYER_INST(30, new_line_out_1_layer29, out_valid_layer29, layer_y_out_layer29);
    `TB_LPRNET_LAYER_INST(31, new_line_out_1_layer30, out_valid_layer30, layer_y_out_layer30);

`undef TB_LPRNET_LAYER_INST

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
        .new_line_input_1(new_line_out_1_layer31),
        .data_input_valid(out_valid_layer31),
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
        $readmemh(INPUT_FILE_PATH_LAYER20, file_mem);
        $display("------------------------------------------------");
        $display("LPRNet v10 TB input: %s", INPUT_FILE_PATH_LAYER20);
        $display("Input line gap: %0d cycles", INPUT_LINE_GAP);
        $display("Mem[0] (Pix0-Ch0): %h", file_mem[0]);
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

        begin
            int input_rows;
            input_rows = IMG_ROW_LAYER20 * 2;
            if ($value$plusargs("INPUT_ROWS=%d", input_rows)) begin
                $display("Override input rows: %0d", input_rows);
            end

        for (int index_y = 0; index_y < input_rows; index_y++) begin
            @(posedge clk);
            new_line_input_1 = 1;
            data_input_valid = 0;

            @(posedge clk);
            new_line_input_1 = 0;

            for (int index_x = 0; index_x < IMG_COL_LAYER20; index_x++) begin
                for (int t = 0; t < CYCLE_PERIOD_IN_LAYER20; t++) begin
                    data_input_valid <= 1;
                    for (int p = 0; p < PE_PAGE_NUM_LAYER20; p++) begin
                        int addr;
                        addr = (index_y * IMG_COL_LAYER20 + index_x) * PE_PAGE_NUM_LAYER20
                             * CYCLE_PERIOD_IN_LAYER20 + p * CYCLE_PERIOD_IN_LAYER20 + t;
                        data_input[p] <= file_mem[addr % MEM_DEPTH];
                    end
                    @(posedge clk);
                end

                data_input_valid <= 0;
                repeat((CYCLE_PERIOD_OUT_LAYER20 / STEP_COL_LAYER20 / STEP_ROW_LAYER20 - 1)
                       * CYCLE_PERIOD_IN_LAYER20) @(posedge clk);
            end

            data_input_valid = 0;
            repeat(INPUT_LINE_GAP) @(posedge clk);
            $display("Finished driving row %0d at time %t", index_y, $time);

            if ((post_char_count > 0) && (index_y >= IMG_ROW_LAYER20)) begin
                $display("Post-process output observed; ending full-chain smoke test early.");
                break;
            end
        end
        end

        data_input_valid = 0;
        if (post_char_count == 0) begin
            int drain_cycles;
            drain_cycles = 500_000;
            if ($value$plusargs("DRAIN_CYCLES=%d", drain_cycles)) begin
                $display("Override drain cycles: %0d", drain_cycles);
            end
            for (int drain_idx = 0; drain_idx < drain_cycles; drain_idx++) begin
                @(posedge clk);
                if (post_char_count > 0) break;
            end
        end
        repeat(1_000) @(posedge clk);
        $display("Simulation Finished Successfully. post_frames=%0d post_chars=%0d",
                 post_frame_count, post_char_count);
        $stop;
    end

    integer out_file_layer20, out_file_layer21, out_file_layer22, out_file_layer23;
    integer out_file_layer24, out_file_layer25, out_file_layer26, out_file_layer27;
    integer out_file_layer28, out_file_layer29, out_file_layer30, out_file_layer31;
    integer out_file_post;

    bit write_enable_layer20, write_enable_layer21, write_enable_layer22, write_enable_layer23;
    bit write_enable_layer24, write_enable_layer25, write_enable_layer26, write_enable_layer27;
    bit write_enable_layer28, write_enable_layer29, write_enable_layer30, write_enable_layer31;

    initial begin
        capture_intermediate = !$test$plusargs("NO_CAPTURE_INTERMEDIATE");
        if (capture_intermediate) begin
            out_file_layer20 = $fopen(OUTPUT_FILE_PATH_LAYER20, "w");
            out_file_layer21 = $fopen(OUTPUT_FILE_PATH_LAYER21, "w");
            out_file_layer22 = $fopen(OUTPUT_FILE_PATH_LAYER22, "w");
            out_file_layer23 = $fopen(OUTPUT_FILE_PATH_LAYER23, "w");
            out_file_layer24 = $fopen(OUTPUT_FILE_PATH_LAYER24, "w");
            out_file_layer25 = $fopen(OUTPUT_FILE_PATH_LAYER25, "w");
            out_file_layer26 = $fopen(OUTPUT_FILE_PATH_LAYER26, "w");
            out_file_layer27 = $fopen(OUTPUT_FILE_PATH_LAYER27, "w");
            out_file_layer28 = $fopen(OUTPUT_FILE_PATH_LAYER28, "w");
            out_file_layer29 = $fopen(OUTPUT_FILE_PATH_LAYER29, "w");
            out_file_layer30 = $fopen(OUTPUT_FILE_PATH_LAYER30, "w");
            out_file_layer31 = $fopen(OUTPUT_FILE_PATH_LAYER31, "w");
        end else begin
            out_file_layer20 = 0;
            out_file_layer21 = 0;
            out_file_layer22 = 0;
            out_file_layer23 = 0;
            out_file_layer24 = 0;
            out_file_layer25 = 0;
            out_file_layer26 = 0;
            out_file_layer27 = 0;
            out_file_layer28 = 0;
            out_file_layer29 = 0;
            out_file_layer30 = 0;
            out_file_layer31 = 0;
        end
        out_file_post = $fopen(OUTPUT_FILE_PATH_POST, "w");
        if (capture_intermediate && !out_file_layer31) $display("Error: Could not open output file for Layer 31!");
        if (!out_file_post) $display("Error: Could not open output file for Post Process!");
    end

    final begin
        if (out_file_layer20) $fclose(out_file_layer20);
        if (out_file_layer21) $fclose(out_file_layer21);
        if (out_file_layer22) $fclose(out_file_layer22);
        if (out_file_layer23) $fclose(out_file_layer23);
        if (out_file_layer24) $fclose(out_file_layer24);
        if (out_file_layer25) $fclose(out_file_layer25);
        if (out_file_layer26) $fclose(out_file_layer26);
        if (out_file_layer27) $fclose(out_file_layer27);
        if (out_file_layer28) $fclose(out_file_layer28);
        if (out_file_layer29) $fclose(out_file_layer29);
        if (out_file_layer30) $fclose(out_file_layer30);
        if (out_file_layer31) $fclose(out_file_layer31);
        if (out_file_post) $fclose(out_file_post);
    end

`define TB_CAPTURE_LAYER(N) \
    if (capture_intermediate && new_line_out_1_layer``N) write_enable_layer``N <= 1; \
    if (capture_intermediate && write_enable_layer``N && out_valid_layer``N) begin \
        for (int c = 0; c < PE_COL_NUM_LAYER``N; c++) begin \
            $fwrite(out_file_layer``N, "%6h ", layer_y_out_layer``N[c]); \
        end \
        $fwrite(out_file_layer``N, "\n"); \
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_enable_layer20 <= 0;
            write_enable_layer21 <= 0;
            write_enable_layer22 <= 0;
            write_enable_layer23 <= 0;
            write_enable_layer24 <= 0;
            write_enable_layer25 <= 0;
            write_enable_layer26 <= 0;
            write_enable_layer27 <= 0;
            write_enable_layer28 <= 0;
            write_enable_layer29 <= 0;
            write_enable_layer30 <= 0;
            write_enable_layer31 <= 0;
            post_frame_count <= 0;
            post_char_count <= 0;
        end else if (clk_en) begin
            `TB_CAPTURE_LAYER(20)
            `TB_CAPTURE_LAYER(21)
            `TB_CAPTURE_LAYER(22)
            `TB_CAPTURE_LAYER(23)
            `TB_CAPTURE_LAYER(24)
            `TB_CAPTURE_LAYER(25)
            `TB_CAPTURE_LAYER(26)
            `TB_CAPTURE_LAYER(27)
            `TB_CAPTURE_LAYER(28)
            `TB_CAPTURE_LAYER(29)
            `TB_CAPTURE_LAYER(30)
            `TB_CAPTURE_LAYER(31)

            if (post_frame_start_out) begin
                post_frame_count <= post_frame_count + 1;
                $display("\nTime %t: Post Process Frame Start detected.", $time);
                $fwrite(out_file_post, "\n--- NEW FRAME ---\n");
            end

            if (post_out_valid) begin
                post_char_count <= post_char_count + 1;
                $fwrite(out_file_post, "%0h ", post_out_char);
                $display("Time %t: Decoded Char (Channel Index) = %0h", $time, post_out_char);
            end
        end
    end

`undef TB_CAPTURE_LAYER

endmodule
