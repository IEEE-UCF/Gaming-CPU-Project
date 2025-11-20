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
    output logic icache_l2_req_o,
    input logic [ADDR_WIDTH-1 : 0] l2_addr_i,
    input logic [LINE_SIZE*8-1:0] l2_data_i
);

  //localparams for constants
  localparam int SETS = IMEM_SIZE / (WAYS * LINE_SIZE);  // 128 sets
  localparam int OFFSET = $clog2(LINE_SIZE);  // 6 bits
  localparam int INDEX = $clog2(SETS);  // 7 bits
  localparam int TAG = ADDR_WIDTH - OFFSET - INDEX;  // 19 bits

  // i-cache storage
  logic [TAG-1:0] icache_tags[SETS][WAYS];
  logic [LINE_SIZE*8-1:0] icache_data[SETS][WAYS];
  logic valid_bits[SETS][WAYS];

  // hold different address portions
  logic [TAG-1 : 0] addr_tag_virtual;
  logic [INDEX-1 : 0] addr_index;
  logic [OFFSET-1 : 0] addr_offset;

  // cache hit
  logic [$clog2(WAYS)-1 : 0] hit_way;
  logic cache_tag_hit;

  // instruction output
  logic [INSTR_WIDTH-1 : 0] icache_resp_instr_next;
  logic icache_resp_valid_next;

  // grab entire set preemptively
  logic [LINE_SIZE*8-1:0] line_data[WAYS];

  // placeholder this is terrible
  logic evict_done;

  assign icache_req_ready_o = (current_state = CACHE_IDLE) ? 1'b1 : 1'b0;

  typedef enum logic [3:0] {
    CACHE_IDLE,
    CACHE_LOOKUP,
    CACHE_HIT,
    CACHE_MISS,
    CACHE_FETCH,
    CACHE_EVICT,
    CACHE_OUTPUT
  } cache_state_t;

  cache_state_t current_state = CACHE_IDLE;
  cache_state_t next_state = CACHE_IDLE;

  // tag lookup
  always_comb begin
    cache_tag_hit = 1'b0;
    hit_way = '0;
    if (current_state == CACHE_LOOKUP) begin
      for (int way = 0; way < WAYS; way++) begin
        if (tlb_pa_tag_i == icache_tags[addr_index][way] && valid_bits[addr_index][way]) begin
          hit_way = way;
          cache_tag_hit = 1'b1;
          break;
        end
      end
    end
  end

  // grab entire line data at set
  always_comb begin
    line_data = '0;
    if (current_state == CACHE_LOOKUP) begin
      line_data = icache_data[addr_index];
    end
  end

  //output data logic
  always_comb begin
    icache_resp_instr_next = '0;
    icache_resp_valid_next = 1'b0;
    if (cache_tag_hit && current_state == CACHE_LOOKUP) begin
      icache_resp_instr_next = line_data[hit_way][addr_offset*8+ADDR_WIDTH-1 : addr_offset*8];
      icache_resp_valid_next = 1'b1;
    end
  end

  // register intstruction into output
  always_ff @(posedge clk_i) begin
    icache_resp_instr_o <= icache_resp_instr_next;
    icache_resp_valid_next <= icache_resp_valid_next;
  end

  // address slicing into offset and index
  always_comb begin
    addr_index = cpu_addr_i[OFFSET+INDEX-1 : OFFSET];
    addr_offset = cpu_addr_i[OFFSET-1 : 0];
    addr_tag_virtual = cpu_addr_i[ADDR_WIDTH-1 : OFFSET+INDEX];
  end

  // rst_ni invalidate all cache lines
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      current_state <= CACHE_IDLE;
      icache_resp_instr_o <= '0;
      icache_resp_valid_o <= 1'b0;
      for (int set = 0; set < SETS; set++) begin
        for (int way = 0; way < WAYS; way++) begin
          valid_bits[set][way] <= 1'b0;
        end
      end
    end
  end

  // FENCE.I invalidate cache
  always_ff @(posedge clk_i) begin
    if (icache_flush_i) begin
      current_state <= CACHE_IDLE;
      for (int set = 0; set < SETS; set++) begin
        for (int way = 0; way < WAYS; way++) begin
          valid_bits[set][way] <= 1'b0;
        end
      end
    end
  end

  // register next state into current state
  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      current_state <= CACHE_IDLE;
    end else begin
      next_state <= current_state;
    end
  end

  // combinational state transition logic
  always_comb begin
    next_state = current_state;
    case (current_state)
      CACHE_IDLE: begin
        if (cpu_req_valid_i && icache_req_ready_o) next_state = CACHE_LOOKUP;
      end
      CACHE_LOOKUP: begin
        if (cache_tag_hit) next_state = CACHE_HIT;
        else next_state = CACHE_MISS;
      end
      CACHE_HIT: begin
        if (cpu_resp_ready_i && icache_resp_valid_o) next_state = CACHE_OUTPUT;
      end
      CACHE_MISS: begin
        if (l2_ready_i && icache_l2_req_o) next_state = CACHE_FETCH;
      end
      CACHE_FETCH: begin
        if (l2_valid_i) next_state = CACHE_EVICT;
      end
      CACHE_EVICT: begin
        if (evict_done) next_state = CACHE_LOOKUP;
      end
      CACHE_OUTPUT: begin
        if (!cpu_resp_ready_i) next_state = CACHE_OUTPUT;
        else next_state = CACHE_IDLE;
      end
      default: begin
        next_state = CACHE_IDLE;
      end
    endcase
  end
endmodule

/*
  add next state combinational logic -- kinda finished
  add replacement/evict logic -- working on it
  add communiaction with L2 cache -- later
  refine state machine -- might be good
*/

