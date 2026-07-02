
//////////////////////////////////////////////////////////////////////////////
//
// Copyright (c) 2019 PANGO MICROSYSTEMS, INC
// ALL RIGHTS REVERVED.
//
// THE SOURCE CODE CONTAINED HEREIN IS PROPRIETARY TO PANGO MICROSYSTEMS, INC.
// IT SHALL NOT BE REPRODUCED OR DISCLOSED IN WHOLE OR IN PART OR USED BY
// PARTIES WITHOUT WRITTEN AUTHORIZATION FROM THE OWNER.
//
//////////////////////////////////////////////////////////////////////////////
//
// Library:
// Filename:ipm2l_fifo_ctrl.v
//
//////////////////////////////////////////////////////////////////////////////

module ipm2l_fifo_ctrl_v1_1_ip_fifo #(
    parameter  c_WR_DEPTH_WIDTH   = 9             ,
    parameter  c_RD_DEPTH_WIDTH   = 9             ,
    parameter  c_FIFO_TYPE        = "ASYN"        ,
    parameter  c_ALMOST_FULL_NUM  = 508           ,
    parameter  c_ALMOST_EMPTY_NUM = 4
) (
    input  wire                           wclk            ,
    input  wire                           w_en            ,
    output wire [c_WR_DEPTH_WIDTH-1 : 0]  waddr           ,
    input  wire                           wrst            ,
    output wire                           wfull           ,
    output wire                           almost_full     ,
    output reg  [c_WR_DEPTH_WIDTH : 0]    wr_water_level  ,

    input  wire                           rclk            ,
    input  wire                           r_en            ,
    output wire [c_RD_DEPTH_WIDTH-1 : 0]  raddr           ,
    input  wire                           rrst            ,
    output wire                           rempty          ,
    output reg  [c_RD_DEPTH_WIDTH : 0]    rd_water_level  ,
    output wire                           almost_empty
);

//**************************************************************************************************************
//declare inner variables
//write address operation variables
//write pointer
reg [c_WR_DEPTH_WIDTH : 0]  wptr                      /* synthesis syn_preserve=1 */ ; 
//1st read-domain to write-domain synchronizer
reg [c_RD_DEPTH_WIDTH : 0]  wrptr1                    /* synthesis syn_preserve=1 */ ;
reg [c_RD_DEPTH_WIDTH : 0]  wrptr2          ;          //2nd read-domain to write-domain synchronizer
reg [c_WR_DEPTH_WIDTH : 0]  wbin            ;          //write current binary  pointer
reg [c_WR_DEPTH_WIDTH : 0]  wbnext          ;          //write next binary  pointer
reg [c_WR_DEPTH_WIDTH : 0]  wgnext          ;          //wriet next gray pointer
reg                         waddr_msb       ;          //the MSB of waddr
//wire                        wgnext_2ndmsb   ;          //the second MSB of wgnext
//wire                        wrptr2_2ndmsb   ;          //the second MSB of wrptr2

//read address operation variables
//read pointer
reg [c_RD_DEPTH_WIDTH : 0]  rptr                      /* synthesis syn_preserve=1 */  ;
//1st  write-domain to read-domain synchronizer
reg [c_WR_DEPTH_WIDTH : 0]  rwptr1                    /* synthesis syn_preserve=1 */  ;
reg [c_WR_DEPTH_WIDTH : 0]  rwptr2          ;          //2nd  write-domain to read-domain synchronizer
reg [c_RD_DEPTH_WIDTH : 0]  rbin            ;          //read current binary  pointer
reg [c_RD_DEPTH_WIDTH : 0]  rbnext          ;          //read next binary  pointer
reg [c_RD_DEPTH_WIDTH : 0]  rgnext          ;          //read next gray pointer
reg                         raddr_msb       ;          //the MSB of raddr

reg [c_RD_DEPTH_WIDTH : 0]  wrptr2_b        ;          //wrptr2 into binary
reg [c_WR_DEPTH_WIDTH : 0]  rwptr2_b        ;          //rwptr2 into binary

reg                         asyn_wfull          ;
reg                         asyn_almost_full    ;
reg                         asyn_rempty         ;
reg                         asyn_almost_empty   ;
reg                         syn_wfull           ;
reg                         syn_almost_full     ;
reg                         syn_rempty          ;
reg                         syn_almost_empty    ;

wire    [c_WR_DEPTH_WIDTH:0]    wwptr;
wire    [c_WR_DEPTH_WIDTH:0]    wrptr;
wire    [c_RD_DEPTH_WIDTH:0]    rwptr;
wire    [c_RD_DEPTH_WIDTH:0]    rrptr;

//main code
//**************************************************************************************************************
generate
    if(c_FIFO_TYPE == "ASYN")
    begin:ASYN_CTRL
        //write gray pointer generate

        always@(*)
        begin
            if(!wfull)
                wbnext = wbin + w_en;
            else
                wbnext = wbin;
        end

        always@(*)
        begin
            wgnext = (wbnext >> 1) ^ wbnext;          //binary to gray converter
        end

        always@( posedge wclk or posedge wrst )
        begin
            if(wrst)
            begin
                wptr <=0;
                waddr_msb <=0;
                wbin <=0;
            end
            else
            begin
               wptr <= wgnext;
               wbin <= wbnext;
               waddr_msb <= wgnext[c_WR_DEPTH_WIDTH] ^ wgnext[c_WR_DEPTH_WIDTH-1];
            end
        end

        //read domain to write domain synchronizer
        always@(posedge wclk or posedge wrst)
        begin
            if(wrst)
                {wrptr2,wrptr1} <= 0;
            else
                {wrptr2,wrptr1} <= {wrptr1,rptr};
        end

        integer i;
        always@(*)
        begin
            for(i = 0;i <= c_RD_DEPTH_WIDTH;i = i+1 )  //gray to binary converter
                wrptr2_b[i] = ^(wrptr2 >> i);
        end

//        //generate fifo write full flag
//        assign  wgnext_2ndmsb = wgnext[c_WR_DEPTH_WIDTH] ^ wgnext[c_WR_DEPTH_WIDTH-1];
//        assign  wrptr2_2ndmsb = wrptr2[c_WR_DEPTH_WIDTH] ^ wrptr2[c_WR_DEPTH_WIDTH-1];

        //**************************************************************************************************************
        //read gray pointer generate

        always@(*)
        begin
            if(!rempty)
                rbnext = rbin + r_en;
            else
                rbnext = rbin;
            rgnext = (rbnext >> 1) ^ rbnext;          //binary to gray converter
        end

        always@( posedge rclk or posedge rrst )
        begin
            if(rrst)
            begin
                rptr <=0;
                raddr_msb <=0;
                rbin <=0;
            end
            else
            begin
                rptr <= rgnext;
                rbin <= rbnext;
                raddr_msb <= rgnext[c_RD_DEPTH_WIDTH] ^ rgnext[c_RD_DEPTH_WIDTH-1];
            end
        end

        //read domain to write domain synchronizer
        always@(posedge rclk or posedge rrst)
        begin
            if(rrst)
                {rwptr2,rwptr1} <= 0;
            else
                {rwptr2,rwptr1} <= {rwptr1,wptr};
        end

        always@(*)
        begin
            for(i = 0;i <= c_WR_DEPTH_WIDTH;i = i+1 )  //gray to binary converter
                rwptr2_b[i] = ^(rwptr2 >> i);
        end

        if(c_WR_DEPTH_WIDTH > c_RD_DEPTH_WIDTH)
        begin
            assign wwptr = wbnext;
            assign wrptr = {wrptr2_b,{(c_WR_DEPTH_WIDTH-c_RD_DEPTH_WIDTH){1'b0}}};
            assign rwptr = rwptr2_b[c_WR_DEPTH_WIDTH:c_WR_DEPTH_WIDTH-c_RD_DEPTH_WIDTH];
            assign rrptr = rbnext;
        end
        else
        begin
            assign wwptr = wbnext;
            assign wrptr = wrptr2_b[c_RD_DEPTH_WIDTH:c_RD_DEPTH_WIDTH-c_WR_DEPTH_WIDTH];
            assign rwptr = {rwptr2_b,{(c_RD_DEPTH_WIDTH-c_WR_DEPTH_WIDTH){1'b0}}};
            assign rrptr = rbnext;
        end

        //generate async_fifo write full flag
        always@(posedge wclk or posedge wrst)
        begin
            if(wrst)
                asyn_wfull <= 1'b0;
            else
                asyn_wfull <= ((wwptr[c_WR_DEPTH_WIDTH] != wrptr[c_WR_DEPTH_WIDTH])
                            && (wwptr[c_WR_DEPTH_WIDTH-1:0] == wrptr[c_WR_DEPTH_WIDTH-1:0]));
        end

        //generate async_fifo read empty flag generate
        always@(posedge rclk or posedge rrst)
        begin
            if(rrst)
                asyn_rempty <= 1'b1;
            else
                asyn_rempty <= (rrptr == rwptr);
        end
    end
    else
    begin:SYN_CTRL
        //write operation
        always@(*)
        begin
            if(!wfull)
                wbnext = wptr + w_en;
            else
                wbnext = wptr;
        end

        always@(*)
        begin
            wgnext =  wbnext;    // syn fifo
        end

        always@( posedge wclk or posedge wrst )
        begin
            if(wrst)
            begin
                wptr <=0;
                waddr_msb <=0;
                wbin <=0;
            end
            else
            begin
                wptr <= wgnext;
                wbin <= wbnext;
                waddr_msb <= wgnext[c_WR_DEPTH_WIDTH-1];
            end
        end

        always@(*)
        begin
            wrptr2 = rptr;    // syn fifo
        end

        always@(*)
        begin
            wrptr2_b = rptr;    // syn fifo
        end

//        //generate fifo write full flag
//        assign  wgnext_2ndmsb = wgnext[c_WR_DEPTH_WIDTH-1];
//        assign  wrptr2_2ndmsb = wrptr2[c_WR_DEPTH_WIDTH-1];

        //**************************************************************************************************************
        //read operation
        always@(*)
        begin
            if(!rempty)
                rbnext = rptr + r_en;
            else
                rbnext = rptr;
        end

        always@(*)
        begin
            rgnext =  rbnext;
        end

        always@( posedge rclk or posedge rrst )
        begin
            if(rrst)
            begin
                rptr <=0;
                raddr_msb <=0;
                rbin <=0;
            end
            else
            begin
                rptr <= rgnext;
                rbin <= rbnext;
                raddr_msb <= rgnext[c_RD_DEPTH_WIDTH-1];
            end
        end

        always@(*)
        begin
            rwptr2   =  wptr;    //syn fifo
        end

        always@(*)
        begin
            rwptr2_b =  wptr;    //syn fifo
        end
        //generate sync_fifo write full flag
        if(c_WR_DEPTH_WIDTH > c_RD_DEPTH_WIDTH)
        begin
            assign wwptr = wbnext;
            assign wrptr = {rbnext,{(c_WR_DEPTH_WIDTH-c_RD_DEPTH_WIDTH){1'b0}}};
            assign rwptr = wbnext[c_WR_DEPTH_WIDTH:c_WR_DEPTH_WIDTH-c_RD_DEPTH_WIDTH];
            assign rrptr = rbnext;
        end
        else
        begin
            assign wwptr = wbnext;
            assign wrptr = rbnext[c_RD_DEPTH_WIDTH:c_RD_DEPTH_WIDTH-c_WR_DEPTH_WIDTH];
            assign rwptr = {wbnext,{(c_RD_DEPTH_WIDTH-c_WR_DEPTH_WIDTH){1'b0}}};
            assign rrptr = rbnext;
        end
        always@(posedge wclk or posedge wrst)
        begin
            if(wrst)
                syn_wfull <= 1'b0;
            else
                syn_wfull <= ((wwptr[c_WR_DEPTH_WIDTH] != wrptr[c_WR_DEPTH_WIDTH])
                           && (wwptr[c_WR_DEPTH_WIDTH-1:0] == wrptr[c_WR_DEPTH_WIDTH-1:0]));
        end

        //generate sync_fifo read empty flag generate
        always@(posedge rclk or posedge rrst)
        begin
            if(rrst)
                syn_rempty <= 1'b1;
            else
                syn_rempty <= (rwptr == rrptr);
        end
    end
endgenerate

//write  flex memory address generate
assign waddr = wbin[c_WR_DEPTH_WIDTH-1:0];

//generate fifo write full flag
assign wfull = (c_FIFO_TYPE == "ASYN") ? asyn_wfull : syn_wfull;

//generate fifo write almost full flag
assign  almost_full = (wr_water_level >= c_ALMOST_FULL_NUM) ? 1'b1:1'b0;
//generate write water level flag
always@(posedge wclk or posedge wrst)
begin
    if(wrst)
        wr_water_level <= 'b0;
    else
        wr_water_level <= ( wwptr[c_WR_DEPTH_WIDTH]==0 && wrptr[c_WR_DEPTH_WIDTH]==0 ) ? (wwptr[c_WR_DEPTH_WIDTH-1:0] - wrptr[c_WR_DEPTH_WIDTH-1:0])     :
                          ( wwptr[c_WR_DEPTH_WIDTH]==0 && wrptr[c_WR_DEPTH_WIDTH]==1 ) ? ({1'b1,wwptr[c_WR_DEPTH_WIDTH-1:0]} - wrptr[c_WR_DEPTH_WIDTH-1:0] ):
                          ( wwptr[c_WR_DEPTH_WIDTH]==1 && wrptr[c_WR_DEPTH_WIDTH]==0 ) ? (wwptr[c_WR_DEPTH_WIDTH :0] - wrptr[c_WR_DEPTH_WIDTH-1:0])      :
                          ( wwptr[c_WR_DEPTH_WIDTH-1:0] - wrptr[c_WR_DEPTH_WIDTH-1:0]) ;
end

//read flex memory address generate
assign  raddr = rbin[c_RD_DEPTH_WIDTH-1:0];

//fifo read empty flag generate
assign rempty = (c_FIFO_TYPE == "ASYN") ? asyn_rempty : syn_rempty;

//generate fifo read almost empty flag
assign  almost_empty = (rd_water_level<= c_ALMOST_EMPTY_NUM) ? 1'b1:1'b0;

//generate read water level flag
always@(posedge rclk or posedge rrst)
begin
    if(rrst)
        rd_water_level <= 'b0;
    else
        rd_water_level <= ( rwptr[c_RD_DEPTH_WIDTH]==0 && rrptr[c_RD_DEPTH_WIDTH]==0 ) ? (rwptr[c_RD_DEPTH_WIDTH-1:0] - rrptr[c_RD_DEPTH_WIDTH-1:0])     :
                          ( rwptr[c_RD_DEPTH_WIDTH]==0 && rrptr[c_RD_DEPTH_WIDTH]==1 ) ? ({1'b1,rwptr[c_RD_DEPTH_WIDTH-1:0]} - rrptr[c_RD_DEPTH_WIDTH-1:0] ):
                          ( rwptr[c_RD_DEPTH_WIDTH]==1 && rrptr[c_RD_DEPTH_WIDTH]==0 ) ? (rwptr[c_RD_DEPTH_WIDTH :0] - rrptr[c_RD_DEPTH_WIDTH-1:0])      :
                          ( rwptr[c_RD_DEPTH_WIDTH-1:0] - rrptr[c_RD_DEPTH_WIDTH-1:0]);
end

endmodule
