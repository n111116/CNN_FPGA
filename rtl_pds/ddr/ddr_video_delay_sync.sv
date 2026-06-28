module ddr_video_delay_sync #(
    parameter MEM_ROW_ADDR_WIDTH = 15,
    parameter MEM_COL_ADDR_WIDTH = 10,
    parameter MEM_BADDR_WIDTH    = 3,
    parameter MEM_DQ_WIDTH       = 32,
    parameter H_ACT              = 1280,
    parameter V_ACT              = 720,
    parameter H_TOTAL            = 1650,
    parameter H_SYNC             = 40,
    parameter H_BP               = 220,
    parameter H_FP               = 110,
    parameter V_TOTAL            = 750,
    parameter V_SYNC             = 5,
    parameter V_BP               = 20,
    parameter V_FP               = 5
) (
    input  logic        pix_clk,
    input  logic        ddr_ref_clk,
    input  logic        rst_n,

    input  logic        video_vs_in,
    input  logic        video_de_in,
    input  logic [23:0] video_rgb_in,

    input  logic        read_start_toggle,

    output logic        video_vs_out,
    output logic        video_hs_out,
    output logic        video_de_out,
    output logic [23:0] video_rgb_out,
    output logic        frame_start_out,

    output wire         ddr_init_done,

    output wire                              mem_rst_n,
    output wire                              mem_ck,
    output wire                              mem_ck_n,
    output wire                              mem_cke,
    output wire                              mem_cs_n,
    output wire                              mem_ras_n,
    output wire                              mem_cas_n,
    output wire                              mem_we_n,
    output wire                              mem_odt,
    output wire  [MEM_ROW_ADDR_WIDTH-1:0]    mem_a,
    output wire  [MEM_BADDR_WIDTH-1:0]       mem_ba,
    inout  wire  [MEM_DQ_WIDTH/8-1:0]        mem_dqs,
    inout  wire  [MEM_DQ_WIDTH/8-1:0]        mem_dqs_n,
    inout  wire  [MEM_DQ_WIDTH-1:0]          mem_dq,
    output wire  [MEM_DQ_WIDTH/8-1:0]        mem_dm
);

    localparam CTRL_ADDR_WIDTH = MEM_ROW_ADDR_WIDTH + MEM_COL_ADDR_WIDTH + MEM_BADDR_WIDTH;
    localparam WORDS_PER_LINE  = H_ACT / 2;
    localparam BEATS_PER_LINE  = WORDS_PER_LINE / 8;
    localparam LINE_ADDR_STEP  = BEATS_PER_LINE * 8;
    localparam FRAME_STRIDE    = LINE_ADDR_STEP * V_ACT;
    localparam LINE_ADDR_BITS  = (V_ACT <= 2) ? 1 : $clog2(V_ACT + 1);
    localparam MEM_DQS_WIDTH   = MEM_DQ_WIDTH / 8;

    wire [CTRL_ADDR_WIDTH-1:0]  axi_awaddr;
    wire [3:0]                  axi_awuser_id;
    wire [3:0]                  axi_awlen;
    wire                        axi_awready;
    wire                        axi_awvalid;
    wire [MEM_DQ_WIDTH*8-1:0]   axi_wdata;
    wire [MEM_DQ_WIDTH-1:0]     axi_wstrb;
    wire                        axi_wready;
    wire                        axi_wusero_last;
    wire [CTRL_ADDR_WIDTH-1:0]  axi_araddr;
    wire [3:0]                  axi_aruser_id;
    wire [3:0]                  axi_arlen;
    wire                        axi_arready;
    wire                        axi_arvalid;
    wire [MEM_DQ_WIDTH*8-1:0]   axi_rdata;
    wire [3:0]                  axi_rid;
    wire                        axi_rlast;
    wire                        axi_rvalid;
    wire [2:0]                  axi_awsize_unused;
    wire [1:0]                  axi_awburst_unused;
    wire                        axi_wvalid_unused;
    wire                        axi_bready_unused;
    wire [2:0]                  axi_arsize_unused;
    wire [1:0]                  axi_arburst_unused;
    wire                        axi_rready_unused;

    wire                        ddr_clk;
    wire                        pll_lock;
    wire                        phy_pll_lock;
    wire                        gpll_lock;
    wire                        rst_gpll_lock;
    wire                        ddrphy_cpd_lock;
    wire [3:0]                  axi_wusero_id_unused;
    wire                        apb_ready_unused;
    wire [15:0]                 apb_rdata_unused;
    wire [33:0]                 debug_calib_ctrl_unused;
    wire [17*MEM_DQS_WIDTH-1:0] dbg_slice_status_unused;
    wire [22*MEM_DQS_WIDTH-1:0] dbg_slice_state_unused;
    wire [69*MEM_DQS_WIDTH-1:0] debug_data_unused;
    wire [1:0]                  dbg_dll_upd_state_unused;
    wire [8:0]                  debug_gpll_dps_phase_unused;
    wire [2:0]                  dbg_rst_dps_state_unused;
    wire [5:0]                  dbg_tran_err_rst_cnt_unused;
    wire                        dbg_ddrphy_init_fail_unused;
    wire [9:0]                  debug_dps_cnt_dir0_unused;
    wire [9:0]                  debug_dps_cnt_dir1_unused;
    wire [7:0]                  ck_dly_set_bin_unused;
    wire                        align_error_unused;
    wire [3:0]                  debug_rst_state_unused;
    wire [3:0]                  debug_cpd_state_unused;

    logic                       wr_cmd_en;
    logic [CTRL_ADDR_WIDTH-1:0] wr_cmd_addr;
    logic [31:0]                wr_cmd_len;
    wire                        wr_cmd_ready;
    wire                        wr_cmd_done;
    wire                        wr_bac;
    logic [255:0]               wr_ctrl_data;
    wire                        wr_data_re;

    logic                       rd_cmd_en;
    logic [CTRL_ADDR_WIDTH-1:0] rd_cmd_addr;
    logic [31:0]                rd_cmd_len;
    wire                        rd_cmd_ready;
    wire                        rd_cmd_done;
    wire [255:0]                rd_data;
    wire                        rd_data_en;

    logic video_vs_d1;
    logic video_de_d1;
    logic input_frame_seen;
    logic wr_frame_bank;
    logic [LINE_ADDR_BITS-1:0] wr_line;
    logic [15:0] wr_rgb565_d1;
    logic wr_pixel_phase;
    logic [2:0] wr_pack_cnt;
    logic [6:0] wr_beat_wr_addr;
    logic [6:0] wr_beat_write_addr;
    logic [255:0] wr_beat_shift;
    logic [255:0] wr_beat_data;
    logic wr_beat_valid;
    logic wr_line_buf_sel;
    logic line_flush_toggle_pix;
    logic flush_frame_bank_pix;
    logic [LINE_ADDR_BITS-1:0] flush_line_pix;
    logic flush_buf_sel_pix;

    logic [2:0] flush_sync;
    logic flush_toggle_ddr;
    logic flush_toggle_ddr_d1;
    logic flush_pulse_ddr;
    logic flush_buf_sel_ddr;
    logic flush_frame_bank_ddr;
    logic [LINE_ADDR_BITS-1:0] flush_line_ddr;
    logic [6:0] wr_beat_addr;
    logic [6:0] wr_line_ram_rd_addr;
    logic wr_line_ram_rd_buf;
    logic wr_line_rd_buf;
    logic [255:0] wr_line_data;
    logic pending_flush_ddr;

    localparam [1:0] WR_IDLE = 2'd0;
    localparam [1:0] WR_SEND = 2'd1;
    localparam [1:0] WR_WAIT = 2'd2;
    logic [1:0] wr_state;

    logic [2:0] read_start_pix_sync;
    logic read_req_toggle_pix;
    logic read_start_toggle_d1_pix;
    logic read_req_pending_pix;
    logic read_bank_pix;
    logic [2:0] read_start_sync;
    logic read_start_ddr_pulse;
    logic [2:0] read_bank_sync;
    logic pending_read;
    logic pending_read_bank;
    logic rd_frame_bank_ddr;
    logic rd_output_busy_ddr;
    logic [LINE_ADDR_BITS-1:0] rd_req_line;
    logic rd_fill_buf_sel;
    logic [6:0] rd_wr_beat_addr;
    logic [1:0] line_ready_ddr;
    logic [1:0] line_ready_toggle_ddr;
    logic consume_toggle_pix;
    logic [2:0] consume_sync;
    logic consume_toggle_ddr;
    logic consume_toggle_ddr_d1;
    logic consume_pulse_ddr;
    logic consume_buf_ddr;
    logic output_done_toggle_pix;
    logic [2:0] output_done_sync;
    logic output_done_toggle_ddr;
    logic output_done_toggle_ddr_d1;
    logic output_done_pulse_ddr;

    localparam [1:0] RD_IDLE = 2'd0;
    localparam [1:0] RD_REQ  = 2'd1;
    localparam [1:0] RD_FILL = 2'd2;
    localparam [1:0] RD_WAIT = 2'd3;
    logic [1:0] rd_state;

    logic output_active;
    logic [11:0] h_cnt;
    logic [11:0] v_cnt;
    logic [10:0] out_x;
    logic out_rd_buf_sel;
    logic [6:0] out_rd_addr;
    logic [6:0] out_line_ram_rd_addr;
    logic [2:0] out_word_sel;
    logic [255:0] out_line_data;
    logic [31:0] out_word;
    logic [15:0] out_rgb565;
    logic [1:0] de_pipe;
    logic [1:0] hs_pipe;
    logic [1:0] vs_pipe;
    logic [23:0] rgb_pipe0;
    logic [23:0] rgb_pipe1;
    logic line_ready_pix0;
    logic line_ready_pix1;
    logic [2:0] line0_ready_sync;
    logic [2:0] line1_ready_sync;
    logic line0_ready_event;
    logic line1_ready_event;
    logic active_area;
    logic output_line_done;
    logic rd_fill_line_ready;

    wire [15:0] video_rgb565_in = {video_rgb_in[23:19], video_rgb_in[15:10], video_rgb_in[7:3]};
    wire [23:0] out_rgb888 = {
        out_rgb565[15:11], out_rgb565[15:13],
        out_rgb565[10:5],  out_rgb565[10:9],
        out_rgb565[4:0],   out_rgb565[4:2]
    };
    wire [31:0] flush_addr32 = (flush_frame_bank_ddr ? FRAME_STRIDE : 0) +
                               flush_line_ddr * LINE_ADDR_STEP;
    wire [CTRL_ADDR_WIDTH-1:0] flush_line_addr = flush_addr32[CTRL_ADDR_WIDTH-1:0];
    wire [31:0] rd_addr32 = (rd_frame_bank_ddr ? FRAME_STRIDE : 0) +
                            rd_req_line * LINE_ADDR_STEP;
    wire [CTRL_ADDR_WIDTH-1:0] rd_line_addr = rd_addr32[CTRL_ADDR_WIDTH-1:0];

    wire input_vs_rise = video_vs_in && !video_vs_d1;
    wire input_de_rise = video_de_in && !video_de_d1;
    wire input_de_fall = !video_de_in && video_de_d1;

    always @(posedge pix_clk or negedge rst_n) begin
        if (!rst_n) begin
            video_vs_d1             <= 1'b0;
            video_de_d1             <= 1'b0;
            read_start_pix_sync     <= 3'b0;
            read_req_toggle_pix     <= 1'b0;
            read_start_toggle_d1_pix <= 1'b0;
            read_req_pending_pix    <= 1'b0;
            read_bank_pix           <= 1'b0;
            input_frame_seen        <= 1'b0;
            wr_frame_bank           <= 1'b0;
            wr_line                 <= '0;
            wr_rgb565_d1            <= 16'd0;
            wr_pixel_phase          <= 1'b0;
            wr_pack_cnt             <= 3'd0;
            wr_beat_wr_addr         <= 7'd0;
            wr_beat_write_addr      <= 7'd0;
            wr_beat_shift           <= 256'd0;
            wr_beat_data            <= 256'd0;
            wr_beat_valid           <= 1'b0;
            wr_line_buf_sel         <= 1'b0;
            line_flush_toggle_pix   <= 1'b0;
            flush_frame_bank_pix    <= 1'b0;
            flush_line_pix          <= '0;
            flush_buf_sel_pix       <= 1'b0;
        end else begin
            video_vs_d1 <= video_vs_in;
            video_de_d1 <= video_de_in;
            read_start_pix_sync <= {read_start_pix_sync[1:0], read_start_toggle};
            read_start_toggle_d1_pix <= read_start_pix_sync[2];
            wr_beat_valid <= 1'b0;

            if (read_req_pending_pix) begin
                read_req_toggle_pix <= ~read_req_toggle_pix;
                read_req_pending_pix <= 1'b0;
            end else if (read_start_toggle_d1_pix ^ read_start_pix_sync[2]) begin
                read_bank_pix <= wr_frame_bank;
                read_req_pending_pix <= 1'b1;
            end

            if (input_vs_rise) begin
                input_frame_seen <= 1'b1;
                wr_line          <= '0;
                wr_pack_cnt      <= 3'd0;
                wr_pixel_phase   <= 1'b0;
                wr_beat_wr_addr  <= 7'd0;
                if (input_frame_seen) begin
                    wr_frame_bank <= ~wr_frame_bank;
                end
            end else if (input_de_rise) begin
                wr_pack_cnt     <= 3'd0;
                wr_pixel_phase  <= 1'b0;
                wr_beat_wr_addr <= 7'd0;
            end

            if (video_de_in) begin
                wr_rgb565_d1 <= video_rgb565_in;
                wr_pixel_phase <= ~wr_pixel_phase;
                if (wr_pixel_phase) begin
                    case (wr_pack_cnt)
                        3'd0: wr_beat_shift[31:0]    <= {wr_rgb565_d1, video_rgb565_in};
                        3'd1: wr_beat_shift[63:32]   <= {wr_rgb565_d1, video_rgb565_in};
                        3'd2: wr_beat_shift[95:64]   <= {wr_rgb565_d1, video_rgb565_in};
                        3'd3: wr_beat_shift[127:96]  <= {wr_rgb565_d1, video_rgb565_in};
                        3'd4: wr_beat_shift[159:128] <= {wr_rgb565_d1, video_rgb565_in};
                        3'd5: wr_beat_shift[191:160] <= {wr_rgb565_d1, video_rgb565_in};
                        3'd6: wr_beat_shift[223:192] <= {wr_rgb565_d1, video_rgb565_in};
                        default: wr_beat_shift[255:224] <= {wr_rgb565_d1, video_rgb565_in};
                    endcase
                    if (wr_pack_cnt == 3'd7) begin
                        wr_beat_data  <= {wr_rgb565_d1, video_rgb565_in, wr_beat_shift[223:0]};
                        wr_beat_write_addr <= wr_beat_wr_addr;
                        wr_beat_valid <= 1'b1;
                        wr_pack_cnt   <= 3'd0;
                        if (wr_beat_wr_addr < BEATS_PER_LINE - 1) begin
                            wr_beat_wr_addr <= wr_beat_wr_addr + 1'b1;
                        end
                    end else begin
                        wr_pack_cnt <= wr_pack_cnt + 1'b1;
                    end
                end
            end

            if (input_de_fall && video_de_d1) begin
                flush_frame_bank_pix  <= wr_frame_bank;
                flush_line_pix        <= wr_line;
                flush_buf_sel_pix     <= wr_line_buf_sel;
                line_flush_toggle_pix <= ~line_flush_toggle_pix;
                wr_line_buf_sel       <= ~wr_line_buf_sel;
                if (wr_line < V_ACT - 1) begin
                    wr_line <= wr_line + 1'b1;
                end
            end
        end
    end

    assign wr_line_ram_rd_addr = (wr_data_re && (wr_beat_addr < BEATS_PER_LINE - 1)) ?
                                 (wr_beat_addr + 1'b1) : wr_beat_addr;
    assign wr_line_ram_rd_buf = ((wr_state == WR_IDLE) && pending_flush_ddr && wr_cmd_ready && ddr_init_done) ?
                                flush_buf_sel_ddr : wr_line_rd_buf;

    ddr_wr_line_ram #(
        .BEATS_PER_LINE(BEATS_PER_LINE),
        .BANKS         (2),
        .BANK_BITS     (1)
    ) u_wr_line_ram (
        .wr_clk    (pix_clk),
        .wr_en     (wr_beat_valid),
        .wr_buf_sel(wr_line_buf_sel),
        .wr_addr   (wr_beat_write_addr),
        .wr_data   (wr_beat_data),

        .rd_clk    (ddr_clk),
        .rd_en     (1'b1),
        .rd_buf_sel(wr_line_ram_rd_buf),
        .rd_addr   (wr_line_ram_rd_addr),
        .rd_data   (wr_line_data)
    );

    always @(posedge ddr_clk or negedge rst_n) begin
        if (!rst_n) begin
            flush_sync           <= 3'b0;
            flush_toggle_ddr_d1  <= 1'b0;
            flush_frame_bank_ddr <= 1'b0;
            flush_line_ddr       <= '0;
            flush_buf_sel_ddr    <= 1'b0;
        end else begin
            flush_sync <= {flush_sync[1:0], line_flush_toggle_pix};
            flush_toggle_ddr_d1 <= flush_toggle_ddr;
            if (flush_pulse_ddr && !pending_flush_ddr) begin
                flush_frame_bank_ddr <= flush_frame_bank_pix;
                flush_line_ddr       <= flush_line_pix;
                flush_buf_sel_ddr    <= flush_buf_sel_pix;
            end
        end
    end

    assign flush_toggle_ddr = flush_sync[2];
    assign flush_pulse_ddr  = flush_toggle_ddr ^ flush_toggle_ddr_d1;

    always @(posedge ddr_clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_state       <= WR_IDLE;
            wr_cmd_en      <= 1'b0;
            wr_cmd_addr    <= '0;
            wr_cmd_len     <= 32'd0;
            wr_beat_addr   <= 7'd0;
            wr_line_rd_buf <= 1'b0;
            pending_flush_ddr <= 1'b0;
        end else begin
            wr_cmd_en <= 1'b0;

            if (flush_pulse_ddr && !pending_flush_ddr) begin
                pending_flush_ddr <= 1'b1;
            end

            case (wr_state)
                WR_IDLE: begin
                    if (pending_flush_ddr && wr_cmd_ready && ddr_init_done) begin
                        wr_line_rd_buf <= flush_buf_sel_ddr;
                        wr_beat_addr   <= 7'd0;
                        wr_cmd_addr    <= flush_line_addr;
                        wr_cmd_len     <= BEATS_PER_LINE;
                        wr_cmd_en      <= 1'b1;
                        pending_flush_ddr <= 1'b0;
                        wr_state       <= WR_SEND;
                    end
                end
                WR_SEND: begin
                    if (wr_data_re && (wr_beat_addr < BEATS_PER_LINE - 1)) begin
                        wr_beat_addr <= wr_beat_addr + 1'b1;
                    end
                    if (wr_cmd_done) begin
                        wr_state <= WR_WAIT;
                    end
                end
                WR_WAIT: begin
                    wr_state <= WR_IDLE;
                end
                default: wr_state <= WR_IDLE;
            endcase
        end
    end

    assign wr_ctrl_data = wr_line_data;

    always @(posedge ddr_clk or negedge rst_n) begin
        if (!rst_n) begin
            read_start_sync        <= 3'b0;
            read_bank_sync         <= 3'b0;
            pending_read           <= 1'b0;
            pending_read_bank      <= 1'b0;
            rd_frame_bank_ddr      <= 1'b0;
            rd_output_busy_ddr     <= 1'b0;
            rd_req_line            <= '0;
            rd_fill_buf_sel        <= 1'b0;
            rd_wr_beat_addr        <= 7'd0;
            line_ready_ddr         <= 2'b0;
            line_ready_toggle_ddr  <= 2'b0;
            consume_sync           <= 3'b0;
            consume_toggle_ddr_d1  <= 1'b0;
            consume_buf_ddr        <= 1'b0;
            output_done_sync       <= 3'b0;
            output_done_toggle_ddr_d1 <= 1'b0;
            rd_state               <= RD_IDLE;
            rd_cmd_en              <= 1'b0;
            rd_cmd_addr            <= '0;
            rd_cmd_len             <= 32'd0;
        end else begin
            read_start_sync <= {read_start_sync[1:0], read_req_toggle_pix};
            read_bank_sync  <= {read_bank_sync[1:0], read_bank_pix};
            consume_sync    <= {consume_sync[1:0], consume_toggle_pix};
            consume_toggle_ddr_d1 <= consume_toggle_ddr;
            output_done_sync <= {output_done_sync[1:0], output_done_toggle_pix};
            output_done_toggle_ddr_d1 <= output_done_toggle_ddr;
            rd_cmd_en <= 1'b0;

            if (consume_pulse_ddr) begin
                if (consume_buf_ddr) begin
                    line_ready_ddr[1] <= 1'b0;
                end else begin
                    line_ready_ddr[0] <= 1'b0;
                end
                consume_buf_ddr <= ~consume_buf_ddr;
            end

            if (read_start_ddr_pulse) begin
                pending_read <= 1'b1;
                pending_read_bank <= read_bank_sync[2];
            end

            case (rd_state)
                RD_IDLE: begin
                    if (pending_read && !rd_output_busy_ddr && ddr_init_done) begin
                        rd_frame_bank_ddr <= pending_read_bank;
                        rd_req_line       <= '0;
                        rd_fill_buf_sel   <= 1'b0;
                        line_ready_ddr    <= 2'b0;
                        consume_buf_ddr   <= 1'b0;
                        rd_output_busy_ddr <= 1'b1;
                        pending_read      <= 1'b0;
                        rd_state          <= RD_REQ;
                    end
                end
                RD_REQ: begin
                    if (rd_req_line < V_ACT && rd_cmd_ready && !rd_fill_line_ready) begin
                        rd_cmd_addr     <= rd_line_addr;
                        rd_cmd_len      <= BEATS_PER_LINE;
                        rd_cmd_en       <= 1'b1;
                        rd_wr_beat_addr <= 7'd0;
                        rd_state        <= RD_FILL;
                    end else if (rd_req_line >= V_ACT) begin
                        rd_state <= RD_WAIT;
                    end
                end
                RD_FILL: begin
                    if (rd_data_en && (rd_wr_beat_addr < BEATS_PER_LINE - 1)) begin
                        rd_wr_beat_addr <= rd_wr_beat_addr + 1'b1;
                    end
                    if (rd_cmd_done) begin
                        if (rd_fill_buf_sel) begin
                            line_ready_ddr[1] <= 1'b1;
                            line_ready_toggle_ddr[1] <= ~line_ready_toggle_ddr[1];
                        end else begin
                            line_ready_ddr[0] <= 1'b1;
                            line_ready_toggle_ddr[0] <= ~line_ready_toggle_ddr[0];
                        end
                        rd_fill_buf_sel <= ~rd_fill_buf_sel;
                        if (rd_req_line < V_ACT - 1) begin
                            rd_req_line <= rd_req_line + 1'b1;
                            rd_state    <= RD_REQ;
                        end else begin
                            rd_req_line <= V_ACT;
                            rd_state    <= RD_WAIT;
                        end
                    end
                end
                RD_WAIT: begin
                    if (output_done_pulse_ddr) begin
                        rd_output_busy_ddr <= 1'b0;
                        rd_state <= RD_IDLE;
                    end
                end
                default: rd_state <= RD_IDLE;
            endcase
        end
    end

    assign read_start_ddr_pulse = read_start_sync[1] ^ read_start_sync[2];
    assign consume_toggle_ddr = consume_sync[2];
    assign consume_pulse_ddr = consume_toggle_ddr ^ consume_toggle_ddr_d1;
    assign output_done_toggle_ddr = output_done_sync[2];
    assign output_done_pulse_ddr = output_done_toggle_ddr ^ output_done_toggle_ddr_d1;
    assign line0_ready_event = line0_ready_sync[1] ^ line0_ready_sync[2];
    assign line1_ready_event = line1_ready_sync[1] ^ line1_ready_sync[2];

    assign out_line_ram_rd_addr = (output_active && active_area && out_x[0] &&
                                   (out_word_sel == 3'd7) &&
                                   (out_rd_addr < BEATS_PER_LINE - 1)) ?
                                  (out_rd_addr + 1'b1) : out_rd_addr;

    ddr_rd_line_ram #(
        .BEATS_PER_LINE(BEATS_PER_LINE)
    ) u_rd_line_ram (
        .wr_clk    (ddr_clk),
        .wr_en     (rd_data_en),
        .wr_buf_sel(rd_fill_buf_sel),
        .wr_addr   (rd_wr_beat_addr),
        .wr_data   (rd_data),

        .rd_clk    (pix_clk),
        .rd_buf_sel(out_rd_buf_sel),
        .rd_en     (1'b1),
        .rd_addr   (out_line_ram_rd_addr),
        .rd_data   (out_line_data)
    );

    always @* begin
        active_area = (v_cnt >= V_SYNC + V_BP) && (v_cnt < V_SYNC + V_BP + V_ACT) &&
                      (h_cnt >= H_SYNC + H_BP) && (h_cnt < H_SYNC + H_BP + H_ACT);
        output_line_done = active_area && (out_x == H_ACT - 1);
        rd_fill_line_ready = rd_fill_buf_sel ? line_ready_ddr[1] : line_ready_ddr[0];
    end

    always @(posedge pix_clk or negedge rst_n) begin
        if (!rst_n) begin
            output_active         <= 1'b0;
            h_cnt                 <= 12'd0;
            v_cnt                 <= 12'd0;
            out_x                 <= 11'd0;
            out_rd_buf_sel        <= 1'b0;
            out_rd_addr           <= 7'd0;
            out_word_sel          <= 3'd0;
            consume_toggle_pix    <= 1'b0;
            output_done_toggle_pix <= 1'b0;
            video_vs_out          <= 1'b0;
            video_hs_out          <= 1'b0;
            video_de_out          <= 1'b0;
            video_rgb_out         <= 24'd0;
            frame_start_out       <= 1'b0;
            line0_ready_sync      <= 3'b0;
            line1_ready_sync      <= 3'b0;
            line_ready_pix0       <= 1'b0;
            line_ready_pix1       <= 1'b0;
            de_pipe               <= 2'b0;
            hs_pipe               <= 2'b0;
            vs_pipe               <= 2'b0;
            rgb_pipe0             <= 24'd0;
            rgb_pipe1             <= 24'd0;
        end else begin
            frame_start_out <= 1'b0;
            line0_ready_sync <= {line0_ready_sync[1:0], line_ready_toggle_ddr[0]};
            line1_ready_sync <= {line1_ready_sync[1:0], line_ready_toggle_ddr[1]};

            if (line0_ready_event) begin
                line_ready_pix0 <= 1'b1;
            end
            if (line1_ready_event) begin
                line_ready_pix1 <= 1'b1;
            end

            if (!output_active && line_ready_pix0) begin
                output_active   <= 1'b1;
                h_cnt           <= 12'd0;
                v_cnt           <= 12'd0;
                out_x           <= 11'd0;
                out_rd_buf_sel  <= 1'b0;
                out_rd_addr     <= 7'd0;
                out_word_sel    <= 3'd0;
                frame_start_out <= 1'b1;
            end else if (output_active) begin
                if (h_cnt == H_TOTAL - 1) begin
                    h_cnt <= 12'd0;
                    if (v_cnt == V_TOTAL - 1) begin
                        v_cnt <= 12'd0;
                        output_active <= 1'b0;
                        output_done_toggle_pix <= ~output_done_toggle_pix;
                    end else begin
                        v_cnt <= v_cnt + 1'b1;
                    end
                end else begin
                    h_cnt <= h_cnt + 1'b1;
                end
            end

            vs_pipe <= {vs_pipe[0], output_active && (v_cnt < V_SYNC)};
            hs_pipe <= {hs_pipe[0], output_active && (h_cnt < H_SYNC)};
            de_pipe <= {de_pipe[0], output_active && active_area};
            rgb_pipe0 <= (output_active && active_area) ? out_rgb888 : 24'd0;
            rgb_pipe1 <= rgb_pipe0;

            if (output_active && active_area) begin
                if (out_x[0]) begin
                    if (out_word_sel == 3'd7) begin
                        out_word_sel <= 3'd0;
                        out_rd_addr  <= out_rd_addr + 1'b1;
                    end else begin
                        out_word_sel <= out_word_sel + 1'b1;
                    end
                end

                if (output_line_done) begin
                    out_x <= 11'd0;
                    out_rd_addr <= 7'd0;
                    out_word_sel <= 3'd0;
                    consume_toggle_pix <= ~consume_toggle_pix;
                    if (out_rd_buf_sel) begin
                        line_ready_pix1 <= line1_ready_event;
                    end else begin
                        line_ready_pix0 <= line0_ready_event;
                    end
                    out_rd_buf_sel <= ~out_rd_buf_sel;
                end else begin
                    out_x <= out_x + 1'b1;
                end
            end

            video_vs_out  <= vs_pipe[1];
            video_hs_out  <= hs_pipe[1];
            video_de_out  <= de_pipe[1];
            video_rgb_out <= de_pipe[1] ? rgb_pipe1 : 24'd0;
        end
    end

    always @* begin
        case (out_word_sel)
            3'd0: out_word = out_line_data[31:0];
            3'd1: out_word = out_line_data[63:32];
            3'd2: out_word = out_line_data[95:64];
            3'd3: out_word = out_line_data[127:96];
            3'd4: out_word = out_line_data[159:128];
            3'd5: out_word = out_line_data[191:160];
            3'd6: out_word = out_line_data[223:192];
            default: out_word = out_line_data[255:224];
        endcase
        out_rgb565 = out_x[0] ? out_word[15:0] : out_word[31:16];
    end

    wr_rd_ctrl_top #(
        .CTRL_ADDR_WIDTH(CTRL_ADDR_WIDTH),
        .MEM_DQ_WIDTH   (MEM_DQ_WIDTH)
    ) u_wr_rd_ctrl_top (
        .clk         (ddr_clk),
        .rstn        (ddr_init_done),
        .wr_cmd_en   (wr_cmd_en),
        .wr_cmd_addr (wr_cmd_addr),
        .wr_cmd_len  (wr_cmd_len),
        .wr_cmd_ready(wr_cmd_ready),
        .wr_cmd_done (wr_cmd_done),
        .wr_bac      (wr_bac),
        .wr_ctrl_data(wr_ctrl_data),
        .wr_data_re  (wr_data_re),
        .rd_cmd_en   (rd_cmd_en),
        .rd_cmd_addr (rd_cmd_addr),
        .rd_cmd_len  (rd_cmd_len),
        .rd_cmd_ready(rd_cmd_ready),
        .rd_cmd_done (rd_cmd_done),
        .read_ready  (1'b1),
        .read_rdata  (rd_data),
        .read_en     (rd_data_en),
        .axi_awaddr  (axi_awaddr),
        .axi_awid    (axi_awuser_id),
        .axi_awlen   (axi_awlen),
        .axi_awsize  (axi_awsize_unused),
        .axi_awburst (axi_awburst_unused),
        .axi_awready (axi_awready),
        .axi_awvalid (axi_awvalid),
        .axi_wdata   (axi_wdata),
        .axi_wstrb   (axi_wstrb),
        .axi_wlast   (axi_wusero_last),
        .axi_wvalid  (axi_wvalid_unused),
        .axi_wready  (axi_wready),
        .axi_bid     (4'd0),
        .axi_bresp   (2'd0),
        .axi_bvalid  (1'b0),
        .axi_bready  (axi_bready_unused),
        .axi_araddr  (axi_araddr),
        .axi_arid    (axi_aruser_id),
        .axi_arlen   (axi_arlen),
        .axi_arsize  (axi_arsize_unused),
        .axi_arburst (axi_arburst_unused),
        .axi_arvalid (axi_arvalid),
        .axi_arready (axi_arready),
        .axi_rready  (axi_rready_unused),
        .axi_rdata   (axi_rdata),
        .axi_rvalid  (axi_rvalid),
        .axi_rlast   (axi_rlast),
        .axi_rid     (axi_rid),
        .axi_rresp   (2'd0)
    );

    ddr3_test u_ddr3_test (
        .ref_clk                (ddr_ref_clk),
        .resetn                 (rst_n),
        .core_clk               (ddr_clk),
        .pll_lock               (pll_lock),
        .phy_pll_lock           (phy_pll_lock),
        .gpll_lock              (gpll_lock),
        .rst_gpll_lock          (rst_gpll_lock),
        .ddrphy_cpd_lock        (ddrphy_cpd_lock),
        .ddr_init_done          (ddr_init_done),
        .axi_awaddr             (axi_awaddr),
        .axi_awuser_ap          (1'b0),
        .axi_awuser_id          (axi_awuser_id),
        .axi_awlen              (axi_awlen),
        .axi_awready            (axi_awready),
        .axi_awvalid            (axi_awvalid),
        .axi_wdata              (axi_wdata),
        .axi_wstrb              (axi_wstrb),
        .axi_wready             (axi_wready),
        .axi_wusero_id          (axi_wusero_id_unused),
        .axi_wusero_last        (axi_wusero_last),
        .axi_araddr             (axi_araddr),
        .axi_aruser_ap          (1'b0),
        .axi_aruser_id          (axi_aruser_id),
        .axi_arlen              (axi_arlen),
        .axi_arready            (axi_arready),
        .axi_arvalid            (axi_arvalid),
        .axi_rdata              (axi_rdata),
        .axi_rid                (axi_rid),
        .axi_rlast              (axi_rlast),
        .axi_rvalid             (axi_rvalid),
        .apb_clk                (1'b0),
        .apb_rst_n              (1'b1),
        .apb_sel                (1'b0),
        .apb_enable             (1'b0),
        .apb_addr               (8'd0),
        .apb_write              (1'b0),
        .apb_ready              (apb_ready_unused),
        .apb_wdata              (16'd0),
        .apb_rdata              (apb_rdata_unused),
        .mem_cs_n               (mem_cs_n),
        .mem_rst_n              (mem_rst_n),
        .mem_ck                 (mem_ck),
        .mem_ck_n               (mem_ck_n),
        .mem_cke                (mem_cke),
        .mem_ras_n              (mem_ras_n),
        .mem_cas_n              (mem_cas_n),
        .mem_we_n               (mem_we_n),
        .mem_odt                (mem_odt),
        .mem_a                  (mem_a),
        .mem_ba                 (mem_ba),
        .mem_dqs                (mem_dqs),
        .mem_dqs_n              (mem_dqs_n),
        .mem_dq                 (mem_dq),
        .mem_dm                 (mem_dm),
        .dbg_gate_start         (1'b0),
        .dbg_cpd_start          (1'b0),
        .dbg_ddrphy_rst_n       (1'b1),
        .dbg_gpll_scan_rst      (1'b0),
        .samp_position_dyn_adj  (1'b0),
        .init_samp_position_even(32'd0),
        .init_samp_position_odd (32'd0),
        .wrcal_position_dyn_adj (1'b0),
        .init_wrcal_position    (32'd0),
        .force_read_clk_ctrl    (1'b0),
        .init_slip_step         (16'd0),
        .init_read_clk_ctrl     (12'd0),
        .debug_calib_ctrl       (debug_calib_ctrl_unused),
        .dbg_slice_status       (dbg_slice_status_unused),
        .dbg_slice_state        (dbg_slice_state_unused),
        .debug_data             (debug_data_unused),
        .dbg_dll_upd_state      (dbg_dll_upd_state_unused),
        .debug_gpll_dps_phase   (debug_gpll_dps_phase_unused),
        .dbg_rst_dps_state      (dbg_rst_dps_state_unused),
        .dbg_tran_err_rst_cnt   (dbg_tran_err_rst_cnt_unused),
        .dbg_ddrphy_init_fail   (dbg_ddrphy_init_fail_unused),
        .debug_cpd_offset_adj   (1'b0),
        .debug_cpd_offset_dir   (1'b0),
        .debug_cpd_offset       (10'd0),
        .debug_dps_cnt_dir0     (debug_dps_cnt_dir0_unused),
        .debug_dps_cnt_dir1     (debug_dps_cnt_dir1_unused),
        .ck_dly_en              (1'b0),
        .init_ck_dly_step       (8'd0),
        .ck_dly_set_bin         (ck_dly_set_bin_unused),
        .align_error            (align_error_unused),
        .debug_rst_state        (debug_rst_state_unused),
        .debug_cpd_state        (debug_cpd_state_unused)
    );

endmodule
