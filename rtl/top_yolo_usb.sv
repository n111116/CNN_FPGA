// =========================================================
// 头文件 Include
// =========================================================
`include "data_process/header/layer0.vh"
`include "data_process/header/layer8.vh"   
`include "data_process/header/layer20.vh"
`include "data_process/header/layer28.vh"  // 新增：用于LPRNet输出维度的宏定义

module top_yolo_usb (
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
    wire  sys_clk_locked;
    
    // 全局基础复位（随外部按钮即时响应）
    wire rst_n = sys_rst_n & sys_clk_locked;

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
                
    logic        video_vs_out_temp;   // 场同步信号
    logic        video_hs_out_temp;   // 行同步信号
    logic        video_de_out_temp;   // 数据使能
    logic [23:0] video_rgb_out_temp;  // RGB888颜色数据
    
    // =========================================================
    // 2. 时钟与 HDMI 接收 (保持全局 rst_n)
    // =========================================================
    clk_wiz_0 u_clk_wiz_usb_cfg (
        .clk_out1(clk_pe),
        .clk_out2(clk_cfg),
        .clk_out3(clk_usb),
        .clk_out4(clk_usb_dgree),
        .reset(~sys_rst_n),
        .locked( sys_clk_locked),
        .clk_in1_p(sys_clk_p),
        .clk_in1_n(sys_clk_n)
    );

    wire init_over;
    wire video_clk_in_bufg;
    wire video_clk_internal; // 内部处理用的视频时钟
    wire locked_video;

    BUFG BUFG_inst_hdmi_in (
        .O(video_clk_in_bufg),
        .I(video_clk_in)
    );
    
    clk_wiz_1 u_clk_wiz_video(
        .clk_out1 (video_clk_out),
        .clk_out2 (video_clk_internal),
        // .clk_out3 (clk_pe),
        .reset    (~sys_rst_n),
        .locked   (locked_video),
        .clk_in1  (video_clk_in_bufg)
    );

    // =========================================================
    // 3. 数据适配器 (使用 rst_n)
    // =========================================================
    layer_data_adapter #(
        .DATA_WIDTH(DATA_WIDTH_LAYER0),
        .CHANNEL_IN(PE_PAGE_NUM_LAYER0), 
        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER0 / STEP_COL_LAYER0 / STEP_ROW_LAYER0),
        .OUT_WIDTH_POST_33(32),
        .OUT_WIDTH_LAYER23(OUT_WIDTH_LAYER8)
    ) u_layer_data_adapter (
        .clk(clk_pe),
        .rst_n(rst_n), // 替换为业务复位
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
    // 4. top_yolo 神经网络核心 (使用 rst_n)
    // =========================================================
    top_yolo #(
        .LUT_FILE(LUT_FILE),
        .CONV_POSITIVE(CONV_POSITIVE),
        .CONF_WIDTH(CONF_WIDTH),
        .CONF_THRESH(CONF_THRESH)
    ) u_top_yolo (
        .clk(clk_pe),
        .clk_en(sys_clk_locked),
        .rst_n(rst_n), // 替换为业务复位

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
    // 5. USB 接口
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
        .down_fifo_data_read(hdmi_fifo_data), 
        .down_fifo_empty(hdmi_fifo_empty),
        .down_fifo_read_en(hdmi_fifo_rd_en),
        .spi_sample_clk(), 
        .up_fifo_write_en(usb_fifo_wr_en),
        .up_fifo_data_write(usb_fifo_data_write) 
    );

    assign led1 = init_over;
    assign led2 = locked_video;

endmodule