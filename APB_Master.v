module APB_Master(
       input CLK,//时钟信号
       input reset_n,//复位信号
//外部输入的user信号和CLK同源，不必做异步处理
       input user_en,
       input user_write,
       input [31:0] user_addr,
       input [31:0] user_wdata,
       input [31:0] PRDATA,//读数据总线
       input PREADY,//准备就绪信号
       output [31:0] user_rdata,
       output user_tran_done,
       output [31:0] PADDR,//地址总线
       output [31:0] PWDATA,//写数据总线
       output PWRITE,//写信号
       output PSEL,//选择信号
       output PENABLE,//使能信号
       output [3:0] PSTRB//写使能信号
    );
       localparam STA_IDLE=6'b000_001;
       localparam STA_WR=6'b000_010;
       localparam STA_RD=6'b000_100;
       localparam STA_ENABLE=6'b001_000;
       localparam STA_DONE=6'b010_000;
       localparam STA_WAIT=6'b100_000;   
         
       reg [31:0] r_PADDR;
       reg [31:0] r_PWDATA;
       reg r_PWRITE;
       reg r_PSEL;
       reg r_PENABLE;
       reg [3:0] r_w_strobe;
       reg r_tran_done;
       reg [31:0] r_prdata;
       reg [5:0] state_cur;
       reg [5:0] state_nxt;
       
       assign PADDR=r_PADDR;
       assign PWDATA=r_PWDATA;
       assign PWRITE=r_PWRITE;
       assign PSEL=r_PSEL;
       assign PENABLE=r_PENABLE;
       assign PSTRB=r_w_strobe;
       assign user_tran_done=r_tran_done;
       assign user_rdata=r_prdata;
//三段式状态机
//第一段     
always@(posedge CLK or negedge reset_n)
       if(!reset_n)
           state_cur<=STA_IDLE;
       else
           state_cur<=state_nxt;
//第二段
always@(*)begin
     if(!reset_n)
         state_nxt=STA_IDLE;
     else begin
         case(state_cur)   
               STA_IDLE:
                   if(user_write & user_en)   
                         state_nxt=STA_WR;
                   else if(!user_write & user_en)
                         state_nxt=STA_RD;
                   else
                         state_nxt=state_nxt;
               STA_WR:
                       state_nxt=STA_ENABLE;
               STA_RD:
                       state_nxt=STA_ENABLE;     
               STA_ENABLE:
                   if(PREADY)
                      state_nxt=STA_DONE;
                   else
                      state_nxt=state_nxt;
               STA_DONE:
                      state_nxt=STA_WAIT;
               STA_WAIT:
                      state_nxt=STA_IDLE;
              default:state_nxt=STA_IDLE;
            endcase
        end
    end
//第三段
always@(posedge CLK or negedge reset_n)
     if(!reset_n)begin
         r_PADDR<=32'd0;
         r_PWDATA<=32'd0;
         r_PWRITE<=1'b0;
         r_PSEL<=1'b0;
         r_PENABLE<=1'b0;
         r_w_strobe<=4'b1111;
         r_tran_done<=1'b0;
         r_prdata<=32'd0;
     end
     else begin
          case(state_cur)
             STA_IDLE:
                begin
                  r_PADDR<=32'd0;
                  r_PWDATA<=32'd0;
                  r_PWRITE<=1'b0;
                  r_PSEL<=1'b0;
                  r_PENABLE<=1'b0;
                  r_w_strobe<=4'b1111;
                  r_tran_done<=1'b0;
                end
             STA_WR:
                begin
                  r_PADDR<=user_addr;
                  r_PWDATA<=user_wdata;
                  r_PWRITE<=1'b1;
                  r_PSEL<=1'b1;
                  r_PENABLE<=1'b0;
                end
             STA_RD:
                begin
                  r_PADDR<=user_addr;
                  r_PWRITE<=1'b0;
                  r_PSEL<=1'b1;
                  r_PENABLE<=1'b0;          
                end
             STA_ENABLE:
                  r_PENABLE<=1'b1;
             STA_DONE:
                begin
                  r_PSEL<=1'b0;
                  r_PENABLE<=1'b0;
                end
             STA_WAIT:
                begin
                  r_tran_done<=1'd1;
                  r_prdata<=PRDATA;
                end
            default:begin
                  r_PADDR<=32'd0;
                  r_PWDATA<=32'd0;
                  r_PWRITE<=1'b0;
                  r_PSEL<=1'b0;
                  r_PENABLE<=1'b0;
                  r_w_strobe<=4'b1111;
                  r_tran_done<=1'b0;
                  r_prdata<=32'd0;
                end
         endcase
      end      
endmodule
