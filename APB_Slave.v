module APB_Slave(
    input CLK,
    input reset_n,
    input [31:0] PADDR,
    input [31:0] PWDATA,
    input PWRITE,
    input PSEL,
    input PENABLE,
    input [3:0] PSTRB,
    output PREADY,
    output [31:0] PRDATA
);

reg [31:0] memory [0:1023];
reg [31:0] r_rdata;
integer i;

// 复位初始化 memory
always@(posedge CLK or negedge reset_n)
    if(!reset_n)
        for(i=0;i<1024;i=i+1)
            memory[i] <= 32'ha5a5a5a5;

// 读写操作
always@(posedge CLK or negedge reset_n)
    if(!reset_n)
        r_rdata <= 0;
    else if(PSEL) begin
        if(PWRITE) begin
            if(PSTRB[0]) memory[PADDR[31:2]][7:0]  <= PWDATA[7:0];
            if(PSTRB[1]) memory[PADDR[31:2]][15:8] <= PWDATA[15:8];
            if(PSTRB[2]) memory[PADDR[31:2]][23:16]<= PWDATA[23:16];
            if(PSTRB[3]) memory[PADDR[31:2]][31:24]<= PWDATA[31:24];
        end
        else
            r_rdata <= memory[PADDR[31:2]];
    end

assign PREADY = 1'b1;   
assign PRDATA = r_rdata;

endmodule