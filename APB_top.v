module APB_top(
       input CLK,
       input reset_n,
       input user_en,
       input user_write,
       input [31:0] user_addr,
       input [31:0] user_wdata,
       output [31:0] user_rdata,
       output user_tran_done
    );
wire [31:0] w_paddr;
wire [31:0] w_pwdata;
wire [31:0] w_prdata;
wire [3:0] w_pstrb;
wire  w_pwrite;
wire  w_psel;
wire  w_penable;
wire  w_pready;

APB_Master APB_Master_inst0(
       .CLK(CLK),
       .reset_n(reset_n),
       .user_en(user_en),
       .user_write(user_write),
       .user_addr(user_addr),
       .user_wdata(user_wdata),
       .user_rdata(user_rdata),
       .user_tran_done(user_tran_done),
       .PADDR(w_paddr),
       .PWDATA(w_pwdata),
       .PRDATA(w_prdata),
       .PWRITE(w_pwrite),
       .PSEL(w_psel),
       .PENABLE(w_penable),
       .PREADY(w_pready),
       .PSTRB(w_pstrb)
 );
 
 APB_Slave APB_Slave_inst0(
       .CLK(CLK),
       .reset_n(reset_n),
       .PADDR(w_paddr),
       .PWDATA(w_pwdata),
       .PRDATA(w_prdata),
       .PWRITE(w_pwrite),
       .PSEL(w_psel),
       .PENABLE(w_penable),
       .PREADY(w_pready),
       .PSTRB(w_pstrb)
 );
endmodule
