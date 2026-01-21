/*
-- replacement policy
*/
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
    input logic [ADDR_WIDTH-1:0] cpu_addr_i,
    input logic cpu_resp_ready_i,
    output logic icache_req_ready_o,
    output logic icache_resp_valid_o,
    output logic [INSTR_WIDTH-1:0] icache_resp_instr_o,

    // TLB -> I$ Interface
    // the 19 bit width is based on current iteration
    //can change based on localparam "TAG"
    input logic [18:0] tlb_pa_tag_i,
    input logic tlb_resp_valid_i,
    output logic icache_tlb_resp_ready_o,

    // AXI interface (placeholder)
    input logic axi_ready_i,
    input logic axi_valid_i,
    output logic icache_axi_req_o,
    output logic [ADDR_WIDTH-1:0] icache_axi_addr_o,
    input logic [ADDR_WIDTH-1:0] axi_addr_i,
    input logic [LINE_SIZE*8-1:0] axi_data_i
);

  // Constants
  localparam int SETS = IMEM_SIZE / (WAYS * LINE_SIZE);  // 128 sets
  localparam int OFFSET = $clog2(LINE_SIZE);  // 6 bits
  localparam int INDEX = $clog2(SETS);  // 7 bits
  localparam int TAG = ADDR_WIDTH - OFFSET - INDEX;  // 19 bits

  typedef enum logic [3:0] {
    IDLE,
    LOOKUP,
    FETCH,
    EVICT
  } cache_state_t;

  cache_state_t current_state, next_state;

  // Cache Storage
  logic [TAG-1:0] icache_tags[SETS][WAYS];
  logic [LINE_SIZE*8-1:0] icache_data[SETS][WAYS];
  logic valid_bits[SETS][WAYS];

  // Address Slicing
  logic [INDEX-1:0] addr_index;
  logic [OFFSET-1:0] addr_offset;
  assign addr_index  = cpu_addr_i[OFFSET+:INDEX];
  assign addr_offset = cpu_addr_i[0+:OFFSET];

  // Hit Signals
  logic [$clog2(WAYS)-1:0] hit_way;
  logic cache_tag_hit;

  // Evict Signals
  logic evict_done;
  logic [$clog2(WAYS)-1:0] victim_way;

  // Output Flags
  assign icache_req_ready_o = (current_state == IDLE);
  assign icache_axi_req_o = (current_state == FETCH);
  assign icache_tlb_resp_ready_o = (current_state == LOOKUP);

  /*//////////////////////////////////////////////
  * GLOBAL RESET / FENCE.I OPERATIONS
  ////////////////////////////////////////////////*/

  // rst_ni / FENCE.I invalidate all cache lines
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni || icache_flush_i) begin
      for (int set = 0; set < SETS; set++) begin
        for (int way = 0; way < WAYS; way++) begin
          valid_bits[set][way] <= 1'b0;
        end
      end
    end
  end

  /*//////////////////////////////////////////////
  * CACHE LOOKUP
  ////////////////////////////////////////////////*/

  logic [LINE_SIZE*8-1:0] hit_line_data;
  assign hit_line_data = icache_data[addr_index][hit_way];

  // Tag Lookup
  always_comb begin
    cache_tag_hit = 1'b0;
    hit_way = {WAYS{1'b0}};
    if (current_state == LOOKUP && tlb_resp_valid_i) begin
      for (int way = 0; way < WAYS; way++) begin
        if ((tlb_pa_tag_i == icache_tags[addr_index][way]) && valid_bits[addr_index][way]) begin
          hit_way = way;
          cache_tag_hit = 1'b1;
        end
      end
    end
  end

  // Cache output
  logic [INSTR_WIDTH-1:0] icache_resp_instr_next;
  logic icache_resp_valid_next;

  always_comb begin
    icache_resp_instr_next = {INSTR_WIDTH{1'b0}};
    icache_resp_valid_next = 1'b0;
    if (cache_tag_hit && current_state == LOOKUP) begin
      icache_resp_instr_next = hit_line_data[{addr_offset, 3'b000}+:INSTR_WIDTH];
      icache_resp_valid_next = 1'b1;
    end
  end

  // Register output
  always_ff @(posedge clk_i) begin
    icache_resp_instr_o <= icache_resp_instr_next;
    icache_resp_valid_o <= icache_resp_valid_next;
  end

  /*//////////////////////////////////////////////
  * CACHE FETCH
  ////////////////////////////////////////////////*/

  assign icache_axi_addr_o = {tlb_pa_tag_i, addr_index, {OFFSET{1'b0}}};

  /*////////////////////////////////////////////////
  * CACHE EVICT
  * -- replacement policy needed
  ////////////////////////////////////////////////*/

  always_ff @(posedge clk_i) begin
    if (current_state == EVICT && axi_valid_i) begin
      icache_data[addr_index][victim_way] <= axi_data_i;
      icache_tags[addr_index][victim_way] <= tlb_pa_tag_i;
      valid_bits[addr_index][victim_way] <= 1'b1;
      evict_done <= 1'b1;
    end
  end

  /*//////////////////////////////////////////////
  * STATE CONTROL / TRANSITION
  ////////////////////////////////////////////////*/

  // register next state into current state
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      current_state <= IDLE;
    end else if (icache_flush_i) begin
      current_state <= IDLE;
    end else begin
      current_state <= next_state;
    end
  end

  // combinational state transition logic
  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (cpu_req_valid_i && icache_req_ready_o) next_state = LOOKUP;
      end
      LOOKUP: begin
        if (!cache_tag_hit) begin
          next_state = FETCH;
        end else begin
          next_state = IDLE;
        end
      end
      FETCH: begin
        if (axi_ready_i) next_state = EVICT;
      end
      EVICT: begin
        if (evict_done) next_state = LOOKUP;
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end
endmodule
