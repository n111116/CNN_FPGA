`timescale 1ns/1ps

module ddr3_test #(
    parameter int MEM_ROW_WIDTH    = 15,
    parameter int MEM_COLUMN_WIDTH = 10,
    parameter int MEM_BANK_WIDTH   = 3,
    parameter int MEM_DQ_WIDTH     = 32,
    parameter int MEM_DM_WIDTH     = 4,
    parameter int MEM_DQS_WIDTH    = 4,
    parameter int CTRL_ADDR_WIDTH  = MEM_ROW_WIDTH + MEM_COLUMN_WIDTH + MEM_BANK_WIDTH,
    parameter int MEMORY_ADDR_BITS = 17
) (
    input                              ref_clk,
    input                              resetn,
    output                             core_clk,
    output                             pll_lock,
    output                             phy_pll_lock,
    output                             gpll_lock,
    output                             rst_gpll_lock,
    output                             ddrphy_cpd_lock,
    output logic                       ddr_init_done,

    input  [CTRL_ADDR_WIDTH-1:0]       axi_awaddr,
    input                              axi_awuser_ap,
    input  [3:0]                       axi_awuser_id,
    input  [3:0]                       axi_awlen,
    output                             axi_awready,
    input                              axi_awvalid,

    input  [8*MEM_DQ_WIDTH-1:0]        axi_wdata,
    input  [MEM_DQ_WIDTH-1:0]          axi_wstrb,
    output                             axi_wready,
    output [3:0]                       axi_wusero_id,
    output                             axi_wusero_last,

    input  [CTRL_ADDR_WIDTH-1:0]       axi_araddr,
    input                              axi_aruser_ap,
    input  [3:0]                       axi_aruser_id,
    input  [3:0]                       axi_arlen,
    output                             axi_arready,
    input                              axi_arvalid,

    output [8*MEM_DQ_WIDTH-1:0]        axi_rdata,
    output [3:0]                       axi_rid,
    output                             axi_rlast,
    output                             axi_rvalid,

    input                              apb_clk,
    input                              apb_rst_n,
    input                              apb_sel,
    input                              apb_enable,
    input  [7:0]                       apb_addr,
    input                              apb_write,
    output                             apb_ready,
    input  [15:0]                      apb_wdata,
    output [15:0]                      apb_rdata,

    output                             mem_cs_n,
    output                             mem_rst_n,
    output                             mem_ck,
    output                             mem_ck_n,
    output                             mem_cke,
    output                             mem_ras_n,
    output                             mem_cas_n,
    output                             mem_we_n,
    output                             mem_odt,
    output [MEM_ROW_WIDTH-1:0]         mem_a,
    output [MEM_BANK_WIDTH-1:0]        mem_ba,
    inout  [MEM_DQS_WIDTH-1:0]         mem_dqs,
    inout  [MEM_DQS_WIDTH-1:0]         mem_dqs_n,
    inout  [MEM_DQ_WIDTH-1:0]          mem_dq,
    output [MEM_DM_WIDTH-1:0]          mem_dm,

    input                              dbg_gate_start,
    input                              dbg_cpd_start,
    input                              dbg_ddrphy_rst_n,
    input                              dbg_gpll_scan_rst,
    input                              samp_position_dyn_adj,
    input  [8*MEM_DQS_WIDTH-1:0]       init_samp_position_even,
    input  [8*MEM_DQS_WIDTH-1:0]       init_samp_position_odd,
    input                              wrcal_position_dyn_adj,
    input  [8*MEM_DQS_WIDTH-1:0]       init_wrcal_position,
    input                              force_read_clk_ctrl,
    input  [4*MEM_DQS_WIDTH-1:0]       init_slip_step,
    input  [3*MEM_DQS_WIDTH-1:0]       init_read_clk_ctrl,
    output [33:0]                      debug_calib_ctrl,
    output [17*MEM_DQS_WIDTH-1:0]      dbg_slice_status,
    output [22*MEM_DQS_WIDTH-1:0]      dbg_slice_state,
    output [69*MEM_DQS_WIDTH-1:0]      debug_data,
    output [1:0]                       dbg_dll_upd_state,
    output [8:0]                       debug_gpll_dps_phase,
    output [2:0]                       dbg_rst_dps_state,
    output [5:0]                       dbg_tran_err_rst_cnt,
    output                             dbg_ddrphy_init_fail,
    input                              debug_cpd_offset_adj,
    input                              debug_cpd_offset_dir,
    input  [9:0]                       debug_cpd_offset,
    output [9:0]                       debug_dps_cnt_dir0,
    output [9:0]                       debug_dps_cnt_dir1,
    input                              ck_dly_en,
    input  [7:0]                       init_ck_dly_step,
    output [7:0]                       ck_dly_set_bin,
    output                             align_error,
    output [3:0]                       debug_rst_state,
    output [3:0]                       debug_cpd_state
);

    localparam int MEM_WORDS = 1 << MEMORY_ADDR_BITS;

    logic [8*MEM_DQ_WIDTH-1:0] memory [0:MEM_WORDS-1];
    logic [7:0] init_cnt;

    logic write_active;
    logic [MEMORY_ADDR_BITS-1:0] write_addr;
    logic [3:0] write_len;
    logic [3:0] write_count;
    logic [3:0] write_id;

    logic read_active;
    logic [MEMORY_ADDR_BITS-1:0] read_addr;
    logic [3:0] read_len;
    logic [3:0] read_count;
    logic [3:0] read_id;
    logic [8*MEM_DQ_WIDTH-1:0] axi_rdata_q;
    logic [3:0] axi_rid_q;
    logic axi_rlast_q;
    logic axi_rvalid_q;

    assign core_clk         = ref_clk;
    assign pll_lock         = ddr_init_done;
    assign phy_pll_lock     = ddr_init_done;
    assign gpll_lock        = ddr_init_done;
    assign rst_gpll_lock    = ddr_init_done;
    assign ddrphy_cpd_lock  = ddr_init_done;

    assign axi_awready      = ddr_init_done && !write_active;
    assign axi_wready       = ddr_init_done && write_active;
    assign axi_wusero_id    = write_id;
    assign axi_wusero_last  = write_active && (write_count == write_len);

    assign axi_arready      = ddr_init_done && !read_active;
    assign axi_rdata        = axi_rdata_q;
    assign axi_rid          = axi_rid_q;
    assign axi_rlast        = axi_rlast_q;
    assign axi_rvalid       = axi_rvalid_q;

    assign apb_ready        = 1'b1;
    assign apb_rdata        = 16'd0;

    assign mem_cs_n         = 1'b1;
    assign mem_rst_n        = resetn;
    assign mem_ck           = ref_clk;
    assign mem_ck_n         = ~ref_clk;
    assign mem_cke          = 1'b1;
    assign mem_ras_n        = 1'b1;
    assign mem_cas_n        = 1'b1;
    assign mem_we_n         = 1'b1;
    assign mem_odt          = 1'b0;
    assign mem_a            = '0;
    assign mem_ba           = '0;
    assign mem_dm           = '0;
    assign mem_dqs          = 'z;
    assign mem_dqs_n        = 'z;
    assign mem_dq           = 'z;

    assign debug_calib_ctrl = '0;
    assign dbg_slice_status = '0;
    assign dbg_slice_state  = '0;
    assign debug_data       = '0;
    assign dbg_dll_upd_state = '0;
    assign debug_gpll_dps_phase = '0;
    assign dbg_rst_dps_state = '0;
    assign dbg_tran_err_rst_cnt = '0;
    assign dbg_ddrphy_init_fail = 1'b0;
    assign debug_dps_cnt_dir0 = '0;
    assign debug_dps_cnt_dir1 = '0;
    assign ck_dly_set_bin    = '0;
    assign align_error       = 1'b0;
    assign debug_rst_state   = '0;
    assign debug_cpd_state   = '0;

    function automatic [MEMORY_ADDR_BITS-1:0] word_addr(
        input [CTRL_ADDR_WIDTH-1:0] byte_addr
    );
        word_addr = byte_addr[MEMORY_ADDR_BITS+2:3];
    endfunction

    always_ff @(posedge ref_clk or negedge resetn) begin
        if (!resetn) begin
            init_cnt      <= 8'd0;
            ddr_init_done <= 1'b0;
        end else if (!ddr_init_done) begin
            init_cnt <= init_cnt + 1'b1;
            if (init_cnt == 8'd20) begin
                ddr_init_done <= 1'b1;
            end
        end
    end

    always_ff @(posedge ref_clk or negedge resetn) begin
        if (!resetn) begin
            write_active <= 1'b0;
            write_addr   <= '0;
            write_len    <= 4'd0;
            write_count  <= 4'd0;
            write_id     <= 4'd0;
        end else begin
            if (axi_awvalid && axi_awready) begin
                write_active <= 1'b1;
                write_addr   <= word_addr(axi_awaddr);
                write_len    <= axi_awlen;
                write_count  <= 4'd0;
                write_id     <= axi_awuser_id;
            end else if (axi_wready) begin
                memory[write_addr] <= axi_wdata;
                write_addr <= write_addr + 1'b1;
                if (write_count == write_len) begin
                    write_active <= 1'b0;
                    write_count  <= 4'd0;
                end else begin
                    write_count <= write_count + 1'b1;
                end
            end
        end
    end

    always_ff @(posedge ref_clk or negedge resetn) begin
        if (!resetn) begin
            read_active  <= 1'b0;
            read_addr    <= '0;
            read_len     <= 4'd0;
            read_count   <= 4'd0;
            read_id      <= 4'd0;
            axi_rdata_q  <= '0;
            axi_rid_q    <= 4'd0;
            axi_rlast_q  <= 1'b0;
            axi_rvalid_q <= 1'b0;
        end else begin
            axi_rvalid_q <= read_active;
            axi_rlast_q  <= read_active && (read_count == read_len);
            axi_rid_q    <= read_id;

            if (read_active) begin
                axi_rdata_q <= memory[read_addr];
                read_addr <= read_addr + 1'b1;
                if (read_count == read_len) begin
                    read_active <= 1'b0;
                    read_count  <= 4'd0;
                end else begin
                    read_count <= read_count + 1'b1;
                end
            end

            if (axi_arvalid && axi_arready) begin
                read_active <= 1'b1;
                read_addr   <= word_addr(axi_araddr);
                read_len    <= axi_arlen;
                read_count  <= 4'd0;
                read_id     <= axi_aruser_id;
            end
        end
    end

endmodule
