module axi_dcache_port

// Parameters subject to change?
import interconnect_pkg::*;
#(
  /*AXI_ADDR_WIDTH = 32,
    AXI_DATA_WIDTH = 64,
    AXI_ID_WIDTH = 4,
    AXI_USER_WIDTH = 1,
    AXI_STRB_WIDTH = AXI_DATA_WIDTH/8,
    AXI_BURST_LEN = (AXI_DATA_WIDTH / 8),
    AXI_BURST_SIZE = $clog2(AXI_BURST_LEN),
  */
)(

  input logic clk_i,
  input logic rst_ni,

  // Write Address (AW) Channel
  output logic [AXI_ID_WIDTH-1:0] aw_id_o, // ID Tag
  output logic [AXI_ADDR_WIDTH-1:0] aw_addr_o, // Addr. of first transfer in write burst
  output logic [AXI_BURST_LEN-1:0] aw_len_o, // No. of transfers in a burst
  output logic [AXI_BURST_SIZE-1:0] aw_size_o, // Bytes per beat
  output logic [1:0] aw_burst_o, // Burst type (fixed, incr, wrap)
  output logic aw_valid_o, // Valid write addr.
  input logic aw_ready_i, // Slave ready to accept addr.

  // Write Data (W) Channel
  output logic [DATA_WIDTH-1:0] w_data_o, // Write data
  output logic [AXI_STRB_WIDTH-1:0] w_strb_o, // Byte lane indicator
  output logic w_last_o, // Last transfer in write burst
  output logic w_valid_o, // Write data available
  input logic w_ready_i, // Slave can accept write data

  // Write Response (B) Channel
  input logic [ID_WIDTH-1:0] b_id_i, // ID tag of write response
  input logic b_valid_i, // Slave signaling valid response
  output logic b_ready_o, // Master can accept write response
  input logic b_resp_i, // transaction status (might be unnecessary)

  // Read Address (AR) Channel
  output logic [ID_WIDTH-1:0] ar_id_o, // ID tag for AR
  output logic [ADDR_WIDTH-1:0] ar_addr_o, // Addr. of first transfer in read burst
  output logic [AXI_BURST_LEN-1:0] ar_len_o, // No. of transfers in a burst
  output logic [AXI_BURST_SIZE:0] ar_size_o, // Bytes per beat
  output logic [1:0] ar_burst_o, // Burst type (fixed, incr, wrap)
  output logic ar_valid_o, // Valid read addr.
  input logic ar_ready_i, // Slave ready to accept addr.

  // Read Data (R) Channel
  input logic [ID_WIDTH-1:0] r_id_i, // ID tag for R
  input logic [DATA_WIDTH-1:0] r_data_i, // Read data
  input logic r_valid_i, // Slave signaling valid response
  output logic r_ready_o, // Master can accept read data
  input logic r_last_i, // Last transfer in read burst
  input logic r_resp_i, // read trans. status (might be unncessary)

  // TODO: D$ <-> AXI
  // D$ -> AXI Interface
  input logic dcache_miss, // Miss occured
  input logic dcache_wb // WB or only allocate

  // AXI Interface -> D$
);

// States (subject to change as needed)
typedef enum logic [2:0] {
  AXI_IDLE,
  AXI_RADDR,
  AXI_RDATA,
  AXI_WADDR,
  AXI_WDATA
} axi_dcache_state_t;
axi_dcache_state_t current_state, next_state;

  // Next State Sequential Logic
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      current_state <= AXI_IDLE;
    end else begin
      current_state <= next_state;
    end
  end

  // TODO: Implement sequential blocks for respective states

  // Drive Depending on State
  assign aw_valid_o = (current_state == AXI_WADDR);
  assign ar_valid_o = (current_state == AXI_RADDR);

  // Next State Combinational Logic (subject to change)
  always_comb begin
  next_state = current_state;
  case(current_state)
    AXI_IDLE: begin
      if(dcache_miss) begin
        if(dcache_wb) begin
          next_state = AXI_WADDR;
        end
        else begin
          next_state = AXI_RADDR;
        end
      end
    end

    AXI_RADDR: begin
      if(ar_valid_o && ar_ready_i) begin
        next_state = AXI_RDATA;
      end
    end

    AXI_WADDR: begin
      if(aw_valid_o && aw_ready_i) begin
        next_state = AXI_WDATA;
      end
    end

    // TODO: Implement comb. logic for RDATA / WDATA
    AXI_RDATA: begin

    end

    AXI_WDATA: begin

    end

    default: begin
      next_state = AXI_IDLE;
    end
  endcase
  end



endmodule
