// =========================================================
// 头文件 Include
// =========================================================
`include "data_process/header/layer0.vh"
`include "data_process/header/layer8.vh"   
`include "data_process/header/layer20.vh"
`include "data_process/header/layer28.vh"  // 新增：用于LPRNet输出维度的宏定义

module top_hdmi_yolo_lprnet_usb (
    input             sys_clk_p,      // 系统差分输入时钟P端 
    input             sys_clk_n,      // 系统差分输入时钟N端 
    input             sys_rst_n,      // 系统复位 

    // USB3.0 接口信号
    output            pclk,           
    output            slcs,           
    inout      [31:0] usb_data,       
    output     [1:0]  usb_addr,       
    output            slrd,           
    output            sloe,           
    output            slwr,           
    input             flaga,          
    input             flagb,          
    input             flagc,          
    input             flagd,          
    output            pktend,         
    output            usb_rest,       
    output            usb_int,

    // HDMI 接口信号
    output            rstn_out,       // 芯片复位信号，低有效
    output            iic_scl,        // I2C的串行时钟信号
    inout             iic_sda,        // I2C的串行数据信号
    
    input             video_clk_in,   // 输入时钟                        
    input             video_vs_in,    // 场同步信号
    input             video_hs_in,    // 行同步信号
    input             video_de_in,    // 数据使能
    input      [23:0] video_rgb_in,   // RGB888颜色数据
   
    output            video_clk_out,  // 输出时钟                        
    output logic      video_vs_out,   // 场同步信号
    output logic      video_hs_out,   // 行同步信号
    output logic      video_de_out,   // 数据使能
    output logic [23:0] video_rgb_out,  // RGB888颜色数据
    output            led1,
    output            led2
);
    
    localparam bit  CONV_POSITIVE = 1;
    localparam int  CONF_WIDTH    = 8;
    localparam int  CONF_THRESH   = 8'h40; // 阈值可调
    localparam int  CROP_HEIGHT   = IMG_ROW_LAYER20;
    localparam int  CROP_WIDTH    = IMG_COL_LAYER20;
    parameter LUT_FILE   = "sigmoid_lut_9bit_to_8bit_h.mem";
    parameter CHARS_FILE = "chars_16x16.mem";
        
    // =========================================================
    // 1. 系统基础信号
    // =========================================================
    wire clk_usb;
    wire clk_usb_dgree;
    wire clk_pe;
    wire clk_cfg;
    wire sys_clk_locked;

    wire init_over;
    wire video_clk_in_bufg;
    wire video_clk_internal; // 内部处理用的视频时钟
    wire locked_video;
    // 全局基础复位（随外部按钮即时响应）
    wire rst_n = sys_rst_n & sys_clk_locked;

    logic        video_vs_out_temp;   // 场同步信号
    logic        video_hs_out_temp;   // 行同步信号
    logic        video_de_out_temp;   // 数据使能
    logic [23:0] video_rgb_out_temp;  // RGB888颜色数据
    
    // =========================================================
    // [核心优化] 业务级帧同步复位 (App Reset) 逻辑
    // 作用：按下复位键时立即拉低；但释放复位键后，必须等待第一个完整的
    //       VSYNC 场同步到来，才释放下游流水线的复位，彻底杜绝半帧死锁。
    // =========================================================
    
    // 1. Video 时钟域的业务复位
    logic rst_n_app_video = 0;
    logic vs_video_d1     = 0;

    always_ff @(posedge video_clk_internal or negedge rst_n) begin
        if (!rst_n) begin
            rst_n_app_video <= 1'b0;
            vs_video_d1     <= 1'b0;
        end else begin
            vs_video_d1 <= video_vs_out_temp;
            // 检测到 VSYNC 上升沿（新的一帧开始），永久释放复位
            if (video_vs_out_temp && !vs_video_d1) begin
                rst_n_app_video <= 1'b1;
            end
        end
    end

    // 2. PE 神经网络时钟域的业务复位
    logic [2:0] vs_pe_sync = 0;
    logic rst_n_app_pe     = 0;

    always_ff @(posedge clk_pe or negedge rst_n) begin
        if (!rst_n) begin
            vs_pe_sync   <= 3'b0;
            rst_n_app_pe <= 1'b0;
        end else begin
            // 跨时钟域抓取 VSYNC
            vs_pe_sync <= {vs_pe_sync[1:0], video_vs_out_temp};
            // 检测到 VSYNC 上升沿，释放 PE 域复位
            if (vs_pe_sync[1] && !vs_pe_sync[2]) begin
                rst_n_app_pe <= 1'b1;
            end
        end
    end

    // =========================================================

    // USB FIFO 接口
    (* mark_debug = "true" *) wire [31:0] hdmi_fifo_data;
    (* mark_debug = "true" *) wire        hdmi_fifo_empty;
    (* mark_debug = "true" *) wire        hdmi_fifo_rd_en;
    (* mark_debug = "true" *) wire        usb_fifo_wr_en;
    (* mark_debug = "true" *) wire [31:0] usb_fifo_data_write;
    
    // 输入数据流 (Adapter -> YOLO)
    (* mark_debug = "true" *) wire [DATA_WIDTH_LAYER0-1:0]  data_to_layer [PE_PAGE_NUM_LAYER0-1:0]; 
    (* mark_debug = "true" *) wire        adapter_valid; 
    (* mark_debug = "true" *) wire        new_line_1;    

    // Layer 8 分支输出 (YOLO -> Adapter)
    wire [OUT_WIDTH_LAYER8-1:0] layer_y_out_layer8 [PE_COL_NUM_LAYER8-1:0];
    wire                        out_valid_layer8;
    wire                        new_line_out_1_layer8;

    // Post Processing 输出 (YOLO -> Adapter)
    (* mark_debug = "true" *) logic [31:0] post_packet_data;
    (* mark_debug = "true" *) logic        post_packet_valid; 
    (* mark_debug = "true" *) logic        post_frame_done;   
                
    
    // =========================================================
    // 2. 时钟与 HDMI 接收 (保持全局 rst_n)
    // =========================================================
    clk_wiz_0 u_clk_wiz_usb_cfg (
        // .clk_out1(clk_pe),
        .clk_out2(clk_cfg),
        .clk_out3(clk_usb),
        .clk_out4(clk_usb_dgree),
        .reset(~sys_rst_n),
        .locked( sys_clk_locked),
        .clk_in1_p(sys_clk_p),
        .clk_in1_n(sys_clk_n)
    );

    BUFG BUFG_inst_hdmi_in (
        .O(video_clk_in_bufg),
        .I(video_clk_in)
    );
    
    clk_wiz_1 u_clk_wiz_video(
        .clk_out1 (video_clk_out),
        .clk_out2 (video_clk_internal),
        .clk_out3 (clk_pe),
        .reset    (~sys_rst_n),
        .locked   (locked_video),
        .clk_in1  (video_clk_in_bufg)
    );

    hdmi_loop_top #(
        .IMG_COL        (IMG_COL_LAYER0),
        .IMG_ROW        (IMG_ROW_LAYER0) 
    ) u_hdmi_loop_top (
        .clk_cfg            (clk_cfg),   
        .clk_pe             (clk_pe),    
        .sys_rst_n          (sys_rst_n), // 保持底层复位
        .video_clk_internal (video_clk_internal),
        .hdmi_fifo_rd_en    (hdmi_fifo_rd_en),   
        .hdmi_fifo_data     (hdmi_fifo_data),    
        .hdmi_fifo_empty    (hdmi_fifo_empty),   
        .init_over          (init_over),
        .rstn_out           (rstn_out),  
        .iic_scl            (iic_scl),    
        .iic_sda            (iic_sda),    
        
        .video_vs_in        (video_vs_in), 
        .video_hs_in        (video_hs_in), 
        .video_de_in        (video_de_in), 
        .video_rgb_in       (video_rgb_in),
        
        .video_vs_out       (video_vs_out_temp), 
        .video_hs_out       (video_hs_out_temp), 
        .video_de_out       (video_de_out_temp), 
        .video_rgb_out      (video_rgb_out_temp) 
    );

    // =========================================================
    // 3. 数据适配器 (使用 rst_n_app_pe)
    // =========================================================
    layer_data_adapter #(
        .DATA_WIDTH(DATA_WIDTH_LAYER0),
        .CHANNEL_IN(PE_PAGE_NUM_LAYER0), 
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER0 / STEP_COL_LAYER0 / STEP_ROW_LAYER0),
        .OUT_WIDTH_POST_33(32),
        .OUT_WIDTH_LAYER23(OUT_WIDTH_LAYER8)
    ) u_layer_data_adapter (
        .clk(clk_pe),
        .rst_n(rst_n_app_pe), // 替换为业务复位
        .usb_fifo_data(hdmi_fifo_data),
        .usb_fifo_empty(hdmi_fifo_empty),
        .usb_rd_en(hdmi_fifo_rd_en),
        
        // 下行: HDMI -> YOLO (Layer 0)
        .new_line_1(new_line_1),        
        .pe_parallel_data(data_to_layer), 
        .input_valid(adapter_valid),
        
        // 上行: YOLO -> HDMI OSD
        .packet_data(post_packet_data),
        .packet_valid(post_packet_valid),
        .frame_done(post_frame_done),   
        .layer23_data(layer_y_out_layer8[0]),
        .layer23_valid(out_valid_layer8),    
        .usb_wr_en(usb_fifo_wr_en),
        .usb_wr_data(usb_fifo_data_write)
    );

    // =========================================================
    // 4. top_yolo 神经网络核心 (使用 rst_n_app_pe)
    // =========================================================
    top_yolo #(
        .LUT_FILE(LUT_FILE),
        .CONV_POSITIVE(CONV_POSITIVE),
        .CONF_WIDTH(CONF_WIDTH),
        .CONF_THRESH(CONF_THRESH)
    ) u_top_yolo (
        .clk(clk_pe),
        .clk_en(sys_clk_locked),
        .rst_n(rst_n_app_pe), // 替换为业务复位

        // 从 Adapter 接收输入数据
        .new_line_input_1(new_line_1),
        .data_input_valid(adapter_valid),
        .data_input(data_to_layer),

        // 输出分支 1
        .layer_y_out_layer8(layer_y_out_layer8),
        .out_valid_layer8(out_valid_layer8),
        .new_line_out_1_layer8(new_line_out_1_layer8),

        // 输出分支 2
        .post_packet_data(post_packet_data),
        .post_packet_valid(post_packet_valid),
        .post_frame_done(post_frame_done)
    );

    // =========================================================
    // 5. 视频 OSD 与 裁剪 (使用 rst_n_app_video)
    // =========================================================
    localparam int MAX_BOX_NUM = 4;

    logic box_wr_en;
    logic [31:0] box_wr_data;
    
    // 子图裁剪相关信号
    logic        start_box_wr [0:MAX_BOX_NUM-1];
    logic        end_box_wr   [0:MAX_BOX_NUM-1];
    logic        crop_wr_en   [0:MAX_BOX_NUM-1];
    logic [15:0] crop_x_min   [0:MAX_BOX_NUM-1]; 
    logic [15:0] crop_y_min   [0:MAX_BOX_NUM-1]; 
    logic [23:0] crop_rgb_out;

    // 画框模块与写字模块中间连线
    logic        video_vs_mid;
    logic        video_hs_mid;
    logic        video_de_mid;
    logic [23:0] video_rgb_mid;

    assign box_wr_en = usb_fifo_wr_en;
    assign box_wr_data = usb_fifo_data_write;

    box_overlay_sync #(
        .IMG_WIDTH(IMG_COL_LAYER0),
        .IMG_HEIGHT(IMG_ROW_LAYER0),
        .CROP_WIDTH(CROP_WIDTH),
        .CROP_HEIGHT(CROP_HEIGHT),
        .GRID_STRIDE_CENTER(16),
        .GRID_STRIDE_LTRB(1),
        .LINE_WIDTH(4),
        .MAX_BOX_NUM(MAX_BOX_NUM)
    ) u_box_overlay_sync (
        .clk_video(video_clk_internal),
        .clk_pe(clk_pe),
        .rst_n(rst_n_app_video), // 替换为业务复位
        
        .video_vs_in(video_vs_out_temp),
        .video_hs_in(video_hs_out_temp),
        .video_de_in(video_de_out_temp),
        .video_rgb_in(video_rgb_out_temp),
        
        // 输出到中间视频流级
        .video_vs_out(video_vs_mid),
        .video_hs_out(video_hs_mid),
        .video_de_out(video_de_mid),
        .video_rgb_out(video_rgb_mid),
        
        .box_wr_en(box_wr_en),
        .box_wr_data(box_wr_data),
        
        // 子图裁剪输出
        .start_box_wr(start_box_wr),
        .end_box_wr  (end_box_wr),
        .crop_x_min(crop_x_min),     
        .crop_y_min(crop_y_min),     
        .crop_wr_en(crop_wr_en),
        .crop_rgb_out(crop_rgb_out)
    );

    // =========================================================
    // 7. LPRNet 子图管理与识别层例化
    // =========================================================
    logic        lprnet_new_line;
    logic        lprnet_data_valid;
    logic [23:0] lprnet_rgb_data;
    logic [DATA_WIDTH_LAYER20-1:0] lprnet_data_in [PE_PAGE_NUM_LAYER20-1:0];
    
    // 从 Manager 输出提取给 char_overlay 使用的当前子图起始坐标
    logic [15:0] crop_x_min_out;
    logic [15:0] crop_y_min_out;

    // 将 24-bit 的 RGB 数据拆分为通道数组匹配 Layer20 输入格式
    assign lprnet_data_in[0] = lprnet_rgb_data[23:16];
    assign lprnet_data_in[1] = lprnet_rgb_data[15:8];
    assign lprnet_data_in[2] = lprnet_rgb_data[7:0];

    localparam int LPRNET_OUT_WIDTH = $clog2(CYCLE_PERIOD_OUT_LAYER28 * PE_COL_NUM_LAYER28);
    (* mark_debug = "true" *) logic [LPRNET_OUT_WIDTH-1:0] lprnet_out_char;
    (* mark_debug = "true" *) logic                        lprnet_out_valid;
    (* mark_debug = "true" *) logic                        lprnet_frame_start;

    // 子图读写缓冲管理 (使用 rst_n_app_video)
    crop_buffer_manager #(
        .MAX_BOX_NUM(MAX_BOX_NUM),
        .LINE_GAP(20_000),  
        .CROP_WIDTH(CROP_WIDTH),
        .CROP_HEIGHT(CROP_HEIGHT),
        .CYCLE_PERIOD(CYCLE_PERIOD_OUT_LAYER20 / STEP_COL_LAYER20 / STEP_ROW_LAYER20)
    ) u_crop_buffer_manager (
        .clk_video   (video_clk_internal),
        .rst_n       (rst_n_app_video), // 替换为业务复位
        
        .start_box_wr(start_box_wr),
        .end_box_wr  (end_box_wr),
        .x_min_in    (crop_x_min),   
        .y_min_in    (crop_y_min),   
        .crop_wr_en  (crop_wr_en),
        .crop_rgb_out(crop_rgb_out),
        
        .clk_pe      (clk_pe),
        .x_min_out   (crop_x_min_out), 
        .y_min_out   (crop_y_min_out),
        .new_line_1  (lprnet_new_line),
        .data_valid  (lprnet_data_valid),
        .data_out    (lprnet_rgb_data)
    );

    // LPRNet 网络推理 (使用 rst_n_app_pe)
    lprnet_top #(
        .CONV_POSITIVE(1),
        .BLANK_CHAR(75)
    ) u_lprnet_top (
        .clk             (clk_pe),
        .clk_en          (sys_clk_locked),
        .rst_n           (rst_n_app_pe), // 替换为业务复位
        
        .new_line_input_1(lprnet_new_line),
        .data_input_valid(lprnet_data_valid),
        .data_input      (lprnet_data_in),
        
        .out_char        (lprnet_out_char),
        .out_valid       (lprnet_out_valid),
        .frame_start_out (lprnet_frame_start)
    );

    // =========================================================
    // 8. OSD 叠加 LPRNet 字符 (char_overlay)
    // =========================================================
    char_overlay #(
        .CROP_HEIGHT(CROP_HEIGHT),
        .FONT_FILE(CHARS_FILE)
    ) u_char_overlay (
        .clk_video   (video_clk_internal),
        .rst_n_video (rst_n_app_video), // 替换为业务复位
        
        .video_vs_in (video_vs_mid),
        .video_hs_in (video_hs_mid),
        .video_de_in (video_de_mid),
        .video_rgb_in(video_rgb_mid),
        
        .video_vs_out(video_vs_out),
        .video_hs_out(video_hs_out),
        .video_de_out(video_de_out),
        .video_rgb_out(video_rgb_out),

        .clk_pe      (clk_pe),
        .rst_n_pe    (rst_n_app_pe),    // 替换为业务复位
        
        .x_min_in    (crop_x_min_out),
        .y_min_in    (crop_y_min_out),
        .new_line_1  (lprnet_new_line),
        
        .out_char    (lprnet_out_char),
        .out_valid   (lprnet_out_valid),
        .frame_start_out(lprnet_frame_start)
    );

    // =========================================================
    // 9. USB 用于字符上传 (保持全局 rst_n)
    // =========================================================  
    usb3_control u_usb3_ctrl (
        .clk_usb(clk_usb),
        .clk_usb_dgree(clk_usb_dgree),
        .clk_spi(clk_pe),          
        .sys_rst_n(rst_n), // USB接口立刻响应，无需等待视频帧同步
        .pclk(pclk),
        .slcs(slcs),
        .usb_data(usb_data),
        .usb_addr(usb_addr),
        .slrd(slrd),
        .sloe(sloe),
        .slwr(slwr),
        .flaga(flaga),
        .flagb(flagb),
        .flagc(flagc),
        .flagd(flagd),
        .pktend(pktend),
        .usb_rest(usb_rest),
        .usb_int(usb_int),
        .down_fifo_data_read(), 
        .down_fifo_empty(),
        .down_fifo_read_en(),
        .spi_sample_clk(), 
        .up_fifo_write_en(lprnet_out_valid),
        .up_fifo_data_write({25'd0, lprnet_out_char}) 
    );

    assign led1 = init_over;
    assign led2 = locked_video;

endmodule