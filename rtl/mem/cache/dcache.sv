module dcache #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32,
    parameter int LINE_BYTES = 64,
    parameter int WAYS = 2,
    parameter int DMEM_SIZE = 16384
) (
    // Global / Control signals
    input logic clk_i,  // Main clock input
    input logic rst_ni, // Active low reset

    // CPU -> D$ Store Instr.
    input  logic                    cpu_we_i,                // 1=store, 0=load
    input  logic                    cpu_req_valid_i,         // Request Valid
    output logic                    dcache_cpu_req_ready_o,  // Cache Ready
    input  logic [  ADDR_WIDTH-1:0] cpu_addr_i,
    input  logic [  DATA_WIDTH-1:0] cpu_wdata_i,             // Write -> Cache
    input  logic [DATA_WIDTH/8-1:0] cpu_wstrb_i,             // Byte-Enabled

    // D$ -> CPU Load Data
    output logic                  dcache_cpu_resp_valid_o,  // D$ Response Valid
    input  logic                  cpu_resp_ready_i,         // CPU Ready
    output logic [DATA_WIDTH-1:0] dcache_resp_rdata_o,      // CPU Load
    //output logic [ADDR_WIDTH-1:0] dcache_resp_addr_o,

    // TLB <-> D$ Interface
    input  logic [TAG-1 : 0] tlb_pa_tag_i,            // Returned Physical Tag
    output logic [TAG-1 : 0] virt_addr_tag_o,         // VA to be Translated
    output logic             dcache_tlb_req_valid_o,  // D$ TLB Request Valid
    input  logic             tlb_req_ready_i,         // TLB Ready
    input  logic             tlb_resp_valid_i,        // TLB Response Valid
    output logic             dcache_tlb_resp_ready_o, // D$ Resposne Ready

    // L2$ <-> D$ Interface
    input logic l2_ready_i,
    input logic l2_valid_i,
    input logic [ADDR_WIDTH-1 : 0] l2_addr_i,
    input logic [LINE_BYTES*8-1:0] l2_data_i
);

  // Local constants
  localparam int SETS = DMEM_SIZE / (WAYS * LINE_BYTES);  // 129 sets
  localparam int OFFSET = $clog2(LINE_BYTES);  // 6 bits
  localparam int INDEX = $clog2(SETS);  // 7 bits
  localparam int TAG = ADDR_WIDTH - OFFSET - INDEX;  // 19 bits

  // D$ Storage
  logic [TAG-1:0] dcache_tags[SETS][WAYS];
  logic [LINE_BYTES*8-1:0] dcache_data[SETS][WAYS];
  logic dirty_bits[SETS][WAYS];
  logic valid_bits[SETS][WAYS];

  // Split Passeed CPU address into tag, index, offset
  logic [OFFSET-1:0] virt_offset;
  logic [INDEX-1:0] virt_index;
  logic [TAG-1:0] virt_tag;
  logic [TAG-1:0] pa_tag;

  // Cache Hit Logic
  logic cache_hit;
  logic [WAYS:0] hit_way;
  localparam int BWIDTH = DATA_WIDTH / 8;

  typedef enum logic [3:0] {
    CACHE_IDLE,
    CACHE_LOOKUP,
    CACHE_HIT,
    CACHE_MISS,
    CACHE_ALLOCATE,
    CACHE_WRITEBACK,
    CACHE_EVICT,
    CACHE_RESPOND
  } cache_state_t;

  cache_state_t current_state, next_state;

  // Reset Cache Lines, Initiate FSM
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      current_state <= CACHE_IDLE;
      for (int set = 0; set < SETS; set++)
      for (int way = 0; way < WAYS; way++) begin
        valid_bits[set][way] <= 1'b0;
        dirty_bits[set][way] <= 1'b0;
      end
    end else begin
      current_state <= next_state;
    end
  end

  // Split Virtual Address
  always_comb begin
    virt_offset = cpu_addr_i[0+:OFFSET];
    virt_index = cpu_addr_i[OFFSET+:INDEX];
    virt_tag = cpu_addr_i[OFFSET+INDEX+:TAG];
  end

  // Cache Lookup Logic
  always_comb begin
    cache_hit = 1'b0;
    pa_tag = tlb_pa_tag_i;
    if (current_state == CACHE_LOOKUP && tlb_resp_valid_i)
      for (int way = 0; way < WAYS; way++) begin
        if (valid_bits[virt_index][way] && (dcache_tags[virt_index][way] == pa_tag)) begin
          cache_hit = 1'b1;
          hit_way   = way;
        end
      end
  end

  // Returning Requested Data to CPU
  always_comb begin
    dcache_cpu_resp_valid_o = 1'b0;
    dcache_resp_rdata_o = '0;
    if (current_state == CACHE_RESPOND) begin
      if (!cpu_we_i) begin
        dcache_resp_rdata_o = dcache_data[virt_index][hit_way];
      end
      dcache_cpu_resp_valid_o = 1'b1;
    end
  end

  // Write to Appropriate Cache Line
  always_ff @(posedge clk_i) begin
    if (current_state == CACHE_HIT && cache_hit) begin
      if (cpu_we_i) begin
        for (int b = 0; b < BWIDTH; b++) begin
          if (cpu_wstrb_i[b]) begin
            dcache_data[virt_index][hit_way][virt_offset+b] <= cpu_wdata_i[b*8+:8];
          end
        end
        dirty_bits[virt_index][hit_way] <= 1'b1;
      end
    end
  end

  // FSM Logic
  always_comb begin
    virt_addr_tag_o = virt_tag_tag;
    dcache_tlb_req_valid_o = 1'b0;
    dcache_cpu_req_ready_o = (current_state == CACHE_IDLE);
    next_state = current_state;

    case (current_state)
      CACHE_IDLE: begin
        if (cpu_req_valid_i && dcache_cpu_req_ready_o && tlb_req_ready_i) begin
          dcache_tlb_req_valid_o = 1'b1;
          next_state = CACHE_LOOKUP;
        end
      end

      CACHE_LOOKUP: begin
        if (tlb_resp_valid_i) begin
          if (cache_hit) begin
            next_state = CACHE_HIT;
          end else if (!cache_hit) begin
            next_state = CACHE_MISS;
          end
        end
      end

      CACHE_HIT: begin
        next_state = CACHE_RESPOND;
      end

      CACHE_MISS: begin
        if (l2_addr_i) begin
          next_state = CACHE_ALLOCATE;
        end
      end

      CACHE_ALLOCATE: begin
        next_state = CACHE_IDLE;
      end

      default: begin
        next_state = CACHE_IDLE;
      end
    endcase
  end

endmodule
