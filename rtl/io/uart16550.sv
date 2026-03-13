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
input wire rst_n,

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
    logic [7:0] ISR; //Interrupt Status Register
    logic [7:0] FCR; //FIFO Control Register
    logic [7:0] LCR; //Line Control Register
    logic [7:0] LSR; //Line Status Register
    logic [7:0] MCR; //Modem Control Register
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
  always_ff @(posedge clk_i or negedge rst_n) begin
    if (!rst_n) begin //reset registers to its reset values
            THR <= 8'h00;
            IER <= 8'h00;
            // ISR is combinatorial, removed from reset to avoid MULTIDRIVEN
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
                            THR <= wdata; // write data to be transmitted (Changed from RHR to THR)
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
                    default: ; // Added to resolve CASEINCOMPLETE warning
                endcase
            end
        end
    end

/**************************BAUD RATE CALC******************************/
    logic [15:0] baud_divisor = {DLM,DLL};   //16-bit divisor from DLM & DLL
    logic [3:0] psd_value = PSD [3:0];       // the lower 4-bit are used
    
    //clk/(16*(PSD+1)*baud_divisor) -- counter holder for the math 
    logic [3:0] PSD_counter;         //for PSD+1
    logic [15:0] divisor_counter;    //divides by divisor
    logic [3:0] multi_by_16;         //divides by 16
    logic baud_tick;                 //final baud pulse
    
  always_ff @(posedge clk_i or negedge rst_n) begin 
    if (!rst_n) begin //reseting the counter
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
                        multi_by_16 <= 4'd0; // Fixed width from 16'd0 to 4'd0
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
typedef enum logic [1:0] {
    IDLE      = 2'b00,  // Line idle (high)
    START_BIT = 2'b01,  // Send start bit (0)
    DATA_BITS = 2'b10,  // Send 8 data bits (LSB first)
    STOP_BIT  = 2'b11   // Send stop bit (1)
} tx_state_e;

tx_state_e tx_state_c, tx_state_n;

logic [7:0] tx_shift_reg;   
logic [2:0] tx_bit_counter; 

// 2. Baud Rate Generator (creates 1-cycle pulse per bit)
wire [31:0] rate_limit = (baud_divisor == 16'd0) ? 32'd1 : {16'd0, baud_divisor};

reg  [31:0] clk_counter;
logic       tx_bit_clk_en;  

  always_ff @(posedge clk_i or negedge rst_n) begin
    if (!rst_n) begin // Fixed polarity for consistency
        clk_counter   <= 32'd0;
        tx_bit_clk_en <= 1'b0;
    end
    else begin
        if (clk_counter >= rate_limit - 1) begin
            clk_counter   <= 32'd0;
            tx_bit_clk_en <= 1'b1;  
        end
        else begin
            clk_counter   <= clk_counter + 1;
            tx_bit_clk_en <= 1'b0;
        end
    end
end

// 3. FIFO Read Controller
typedef enum logic {
    RD_IDLE = 1'b0,
    RD_WAIT = 1'b1
} rd_state_e;

rd_state_e rd_state_c;

logic [7:0] fifo_data_reg;
logic [7:0] fifo_data_out;
logic       fifo_data_valid; 
logic       fifo_rd_en; // Added read enable back

// Wire up the output from the FIFO
assign fifo_data_out = fifo_mem[raddr_ptr];

wire fifo_data_consumed = (tx_state_c == START_BIT) && tx_bit_clk_en;

  always_ff @(posedge clk_i or negedge rst_n) begin
  if (!rst_n) begin // Fixed polarity for consistency
        rd_state_c      <= RD_IDLE;
        fifo_rd_en      <= 1'b0;
        fifo_data_reg   <= 8'd0;
        fifo_data_valid <= 1'b0;
    end
    else begin
        fifo_rd_en <= 1'b0;

        case (rd_state_c)
            RD_IDLE: begin
                if ((tx_state_c == IDLE) && (!fifo_empty) && (!fifo_data_valid)) begin
                    fifo_rd_en <= 1'b1; // Replaced array assignment
                    rd_state_c <= RD_WAIT;
                end

                if (fifo_data_consumed)
                    fifo_data_valid <= 1'b0;
            end

            RD_WAIT: begin
                fifo_data_reg   <= fifo_data_out;
                fifo_data_valid <= 1'b1;
                rd_state_c      <= RD_IDLE;
            end
        endcase

        if (fifo_data_consumed)
            fifo_data_valid <= 1'b0;
    end
end

// 4. State + Shift Logic
  always_ff @(posedge clk_i or negedge rst_n) begin
  if (!rst_n) begin // Fixed polarity for consistency
        tx_state_c     <= IDLE;
        tx_shift_reg   <= 8'b0;
        tx_bit_counter <= 3'd0;
    end
    else if (tx_bit_clk_en) begin
        tx_state_c <= tx_state_n;

        case (tx_state_c)
            IDLE: begin
                tx_bit_counter <= 3'd0;
            end

            START_BIT: begin
                tx_shift_reg   <= fifo_data_reg;
                tx_bit_counter <= 3'd0;
            end

            DATA_BITS: begin
                tx_shift_reg   <= {1'b0, tx_shift_reg[7:1]};
                tx_bit_counter <= tx_bit_counter + 1;
            end

            STOP_BIT: begin
                tx_bit_counter <= 3'd0;
            end
        endcase
    end
end

// 5. Next-State Logic
always_comb begin
    tx_state_n = tx_state_c;

    if (tx_bit_clk_en) begin
        case (tx_state_c)
            IDLE:
                if (fifo_data_valid)
                    tx_state_n = START_BIT;

            START_BIT:
                tx_state_n = DATA_BITS;

            DATA_BITS:
                if (tx_bit_counter == 3'd7)
                    tx_state_n = STOP_BIT;

            STOP_BIT:
                tx_state_n = IDLE;

            default:
                tx_state_n = IDLE;
        endcase
    end
end

// 6. Serial Output Logic
assign tx_o =
    (tx_state_c == START_BIT) ? 1'b0 :
    (tx_state_c == DATA_BITS) ? tx_shift_reg[0] :
    1'b1;

/***************************UART to CPU********************************/
// AXI-Lite read/write response
// RHR, RBR, FIFO status, line status
  always_ff @(posedge clk_i or negedge rst_n) begin //aready logic --Is UART ready to read from an address? 
      if (!rst_n) begin
            arready <= 1'b1; // Ready out of reset
        end else begin
            if (arvalid && arready) begin
                arready <= 1'b0; // UART not ready for read request, processing data
            end else if (rvalid && rready) begin
                arready <= 1'b1; // UART finished processing data
            end
        end
    end

  always_ff @(posedge clk_i or negedge rst_n) begin //rvalid logic --Is the data in rdata and rresp valid? 
    if (!rst_n) begin
            rvalid <= 1'b0;
            rdata  <= 8'h0; // Fixed width from 32'h0 to 8'h0
        end else begin
            // Start the read after the address handshake
            if (arvalid && arready) begin
                rvalid <= 1'b1;
                // Decode the address to get the data
                case (araddr) // Fixed SELRANGE (was araddr[4:2] on a 3-bit wire)
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

  always_ff @(posedge clk_i) begin //rresp logic
        if (arvalid && arready) begin
            // Removed redundant bounds check (awaddr is 3 bits, so it's always <= 7)
            rresp <= 2'b00; // OKAY
        end
    end


/***************************INTERRUPT irq_o****************************/
// Internal interrupt trigger signals
logic rx_data_int;
logic tx_empty_int;
logic line_status_int;
logic modem_status_int;

// IER[0]: Enable Received Data Available Interrupt
// IER[1]: Enable Transmitter Holding Register Empty Interrupt
// IER[2]: Enable Receiver Line Status Interrupt (Errors)
// IER[3]: Enable Modem Status Interrupt

// 1. Data available in RX FIFO
assign rx_data_int = IER[0] & (!fifo_empty); 

// 2. Transmit FIFO is empty and state machine is idle
assign tx_empty_int = IER[1] & (count == 0 && tx_state_c == IDLE); 

// 3. Any error bit (Overrun, Parity, Framing, Break) is set in the LSR
assign line_status_int = IER[2] & (|LSR[4:1]); 

// 4. Modem Status change (change in state of CTS, DSR, RI, or DCD signal)
assign modem_status_int = IER[3] & (|MSR[3:0]);
    
// Update Interrupt Status Register (ISR) for the CPU to read
// ISR[0]   : 0 = Interrupt pending, 1 = No interrupt pending
// ISR[2:1] : Interrupt Priority ID
always_comb begin
    if (line_status_int)      ISR = 8'b00000110; // Priority 1: Line Status Error
    else if (rx_data_int)     ISR = 8'b00000100; // Priority 2: RX Data Available
    else if (tx_empty_int)    ISR = 8'b00000010; // Priority 3: TX Empty
    else if (modem_status_int)    ISR = 8'b00000000; // Priority 4: Modem status change
    else                      ISR = 8'b00000001; // Default   : No Interrupt
end

// Master interrupt output sent to CPU
assign irq_o = !ISR[0];
    
/***FIFO MANAGEMENT**/

// FIFO Push (write) and Pop (read) logic
always_ff @(posedge clk_i or negedge rst_n) begin // <--- Changed to negedge rst_n
    if (!rst_n) begin                             // <--- Changed to active-low check
        waddr_ptr <= 0;
        raddr_ptr <= 0;
        count <= 0;
        RHR <= 8'h00;                             // <--- ADDED RHR RESET HERE
    end
    else begin
        // Push data to FIFO (CPU write)
        if (wvalid && awvalid && !fifo_full) begin
            fifo_mem[waddr_ptr] <= wdata;   // Write CPU data into FIFO
            waddr_ptr <= waddr_ptr + 1;     // Increment write pointer
            count <= count + 1;             // Increment FIFO count
        end

        // Pop data from FIFO (CPU read or Internal State Machine Read)
        if ((rready && arvalid && !fifo_empty) || (fifo_rd_en && !fifo_empty)) begin
            RHR <= fifo_mem[raddr_ptr];     // Load data to read register
            raddr_ptr <= raddr_ptr + 1;     // Increment read pointer
            count <= count - 1;             // Decrement FIFO count
        end
    end
end


/***************************ERROR DETECTION***************************/
// Note: These signals should be driven by the RX State Machine (Receive_rx)
logic rx_done;            // Pulses high for 1 clock cycle when a full frame is received
logic rx_stop_bit;        // The actual value of the sampled stop bit
logic rx_parity_calc;     // The calculated parity of the incoming data
logic rx_parity_sampled;  // The actual parity bit sampled from the rx_i line
logic rx_break_detect;    // Pulses high if rx_i is held low for longer than a full frame

always_ff @(posedge clk_i or negedge rst_n) begin
    if (!rst_n) begin
        // Reset Line Status Register (LSR[6:5] = 1 means TX is completely empty)
        LSR <= 8'h60;
    end 
    else begin
        // 1. Overrun Error (LSR[1]): New data arrived but FIFO is completely full
        if (rx_done && fifo_full) begin
            LSR[1] <= 1'b1;
        end

        // 2. Parity Error (LSR[2]): Parity doesn't match (Only if LCR[3] Parity Enable is 1)
        if (rx_done && LCR[3] && (rx_parity_calc != rx_parity_sampled)) begin
            LSR[2] <= 1'b1;
        end

        // 3. Framing Error (LSR[3]): Expected a stop bit (1), but got a 0
        if (rx_done && (rx_stop_bit == 1'b0)) begin
            LSR[3] <= 1'b1;
        end

        // 4. Break Interrupt (LSR[4]): RX line held low for an entire word duration
        if (rx_break_detect) begin
            LSR[4] <= 1'b1;
        end

        // Clear error bits when the CPU successfully reads the LSR
        // Fixed SELRANGE (was araddr[4:2] on a 3-bit wire)
        if (arvalid && arready && (araddr == 3'b101)) begin
            LSR[4:1] <= 4'b0000;
        end

        // Continuously update status flags
        LSR[0] <= !fifo_empty;                        // Data Ready (DR)
        LSR[5] <= (count == 0);                       // Transmit Holding Register Empty (THRE)
        LSR[6] <= (count == 0 && tx_state_c == IDLE); // Transmitter Empty (TEMT)
    end
end
endmodule
