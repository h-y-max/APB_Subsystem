module APB_uart_Slave 
     #(parameter CLOCK=50_000_000
     )(input CLK,
       input reset_n,
       input [31:0] PADDR,
       input [31:0] PWDATA,
       input PSEL,
       input PWRITE,
       input PENABLE,
       input [3:0] PSTRB,
       output [31:0] PRDATA,
       output PREADY,
       output reg IRQ,
       output uart_tx,
       input uart_rx
    );
    
       localparam ADDR_TX=8'd00;
       localparam ADDR_RX=8'd04;
       localparam ADDR_STA=8'd08;
       localparam ADDR_CTRL=8'h0C;
       
       reg [7:0] Tx_data;
       wire Tx_done;
       reg send_go;
       wire [7:0] Rx_data;
       wire Rx_done;
       reg [31:0] r_rdata;
       
uart_tx #(
    .CLOCK(CLOCK)
    ) uart_tx_inst0(
       .CLK(CLK),
       .reset_n(reset_n),
       .Tx_data(Tx_data),
       .Tx_done(Tx_done),
       .uart_tx(uart_tx),
       .Tx_LED(),
       .send_go(send_go)
 );
 uart_rx #(
    .CLOCK(CLOCK)
    ) uart_rx_inst0(
       .CLK(CLK),
       .reset_n(reset_n),
       .Rx_data(Rx_data),
       .Rx_done(Rx_done),
       .uart_rx(uart_rx),
       .Rx_LED(),
       .LED()
 );    
 
      reg tx_irq_en;
      reg rx_irq_en;
      reg tx_irq_flag;
      reg rx_irq_flag;
      reg tx_busy;
      
always@(posedge CLK or negedge reset_n)
       if(!reset_n)begin
           Tx_data<=8'd0;
           send_go<=1'd0;
           tx_busy<=1'd0;
       end
       else begin
           send_go<=1'd0;
           if(Tx_done)
               tx_busy<=1'd0;
               
           if(PSEL && PWRITE && PENABLE && PADDR[7:0]==ADDR_TX)begin
               if(!tx_busy)begin
                  Tx_data<=PWDATA[7:0];
                  send_go<=1'd1;
                  tx_busy<=1'd1;
               end
           end
       end

always@(posedge CLK or negedge reset_n)
       if(!reset_n)begin
           tx_irq_en<=1'b0;
           rx_irq_en<=1'b0;
           tx_irq_flag<=1'b0;
           rx_irq_flag<=1'b0;
           IRQ<=1'b0;
       end
       else begin
           if(Tx_done && tx_irq_en)
                tx_irq_flag<=1'b1;
           else if(PSEL && PWRITE && PENABLE && PADDR[7:0]==ADDR_CTRL && PWDATA[31])
                tx_irq_flag<=1'b0;
                
           if(Rx_done && rx_irq_en)
                rx_irq_flag<=1'b1;
           else if(PSEL && !PWRITE && PENABLE && PADDR[7:0]==ADDR_RX)
                rx_irq_flag<=1'b0;
                
           if(PSEL && PWRITE && PENABLE && PADDR[7:0]==ADDR_CTRL)begin
                if(PSTRB[0])begin
                     tx_irq_en<=PWDATA[0];
                     rx_irq_en<=PWDATA[1];        
                end
           end

           IRQ<=tx_irq_flag||rx_irq_flag;
        end      
           
always@(posedge CLK or negedge reset_n)
        if(!reset_n)
            r_rdata<=0;
        else if(PSEL && PENABLE && !PWRITE)begin
            case(PADDR[7:0])
              ADDR_RX: 
                   r_rdata<={24'b0,Rx_data};
              ADDR_STA:
                   r_rdata<={25'b0,tx_busy,tx_irq_en,rx_irq_en,tx_irq_flag,rx_irq_flag,Tx_done,Rx_done};
              ADDR_CTRL:
                   r_rdata<={30'b0,rx_irq_en,tx_irq_en};
             default:r_rdata<=32'b0;
            endcase
         end
            
 assign PRDATA=r_rdata;
 assign PREADY=!(PSEL && PENABLE && PWRITE && PADDR[7:0]==ADDR_TX && tx_busy);
           
endmodule
