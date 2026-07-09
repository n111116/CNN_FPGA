// =========================================================
// 头文件 Include
// =========================================================
`include "data_process/header/layer0.vh"
`include "data_process/header/layer7.vh"   
`include "data_process/header/layer20.vh"
`include "data_process/header/layer24.vh"
`include "data_process/header/layer31.vh"  // 用于LPRNet输出维度的宏定义

`define UD #1

module hdmi_loop #(
    parameter   X_WIDTH = 4'd12,
    parameter   Y_WIDTH = 4'd12,
    parameter   IMG_COL = 128,      
    parameter   IMG_ROW = 128,
    
    // 网络配置及 OSD 相关参数
    parameter   LUT_FILE   = "mem_data/sigmoid_lut_9bit_to_8bit_h.mem",
    parameter   CHARS_FILE = "../data_process/mem_data/chars_16x16.mem"
)(
    input  wire       sys_clk       , // input system clock 50MHz    
    input  wire       rst_n         ,  
    output            rstn_out      ,
    output            hd_scl        ,
    inout             hd_sda        ,
    output            led_int       ,
    output            ddr_init_done ,

    // DDR3
    input             clk_p         ,
    input             clk_n         ,
    output            mem_rst_n     ,
    output            mem_ck        ,
    output            mem_ck_n      ,
    output            mem_cke       ,
    output            mem_cs_n      ,
    output            mem_ras_n     ,
    output            mem_cas_n     ,
    output            mem_we_n      ,
    output            mem_odt       ,
    output [14:0]     mem_a         ,
    output [2:0]      mem_ba        ,
    inout  [3:0]      mem_dqs       ,
    inout  [3:0]      mem_dqs_n     ,
    inout  [31:0]     mem_dq        ,
    output [3:0]      mem_dm        ,
    
    // hdmi_out 
    output            tmds_clk_n    , 
    output            tmds_clk_p    , 
    output [2:0]      tmds_data_n   , 
    output [2:0]      tmds_data_p   , 

    // HDMI_IN
    input             pixclk_in     ,                            
    input             vs_in         , 
    input             hs_in         , 
    input             de_in         ,
    input     [7:0]   r_in          , 
    input     [7:0]   g_in          , 
    input     [7:0]   b_in          
);

    // =========================================================
    // 0. 局部参数及连线声明
    // =========================================================
    localparam bit CONV_POSITIVE = 1;
    localparam int CONF_WIDTH    = 8;
    localparam int CONF_THRESH   = 8'h40; // 阈值可调
    localparam int CROP_HEIGHT   = IMG_ROW_LAYER20;
    localparam int CROP_WIDTH    = IMG_COL_LAYER20;
    localparam int MAX_BOX_NUM   = 6;
    localparam int HDMI_FIFO_MIN_DEPTH = IMG_COL / 2;
    localparam int HDMI_FIFO_DEPTH =
        (HDMI_FIFO_MIN_DEPTH <= 2)     ? 2     :
        (HDMI_FIFO_MIN_DEPTH <= 4)     ? 4     :
        (HDMI_FIFO_MIN_DEPTH <= 8)     ? 8     :
        (HDMI_FIFO_MIN_DEPTH <= 16)    ? 16    :
        (HDMI_FIFO_MIN_DEPTH <= 32)    ? 32    :
        (HDMI_FIFO_MIN_DEPTH <= 64)    ? 64    :
        (HDMI_FIFO_MIN_DEPTH <= 128)   ? 128   :
        (HDMI_FIFO_MIN_DEPTH <= 256)   ? 256   :
        (HDMI_FIFO_MIN_DEPTH <= 512)   ? 512   :
        (HDMI_FIFO_MIN_DEPTH <= 1024)  ? 1024  :
        (HDMI_FIFO_MIN_DEPTH <= 2048)  ? 2048  :
        (HDMI_FIFO_MIN_DEPTH <= 4096)  ? 4096  :
        (HDMI_FIFO_MIN_DEPTH <= 8192)  ? 8192  :
        (HDMI_FIFO_MIN_DEPTH <= 16384) ? 16384 :
        (HDMI_FIFO_MIN_DEPTH <= 32768) ? 32768 : 65536;
    localparam int LPRNET_OUT_WIDTH = $clog2(CYCLE_PERIOD_OUT_LAYER31 * PE_COL_NUM_LAYER31);

    wire                        pix_clk_5x ;
    wire                        cfg_clk    ;
    wire                        ddr_ref_clk;
    wire                        locked     ;
    wire                        init_over  ;
    wire                        rx_init_done;
    wire                        rx_rst_n   ;  
    wire                        pixclk_out ;  // 充当 video_clk_internal
    wire                        clk_pe     ;
    reg  [15:0]                 rstn_1ms   ;
    // --- 视频流两级打拍 (用于边缘检测与同步) ---
    reg                         vs_in_dly1, vs_in_dly2;
    reg                         hs_in_dly1, hs_in_dly2;
    reg                         de_in_dly1, de_in_dly2;
    reg  [23:0]                 rgb_in_dly1, rgb_in_dly2;
    
    // --- 业务层网络用到的信号 ---
    logic rst_n_app_video = 0;
    logic vs_video_d1     = 0;
    logic [2:0] vs_pe_sync= 0;
    logic rst_n_app_pe    = 0;

    // FIFO 相关
    reg                         hdmi_fifo_wr_en;
    reg  [31:0]                 hdmi_fifo_data_wr;
    wire                        hdmi_fifo_full;
    wire [31:0]                 hdmi_fifo_dout;
    wire                        hdmi_fifo_empty;
    wire                        hdmi_fifo_rd_en; // 网络层的读使能

    wire        usb_fifo_wr_en;
    wire [31:0] usb_fifo_data_write;
    
    // 输入数据流 (Adapter -> YOLO) (已修改为标准压缩数组)
    wire [PE_PAGE_NUM_LAYER0-1:0][DATA_WIDTH_LAYER0-1:0]  data_to_layer ; 
    wire        adapter_valid; 
    wire        new_line_1;    

    // Layer 8 分支输出 (YOLO -> Adapter) (已修改为标准压缩数组)
    wire [PE_COL_NUM_LAYER7-1:0][OUT_WIDTH_LAYER7-1:0] layer_y_out_layer7;
    wire                        out_valid_layer7;
    wire                        new_line_out_1_layer7;

    // Post Processing 输出 (YOLO -> Adapter)
    logic [31:0] post_packet_data;
    logic        post_packet_valid; 
    logic        post_frame_done;   
    logic [$clog2(IMG_ROW_LAYER7)-1:0] layer7_line_cnt;
    logic        ddr_read_start_toggle;
    
    // 画框模块与写字模块中间连线
    logic        video_vs_mid;
    logic        video_hs_mid;
    logic        video_de_mid;
    logic [23:0] video_rgb_mid;
    
    // 最终准备送往 TMDS 的输出信号
    wire         final_vs_out;
    wire         final_hs_out;
    wire         final_de_out;
    wire  [23:0] final_rgb_out;

    // DDR 延迟后的视频流，作为 overlay/crop 的底图
    logic        ddr_video_vs;
    logic        ddr_video_hs;
    logic        ddr_video_de;
    logic [23:0] ddr_video_rgb;

    // 子图裁剪与 LPRNet 通信信号 (已修改为标准 [MAX-1:0] 压缩数组)
    logic        box_wr_en;
    logic [31:0] box_wr_data;
    logic [MAX_BOX_NUM-1:0]        start_crop_wr;
    logic [MAX_BOX_NUM-1:0]        end_crop_wr;
    logic [MAX_BOX_NUM-1:0]        crop_wr_en;
    logic [MAX_BOX_NUM-1:0][15:0]  crop_x_min; 
    logic [MAX_BOX_NUM-1:0][15:0]  crop_y_min; 
    logic [MAX_BOX_NUM-1:0][15:0]  crop_w0;  // [新增] 连接引脚
    logic [MAX_BOX_NUM-1:0][15:0]  crop_h0;  // [新增] 连接引脚
    logic [MAX_BOX_NUM-1:0][23:0]  crop_rgb_out;

    logic        lprnet_new_line/*synthesis PAP_MARK_DEBUG="1"*/;
    logic        lprnet_data_valid/*synthesis PAP_MARK_DEBUG="1"*/;
    logic [23:0] lprnet_rgb_data/*synthesis PAP_MARK_DEBUG="1"*/;
    logic [PE_PAGE_NUM_LAYER20-1:0] [DATA_WIDTH_LAYER20-1:0] lprnet_data_in ;
    logic [15:0] crop_x_min_out/*synthesis PAP_MARK_DEBUG="1"*/;
    logic [15:0] crop_y_min_out/*synthesis PAP_MARK_DEBUG="1"*/;
    
    logic [LPRNET_OUT_WIDTH-1:0] lprnet_out_char/*synthesis PAP_MARK_DEBUG="1"*/;
    logic                        lprnet_out_valid/*synthesis PAP_MARK_DEBUG="1"*/;
    logic                        lprnet_frame_start/*synthesis PAP_MARK_DEBUG="1"*/;
    logic                        char_seen_latch/*synthesis PAP_MARK_DEBUG="1"*/;


    // =========================================================
    // 1. 系统基础配置与时钟/复位管理
    // =========================================================
    assign pixclk_out = pixclk_in;
    assign led_int    = char_seen_latch;

    always_ff @(posedge clk_pe or negedge rstn_out) begin
        if (!rstn_out) begin
            char_seen_latch <= 1'b0;
        end else if (lprnet_frame_start || lprnet_out_valid) begin
            char_seen_latch <= 1'b1;
        end
    end

    GTP_INBUFGDS #(
        .IOSTANDARD("DEFAULT"),
        .TERM_DIFF("ON")
    ) u_ddr_refclk_buf (
        .O (ddr_ref_clk),
        .I (clk_p),
        .IB(clk_n)
    );

    PLL u_pll (
      .clkout1(pix_clk_5x),    
      .clkout2(clk_pe),    
      .lock(    ),             
      .clkin1(pixclk_out)      
    );

    ms72 u_ms72 (
      .clkout0(cfg_clk),       
      .lock(locked),           
      .clkin1(sys_clk)         
    );

    ms72xx_ctl ms72xx_ctl(
        .clk         (  cfg_clk    ), 
        .rst_n       (  rstn_out   ), 
               
        .init_over_rx(  rx_init_done),                 
        .init_over   (  init_over  ), 
        .iic_scl     (  hd_scl     ), 
        .iic_sda     (  hd_sda     )  
    );

    always @(posedge cfg_clk or negedge rst_n) begin
        if(!rst_n)
            rstn_1ms <= 16'd0;
        else begin
            if(rstn_1ms == 16'h2710)
                rstn_1ms <= rstn_1ms;
            else
                rstn_1ms <= rstn_1ms + 1'b1;
        end
    end

    assign rstn_out = (rstn_1ms == 16'h2710);


    // =========================================================
    // 2. 业务级帧同步复位 (App Reset) 
    // =========================================================
    // 采用稳定复位rstn_out，并确保复位后等待第一个完整场同步才释放
    
    // Video 域业务复位
    always_ff @(posedge pixclk_out or negedge rstn_out) begin
        if (!rstn_out) begin
            rst_n_app_video <= 1'b0;
            vs_video_d1     <= 1'b0;
        end else begin
            vs_video_d1 <= vs_in_dly2;
            if (vs_in_dly2 && !vs_video_d1) begin
                rst_n_app_video <= 1'b1;
            end
        end
    end

    // PE 域业务复位
    always_ff @(posedge clk_pe or negedge rstn_out) begin
        if (!rstn_out) begin
            vs_pe_sync   <= 3'b0;
            rst_n_app_pe <= 1'b0;
        end else begin
            vs_pe_sync <= {vs_pe_sync[1:0], vs_in_dly2};
            if (vs_pe_sync[1] && !vs_pe_sync[2]) begin
                rst_n_app_pe <= 1'b1;
            end
        end
    end


    // =========================================================
    // 3. HDMI 视频输入信号打拍与 FIFO 写入
    // =========================================================
    always @(posedge pixclk_out) begin
        if (!rstn_out) begin
            vs_in_dly1 <= 0; vs_in_dly2 <= 0;
            hs_in_dly1 <= 0; hs_in_dly2 <= 0;
            de_in_dly1 <= 0; de_in_dly2 <= 0;
            rgb_in_dly1<= 0; rgb_in_dly2<= 0;
        end else begin
            vs_in_dly1 <= vs_in; hs_in_dly1 <= hs_in; de_in_dly1 <= de_in;
            vs_in_dly2 <= vs_in_dly1; hs_in_dly2 <= hs_in_dly1; de_in_dly2 <= de_in_dly1;
            
            rgb_in_dly1 <= {r_in, g_in, b_in};
            rgb_in_dly2 <= rgb_in_dly1;
        end
    end 
    
    always @(posedge pixclk_out or negedge rstn_out) begin
        if(!rstn_out) begin
            hdmi_fifo_wr_en <= 1'b0;
            hdmi_fifo_data_wr <= 32'd0;
        end else begin
            // de上升沿写入 0xFF_00_00_00 作为行首标记
            if(de_in_dly1 & ~de_in_dly2) begin
                hdmi_fifo_wr_en   <= 1'b1; 
                hdmi_fifo_data_wr <= 32'hFF_00_00_00;
            end else if(de_in_dly2) begin
                hdmi_fifo_wr_en   <= 1'b1;
                hdmi_fifo_data_wr[31:24] <= 8'd0; // 高 8 位填充 0
                hdmi_fifo_data_wr[7 :0 ] <= rgb_in_dly2[23:16]; // R
                hdmi_fifo_data_wr[15:8 ] <= rgb_in_dly2[15:8 ]; // G
                hdmi_fifo_data_wr[23:16] <= rgb_in_dly2[7 :0 ]; // B // 高 8 位填充 0, 之后 B G R
            end else begin
                hdmi_fifo_wr_en   <= 1'b0;
            end
        end
    end
    
    // 视频帧特征 FIFO，支持外部模块读写并联 
    my_fifo #(
        .DATA_WIDTH(32),
        .FIFO_DEPTH(HDMI_FIFO_DEPTH)
    ) u_hdmi_fifo (
        .rd_clk         (clk_pe),
        .wr_clk         (pixclk_out),
        .rst            (~rst_n),
        .wr_en          (hdmi_fifo_wr_en),
        .din            (hdmi_fifo_data_wr),
        .rd_en          (hdmi_fifo_rd_en),
        .dout           (hdmi_fifo_dout),
        .full           (hdmi_fifo_full),
        .empty          (hdmi_fifo_empty)
    );
    


    // =========================================================
    // 4. 数据适配器与 YOLO 神经网络推理核心
    // =========================================================
    layer_data_adapter #(
        .DATA_WIDTH(DATA_WIDTH_LAYER0),
        .CHANNEL_IN(PE_PAGE_NUM_LAYER0), 
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER0 / STEP_COL_LAYER0 / STEP_ROW_LAYER0),
        .OUT_WIDTH_POST_33(32),
        .OUT_WIDTH_LAYER23(OUT_WIDTH_LAYER7)
    ) u_layer_data_adapter (
        .clk              (clk_pe),
        .rst_n            (rst_n_app_pe), 
        .usb_fifo_data    (hdmi_fifo_dout),   // 对接本地 FIFO 读出
        .usb_fifo_empty   (hdmi_fifo_empty),
        .usb_rd_en        (hdmi_fifo_rd_en),       // 由 Adapter 产生内部网络读请求
        
        .new_line_1       (new_line_1),        
        .pe_parallel_data (data_to_layer), 
        .input_valid      (adapter_valid),
        
        .packet_data      (post_packet_data),
        .packet_valid     (post_packet_valid),
        .frame_done       (post_frame_done),   
        .layer23_data     (layer_y_out_layer7[0]),
        .layer23_valid    (out_valid_layer7),    
        .usb_wr_en        (usb_fifo_wr_en),
        .usb_wr_data      (usb_fifo_data_write)
    );

    top_yolo #(
        .LUT_FILE(LUT_FILE),
        .CONV_POSITIVE(CONV_POSITIVE),
        .CONF_WIDTH(CONF_WIDTH),
        .CONF_THRESH(CONF_THRESH)
    ) u_top_yolo (
        .clk                  (clk_pe),
        .clk_en               (1'b1), 
        .rst_n                (rst_n_app_pe), 
    
        .new_line_input_1     (new_line_1),
        .data_input_valid     (adapter_valid),      
        .data_input           (data_to_layer),
    
        .layer_y_out_layer7   (layer_y_out_layer7),
        .out_valid_layer7     (out_valid_layer7),
        .new_line_out_1_layer7(new_line_out_1_layer7),
    
        .post_packet_data     (post_packet_data),
        .post_packet_valid    (post_packet_valid),
        .post_frame_done      (post_frame_done)
    );

    always_ff @(posedge clk_pe or negedge rst_n_app_pe) begin
        if (!rst_n_app_pe) begin
            layer7_line_cnt <= '0;
            ddr_read_start_toggle <= 1'b0;
        end else if (new_line_out_1_layer7) begin
            if (layer7_line_cnt == '0) begin
                ddr_read_start_toggle <= ~ddr_read_start_toggle;
            end

            if (layer7_line_cnt == IMG_ROW_LAYER7 - 1) begin
                layer7_line_cnt <= '0;
            end else begin
                layer7_line_cnt <= layer7_line_cnt + 1'b1;
            end
        end
    end

    ddr_video_delay_sync #(
        .H_ACT   (1280),
        .V_ACT   (720),
        .H_TOTAL (1650),
        .H_SYNC  (40),
        .H_BP    (220),
        .H_FP    (110),
        .V_TOTAL (750),
        .V_SYNC  (5),
        .V_BP    (20),
        .V_FP    (5)
    ) u_ddr_video_delay_sync (
        .pix_clk          (pixclk_out),
        .ddr_ref_clk      (ddr_ref_clk),
        .rst_n            (rstn_out),
        .video_vs_in      (vs_in_dly2),
        .video_de_in      (de_in_dly2),
        .video_rgb_in     (rgb_in_dly2),
        .read_start_toggle(ddr_read_start_toggle),
        .video_vs_out     (ddr_video_vs),
        .video_hs_out     (ddr_video_hs),
        .video_de_out     (ddr_video_de),
        .video_rgb_out    (ddr_video_rgb),
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


    // =========================================================
    // 5. 视频级 OSD: 目标框图叠加 (Box Overlay)
    // =========================================================
    assign box_wr_en   = usb_fifo_wr_en;
    assign box_wr_data = usb_fifo_data_write;

    box_overlay_sync #(
        .IMG_WIDTH(IMG_COL_LAYER0),
        .IMG_HEIGHT(IMG_ROW_LAYER0),
        .CROP_WIDTH(CROP_WIDTH),
        .CROP_HEIGHT(CROP_HEIGHT),
        .GRID_STRIDE_CENTER(16),
        .GRID_STRIDE_LTRB(2),  // 模型更改后，LTBR的scale变了
        .LINE_WIDTH(4),
        .MAX_BOX_NUM(MAX_BOX_NUM)
    ) u_box_overlay_sync (
        .clk_video   (pixclk_out),
        .clk_pe      (clk_pe),
        .rst_n       (rst_n_app_video), 
        
        // 输入信号为 DDR 读回的同帧底图视频流
        .video_vs_in (ddr_video_vs),
        .video_hs_in (ddr_video_hs),
        .video_de_in (ddr_video_de),
        .video_rgb_in(ddr_video_rgb),
        
        // 第一级处理后的 OSD 视频流
        .video_vs_out(video_vs_mid),
        .video_hs_out(video_hs_mid),
        .video_de_out(video_de_mid),
        .video_rgb_out(video_rgb_mid),
        
        .box_wr_en   (box_wr_en),
        .box_wr_data (box_wr_data),
        
        // 子图裁剪输出供 LPRNet 识别
        .start_crop_wr(start_crop_wr),
        .end_crop_wr  (end_crop_wr),
        .crop_x_min   (crop_x_min),     
        .crop_y_min   (crop_y_min),    
        // .crop_w0      (crop_w0),     // [新增]
        // .crop_h0      (crop_h0),     // [新增] 
        .crop_wr_en   (crop_wr_en),
        .crop_rgb_out (crop_rgb_out)
    );


    // =========================================================
    // 6. LPRNet 子图裁剪管理与车牌号推理识别
    // =========================================================
    assign lprnet_data_in[0] = lprnet_rgb_data[23:16];
    assign lprnet_data_in[1] = lprnet_rgb_data[15:8];
    assign lprnet_data_in[2] = lprnet_rgb_data[7:0];

    crop_buffer_manager #(
        .MAX_BOX_NUM(MAX_BOX_NUM),
        .LINE_GAP((((CYCLE_PERIOD_OUT_LAYER24 / STEP_COL_LAYER24 / STEP_ROW_LAYER24)) * CYCLE_PERIOD_IN_LAYER24 
                * IMG_COL_LAYER24  / STEP_ROW_LAYER20)),  
        .CROP_WIDTH(CROP_WIDTH),
        .CROP_HEIGHT(CROP_HEIGHT),
        .CYCLE_PERIOD(CYCLE_PERIOD_OUT_LAYER20 / STEP_COL_LAYER20 / STEP_ROW_LAYER20)
    ) u_crop_buffer_manager (
        .clk_video   (pixclk_out),
        .rst_n       (rst_n_app_video),
        
        .start_crop_wr(start_crop_wr),
        .end_crop_wr  (end_crop_wr),
        .x_min_in    (crop_x_min),   
        .y_min_in    (crop_y_min),  
        // .crop_w0     (crop_w0),     // [新增]
        // .crop_h0     (crop_h0),     // [新增] 
        .crop_wr_en  (crop_wr_en),
        .crop_rgb_out(crop_rgb_out),
        
        .clk_pe      (clk_pe),
        .x_min_out   (crop_x_min_out), 
        .y_min_out   (crop_y_min_out),
        .new_line_1  (lprnet_new_line),
        .data_valid  (lprnet_data_valid),
        .data_out    (lprnet_rgb_data)
    );

    lprnet_top #(
        .CONV_POSITIVE(1),
        .BLANK_CHAR(75),
        .VALID_CHAR_NUM(76)
    ) u_lprnet_top (
        .clk             (clk_pe),
        .clk_en          (1'b1),
        .rst_n           (rstn_out), 
        
        .new_line_input_1(lprnet_new_line),
        .data_input_valid(lprnet_data_valid),
        .data_input      (lprnet_data_in),
        
        .out_char        (lprnet_out_char),
        .out_valid       (lprnet_out_valid),
        .frame_start_out (lprnet_frame_start)
    );


    // =========================================================
    // 7. 视频级 OSD: 字符叠加模块与最终显示 (Char Overlay)
    // =========================================================
    char_overlay #(
        .CROP_HEIGHT(CROP_HEIGHT),
        .CHAR_NUM(76),
        .FONT_FILE(CHARS_FILE)
    ) u_char_overlay (
        .clk_video   (pixclk_out),
        .rst_n_video (rst_n), 
        
        // 接收已画框的视频源流
        .video_vs_in (video_vs_mid),
        .video_hs_in (video_hs_mid),
        .video_de_in (video_de_mid),
        .video_rgb_in(video_rgb_mid),
        
        // 最终加上车牌字符后的 OSD 输出
        .video_vs_out(final_vs_out),
        .video_hs_out(final_hs_out),
        .video_de_out(final_de_out),
        .video_rgb_out(final_rgb_out),

        .clk_pe      (clk_pe),
        .rst_n_pe    (rst_n_app_pe),    
        
        .x_min_in    (crop_x_min_out),
        .y_min_in    (crop_y_min_out),
        .new_line_1  (lprnet_new_line),
        
        .out_char    (lprnet_out_char),
        .out_valid   (lprnet_out_valid),
        .frame_start_out(lprnet_frame_start)
    );


    // =========================================================
    // 8. 视频输出转换为 TMDS 电平协议
    // =========================================================
    // 将附加了 OSD 和所有识别处理逻辑的视频流转发给 TMDS 输出
    rgb2tmds rgb2tmds (
        .tmds_clk_p         (  tmds_clk_p             ),
        .tmds_clk_n         (  tmds_clk_n             ),
        .tmds_data_p        (  tmds_data_p            ),
        .tmds_data_n        (  tmds_data_n            ),
                                                    
        .rstn               (  rstn_out               ), 
                                                      
        .vid_pdata          (  final_rgb_out          ),
        .vid_pvde           (  final_de_out           ),
        .vid_phsync         (  final_hs_out           ),
        .vid_pvsync         (  final_vs_out           ),
        .pixelclk           (  pixclk_in              ),
                                                      
        .serialclk          (  pix_clk_5x             )
   ); 

endmodule
