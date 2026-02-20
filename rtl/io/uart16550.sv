//UART Module 
//2025-2026 Created for IEE Gaming CPU Project
// Former Co-Lead : Leo, Current Co-Lead: Nicholas 
//UART Framework by Leo 
//Members: 
//Qing - Config Registers & Baud Rate
//Matthew E - Transmit_tx
//Matthew K - Recieve_rx
//Nicholas - UART to CPU
//Ryan - FIFO Management 
//Paul - Error Detection 

`timescale 1ns / 1ps
parameter FIFO_DEPTH = 16;

//UART interface
module UARTmodule(

//clock to generate Baud rate
input wire clk_i,

//reset signal to initialize/clear registers
input wire rst_ni,

//Axi-lite bus interface
input  wire [31:0] CPU_to_UART, 
output wire [31:0] UART_to_CPU,

//Recieve/Transmit serial bit 
input wire rx_i, //Recieve flag
output wire tx_o, //Transmit flag

//Interrupt for CPU to read
output wire irq_o
    );
/*******************************BUS BIT FIELDS*****************************/
    //CPU to UART internal signals for write
    logic awvalid = CPU_to_UART [0]; //Indicates address and control information on awaddr is valid
    logic wvalid = CPU_to_UART [1]; //Indicates the data on wdata bus is valid
    logic [2:0] awaddr = CPU_to_UART [4:2]; //3 bit address of target register
    logic bready = CPU_to_UART [5]; //Ready to accept UART response
    logic [7:0] wdata = CPU_to_UART [13:6]; //Character to transmit

    //UART to CPU internal signals for write
    logic awready; //UART ready to accept address
    logic wready; //Successfully sampled/buffered data
    logic bvalid; //Write response is available
    logic [1:0] bresp; //Write status, 00-Okay, 01-EXOKAY 10-Slave Error, 11- Decode Error

    //CPU to UART internal signals for read
    logic arvalid = CPU_to_UART [15]; //Read address valid
    logic [2:0] araddr = CPU_to_UART [18:16]; //requested read address
    logic rready = CPU_to_UART [19]; //CPU has captured the data, UART can stop driving the bus

    //UART to CPU internal signals for read
    logic arready; //Ready to process read request
    logic rvalid; //Indicates rdata and rresp are valid and ready for CPU
    logic [1:0] rresp; //Read status. Same values as bresp
    logic [7:0] rdata; //8-bit value from internal register
    //assign write-related bits
    
/**************************REGISTERS & FIFO QUEUE*************************/ 
    localparam ADDR_WIDTH = $clog2(FIFO_DEPTH);
    logic [7:0] RHR; //Reciever Holding Register
    logic [7:0] THR;//Transmitter Holding Register
    logic [7:0] IER; //Interrupt Enable Register 
    logic [7:0] ISR; //FIFO Control Register
    logic [7:0] FCR; //Line Control Register
    logic [7:0] LCR; //Line Control Register
    logic [7:0] LSR; //Modem Control Register
    logic [7:0] MCR; //Line Status Register
    logic [7:0] MSR; //Modem Status Register
    logic [7:0] SPR; //Scratch Pad Register
    logic [7:0] DLL; //Divisor Latch Least signif byte
    logic [7:0] DLM; //Divisor Latch most signif byte
    logic [7:0] PSD; //Prescalar Division 
    //FIFO mem stack, pointers and status
    logic [7:0] fifo_mem [0:FIFO_DEPTH-1];
    logic [ADDR_WIDTH-1:0] waddr_ptr;
    logic [ADDR_WIDTH-1:0] raddr_ptr;
    logic [ADDR_WIDTH:0] count;
    logic fifo_full  = (count == FIFO_DEPTH);
    logic fifo_empty = (count == 0);

/****************************CONFIG REGS*******************************/
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin //reset registers to its reset values
            RHR <= 8'h00;
            THR <= 8'h00;
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
                        if (LCR[7]==1'b0)// check DLAB = 0 -> RHR, DLAB = 1 -> DLL
                            RHR <= wdata; // write data to be transmitted
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
    
    always_ff @(posedge clk or negedge rst) begin 
        if (!rst) begin //reseting the counter
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
// RHR, RBR, FIFO status, line status
    always_ff @(posedge clk or negedge rst) begin //aready logic --Is UART ready to read from an address? 
        if (!rst) begin
            arready <= 1'b1; // Ready out of reset
        end else begin
            if (arvalid && arready) begin
                arready <= 1'b0; // UART not ready for read request, processing data
            end else if (rvalid && rready) begin
                arready <= 1'b1; // UART finished processing data
            end
        end
    end

    always_ff @(posedge clk or negedge rst) begin //rvalid logic --Is the data in rdata and rresp valid? 
        if (!rst) begin
            rvalid <= 1'b0;
            rdata  <= 32'h0;
        end else begin
            // Start the read after the address handshake
            if (arvalid && arready) begin
                rvalid <= 1'b1;
                // Decode the address to get the data
                case (araddr[4:2]) // 16550 registers are often word-aligned
                    3'b000: rdata <= RHR;
                    3'b001: rdata <= IER;
                    3'b010: rdata <= ISR;
                    3'b011: rdata <= LCR;
                    3'b100: rdata <= MCR;
                    3'b101: rdata <= LSR;
                    3'b110: rdata <= MSR;
                    3'b111: rdata <= SPR;
                endcase
            end 
            // End the read after the data handshake
            else if (rvalid && rready) begin
                rvalid <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk) begin //rresp logic
        if (arvalid && arready) begin
            // If address is within 0-7, it's OKAY. Otherwise, SLVERR.
            if () begin 
                rresp <= 2'b00; // OKAY
            end else begin
                rresp <= 2'b10; // SLVERR (Address out of range)
            end
        end
    end


/***************************INTERRUPT irq_o****************************/
// RX/TX interrupts based on IER and FIFO/line status

/***************************FIFO MANAGEMENT****************************/
// Push/pop data, update pointers and count

/***************************ERROR DETECTION***************************/
// Parity, framing, overrun errors
endmodule