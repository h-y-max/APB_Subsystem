`timescale 1ns / 1ps
module APB_uart_top_tb();
// 位时间（CLOCK=1M, BAUD=9600 → 104 拍/位；半位 52 拍）
   localparam FULL_BIT=104;
   localparam HALF_BIT=52;

   reg CLK;
   reg reset_n;
   reg user_en;
   reg user_write;
   reg [31:0] user_addr;
   reg [31:0] user_wdata;
   wire user_tran_done;
   wire [31:0] user_rdata;
   wire IRQ;
   wire uart_tx;
   reg uart_rx;
   
   reg [31:0] sta;
   reg [7:0] tx_model_mem [0:63];
   integer tx_wr_ptr;
   integer tx_rd_ptr;
   reg [31:0] rd;
   reg [7:0] rx_model_mem [0:63];
   integer rx_wr_ptr;
   integer rx_rd_ptr;
   
 APB_uart_top #(
    .CLOCK(1_000_000)
  )  APB_uart_top_inst(
        .CLK(CLK),
        .reset_n(reset_n),
        .user_en(user_en),
        .user_write(user_write),
        .user_addr(user_addr),
        .user_wdata(user_wdata),
        .user_tran_done(user_tran_done),
        .user_rdata(user_rdata),
        .IRQ(IRQ),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx)
     );
  
 initial CLK=0;
 always #10 CLK=~CLK;
 
 //task
    //task1:user发起一次写
         task apb_user_write(input [31:0] addr, input [31:0] data);
            begin
               @(posedge CLK);
               user_addr<=addr;
               user_wdata<=data;
               user_en<=1'b1;
               user_write<=1'b1;
               @(posedge CLK);
               user_en<=1'b0;
               @(posedge user_tran_done);
               #1;
            end
         endtask
     //task2:user发起一次读
         task apb_user_read(input [31:0] addr,output [31:0] rd_data);
           begin
              @(posedge CLK);
              user_addr<=addr;
              user_en<=1'b1;
              user_write<=1'b0;
              @(posedge CLK);
              user_en<=1'b0;
              @(posedge user_tran_done);
              #1;
              rd_data=user_rdata;
            end
          endtask
     //task3:写 TX 寄存器并记入邮箱
          task apb_write_tx(input [7:0] data);
            begin
              apb_user_write(32'h0,{24'd0,data});
              tx_model_mem[tx_wr_ptr]=data;
              tx_wr_ptr=tx_wr_ptr+1;
            end
          endtask
      //task4:TB 在 uart_rx 上发出一帧
          task rx_send_byte(input [7:0] data);
             integer b;
             begin
               @(posedge CLK);
               uart_rx<=1'b0;
               repeat(FULL_BIT)@(posedge CLK);
               for(b=0;b<8;b=b+1)begin
                  uart_rx<=data[b];
                  repeat(FULL_BIT)@(posedge CLK);
               end
               uart_rx<=1'b1;
               repeat(FULL_BIT)@(posedge CLK);
               repeat(FULL_BIT)@(posedge CLK);// 多等一位：DUT 的同步链+中点采样有滞后
               rx_model_mem[rx_wr_ptr]=data;
               rx_wr_ptr=rx_wr_ptr+1;
             end
          endtask   
//进程1：上机位
 initial begin
   user_en=0;
   user_write=0;
   user_addr=0;
   user_wdata=0;
   reset_n=0;
   tx_wr_ptr=0;
   tx_rd_ptr=0;
   rx_wr_ptr=0;
   rx_rd_ptr=0;
   repeat(5)@(posedge CLK);
   reset_n<=1;
   repeat(5)@(posedge CLK);
   //测试1a：复位后的空闲信号
   if(uart_tx!==1'b1)begin
      $display("FAIL:uart_tx should be idle-high after reset");
      $finish;
   end
   if(IRQ!==1'b0)begin
      $display("FAIL:IRQ should be 0 after reset");
      $finish;
   end
   $display("TEST POINT 1a PASSED:idle signals OK");
   //测试点1b:复位后STA寄存器
   apb_user_read(32'h08,sta);
   if(sta!==32'h0000_0000)begin
      $display("FAIL:STA should be 0 after reset,got %h",sta);
      $finish;
   end
   $display("TEST POINT 1b PASSED:STA reset value OK");
   //测试点2：TX单字节
   apb_write_tx(8'hA5);
   //测试点3:背靠背3字节
   apb_write_tx(8'h11);
   apb_write_tx(8'h22);
   apb_write_tx(8'h33);
   wait(tx_wr_ptr===tx_rd_ptr);
   #1;
   $display("TEST POINT 2&3 PASSED:TX bytes OK");
   //测试点4：RX单字节
   rx_send_byte(8'hA5);
   apb_user_read(32'h04,rd);
   if(rd!=={24'b0,rx_model_mem[rx_rd_ptr]})begin
       $display("FAIL:RX mismatch:got %h,exp %h",rd,rx_model_mem[rx_rd_ptr]);
       $finish;
   end
   $display("RX OK: %h",rd[7:0]);
   rx_rd_ptr=rx_rd_ptr+1;
   $display("TEST POINT 4 PASSED:RX signal byte OK");
   //测试点5：RX连续3字节
   rx_send_byte(8'h11);
   apb_user_read(32'h04,rd);
   if(rd[7:0]!==rx_model_mem[rx_rd_ptr])begin
      $display("FAIL RX2");
      $finish;
   end
   $display("RX OK:%h",rd[7:0]);
   rx_rd_ptr=rx_rd_ptr+1;
   
   rx_send_byte(8'h22);
   apb_user_read(32'h04,rd);
   if(rd[7:0]!==rx_model_mem[rx_rd_ptr])begin
      $display("FAIL RX3");
      $finish;
   end
   $display("RX OK:%h",rd[7:0]);
   rx_rd_ptr=rx_rd_ptr+1;
   
   rx_send_byte(8'h33);
   apb_user_read(32'h04,rd);
   if(rd[7:0]!==rx_model_mem[rx_rd_ptr])begin
      $display("FAIL RX4");
      $finish;
   end
   $display("RX OK:%h",rd[7:0]);
   rx_rd_ptr=rx_rd_ptr+1;
   
   $display("TEST POINT 5 PASSED:RX 3 bytes OK");
   $finish;
 end
//进程2：外部串口设备
 initial begin
    uart_rx=1'b1;
 end
//进程3:scoreboard——uart_tx线协议解析器
   integer k;
   reg [7:0] sb_byte;
   initial begin
      forever begin
         @(negedge uart_tx);
         repeat(HALF_BIT) @(posedge CLK);
         if(uart_tx!==1'b0)begin
             $display("FAIL:start bit is not 0");
             $finish;
         end
         for(k=0;k<8;k=k+1)begin
            repeat(FULL_BIT) @(posedge CLK);
            sb_byte[k]=uart_tx;
         end
         repeat(FULL_BIT) @(posedge CLK);
         if(uart_tx!==1'b1)begin
             $display("FAIL:stop bit is not 1");
             $finish;
         end
         //解析完毕，与邮箱对比
         if(tx_wr_ptr===tx_rd_ptr)begin
            $display("FAIL:TX frame received but mailbox empty");
            $finish;
         end
         if(sb_byte!==tx_model_mem[tx_rd_ptr])begin
            $display("FAIL:TX mismatch:got %h,exp %h",sb_byte,tx_model_mem[tx_rd_ptr]);
            $finish;
         end
         $display("TX OK: %h",sb_byte);
         tx_rd_ptr=tx_rd_ptr+1;
     end
  end 
//看门狗
 initial begin
   #1_000_000;
   $display("FAIL:TIMEOUT! wr=%0d,rd=%0d",tx_wr_ptr,tx_rd_ptr);
   $finish;
 end
endmodule
