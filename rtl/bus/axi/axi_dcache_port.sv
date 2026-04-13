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

  // Global & Control Signals
  input logic m_clk_i,  // Master (main) clock signal
  input logic s_clk_i, // Slave clock signal
  input logic rst_ni,

  // Write Address (AW) Channel
  output logic [AXI_ID_WIDTH-1:0] aw_id_o, // ID Tag
  output logic [AXI_ADDR_WIDTH-1:0] aw_addr_o, // Addr. of first transfer in write burst
  output logic [AXI_BURST_LEN-1:0] aw_len_o, // No. of transfers in a burst
  output logic [AXI_BURST_SIZE-1:0] aw_size_o, // Bytes per beats
  output logic [1:0] aw_burst_o, // Burst type (fixed, incr, wrap)
  output logic aw_valid_o, // Valid write addr.
  input logic aw_ready_i, // Slave ready to accept addr.
  input logic aw_fifo_full_i, // FIFO full indicator
  input logic aw_fifo_empty_i, // FIFO empty indicator

  // Write Data (W) Channel
  output logic [DATA_WIDTH*8-1:0] w_data_o, // Write data
  output logic [AXI_STRB_WIDTH-1:0] w_strb_o, // Byte lane indicator
  output logic w_last_o, // Last transfer in write burst
  output logic w_valid_o, // Write data available
  input logic w_ready_i, // Slave can accept write data
  input logic w_fifo_full_i, // FIFO full indicator
  input logic w_fifo_empty_i, // FIFO empty indicator

  // Write Response (B) Channel
  input logic [ID_WIDTH-1:0] b_id_i, // ID tag of write response
  input logic b_valid_i, // Slave signaling valid response
  output logic b_ready_o, // Master can accept write response
  input logic b_resp_i, // transaction status (might be unnecessary)
  input logic b_fifo_full_i, // FIFO full indicator
  input logic b_fifo_empty_i, // FIFO empty indicator

  // Read Address (AR) Channel
  output logic [ID_WIDTH-1:0] ar_id_o, // ID tag for AR
  output logic [ADDR_WIDTH-1:0] ar_addr_o, // Addr. of first transfer in read burst
  output logic [AXI_BURST_LEN-1:0] ar_len_o, // No. of transfers in a burst
  output logic [AXI_BURST_SIZE:0] ar_size_o, // Bytes per beats
  output logic [1:0] ar_burst_o, // Burst type (fixed, incr, wrap)
  output logic ar_valid_o, // Valid read addr.
  input logic ar_ready_i, // Slave ready to accept addr.
  input logic ar_fifo_full_i, // FIFO full indicator
  input logic ar_fifo_empty_i, // FIFO empty indicator

  // Read Data (R) Channel
  input logic [ID_WIDTH-1:0] r_id_i, // ID tag for R
  input logic [DATA_WIDTH*8-1:0] r_data_i, // Read data
  input logic r_valid_i, // Slave signaling valid response
  output logic r_ready_o, // Master can accept read data
  input logic r_last_i, // Last transfer in read burst
  input logic [1:0] r_resp_i, // read trans. status (might be unncessary)
  input logic r_fifo_full_i, // FIFO full indicator
  input logic r_fifo_empty_i, // FIFO empty indicator

  //D$ <-> AXI
  input logic dcache_axi_req_valid_i,
  output logic axi_dcache_req_ready_o,
  input logic dcache_wb_e,
  input logic [ADDR_WIDTH-1:0] dcache_axi_req_addr_i,
  input logic [DATA_WIDTH*8-1:0] dcache_axi_req_data_i,
  output logic axi_dcache_resp_valid_o,
  input logic axi_dcache_resp_ready_i,
  output logic [DATA_WIDTH*8-1:0] axi_dcache_resp_data_o
);

// Registers for latching addr/data from D$
logic [ADDR_WIDTH-1:0] dcache_addr_latched;
logic [DATA_WIDTH*8-1:0] dcache_data_latched;
logic addr_data_latched_w;

logic [ADDR_WIDTH-1:0] dcache_addr_latched_r;
logic addr_latched_r;

// Register for tracking beats in a transaction
logic [AXI_BURST_LEN-1:0] beats;

// Flags for writeback (B) response
logic write_resp;
logic write_error;

// Flags for pushing / popping from respective FIFOs
logic aw_fifo_wr_push_o;
logic w_fifo_wr_push_o;
logic b_fifo_rd_pop_o;
logic ar_fifo_wr_push_o;
logic r_fifo_rd_pop_o;

typedef struct packed {
  logic [AXI_ID_WIDTH-1:0] id;
  logic [AXI_ADDR_WIDTH-1:0] addr;
  logic [AXI_BURST_LEN-1:0] len;
  logic [AXI_BURST_SIZE-1:0] size;
  logic [1:0] burst;
} axi_aw_payload_t;

typedef struct packed {
  logic [DATA_WIDTH*8-1:0] data;
  logic [AXI_STRB_WIDTH-1:0] strb;
  logic last;
} axi_w_payload_t;

typedef struct packed {
  logic [ID_WIDTH-1:0] id;
  logic [1:0] resp;
} axi_b_payload_t;

typedef struct packed {
  logic [ID_WIDTH-1:0] id;
  logic [ADDR_WIDTH-1:0] addr;
  logic [AXI_BURST_LEN-1:0] len;
  logic [AXI_BURST_SIZE:0] size;
  logic [1:0] burst;
} axi_ar_payload_t;

typedef struct packed {
  logic [ID_WIDTH-1:0] id;
  logic [DATA_WIDTH*8-1:0] data;
  logic last;
  logic resp;
} axi_r_payload_t;

// Instatiate module side payloads
axi_aw_payload_t aw_wr_s;
axi_w_payload_t w_wr_s;
axi_b_payload_t b_rd_s;
axi_ar_payload_t ar_wr_s;
axi_r_payload_t r_rd_s;

// Construct payloads for module side (ids are defaulted to 0 and does not support multiple transactions...TODO)
assign aw_wr_s = '{id: '0, addr: dcache_addr_latched, len: AXI_BURST_LEN-1, size: AXI_BURST_SIZE, burst: 2'b01};
assign w_wr_s  = '{data: dcache_data_latched, strb: '1, last: (beats == AXI_BURST_LEN-1)};
assign b_rd_s  = '{id: b_id_i, resp: b_resp_i};
assign ar_wr_s = '{id: '0, addr: dcache_addr_latched_r, len: AXI_BURST_LEN-1, size: AXI_BURST_SIZE, burst: 2'b01};
assign r_rd_s  = '{id: r_id_i, data: r_data_i, last: r_last_i, resp: r_resp_i};

// Payloads signals to be passed through respective FIFOs
logic [$bits(axi_aw_payload_t)-1:0] aw_wr_data_o;
logic [$bits(axi_w_payload_t)-1:0]  w_wr_data_o;
logic [$bits(axi_b_payload_t)-1:0]  b_rd_data_i;
logic [$bits(axi_ar_payload_t)-1:0] ar_wr_data_o;
logic [$bits(axi_r_payload_t)-1:0]  r_rd_data_i;

// Drive struct payloads for use in FIFOs
assign aw_wr_data_o = aw_wr_s;
assign w_wr_data_o = w_wr_s;
assign b_rd_data_i = b_rd_s;
assign ar_wr_data_o = ar_wr_s;
assign r_rd_data_i = r_rd_s;

// Instatiate FIFOs for each respective channel
axi_fifo #(
  .DATA_WIDTH($bits(axi_aw_payload_t))
) aw_ch_fifo_o ( // Write Address (AW) FIFO
  .wr_clk_i(m_clk_i),
  .rd_clk_i(s_clk_i),
  .rst_ni(rst_ni),
  .wr_en_i(aw_fifo_wr_push_o),
  .rd_en_i(1'b0),
  .wr_data_i(aw_wr_data_o),
  .rd_data_o(),
  .full_o(aw_fifo_full_i),
  .empty_o(aw_fifo_empty_i)
);

axi_fifo #(
  .DATA_WIDTH($bits(axi_w_payload_t))
) w_ch_fifo_o ( // Write Data (W) FIFO
  .wr_clk_i(m_clk_i),
  .rd_clk_i(s_clk_i),
  .rst_ni(rst_ni),
  .wr_en_i(w_fifo_wr_push_o),
  .rd_en_i(1'b0),
  .wr_data_i(w_wr_data_o),
  .rd_data_o(),
  .full_o(w_fifo_full_i),
  .empty_o(w_fifo_empty_i)
);

axi_fifo #(
  .DATA_WIDTH($bits(axi_b_payload_t))
) b_ch_fifo_i ( // Write Response (B) FIFO
  .wr_clk_i(s_clk_i),
  .rd_clk_i(m_clk_i),
  .rst_ni(rst_ni),
  .wr_en_i(1'b0),
  .rd_en_i(b_fifo_rd_pop_o),
  .wr_data_i(),
  .rd_data_o(b_rd_data_i),
  .full_o(b_fifo_full_i),
  .empty_o(b_fifo_empty_i)
);

axi_fifo #(
  .DATA_WIDTH($bits(axi_ar_payload_t))
) ar_ch_fifo_o ( // Read Address (AR) FIFO
  .wr_clk_i(m_clk_i),
  .rd_clk_i(s_clk_i),
  .rst_ni(rst_ni),
  .wr_en_i(ar_fifo_wr_push_o),
  .rd_en_i(1'b0),
  .wr_data_i(ar_wr_data_o),
  .rd_data_o(),
  .full_o(ar_fifo_full_i),
  .empty_o(ar_fifo_empty_i)
);

axi_fifo #(
  .DATA_WIDTH($bits(axi_r_payload_t))
) r_ch_fifo_i ( // Read Data (R) FIFO
  .wr_clk_i(s_clk_i),
  .rd_clk_i(m_clk_i),
  .rst_ni(rst_ni),
  .wr_en_i(1'b0),
  .rd_en_i(r_fifo_rd_pop_o),
  .wr_data_i(),
  .rd_data_o(r_rd_data_i),
  .full_o(r_fifo_full_i),
  .empty_o(r_fifo_empty_i)
);

// Write FSM Definition
typedef enum logic [2:0] {
  W_IDLE,
  W_ADDR,
  W_DATA,
  W_BWAIT,
  W_DONE
} axi_write_state_t;
axi_write_state_t w_current_state, w_next_state;

// Read FSM Definition
typedef enum logic [2:0] {
  R_IDLE,
  R_ADDR,
  R_DATA,
  R_DONE
} axi_read_state_t;
axi_read_state_t r_current_state, r_next_state;

  // Next State Sequential Logic
  // Reset Condition for both state machines
  always_ff @(posedge m_clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      w_current_state <= W_IDLE;
      r_current_state <= R_IDLE;
    end else begin
      w_current_state <= w_next_state;
      r_current_state <= r_next_state;
    end
  end

  // Requests are accepted when no transaction is in progress (this will be changed for multiple outstanding transactions)
  assign axi_dcache_req_ready_o = (r_current_state == R_IDLE && w_current_state == W_IDLE);
  assign axi_dcache_resp_data_o = r_rd_s.data;

  // Sequential block for latching D$ data
  always_ff @(posedge m_clk_i or negedge rst_ni) begin
    if(!rst_ni) begin
      dcache_addr_latched <= '0;
      dcache_data_latched <= '0;
      addr_data_latched_w <= 1'b0;
    end
    else if(w_current_state == W_IDLE) begin
        if(dcache_axi_req_valid_i && dcache_wb_e && axi_dcache_req_ready_o) begin
          dcache_addr_latched <= dcache_axi_req_addr_i;
          dcache_data_latched <= dcache_axi_req_data_i;
          addr_data_latched_w <= 1'b1;
        end
      end
  end

// Sequential block for sending write address (AW)
  always_ff @(posedge m_clk_i or negedge rst_ni) begin
    if(!rst_ni) begin
      aw_valid_o <= 1'b0;
      aw_fifo_wr_push_o <= 1'b0;
    end else begin
      aw_valid_o <= 1'b0;
      aw_fifo_wr_push_o <= 1'b0;

      if(w_current_state == W_ADDR && !aw_fifo_full_i) begin
        aw_valid_o <= 1'b1;
        aw_fifo_wr_push_o <= 1'b1;
      end
    end
  end

// Sequential block for write data (W)
  always_ff @(posedge m_clk_i or negedge rst_ni) begin
    beats <= '0;
    if(!rst_ni) begin
      w_valid_o <= 1'b0;
      beats <= '0;
      w_fifo_wr_push_o <= 1'b0;
    end
      if(w_current_state == W_DATA && !w_fifo_full_i) begin
        w_valid_o <= 1'b1;
        w_fifo_wr_push_o <= 1'b1;

        if(beats != AXI_BURST_LEN-1) begin
          beats <= beats + 1'b1;
        end
        else begin
          beats <= '0;
        end
      end
  end

 // Sequential block for write response (B)
  always_ff @(posedge m_clk_i or negedge rst_ni) begin
    write_resp <= 1'b0;
    write_error <= 1'b0;
    if(!rst_ni) begin
      b_ready_o <= 1'b0;
      write_resp <= 1'b0;
      write_error <= 1'b0;
      b_fifo_rd_pop_o <= 1'b0;
    end
    if(w_current_state == W_BWAIT && !b_fifo_empty_i) begin
        b_ready_o <= 1'b1;
        b_fifo_rd_pop_o <= 1'b1;
        write_resp <= 1'b1;
        write_error <= (b_rd_s.resp != 2'b00);
        addr_data_latched_w <= 1'b0;
      end
  end

  //TODO: Implement ID Tracker to handle multiple outstanding transactions
  //TODO: Implement handler in event of write respond (B) error (might be unneccesary?)

  // Write State Combinational Block
  always_comb begin
  w_next_state = w_current_state;
  case(w_current_state)
    W_IDLE: begin
      if(addr_data_latched_w && dcache_wb_e) begin
        w_next_state = W_ADDR;
      end
    end
    W_ADDR: begin
      if(!aw_fifo_full_i) begin
        w_next_state = W_DATA;
      end
    end
    W_DATA: begin
      if(!w_fifo_full_i && w_wr_s.last) begin
        w_next_state = W_BWAIT;
      end
    end
    W_BWAIT: begin
      if(!b_fifo_empty_i) begin
        w_next_state = W_DONE;
      end
    end
    W_DONE: begin
      if(!write_error) begin
        w_next_state = W_IDLE;
      end
    end
    default: begin
      w_next_state = W_IDLE;
    end
  endcase
  end

   // Sequential block latching read address
  always_ff @(posedge m_clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      dcache_addr_latched_r <= '0;
      addr_latched_r <= 1'b0;
    end
    if (r_current_state == R_IDLE) begin
      if (dcache_axi_req_valid_i && !dcache_wb_e && !ar_fifo_full_i && axi_dcache_req_ready_o) begin
        dcache_addr_latched_r <= dcache_axi_req_addr_i;
        addr_latched_r <= 1'b1;
      end
    end
  end

  // Sequential block for read address (AR)
  always_ff @(posedge m_clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ar_valid_o <= 1'b0;
      ar_fifo_wr_push_o <= 1'b0;
    end else begin
      ar_valid_o <= 1'b0;
      ar_fifo_wr_push_o <= 1'b0;

      if (r_current_state == R_ADDR) begin
        if (addr_latched_r && !ar_fifo_full_i) begin
          ar_valid_o <= 1'b1;
          ar_fifo_wr_push_o <= 1'b1;
        end
      end
    end
  end

  // Sequential block for read data (R)
  always_ff @(posedge m_clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      r_ready_o <= 1'b0;
      r_fifo_rd_pop_o <= 1'b0;
    end else begin
      r_ready_o <= 1'b0;
      r_fifo_rd_pop_o <= 1'b0;

      if (r_current_state == R_DATA) begin
        if (!r_fifo_empty_i) begin
          r_ready_o <= 1'b1;
          r_fifo_rd_pop_o <= 1'b1;
        end
      end
    end
  end

  // Sequential for returning to dcache (done)
  always_ff @(posedge m_clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      axi_dcache_resp_valid_o <= 1'b0;
    end else if (r_current_state == R_DONE) begin
      axi_dcache_resp_valid_o <= 1'b1;
      if (axi_dcache_resp_valid_o && axi_dcache_resp_ready_i) begin
        axi_dcache_resp_valid_o <= 1'b0;
      end
    end else begin
      axi_dcache_resp_valid_o <= 1'b0;
      addr_latched_r <= 1'b0;
    end
  end

  // Read State Combinational Block
  always_comb begin
  r_next_state = r_current_state;
  case(r_current_state)
    R_IDLE: begin
      if(dcache_axi_req_valid_i && !dcache_wb_e && !ar_fifo_full_i && addr_latched_r) begin
        r_next_state = R_ADDR;
      end
      else if(addr_latched_r) begin
        r_next_state = R_ADDR;
      end
    end
    R_ADDR: begin
      if(!ar_fifo_full_i && addr_latched_r) begin
        r_next_state = R_DATA;
      end
    end
    R_DATA: begin
      if(!r_fifo_empty_i && r_rd_s.last && (r_rd_s.resp == 1'b0)) begin
        r_next_state = R_DONE;
      end
    end
    R_DONE: begin
      if(axi_dcache_resp_valid_o && axi_dcache_resp_ready_i) begin
        r_next_state = R_IDLE;
      end
    end
    default: begin
      r_next_state = R_IDLE;
    end
  endcase
  end
endmodule
