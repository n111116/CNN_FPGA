module usb3_control(
    input             clk_usb,        // 100MHz时钟
    input             clk_usb_dgree,  // 100MHz偏移时钟
    input             clk_spi,        // SPI时钟
    input             sys_rst_n,      // 系统复位
    // USB3.0物理接口
    output            pclk,           // 数据随路时钟              
    output            slcs,           // 片选信号        
    inout      [31:0] usb_data,       // USB双向数据总线
    output     [1:0]  usb_addr,       // 缓冲区选择       
    output            slrd,           // 读请求信号
    output            sloe,           // 读写使能信号
    output            slwr,           // 写请求信号
    input             flaga,          // 缓冲区A空满信号
    input             flagb,          // 缓冲区B空满信号
    input             flagc,          // 缓冲区C空满信号
    input             flagd,          // 缓冲区D空满信号
    output      reg   pktend,         // 包结束标志
    output            usb_rest,       // USB复位信号
    output            usb_int,        // USB中断信号
    // SPI数据流接口
    input             spi_sample_clk,         // SPI 帧结束符号
    input             up_fifo_write_en,       // UP FIFO写使能
    input      [31:0] up_fifo_data_write,     // UP FIFO写数据
    input             down_fifo_read_en,      // DOWN FIFO读使能
    output     [31:0] down_fifo_data_read,    // DOWN FIFO读数据
    output            down_fifo_empty,        // DOWN FIFO空状态
    output      reg   spi_start
);

// 状态参数定义
localparam IDLE       = 3'd1;   // 初始化状态
localparam READ_ADDR  = 3'd2;   // 读地址状态
localparam WRITE_ADDR = 3'd3;   // 写地址状态
localparam READ_DATA  = 3'd4;   // 读数据状态
localparam WRITE_DATA = 3'd5;   // 写数据状态

// USB控制信号
wire [2:0]  state;
wire [12:0] fifo_data_count;

// USB数据缓冲
reg  [31:0] usb_data_in_0;
reg  [31:0] usb_data_in_1;
wire [31:0] usb_data_in;
wire [31:0] usb_data_out;
reg  [12:0] fifo_data_count_reg; //上行FIFO数据计数信号

// 标志信号缓冲
reg         flaga_0, flaga_1;
reg         flagb_0, flagb_1;
reg         flagc_0, flagc_1;
reg         flagd_0, flagd_1;
reg         spi_sample_clk_reg, spi_sample_clk_reg1;
//*****************************************************
//**                    main code
//*****************************************************
always @(posedge clk_usb or negedge sys_rst_n)begin
    if(~sys_rst_n) begin
        spi_start <= 1'b0;
    end
    else begin
        if(usb_data_in_1[7:0] == 8'h31)begin
            spi_start <= 1'b1;
        end
    end
end

//将读FIFO计数器的值进行寄存
always @(posedge clk_usb or negedge sys_rst_n)begin
    if(!sys_rst_n)
        fifo_data_count_reg <= 1'b0;
    else if(state==WRITE_ADDR )
       fifo_data_count_reg<= fifo_data_count;
    else
        fifo_data_count_reg<=fifo_data_count_reg;
end
// 在写状态，写使能时，读FIFO数据计数器为0或者1时，使能写一包数据最后一个数据的标志
always @(posedge clk_usb or negedge sys_rst_n)begin
    if(!sys_rst_n)
        pktend <= 1'b1;
    else if(((fifo_data_count_reg>1)&&state==WRITE_DATA && (fifo_data_count==1||fifo_data_count==0) && (~slwr)))   
        pktend <= 1'b0;
    else if(((fifo_data_count_reg<=1)&&state==WRITE_DATA && (fifo_data_count==1||fifo_data_count==0)))  //零长度数据包
        pktend <= 1'b0;
    else
        pktend <= 1'b1;
end

// USB3.0读写控制模块
usb_rw #(
    .IDLE(IDLE),
    .READ_ADDR(READ_ADDR),
    .WRITE_ADDR(WRITE_ADDR),
    .READ_DATA(READ_DATA),
    .WRITE_DATA(WRITE_DATA)
) u_usb_rw (
    .clk_usb(clk_usb),
    .sys_rst_n(sys_rst_n),
    .slcs(slcs),
    .usb_addr(usb_addr),
    .slrd(slrd),
    .sloe(sloe),
    .slwr(slwr),
    .flaga_1(flaga_1),
    .flagb_1(flagb_1),
    .flagc_1(flagc_1),
    .flagd_1(flagd_1),
    .pktend(pktend),
    .fifo_data_count(fifo_data_count),
    .state(state)
);

// SPI数据流模块
usb3_fifo_control #(
    .IDLE(IDLE),
    .READ_ADDR(READ_ADDR),
    .WRITE_ADDR(WRITE_ADDR),
    .READ_DATA(READ_DATA),
    .WRITE_DATA(WRITE_DATA)
) u_usb3_fifo_control (
    .clk_usb(clk_usb),
    .clk_spi(clk_spi),
    .sys_rst_n(sys_rst_n),
    .fifo_data_count(fifo_data_count),
    .slrd(slrd),
    .slwr(slwr),
    .usb_data_in_1(usb_data_in_1),
    .flagc_1(flagc_1),
    .pktend(pktend),
    .state(state),
    .usb_data_out(usb_data_out),
    // SPI接口
    .up_fifo_write_en(up_fifo_write_en),
    .up_fifo_data_write(up_fifo_data_write),
    .down_fifo_read_en(down_fifo_read_en),
    .down_fifo_data_read(down_fifo_data_read),
    .down_fifo_empty(down_fifo_empty)
);

// 信号同步和缓冲
always @(posedge clk_usb or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        flaga_0 <= 1'b0; flagb_0 <= 1'b0; flagc_0 <= 1'b0; flagd_0 <= 1'b0;
        flaga_1 <= 1'b0; flagb_1 <= 1'b0; flagc_1 <= 1'b0; flagd_1 <= 1'b0;
        usb_data_in_0 <= 32'd0;
        usb_data_in_1 <= 32'd0;
    end else begin
        flaga_0 <= flaga; flagb_0 <= flagb; flagc_0 <= flagc; flagd_0 <= flagd;
        flaga_1 <= flaga_0; flagb_1 <= flagb_0; flagc_1 <= flagc_0; flagd_1 <= flagd_0;
        usb_data_in_0 <= usb_data_in;
        usb_data_in_1 <= usb_data_in_0;
        spi_sample_clk_reg <= spi_sample_clk;
        spi_sample_clk_reg1 <= spi_sample_clk_reg;
    end
end

// 连续赋值
assign pclk = clk_usb_dgree;
assign usb_rest = 1'b1;
assign usb_int = 1'b1;
assign usb_data_in = usb_data;
assign usb_data = (state == WRITE_DATA) ? usb_data_out : {32{1'bz}};

endmodule