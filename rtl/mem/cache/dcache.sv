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
    input  logic                    cpu_load_store_i,    // 1=store, 0=load
    input  logic                    cpu_req_valid_i,     // Request valid
    output logic                    dcache_req_ready_o,  // Cache ready
    input  logic [  ADDR_WIDTH-1:0] cpu_addr_i,
    input  logic [  DATA_WIDTH-1:0] cpu_write_i,         // Store data
    input  logic [DATA_WIDTH/8-1:0] cpu_byte_en_i,       // byte-enables
    input  logic                    dcache_flush_i,      // Flush D$

    // D$ -> CPU Load Data
    output logic dcache_resp_valid_o,  // response valid
    input  logic cpu_resp_ready_i,     // CPU can accept resp
    output logic [DATA_WIDTH-1:0] dcache_resp_rdata_o,   // load data

    // TLB -> D$ Interface
    input logic tlb_req_ready_i,  // TLB ready for translation
    input logic tlb_resp_valid_i,  // TLB response is valid
    input logic [ADDR_WIDTH-1:0] tlb_resp_pa_i,  // PA from TLB

    // D$ -> TLB Interface
    output logic dcache_tlb_req_valid_o,  // Req. to send VA to TLB
    output logic [ADDR_WIDTH-1:0] dcache_tlb_valid_o,  // VA to be translated
    output logic dcache_tlb_resp_ready_o,  // D$ ready to accept TLB response



    // D$ <-> Replacement Policy Logic (this will prob need changes)
    output logic dcache_evict_req_valid_o,  // Req. to send set index for eviction,
    output logic [SETS-1:0] dcache_set_evict_o,  // Set in which line will be replaced
    input logic evict_resp_valid,  // Evict response valid
    input logic dcache_evict_way_i,  // Specific line to replace
    input logic victim_valid,  // 0=empty, 1=occupied

    // D$ <-> AXI Interface (subject to change)
    /*input logic axi_ready_i,
    input logic axi_valid_i,
    output logic dcache_axi_req_o,
    output logic [ADDR_WIDTH-1:0] dcache_axi_addr_o,
    output logic [DATA_WIDTH-1:0] dcache_axi_data_o,
    input logic [ADDR_WIDTH-1:0] axi_address_i,
    input logic [LINE_BYTES*8-1:0] axi_data_i,
    output logic dcache_axi_resp_valid */

    // D$ <-> AXI ASYNC FIFO
    output logic dcache_bridge_req_valid_o, // D$ req. to push address
    input logic bridge_dcache_req_ready_i, // FIFO ready to recieve address
    output logic [ADDR_WIDTH-1:0] dcache_bridge_req_addr_o, // D$ Address to be pushed
    output logic [LINE_BYTES*8-1:0] dcache_bridge_req_data_o,
    input logic bridge_dcache_resp_valid_i, // FIFO data res is valid
    output logic dcache_bridge_resp_ready_o, // D$ can recieve data from bus queue
    input logic [LINE_BYTES*8-1:0] bridge_dcache_resp_data, // Data to be written at req. address
    output logic dcache_bridge_resp_valid_o // D$ has latched the new data from bus
);

  // Local constants
  localparam int SETS = DMEM_SIZE / (WAYS * LINE_BYTES);  // 128 sets
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
  logic [ADDR_WIDTH-1:0] phys_addr;
  assign virt_offset = cpu_addr_i[0+:OFFSET];
  assign virt_index = cpu_addr_i[OFFSET+:INDEX];
  assign virt_tag = cpu_addr_i[(OFFSET+INDEX)+:TAG];
  assign phys_addr = {pa_tag, virt_index, {OFFSET-1{1'b0}}};

  // Cache Hit / Replacement Logic
  logic cache_hit;
  logic [WAYS-1:0] hit_way;
  logic [$clog2(WAYS)-1:0] victim_way;

  // Local flag for write allocation logic
  logic allocation_valid;
  // Local flag for store completion
  logic store_complete;

  typedef enum logic [3:0] {
    CACHE_IDLE,
    CACHE_LOOKUP,
    CACHE_HIT,
    CACHE_MISS,
    CACHE_STORE,
    CACHE_ALLOCATE,
    CACHE_WRITEBACK,
    CACHE_RESPOND
  } cache_state_t;
  cache_state_t current_state, next_state;

  // Reset Cache Lines
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni || dcache_flush_i) begin
      for (int set = 0; set < SETS; set++) begin
        for (int way = 0; way < WAYS; way++) begin
          valid_bits[set][way] <= 1'b0;
          dirty_bits[set][way] <= 1'b0;
        end
      end
    end
  end

  // Cache Lookup Logic
  always_comb begin
    cache_hit = 1'b0;
    if (current_state == CACHE_LOOKUP && tlb_resp_valid_i) begin
      for (int way = 0; way < WAYS; way++) begin
        if (valid_bits[virt_index][way] && (dcache_tags[virt_index][way] == pa_tag)) begin
          cache_hit = 1'b1;
          hit_way   = way;
        end
      end
    end
  end

  // TLB Translation Logic (this might need adjusting)
  always_ff @(posedge clk_i or negedge rst_ni) begin
      if (current_state == CACHE_LOOKUP) begin
        dcache_tlb_resp_ready_o <= 1'b0;
        pa_tag <= '0;
        if (tlb_req_ready_i) begin
          dcache_tlb_va_o <= cpu_addr_i;
          dcache_tlb_resp_ready_o <= 1'b1;
        end
        if (tlb_resp_valid_i) begin
          pa_tag <= tlb_resp_pa_i[TAG-1:INDEX];
        end
      end
  end

  // CPU Store: Write data to specified line already in cache
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni || dcache_flush_i) begin
      store_complete <= 1'b0;
    end else begin
      store_complete <= 1'b0;
      if (current_state == CACHE_STORE) begin
        for (int b = 0; b < (DATA_WIDTH / 8); b++) begin
          if (cpu_byte_en_i[b]) begin
            dcache_data[virt_index][hit_way][virt_offset+(b*8)] <= cpu_write_i[(b*8)+:8];
          end
        end
        dirty_bits[virt_index][hit_way] <= 1'b1;
        store_complete <= 1'b1;
      end
    end
  end

  // CPU Miss: Latching the Victim Way
  always_ff @(posedge clk_i) begin
    if(current_state == CACHE_MISS && evict_resp_valid) begin
      victim_way <= dcache_evict_way_i;
    end
  end

  // CPU Load: Returning requested data to CPU
  always_ff @(posedge clk_i) begin
    if (current_state == CACHE_RESPOND && cpu_resp_ready_i) begin
      dcache_resp_rdata_o <= dcache_data[virt_index][hit_way];
      dcache_resp_valid_o <= 1'b1;
    end
  end

  // Cache Allocate: On Write Allocate (subject to change)
  always_ff @(posedge clk_i) begin
    if (current_state == CACHE_ALLOCATE) begin
      allocation_valid <= 1'b0;
      if(bridge_dcache_req_ready_i) begin
        dcache_bridge_req_addr_o <= phys_addr;
      end else if (dcache_resp_ready_o && bridge_dcache_resp_valid_i) begin
        dcache_data[virt_index][victim_way] <= bridge_dcache_resp_data;
        dcache_tags[virt_index][victim_way] <= pa_tag;
        valid_bits[virt_index][victim_way] <= 1'b1;

        if(cpu_load_store_i == 1'b0) begin
          dirty_bits[virt_index][victim_way] <= 1'b0;
        end

        if(cpu_load_store_i == 1) begin
          for(int b = 0 ; b (DATA_WIDTH / 8) ; b++) begin
            if(cpu_byte_en_i[b]) begin
              dcache_data[virt_index][victim_way][virt_offset+(b*8)] <= cpu_write_i[(b*8)+:8];
            end
          end
          dirty_bits[virt_index][victim_way] <= 1'b1;
        end
        allocation_valid <= 1'b1;
      end
    end
  end

  // Cache Writeback: On Writeback (subject to change)
  always_ff @(posedge clk_i) begin
    if(current_state == CACHE_WRITEBACK) begin
      if (bridge_dcache_req_ready_i) begin
        dcache_bridge_req_addr_o <= phys_addr;
        dcache_bridge_req_data_o <= dcache_data[virt_index][victim_way];
      end else if (bridge_dcache_resp_valid_i) begin
        dirty_bits[virt_index][victim_way] <= 1'b0;
      end
    end
  end

  // Next State Sequential Logic
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni || dcache_flush_i) begin
      current_state <= CACHE_IDLE;
    end else begin
      current_state <= next_state;
    end
  end

  // Next State Combinational Logic
  always_comb begin
    next_state = current_state;
    dcache_req_ready_o = (current_state == CACHE_IDLE);
    case (current_state)
      CACHE_IDLE: begin
        if (cpu_req_valid_i && dcache_req_ready_o && tlb_req_ready_i) begin
          next_state = CACHE_LOOKUP;
        end
      end

      CACHE_LOOKUP: begin
        dcache_tlb_req_valid_o = 1'b1;
        dcache_tlb_resp_ready = 1'b0;
        dcache_tlb_valid_o = 'b0;
        if (tlb_resp_valid_i) begin
          if (cache_hit) begin
            next_state = CACHE_HIT;
          end else if (!cache_hit) begin
            next_state = CACHE_MISS;
          end
        end
      end

      CACHE_HIT: begin
        if (cpu_load_store_i == 0) begin
          next_state = CACHE_RESPOND;
        end else begin
          next_state = CACHE_STORE;
        end
      end

      CACHE_STORE: begin
        if (store_complete) begin
          next_state = CACHE_IDLE;
        end
      end


      CACHE_MISS: begin
        dcache_set_evict_o = virt_index;
        dcache_evict_req_valid_o = 1'b1;
        if (evict_resp_valid) begin
          if (!victim_valid) begin
            next_state = CACHE_ALLOCATE;
          end else if (victim_valid && !dirty_bits[virt_index][victim_way]) begin
            next_state = CACHE_ALLOCATE;
          end else if (victim_valid && dirty_bits[virt_index][victim_way]) begin
            next_state = CACHE_WRITEBACK;
          end
        end
      end

      CACHE_ALLOCATE: begin
        dcache_bridge_req_valid_o = 1'b1;
        dcache_bridge_req_addr_o = phys_addr;
        dcache_bridge_resp_ready_o = 1'b1;
        if(cpu_load_store_i == 0) begin
          next_state = CACHE_RESPOND;
        end else if(cpu_load_store_i && allocation_valid) begin
          next_state = CACHE_IDLE;
        end
      end

      CACHE_WRITEBACK: begin
        dcache_bridge_req_valid_o = 1'b1;
        dcache_bridge_req_addr_o = phys_addr;
        dcache_bridge_req_data_o = dcache_data[virt_index][victim_way];
        dcache_bridge_resp_ready_o = 1'b1;
        if(bridge_dcache_resp_valid_i) begin
          next_state = CACHE_IDLE;
        end
      end

      CACHE_RESPOND: begin
        dcache_resp_valid_o = 1'b0;
        dcache_resp_rdata_o = '0;
        if (dcache_resp_valid_o) begin
          next_state = CACHE_IDLE;
        end
      end

      default: begin
        next_state = CACHE_IDLE;
      end
    endcase
  end

endmodule


