module icache #(
    parameter int INSTR_WIDTH = 32,
    parameter int ADDR_WIDTH = 32,
    parameter int LINE_SIZE = 64,
    parameter int WAYS = 2,
    parameter int IMEM_SIZE = 16384
) (
    // Global / Control signals
    input logic clk_i,
    input logic rst_ni,
    input logic icache_flush_i, // FENCE_I

    // CPU <-> I$ Interface
    input logic cpu_req_valid_i,
    input logic [ADDR_WIDTH-1 : 0] cpu_addr_i,
    input logic cpu_resp_ready_i,
    output logic icache_req_ready_o,
    output logic icache_resp_valid_o,
    output logic [INSTR_WIDTH-1 : 0] icache_resp_instr_o,

    // TLB -> I$ Interface
    input logic [TAG-1 : 0] tlb_pa_tag_i,
    input logic tlb_req_ready_i,
    input logic tlb_resp_valid_i,
    output logic icache_tlb_resp_ready_o,

    // L2$ <-> I$ Interface
    input logic l2_ready_i,
    input logic l2_valid_i,
    input logic [ADDR_WIDTH-1 : 0] l2_addr_i,
    input logic [LINE_SIZE*8-1:0] l2_data_i

    // AXI Interface not needed on I$, we only communicate with CPU and L2 Cache
);
  //localparams for constants
  localparam int SETS = IMEM_SIZE / (WAYS * LINE_SIZE);  // 128 sets
  localparam int OFFSET = $clog2(LINE_SIZE);  // 6 bits
  localparam int INDEX = $clog2(SETS);  // 7 bits
  localparam int TAG = ADDR_WIDTH - OFFSET - INDEX;  // 19 bits

  //main cache storage
  logic [TAG-1:0] icache_tags [SETS][WAYS];
  logic [LINE_SIZE*8-1:0] icache_data [SETS][WAYS];
  logic valid_bits [SETS][WAYS];

  //address
  logic [TAG-1 : 0] addr_tag_virtual;
  logic [INDEX-1 : 0] addr_index;
  logic [OFFSET-1 : 0] addr_offset;

  //cache state machine
  typedef enum logic [2:0] {
    IDLE,
    LOOKUP,
    MISS,
    DATA
  } cache_state_t;

  cache_state_t current_state, next_state;

  // main sequential loop
  always_ff @(posedge clk_i) begin
    if(!rst_ni) begin
      current_state <= IDLE;
      for(int set = 0; set < SETS; set++) begin
        for(int way = 0; way < WAYS; way++) begin
          valid_bits[set][way] <= 1'b0;
        end
      end
    end
    else if(icache_flush_i) begin
      current_state <= IDLE;
      for(int set = 0; set < SETS; set++) begin
        for(int way = 0; way < WAYS; way++) begin
          valid_bits[set][way] <= 1'b0;
        end
      end
    end
    else begin
      current_state <= next_state;
    end
  end

  // VIPT address stuff
  always_comb begin
    addr_index = cpu_addr_i[OFFSET+INDEX-1 : OFFSET];
    addr_offset = cpu_addr_i[OFFSET-1 : 0];
    addr_tag_virtual = cpu_addr_i[ADDR_WIDTH-1 : OFFSET+INDEX];
  end

  //combinational next state control
  always_comb begin
    case (current_state)
      IDLE:
      LOOKUP:
      MISS:
      DATA:
      default: next_state = IDLE;
    endcase
  end

/*
add next state combinational logic
add replacement/evict logic
add communiaction with L2 cache
refine state machine
*/

endmodule
