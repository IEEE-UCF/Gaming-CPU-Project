parameter FIFO_DEPTH = 16;
//UART interface
module UARTmodule #(
    parameter FIFO_DEPTH = 16
) (
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
// LCR, IER, FCR, MCR, MSR, LSR, etc.

/**************************BAUD RATE CALC******************************/
// Generate baud tick from clk

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
