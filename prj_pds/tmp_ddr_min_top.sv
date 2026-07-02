module tmp_ddr_min_top (
    input         pix_clk,
    input         clk_p,
    input         clk_n,
    input         rst_n,
    input         video_vs_in,
    input         video_de_in,
    input  [23:0] video_rgb_in,
    input         read_start_toggle,
    output        video_vs_out,
    output        video_hs_out,
    output        video_de_out,
    output [23:0] video_rgb_out,
    output        ddr_init_done,
    output        mem_rst_n,
    output        mem_ck,
    output        mem_ck_n,
    output        mem_cke,
    output        mem_cs_n,
    output        mem_ras_n,
    output        mem_cas_n,
    output        mem_we_n,
    output        mem_odt,
    output [14:0] mem_a,
    output [2:0]  mem_ba,
    inout  [3:0]  mem_dqs,
    inout  [3:0]  mem_dqs_n,
    inout  [31:0] mem_dq,
    output [3:0]  mem_dm
);

    wire ddr_ref_clk;

    GTP_INBUFGDS #(
        .IOSTANDARD("DEFAULT"),
        .TERM_DIFF("ON")
    ) u_ddr_refclk_buf (
        .O (ddr_ref_clk),
        .I (clk_p),
        .IB(clk_n)
    );

    ddr_video_delay_sync u_ddr_video_delay_sync (
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
        .frame_start_out  (),
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

endmodule
