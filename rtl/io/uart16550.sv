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

module uart_tx (
    input  logic        clk,
    input  logic        rst,
    input  logic [7:0]  DLM, DLL,        //Baud divisor registers
    input  logic [7:0]  fifo_data_out,   //Data sitting at FIFO output
    input  logic        fifo_empty,      //High if no data
    output logic        tx_o,            //The actual serial line
    output logic        fifo_rd_en       //Tells FIFO to pop data
);

    //1. State Definitions
    typedef enum logic [1:0] {
        IDLE      = 2'b00,
        START_BIT = 2'b01,
        DATA_BITS = 2'b10,
        STOP_BITS = 2'b11
    } tx_state_e;

    tx_state_e tx_state_c, tx_state_n;
    logic [7:0] tx_shift_reg;     
    logic [3:0] tx_bit_counter; 
    
    //2. Baud Rate Generator
    wire [15:0] baud_divisor = {DLM, DLL}; //16 bits is used for RX oversampling.
    localparam CLK_PER_BIT = 16; 
    wire [31:0] rate_limit = baud_divisor * CLK_PER_BIT;
    reg [31:0] clk_counter;
    logic tx_bit_clk_en;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_counter <= 0;
            tx_bit_clk_en <= 1'b0;
        end else begin
            if (clk_counter >= rate_limit - 1) begin
                clk_counter <= 0;
                tx_bit_clk_en <= 1'b1;
            end else begin
                clk_counter <= clk_counter + 1;
                tx_bit_clk_en <= 1'b0;
            end
        end
    end

    //3. FIFO Handshake
    //Read enable only for one clock cycle when we move out of IDLE.
    assign fifo_rd_en = (tx_state_c == IDLE && !fifo_empty && tx_bit_clk_en);

    //4. Sequential Engine
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_state_c     <= IDLE;
            tx_shift_reg   <= 8'b0;
            tx_bit_counter <= 4'b0;
        end else if (tx_bit_clk_en) begin
            tx_state_c <= tx_state_n; //Move to next state every bit-period

            case (tx_state_c)
                IDLE: begin
                    tx_bit_counter <= 0;
                    if (!fifo_empty) begin
                        tx_shift_reg <= fifo_data_out; //Captures the data from FIFO
                    end
                end
                DATA_BITS: begin  //This moves the next bit into index [0] every bit-period
                    tx_shift_reg   <= {1'b0, tx_shift_reg[7:1]}; 
                    tx_bit_counter <= tx_bit_counter + 1;
                end
                default: tx_bit_counter <= 0;
            endcase
        end
    end

    //5. Combinational Logic
    always_comb begin
        tx_state_n = tx_state_c;
        case (tx_state_c)
            IDLE:      if (!fifo_empty) tx_state_n = START_BIT;
            START_BIT: tx_state_n = DATA_BITS;
            DATA_BITS: if (tx_bit_counter == 4'd7) tx_state_n = STOP_BITS;
            STOP_BITS: tx_state_n = IDLE;
            default:   tx_state_n = IDLE;
        endcase
    end
    //6. Output Assignment
    assign tx_o = (tx_state_c == DATA_BITS)  ? tx_shift_reg[0] : 
                  (tx_state_c == START_BIT) ? 1'b0 : 
                  1'b1; //Defaults to High (Idle/Stop)

endmodule

