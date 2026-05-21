`timescale 1ns / 1ps
`define WCLK_PERILOD 20
module APB_top_tb();
       reg CLK;
       reg reset_n;
       reg user_en;
       reg user_write;
       reg [31:0] user_addr;
       reg [31:0] user_wdata;
       wire [31:0] user_rdata;
       wire user_tran_done;
APB_top APB_top_inst(
     .CLK(CLK),
     .reset_n(reset_n),
     .user_en(user_en),
     .user_write(user_write),
     .user_addr(user_addr),
     .user_wdata(user_wdata),
     .user_rdata(user_rdata),
     .user_tran_done(user_tran_done)
);

initial begin
     CLK=0;
     forever
        #(`WCLK_PERILOD/2) CLK=~CLK;
end

initial begin
     reset_n=0;
     repeat(20)@(posedge CLK);
     reset_n=1;
end

initial begin
user_en=0;
user_write=0;
user_addr=32'd0;
user_wdata=32'd0;
repeat(30)@(posedge CLK);

user_en=1;
user_write=1;
user_addr=32'd0;
user_wdata=32'd102;
@(posedge CLK);
user_en=0;
@(posedge user_tran_done);

user_en=1;
user_write=1;
user_addr=32'd4;
user_wdata=32'd109;
@(posedge CLK);
user_en=0;
@(posedge user_tran_done);

user_en=1;
user_write=1;
user_addr=32'd8;
user_wdata=32'd115;
@(posedge CLK);
user_en=0;
@(posedge user_tran_done);

user_en=1;
user_write=0;
user_addr=32'd0;
@(posedge CLK);
user_en=0;
@(posedge user_tran_done);

user_en=1;
user_write=0;
user_addr=32'd4;
@(posedge CLK);
user_en=0;
@(posedge user_tran_done);

user_en=1;
user_write=0;
user_addr=32'd8;
@(posedge CLK);
user_en=0;
@(posedge user_tran_done);

repeat(30)@(posedge CLK);
$finish;
end
endmodule
