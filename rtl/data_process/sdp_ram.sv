module sdp_ram #(
    parameter WIDTH = 21,
    parameter DEPTH = 128
)(
    input  logic             clk,
    input  logic             clk_en,
    input  logic             we,    // 写使能
    input  logic [DEPTH == 1 ? 0 : ($clog2(DEPTH)-1):0] waddr, // 写地址
    input  logic [WIDTH-1:0] wdata, // 写数据
    input  logic             re,    // 读使能
    input  logic [DEPTH == 1 ? 0 : ($clog2(DEPTH)-1):0] raddr, // 读地址
    output logic [WIDTH-1:0] q      // 读数据
);

    logic [WIDTH-1:0] mem [0:DEPTH-1];
    int i;
    initial begin
        for (i = 0; i < DEPTH; i++) begin
            mem[i] = '0;
        end
    end
    always @(posedge clk) begin
        if (clk_en) begin
            if (we) begin
                mem[waddr] <= wdata;
            end
            if (re) begin
                q <= mem[raddr];
            end
        end
    end

endmodule