module usb3_fifo_control #(
    parameter IDLE       = 3'd1,   // 初始化状态
    parameter READ_ADDR  = 3'd2,   // 读地址状态
    parameter WRITE_ADDR = 3'd3,   // 写地址状态
    parameter READ_DATA  = 3'd4,   // 读数据状态
    parameter WRITE_DATA = 3'd5    // 写数据状态
)(
    input             clk_usb,            // USB时钟(100M)
    input             clk_spi,            // SPI时钟
    input             sys_rst_n,          // 系统复位
    output [12:0]     fifo_data_count,    // FIFO数据计数
    input             slrd,               // 读请求信号
    input             slwr,               // 写请求信号
    input [31:0]      usb_data_in_1,      // USB输入数据
    input             flagc_1,            // 缓冲区标志
    input             pktend,             // 包结束标志
    input [2:0]       state,              // 状态寄存器
    output [31:0]     usb_data_out,       // USB输出数据
    // SPI接口
    input             up_fifo_write_en,       // UP FIFO写使能
    input [31:0]      up_fifo_data_write,     // UP FIFO写数据
    input             down_fifo_read_en,      // DOWN FIFO读使能
    output [31:0]     down_fifo_data_read,    // DOWN FIFO读数据
    output            down_fifo_empty         // DOWN FIFO空状态
);

// 内部信号定义
reg [2:0] slrd_cnt;
reg wr_en;
reg fifo_data_first_en;

// FIFO控制信号
wire up_fifo_rd_en;
wire down_fifo_wr_en;

// FIFO状态信号
wire up_fifo_full;
wire up_fifo_empty;

wire down_fifo_full;

//*****************************************************
//**                    main code
//*****************************************************

// DOWN FIFO写使能
assign down_fifo_wr_en = wr_en & flagc_1;

// UP FIFO读使能 - 使用参数化的状态
assign up_fifo_rd_en = fifo_data_first_en || ((state == WRITE_DATA) && (~slwr) && pktend);

// FIFO写使能信号
always @(posedge clk_usb or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        slrd_cnt <= 3'd0;
        wr_en <= 1'b0;
    end else if (~slrd) begin
        if (slrd_cnt < 3) begin
            slrd_cnt <= slrd_cnt + 1'b1;
            wr_en <= 1'b0;
        end else begin
            slrd_cnt <= slrd_cnt;
            wr_en <= 1'b1;
        end
    end else begin
        slrd_cnt <= 3'd0;
        wr_en <= 1'b0;
    end
end

// 产生FIFO读使能信号 - 使用参数化的状态
always @(posedge clk_usb or negedge sys_rst_n) begin
    if (!sys_rst_n)
        fifo_data_first_en <= 1'b0;
    else if (fifo_data_first_en)
        fifo_data_first_en <= 1'b0;
    else if (state == WRITE_ADDR)
        fifo_data_first_en <= 1'b1;
    else
        ;
end

// 例化UP FIFO（SPI到USB的数据流）
fifo_generator_0 u_up_fifo (
    .rd_clk         (clk_usb),
    .wr_clk         (clk_spi),
    .rst            (~sys_rst_n),
    .din            (up_fifo_data_write),
    .wr_en          (up_fifo_write_en),
    .rd_en          (up_fifo_rd_en),
    .dout           (usb_data_out),
    .full           (up_fifo_full),
    .empty          (up_fifo_empty),
    .rd_data_count  (fifo_data_count)
);
// assign down_fifo_empty = 1'b1;
// assign down_fifo_data_read = 1;
// 例化DOWN FIFO（USB到SPI的数据流）
fifo_generator_1 u_down_fifo (
    .rd_clk         (clk_spi),
    .wr_clk         (clk_usb),
    .rst            (~sys_rst_n),
    .din            (usb_data_in_1),
    .wr_en          (down_fifo_wr_en),
    .rd_en          (down_fifo_read_en),
    .dout           (down_fifo_data_read),
    .full           (down_fifo_full),
    .empty          (down_fifo_empty)
);

endmodule