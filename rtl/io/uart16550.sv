// Developed by Nicholas McNeill 4/20/2026
// UART module 
// Implements a bidirectional UART with parity checking. 
// 8 bit packets, + 1 parity bit
//BAUD rate not implemented

module uart(
  input  logic clk,
  input  logic rst_n,
  input  logic [31:0] CPU_bus,
  input  logic begin_transmission,
  
  // UART IO (transmit_pin and receive_pin)
  input  logic rx_pin,     
  output logic tx_pin,
  
  // Status to CPU
  output logic tx_complete,
  output logic rx_complete,
  output logic parity_mismatch,
  output logic [7:0] data_out
);
  
  // Internal signals
  logic [7:0] tx_data;
  logic [10:0] tx_shift_reg; // [0]Start, [8:1]Data, [9]Parity, [10]Stop
  logic [8:0] rx_shift_reg; // [7:0]Data, [8]Parity
  
  typedef enum logic {IDLE = 1'b0, BUSY = 1'b1} state_t;
  state_t tx_state, rx_state;

  integer i, f; //counters for Recieve and Transmit

  assign tx_data = CPU_bus[7:0]; 
   
  // -------------------------
  // Transmit Logic 
  // -------------------------
  always_ff @(posedge clk or negedge rst_n) begin 
    if (!rst_n) begin 
      tx_state    <= IDLE; 
      tx_shift_reg <= '0;
      tx_pin      <= 1'b1; // UART idle high
      tx_complete <= 1'b0;
      i           <= 0;
    end else begin
      case (tx_state)
        IDLE: begin 
          tx_complete <= 1'b0;
          if (begin_transmission) begin 
            tx_shift_reg[0]    <= 1'b0;          // Start bit
            tx_shift_reg[8:1]  <= tx_data;       // Data bits
            tx_shift_reg[9]    <= ^tx_data;      // Even Parity bit 
            tx_shift_reg[10]   <= 1'b1;          // Stop bit
            tx_state           <= BUSY;
            i                  <= 0;
          end
        end
        
        BUSY: begin 
          tx_pin <= tx_shift_reg[i];
          if (i == 10) begin 
            tx_complete <= 1'b1;
            tx_state    <= IDLE;
          end else begin
            i <= i + 1;
          end
        end
      endcase
    end
  end
  
  // -------------------------
  // Receive Logic 
  // -------------------------
  always_ff @(posedge clk or negedge rst_n) begin 
    if (!rst_n) begin 
      rx_state         <= IDLE; 
      rx_shift_reg     <= '0;
      rx_complete      <= 1'b0;
      parity_mismatch  <= 1'b0;
      data_out         <= 8'h00;
      f                <= 0;
    end else begin
      case (rx_state)
        IDLE: begin
          rx_complete <= 1'b0;
          if (!rx_pin) begin // Start bit detected (falling edge)
            rx_state <= BUSY; 
            f        <= 0;
          end
        end
        
        BUSY: begin 
          if (f < 9) begin
             rx_shift_reg[f] <= rx_pin;
             f <= f + 1;
          end else begin
             data_out        <= rx_shift_reg[7:0];
             rx_complete     <= 1'b1;
             rx_state        <= IDLE;
             
             if (^rx_shift_reg[7:0] != rx_shift_reg[8]) begin 
               parity_mismatch <= 1'b1; 
             end else begin
               parity_mismatch <= 1'b0;
             end
          end
        end
      endcase
    end
  end

endmodule
