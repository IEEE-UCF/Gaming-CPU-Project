import interconnect_pkg;

module axi_icache_port #(
  // System AXI Parameters
  parameter int unsigned AXI_ADDR_WIDTH = 32,
  parameter int unsigned AXI_DATA_WIDTH = 64,
  parameter int unsigned AXI_ID_WIDTH   = 4,
  parameter int unsigned AXI_USER_WIDTH = 1,



)(
  // TODO: Port set up ports

  // global clock and reset signals
  input logic clk_i,
  input logic rst_ni

  // icache valid request and address
  input logic                         ic_req_valid_i,
  input logic[AXI_ADDR_WIDTH-1:0]     ic_addr_valid_i,

  // icache


  // axi address read signals
  output logic axi_mem_ar_o,
  output logic axi_ar_valid_o, 
  input logic axi_ar_ready_i, 

  // axi read data signals
  input logic axi_mem_r_i,
  input logic axi_r_ready_i, 
  input logic axi_r_valid_i,


  typedef enum [2:0] {
    IDLE;					  // Do nothing, wait for i$ to miss
    AR_SEND;				// cache requested a line, put it on araddr and set ARVALID to high
    R_COLLECT;      // collect the requested data from the crossbar and send it to cache

  } icache_port_state_e;

  icache_port_state_e current_state, next_state;

  // state transition
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      current_state <= IDLE;
    end
    else begin
      current_state <= next_state;
    end
  end
  
);

endmodule
