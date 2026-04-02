module hdmi_loop_top#(
    parameter int unsigned IMG_COL          = 128, 
    parameter int unsigned IMG_ROW          = 128
)
(
    input         		clk_cfg,
    input         		clk_pe,
    input         		video_clk_internal,
    input         		sys_rst_n,     
    
    input               hdmi_fifo_rd_en,
    output       [31:0] hdmi_fifo_data,
    output              hdmi_fifo_empty,

    output              init_over,
    output            	rstn_out,     //芯片复位信号，低有效
    output            	iic_scl,      //I2C的串行时钟信号
    inout             	iic_sda,      //I2C的串行数据信号
	                     
    input            	video_vs_in ,     //场同步信号
    input            	video_hs_in ,     //行同步信号
    input            	video_de_in ,     //数据使能
    input      [23:0]   video_rgb_in,     //RGB888颜色数据
                      
    output reg          video_vs_out,     //场同步信号
    output reg          video_hs_out,     //行同步信号
    output reg          video_de_out,     //数据使能
    output reg [23:0]   video_rgb_out     //RGB888颜色数据
);

//wire define

//reg define
reg        video_vs_in_dly;
reg        video_hs_in_dly;
reg        video_de_in_dly;
reg [23:0] video_rgb_in_dly;
reg        video_vs_in_dly1;           
reg        video_hs_in_dly1;            
reg        video_de_in_dly1;
reg [23:0] video_rgb_in_dly1;
reg        video_vs_in_dly2;           
reg        video_hs_in_dly2;            
reg        video_de_in_dly2;
reg [23:0] video_rgb_in_dly2;

//*****************************************************
//**                    main code
//*****************************************************  

assign rst_n = sys_rst_n;


//例化视频芯片控制模块
ms72xx_ctl ms72xx_ctl(
    .clk            (clk_cfg    ), 
    .rst_n          (rst_n      ),  

    .rstn_out       (rstn_out   ),      //配置全部完成标志                        
    .init_over      (init_over  ),      //芯片复位信号，低有效
    .iic_scl        (iic_scl    ), 
    .iic_sda        (iic_sda    )  
);

always  @(posedge video_clk_internal)begin
    video_vs_in_dly  <= video_vs_in;
    video_hs_in_dly  <= video_hs_in;
    video_de_in_dly  <= video_de_in;
    video_rgb_in_dly <= video_rgb_in;
    video_vs_in_dly1  <= video_vs_in_dly;
    video_hs_in_dly1  <= video_hs_in_dly;
    video_de_in_dly1  <= video_de_in_dly;
    video_rgb_in_dly1 <= video_rgb_in_dly;
    video_vs_in_dly2  <= video_vs_in_dly1;
    video_hs_in_dly2  <= video_hs_in_dly1;
    video_de_in_dly2  <= video_de_in_dly1;
    video_rgb_in_dly2 <= video_rgb_in_dly1;
end 

always  @(posedge video_clk_internal)begin
    if(!init_over)begin  //在没有配置完时，信号输出0
	    video_vs_out  <=  1'b0  ;
        video_hs_out  <=  1'b0  ;
        video_de_out  <=  1'b0  ;
        video_rgb_out <=  24'd0 ;
    end
	else begin
	    video_vs_out  <= video_vs_in_dly2 ;
        video_hs_out  <= video_hs_in_dly2 ;
        video_de_out  <= video_de_in_dly2 ;
        video_rgb_out <= video_rgb_in_dly2;       
    end
end 

    logic hdmi_fifo_wr_en;
    logic [31:0] hdmi_fifo_data_wr;
    (* mark_debug = "true" *)logic hdmi_fifo_full;
    // my_fifo #(
    //     .DATA_WIDTH(32),
    //     .FIFO_DEPTH(IMG_COL/2)
    // ) u_hdmi_fifo(
    //     .rd_clk         (clk_pe),
    //     .wr_clk         (video_clk_internal),
    //     .rst            (~rst_n),
    //     .wr_en          (hdmi_fifo_wr_en),
    //     .din            (hdmi_fifo_data_wr),
    //     .rd_en          (hdmi_fifo_rd_en),
    //     .dout           (hdmi_fifo_data),
    //     .full           (hdmi_fifo_full),
    //     .empty          (hdmi_fifo_empty)
    // );
    ip_fifo u_hdmi_fifo(
        .rd_clk         (clk_pe),
        .wr_clk         (video_clk_internal),
        .rst            (~rst_n),
        .wr_en          (hdmi_fifo_wr_en),
        .din            (hdmi_fifo_data_wr),
        .rd_en          (hdmi_fifo_rd_en),
        .dout           (hdmi_fifo_data),
        .full           (hdmi_fifo_full),
        .empty          (hdmi_fifo_empty)
    );

    always @(posedge video_clk_internal or negedge rst_n) begin
        if(!rst_n) begin
            hdmi_fifo_wr_en <= 1'b0;
            hdmi_fifo_data_wr <= 32'd0;
        end
        else begin
            // de上升沿写入 0xFF_00_00_00 作为行首标记
            if(video_de_in_dly1 & ~video_de_in_dly2) begin
                hdmi_fifo_wr_en <= 1'b1; // 行同步上升沿时写入 0xFF000000
                hdmi_fifo_data_wr <= 32'hFF_00_00_00;
            end
            else if(video_de_in_dly2) begin
                hdmi_fifo_wr_en <= 1'b1;
                hdmi_fifo_data_wr[31:24] <= 8'd0; // 高 8 位填充 0
                hdmi_fifo_data_wr[7 :0 ] <= video_rgb_in_dly2[23:16]; // R
                hdmi_fifo_data_wr[15:8 ] <= video_rgb_in_dly2[15:8 ]; // G
                hdmi_fifo_data_wr[23:16] <= video_rgb_in_dly2[7 :0 ]; // B
            end
            else begin
                hdmi_fifo_wr_en <= 1'b0;
                hdmi_fifo_data_wr <= hdmi_fifo_data_wr;
            end
        end
    end


endmodule