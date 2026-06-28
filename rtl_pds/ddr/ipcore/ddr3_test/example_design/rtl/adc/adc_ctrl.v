module adc_ctrl(
input				clk,
input				rst_n,
input				dbg_temp_rd,
input				dbg_volt_rd,
output  [15:0]		pdata
);

wire			sel;
wire			penable;
//reg [4:0] alarm_r;

wire      ready;
//wire			over_temp;
//wire			logic_done_a;
//wire			logic_done_b;
//wire			adc_clk_out;
//wire			dmodified;
//wire	[4:0]	alarm;
reg  [7:0] paddr;

reg  [3:0] dbg_temp_rd_d;
reg  [3:0] dbg_volt_rd_d;
wire       dbg_temp_rd_pos;
wire       dbg_volt_rd_pos;
reg  [1:0] dbg_temp_rd_pos_d;
reg  [1:0] dbg_volt_rd_pos_d;

always@ (posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
    begin
		dbg_temp_rd_d <= 4'b0;
		dbg_volt_rd_d <= 4'b0;
    end
	else
    begin
		dbg_temp_rd_d <= {dbg_temp_rd_d[2:0],dbg_temp_rd};
		dbg_volt_rd_d <= {dbg_volt_rd_d[2:0],dbg_volt_rd};
    end
end

assign dbg_temp_rd_pos = ~dbg_temp_rd_d[1] & dbg_temp_rd_d[0];
assign dbg_volt_rd_pos = ~dbg_volt_rd_d[1] & dbg_volt_rd_d[0];

always@ (posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
    begin
		dbg_temp_rd_pos_d <= 2'b0;
		dbg_volt_rd_pos_d <= 2'b0;
    end
	else
    begin
		dbg_temp_rd_pos_d <= {dbg_temp_rd_pos_d[0],dbg_temp_rd_pos};
		dbg_volt_rd_pos_d <= {dbg_volt_rd_pos_d[0],dbg_volt_rd_pos};
    end
end

always@ (posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		paddr <= 8'h40;
	else if(dbg_temp_rd_pos)
		paddr <= 8'h40;
	else if(dbg_volt_rd_pos)
		paddr <= 8'h41;
    else;
end

assign sel     = (dbg_temp_rd_pos_d[0] | dbg_temp_rd_pos_d[1]) | (dbg_volt_rd_pos_d[0] | dbg_volt_rd_pos_d[1]);
assign penable = dbg_temp_rd_pos_d[1] | dbg_volt_rd_pos_d[1];

//always@ (posedge clk or negedge rst_n)
//begin
//	if(rst_n == 1'b0)
//		sel <= 1'b0;
//	else if(dbg_adc_rd_pos)
//		sel <= 1'b1;
//	else if(ready)
//		sel <= 1'b0;
//    else;
//end
//
//always@ (posedge clk or negedge rst_n)
//begin
//	if(rst_n == 1'b0)
//		penable <= 1'b0;
//	else if(sel)
//		penable <= 1'b1;
//	else if(ready)
//		penable <= 1'b0;
//    else;
//end

//always@ (posedge clk)
//begin
//    ready_r <= ready;
//	over_temp_r <= over_temp;
//	logic_done_a_r <= logic_done_a;
//	logic_done_b_r <= logic_done_b;
//	adc_clk_out_r <= adc_clk_out;
//	dmodified_r <= dmodified;
//	alarm_r <= alarm;
//	alarm_r_t <= |alarm_r;
//end

ADC ADC_inst (
	//.VA           (),
    .VAUX					(32'b0), 
    .clk					(clk),
    .PADDR				(paddr), //40: temp; 41:vcc; 
    .PSEL					(sel),	
    .PENABLE			(penable),
    .PWRITE				(1'b0),
    .CONVST				(1'b0), 
    .RST_N				(rst_n),
    .PREADY				(),    
    .PDATA				(pdata),
    .OVER_TEMP		(),
    .LOGIC_DONE_A	(),
    .LOGIC_DONE_B	(),
    .ADC_CLK_OUT	(),
    .DMODIFIED		(), 
    .ALARM   		()
);

endmodule
