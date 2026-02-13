`timescale 1ns / 1ps
parameter FIFO_DEPTH = 16;
//UART interface
module UARTmodule(
//clock to generate Baud rate
input wire clk,
//reset signal to initialize/clear registers
input wire rst,
//Axi-lite bus interface
input  wire [31:0] CPU_to_UART, 
output wire [31:0] UART_to_CPU,
//Recieve/Transmit serial bit 
input wire rx_i,
output wire tx_o,
//Interrupt for CPU to read
output wire irq_o
    );
/*******************************BUS BIT FIELDS*****************************/
    //CPU to UART internal signals for write
    wire awvalid = CPU_to_UART [0];
    wire wvalid = CPU_to_UART [1];
    wire [2:0] awaddr = CPU_to_UART [4:2];
    wire bready = CPU_to_UART [5];
    wire [7:0] wdata = CPU_to_UART [13:6];
    //UART to CPU internal signals for write
    wire awready;
    wire wready;
    wire bvalid;
    wire [1:0] bresp;
    //CPU to UART internal signals for read
    wire arvalid = CPU_to_UART [15];
    wire [2:0] araddr = CPU_to_UART [18:16];
    wire rready = CPU_to_UART [19];
    //UART to CPU internal signals for read
    wire arready;
    wire rvalid;
    wire [1:0] rresp;
    wire [7:0] rdata;
    //assign write-related bits
    
/**************************REGISTERS & FIFO QUEUE*************************/ 
    localparam ADDR_WIDTH = $clog2(FIFO_DEPTH);
    reg [7:0] THR;
    reg [7:0] RBR;
    reg [7:0] IER;
    reg [7:0] ISR;
    reg [7:0] FCR;
    reg [7:0] LCR;
    reg [7:0] LSR;
    reg [7:0] MCR;
    reg [7:0] MSR;
    reg [7:0] SPR;
    reg [7:0] DLL;
    reg [7:0] DLM;
    reg [7:0] PSD;
    //FIFO mem stack, pointers and status
    reg [7:0] fifo_mem [0:FIFO_DEPTH-1];
    reg [ADDR_WIDTH-1:0] waddr_ptr;
    reg [ADDR_WIDTH-1:0] raddr_ptr;
    reg [ADDR_WIDTH:0] count;
    wire fifo_full  = (count == FIFO_DEPTH);
    wire fifo_empty = (count == 0);
    
/****************************CONFIG REGS*******************************/
    always @(posedge clk or posedge rst) begin
        if (rst) begin //reset registers to its reset values
            THR <= 8'h00;
            RBR <= 8'h00;
            IER <= 8'h00;
            ISR <= 8'h01;
            FCR <= 8'h00; //the datasheet reset value is 0x00? 
            LCR <= 8'h00;
            LSR <= 8'h60;
            MCR <= 8'h00;
            MSR <= 8'h00;
            SPR <= 8'h00;
            DLL <= 8'h01;
            DLM <= 8'h01;
            PSD <= 8'h00;
        end
        else begin //to handle CPU writes 
            if  (awvalid && wvalid && awready && wready) begin 
                case (awaddr) //address of the register
                    3'b000: begin 
                        if (LCR[7]==1'b0)// check DLAB = 0 -> THR, DLAB = 1 -> DLL
                            THR <= wdata; // write data to be transmitted
                        else
                            DLL <= wdata; // baudrate low byte
                    end
                    3'b001: begin
                        if (LCR[7]==1'b0)
                            IER <= wdata; // enable interrupt 
                        else
                            DLM <= wdata; // baudrate high byte
                    end 
                    3'b010: FCR <= wdata; //FIFO control
                    3'b011: LCR <= wdata; //Line Control
                    3'b100: MCR <= wdata; //Modern control
                    3'b101: begin 
                        if (LCR [7] ==1'b1) 
                            PSD <= {4'b0000, wdata[3:0]}; //prescaler division
                    end
                    3'b111: SPR <= wdata; // Scratch Pad 
                endcase
            end
        end
    end

/**************************BAUD RATE CALC******************************/
 wire [15:0] baud_divisor = {DLM,DLL};   //16-bit divisor from DLM & DLL
    wire [3:0] psd_value = PSD [3:0];       // the lower 4-bit are used
    
    //clk/(16*(PSD+1)*baud_divisor) -- counter holder for the math 
    reg [3:0] PSD_counter;         //for PSD+1
    reg [15:0] divisor_counter;    //divides by divisor
    reg [3:0] multi_by_16;         //divides by 16
    reg baud_tick;                 //final baud pulse
    
    always @(posedge clk_i or negedge rst_ni) begin 
        if (!rst_ni) begin //reseting the counter
            PSD_counter <= 4'd0;
            divisor_counter <= 16'd0;
            multi_by_16 <= 4'd0;
            baud_tick <= 1'b0; 
        end 
        else begin
            baud_tick <= 1'b0; //default setting counting clock cycle
            
            if (PSD_counter == psd_value) begin // divides by PSD + 1 
                PSD_counter <= 4'd0;
            
                if (divisor_counter == baud_divisor - 1) begin //divides by divisor
                    divisor_counter <= 16'd0;
                
                     if (multi_by_16 == 4'd15) begin // divide by 16 
                        multi_by_16 <= 16'd0;
                        baud_tick <= 1'b1; 
                    end 
                    else begin 
                        multi_by_16 <= multi_by_16 + 1'b1;
                    end
                    end //end the most inner if statment
                    
                else begin    
                    divisor_counter <= divisor_counter + 1'b1;
                end
                end// end the second inner if statment
            
             else begin               
                PSD_counter <= PSD_counter + 1'b1;
            end     
            end //end the last if statment
     end
/***************************TRANSMIT tx_o******************************/
// FIFO -> shift register -> serial output

/***************************RECEIVE rx_i*******************************/
// Serial input -> shift register -> FIFO

/***************************UART to CPU********************************/
// AXI-Lite read/write response
// THR, RBR, FIFO status, line status

/***************************INTERRUPT irq_o****************************/
// RX/TX interrupts based on IER and FIFO/line status

/***************************FIFO MANAGEMENT****************************/
// Push/pop data, update pointers and count

/***************************ERROR DETECTION***************************/
// Parity, framing, overrun errors
endmodule



