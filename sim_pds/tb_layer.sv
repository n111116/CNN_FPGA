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

module tb_layer #(
    parameter int TARGET_LAYER = 31
);

`define SELECT_LPR_PARAM(P) \
    ((TARGET_LAYER == 20) ? P``_LAYER20 : \
     (TARGET_LAYER == 21) ? P``_LAYER21 : \
     (TARGET_LAYER == 22) ? P``_LAYER22 : \
     (TARGET_LAYER == 23) ? P``_LAYER23 : \
     (TARGET_LAYER == 24) ? P``_LAYER24 : \
     (TARGET_LAYER == 25) ? P``_LAYER25 : \
     (TARGET_LAYER == 26) ? P``_LAYER26 : \
     (TARGET_LAYER == 27) ? P``_LAYER27 : \
     (TARGET_LAYER == 28) ? P``_LAYER28 : \
     (TARGET_LAYER == 29) ? P``_LAYER29 : \
     (TARGET_LAYER == 30) ? P``_LAYER30 : P``_LAYER31)

    localparam int TL_LAYER_NUM            = `SELECT_LPR_PARAM(LAYER_NUM);
    localparam int TL_PE_PAGE_NUM          = `SELECT_LPR_PARAM(PE_PAGE_NUM);
    localparam int TL_PE_COL_NUM           = `SELECT_LPR_PARAM(PE_COL_NUM);
    localparam int TL_PE_ROW_NUM           = `SELECT_LPR_PARAM(PE_ROW_NUM);
    localparam int TL_KERNEL_COL           = `SELECT_LPR_PARAM(KERNEL_COL);
    localparam int TL_KERNEL_ROW           = `SELECT_LPR_PARAM(KERNEL_ROW);
    localparam int TL_MAX_POOL             = `SELECT_LPR_PARAM(MAX_POOL);
    localparam int TL_WITH_RELU            = `SELECT_LPR_PARAM(WITH_RELU);
    localparam int TL_STEP_ROW             = `SELECT_LPR_PARAM(STEP_ROW);
    localparam int TL_STEP_COL             = `SELECT_LPR_PARAM(STEP_COL);
    localparam int TL_DATA_WIDTH           = `SELECT_LPR_PARAM(DATA_WIDTH);
    localparam int TL_WEIGHT_WIDTH         = `SELECT_LPR_PARAM(WEIGHT_WIDTH);
    localparam int TL_BIAS_WIDTH           = `SELECT_LPR_PARAM(BIAS_WIDTH);
    localparam int TL_OUT_WIDTH            = `SELECT_LPR_PARAM(OUT_WIDTH);
    localparam int TL_CYCLE_PERIOD_IN      = `SELECT_LPR_PARAM(CYCLE_PERIOD_IN);
    localparam int TL_CYCLE_PERIOD_OUT     = `SELECT_LPR_PARAM(CYCLE_PERIOD_OUT);
    localparam int TL_SHIFT_KEY            = `SELECT_LPR_PARAM(SHIFT_KEY);
    localparam int TL_IMG_COL              = `SELECT_LPR_PARAM(IMG_COL);
    localparam int TL_IMG_ROW              = `SELECT_LPR_PARAM(IMG_ROW);
    localparam int TL_PE_PAGE_OUTPUT_WIDTH = `SELECT_LPR_PARAM(PE_PAGE_OUTPUT_WIDTH);
    localparam int TL_ACC_WIDTH            = `SELECT_LPR_PARAM(ACC_WIDTH);
    localparam int TL_MEM_DEPTH            = TL_IMG_COL * TL_IMG_ROW * TL_CYCLE_PERIOD_IN * TL_PE_PAGE_NUM;
    localparam int TL_OUT_LINE_GAP         = (TL_CYCLE_PERIOD_OUT / TL_STEP_COL / TL_STEP_ROW) * TL_CYCLE_PERIOD_IN;

    logic clk;
    logic clk_en;
    logic rst_n;
    logic new_line_input_1;
    logic data_input_valid;
    logic output_valid;
    logic [TL_PE_PAGE_NUM-1:0][TL_DATA_WIDTH-1:0] data_input;
    logic [TL_PE_COL_NUM-1:0][TL_OUT_WIDTH-1:0] y_out;
    logic new_line_out_1;
    logic [TL_DATA_WIDTH-1:0] file_mem [0:TL_MEM_DEPTH-1];
    string input_file_path;
    string output_file_path;

    layer #(
        .LAYER_NUM(TL_LAYER_NUM),
        .PE_PAGE_NUM(TL_PE_PAGE_NUM),
        .PE_ROW_NUM(TL_PE_ROW_NUM),
        .PE_COL_NUM(TL_PE_COL_NUM),
        .MAX_POOL(TL_MAX_POOL),
        .WITH_RELU(TL_WITH_RELU),
        .KERNEL_COL(TL_KERNEL_COL),
        .KERNEL_ROW(TL_KERNEL_ROW),
        .USE_DSP_PE("no"),
        .DATA_WIDTH(TL_DATA_WIDTH),
        .WEIGHT_WIDTH(TL_WEIGHT_WIDTH),
        .CYCLE_PERIOD_IN(TL_CYCLE_PERIOD_IN),
        .CYCLE_PERIOD_OUT(TL_CYCLE_PERIOD_OUT),
        .STEP_COL(TL_STEP_COL),
        .STEP_ROW(TL_STEP_ROW),
        .IMG_COL(TL_IMG_COL),
        .IMG_ROW(TL_IMG_ROW),
        .SHIFT_KEY(TL_SHIFT_KEY),
        .BIAS_WIDTH(TL_BIAS_WIDTH),
        .OUT_WIDTH(TL_OUT_WIDTH),
        .PE_PAGE_OUTPUT_WIDTH(TL_PE_PAGE_OUTPUT_WIDTH),
        .ACC_WIDTH(TL_ACC_WIDTH)
    ) u_layer (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(rst_n),
        .new_line_input_1(new_line_input_1),
        .data_input_valid(data_input_valid),
        .data_input(data_input),
        .y_out(y_out),
        .new_line_out_1(new_line_out_1),
        .output_valid(output_valid)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        if (TARGET_LAYER < 20 || TARGET_LAYER > 31) begin
            $display("Error: tb_layer TARGET_LAYER=%0d is outside LPRNet v10 range 20..31.", TARGET_LAYER);
            $stop;
        end

        case (TARGET_LAYER)
            20: begin input_file_path = INPUT_FILE_PATH_LAYER20; output_file_path = OUTPUT_FILE_PATH_LAYER20; end
            21: begin input_file_path = INPUT_FILE_PATH_LAYER21; output_file_path = OUTPUT_FILE_PATH_LAYER21; end
            22: begin input_file_path = INPUT_FILE_PATH_LAYER22; output_file_path = OUTPUT_FILE_PATH_LAYER22; end
            23: begin input_file_path = INPUT_FILE_PATH_LAYER23; output_file_path = OUTPUT_FILE_PATH_LAYER23; end
            24: begin input_file_path = INPUT_FILE_PATH_LAYER24; output_file_path = OUTPUT_FILE_PATH_LAYER24; end
            25: begin input_file_path = INPUT_FILE_PATH_LAYER25; output_file_path = OUTPUT_FILE_PATH_LAYER25; end
            26: begin input_file_path = INPUT_FILE_PATH_LAYER26; output_file_path = OUTPUT_FILE_PATH_LAYER26; end
            27: begin input_file_path = INPUT_FILE_PATH_LAYER27; output_file_path = OUTPUT_FILE_PATH_LAYER27; end
            28: begin input_file_path = INPUT_FILE_PATH_LAYER28; output_file_path = OUTPUT_FILE_PATH_LAYER28; end
            29: begin input_file_path = INPUT_FILE_PATH_LAYER29; output_file_path = OUTPUT_FILE_PATH_LAYER29; end
            30: begin input_file_path = INPUT_FILE_PATH_LAYER30; output_file_path = OUTPUT_FILE_PATH_LAYER30; end
            default: begin input_file_path = INPUT_FILE_PATH_LAYER31; output_file_path = OUTPUT_FILE_PATH_LAYER31; end
        endcase

        for (int i = 0; i < TL_MEM_DEPTH; i++) file_mem[i] = '0;
        $readmemh(input_file_path, file_mem);
        $display("------------------------------------------------");
        $display("Target layer: %0d", TARGET_LAYER);
        $display("File Read Check from: %s", input_file_path);
        $display("%s", $sformatf("weight_layer%0d_page%0d.mem", TL_LAYER_NUM, 0));
        $display("Mem[0] (Pix0-Ch0): %h", file_mem[0]);
        if (TL_MEM_DEPTH > 1) $display("Mem[1] (Pix0-Ch1): %h", file_mem[1]);
        $display("------------------------------------------------");
    end

    int addr;
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

        for (int index_y = 0; index_y < TL_IMG_ROW * 2; index_y++) begin
            @(posedge clk);
            new_line_input_1 = 1;
            data_input_valid = 0;

            @(posedge clk);
            new_line_input_1 = 0;

            for (int index_x = 0; index_x < TL_IMG_COL; index_x++) begin
                for (int t = 0; t < TL_CYCLE_PERIOD_IN; t++) begin
                    data_input_valid <= 1;
                    for (int p = 0; p < TL_PE_PAGE_NUM; p++) begin
                        addr = (index_y * TL_IMG_COL + index_x) * TL_PE_PAGE_NUM
                             * TL_CYCLE_PERIOD_IN + p * TL_CYCLE_PERIOD_IN + t;
                        data_input[p] <= file_mem[addr % TL_MEM_DEPTH];
                    end
                    @(posedge clk);
                end

                data_input_valid <= 0;
                repeat(TL_OUT_LINE_GAP - TL_CYCLE_PERIOD_IN) @(posedge clk);
            end

            data_input_valid = 0;
            repeat(TL_OUT_LINE_GAP) @(posedge clk);
            $display("Finished driving row %0d at time %t", index_y, $time);
        end

        data_input_valid = 0;
        repeat(300_000) @(posedge clk);
        $stop;
    end

    integer out_file;
    int write_cnt;
    bit write_enable;

    initial begin
        #1;
        out_file = $fopen(output_file_path, "w");
        if (!out_file) begin
            $display("Error: Could not open output file: %s", output_file_path);
            $stop;
        end else begin
            $display("Output file opened: %s", output_file_path);
        end
    end

    final begin
        if (out_file) $fclose(out_file);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_cnt <= 0;
            write_enable <= 0;
        end else if (clk_en) begin
            if (new_line_out_1) begin
                write_enable <= 1;
                $display("\nTime %t: New Line Out detected. Starting capture.", $time);
            end
            if (write_enable && output_valid) begin
                for (int c = 0; c < TL_PE_COL_NUM; c++) begin
                    $fwrite(out_file, "%6h ", y_out[c]);
                end
                $fwrite(out_file, "\n");
                write_cnt <= write_cnt + 1;
            end
        end
    end

`undef SELECT_LPR_PARAM

endmodule
