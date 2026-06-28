module ddr_wr_line_ram #(
    parameter BEATS_PER_LINE = 80,
    parameter BANKS          = 4,
    parameter BANK_BITS      = $clog2(BANKS)
) (
    input  logic        wr_clk,
    input  logic        wr_en,
    input  logic [BANK_BITS-1:0] wr_buf_sel,
    input  logic [6:0]  wr_addr,
    input  logic [255:0] wr_data,

    input  logic        rd_clk,
    input  logic        rd_en,
    input  logic [BANK_BITS-1:0] rd_buf_sel,
    input  logic [6:0]  rd_addr,
    output logic [255:0] rd_data
);

    (* ram_style = "block" *) logic [255:0] mem [0:BANKS-1][0:BEATS_PER_LINE-1];

    always @(posedge wr_clk) begin
        if (wr_en) begin
            mem[wr_buf_sel][wr_addr] <= wr_data;
        end
    end

    always @(posedge rd_clk) begin
        if (rd_en) begin
            rd_data <= mem[rd_buf_sel][rd_addr];
        end
    end

endmodule
