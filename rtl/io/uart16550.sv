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


/***************************TRANSMIT tx_o******************************/
// FIFO -> shift register -> serial output
    
// logic [7:0] tx_shift_reg; Holds the byte to transmit
// logic tx_fifo_rreq; Request to read/pop FIFO
// logic tx_bit_clk; Baud rate clock (1x)  

logic [7:0] tx_shift_reg;     
    logic [3:0] tx_bit_counter; // Tracks data bits transmitted from 0 to 7
	// TX State Machine Definition
	typedef enum logic [2:0] {
		IDLE,
		START_BIT,
		DATA_BITS,
		STOP_BITS,
	} tx_state_e;  
    
//Baud Rate Generator:
    wire [15:0] baud_divisor = {DLM, DLL};
    localparam CLK_PER_BIT = 16; //16 clock div.
    wire [19:0] rate_limit = baud_divisor * CLK_PER_BIT;
    reg [19:0] clk_counter;
	logic tx_bit_clk_en; //Enables Baud Rate of 1x

    always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
		clk_counter <= 0;
		tx_bit_clk_en <= 1'b0;
    end else begin
	    if (clk_counter == rate_limit - 1) begin
		clk_counter <= 0;
		tx_bit_clk_en <= 1'b1;
    end else begin
				clk_counter <= clk_counter + 1;
				tx_bit_clk_en <= 1'b0;
	        end
	    end
	end

    //TX State Registers
    reg [2:0] tx_state_c, tx_state_n //3 bits for the state
    wire tx_data_avail = ~fifo_empty; // Checks if there's data to send
    wire tx_fifo_rreq = (tx_state_c == IDLE) && tx_data_avail; //FIFO request signal
    //output for assign TX State
    assign tx_o = (tx_state_c == DATA_BITS) ? tx_shift_reg[0] : // Transmit LSB first
                  ((tx_state_c == IDLE) || (tx_state_c == STOP_BITS)) ? 1'b1 : // Idle/Stop is '1' (Mark)
                  1'b0; // Start bit is '0' (Space)

    
/***************************ERROR DETECTION***************************/
// Parity, framing, overrun errors  
endmodule


