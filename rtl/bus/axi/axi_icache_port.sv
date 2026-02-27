import interconnect_pkg;

module axi_icache_port #(
  // System AXI Parameters
  parameter int unsigned AXI_ADDR_WIDTH = 32,
  parameter int unsigned AXI_DATA_WIDTH = 64,
  parameter int unsigned AXI_ID_WIDTH   = 4,
  parameter int unsigned AXI_USER_WIDTH = 1,


)(

  // global clock and reset signals
  input logic clk_i,
  input logic rst_ni


  // icache valid request and address
  input logic                             ic_req_valid_i,
  input logic[AXI_ADDR_WIDTH-1:0]         ic_addr_valid_i,
  input logic

  // icache 


  // axi address read signals
  output logic [AXI_ADDR_WIDTH-1:0]       axi_mem_ar_o,
  output logic axi_ar_valid_o, 
  input logic axi_ar_ready_i, 
  


  // axi read data signals
  input logic axi_mem_r_i,
  input logic axi_r_ready_i, 
  input logic axi_r_valid_i,
  input logic [AXI_ADDR_WIDTH*4-1:0]      axi_mem_r_i,

  typedef enum [2:0] {
    IDLE,					  // Do nothing, wait for icache to miss
    AR_SEND,				// cache requested a line, put it on araddr and set ARVALID to high
    R_COLLECT,      // collect the requested data from the crossbar and send it to cache, once rlast is recieved, flip back to idle

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


  // state transition logic
  always_comb begin 
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (conditions) next_state = AR_SEND;

      end

      AR_SEND: begin
        if (conditions) next_state = R_COLLECT;

      end

      R_COLLECT: begin
        if (conditions) next_state = IDLE;

      end
    endcase
    
  end
);

endmodule
