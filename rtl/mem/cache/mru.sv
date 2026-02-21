// most recently used replacement policy (Updated for N-way cache)

module mru #(
    parameter int SETS = 128,
    parameter int WAYS = 2
) (
    input logic clk_i,
    input logic rst_ni,

    input logic [$clog2(SETS)-1:0] set_index_i,
    input logic [WAYS-1:0] isWay_valid_i,

    input  logic [$clog2(WAYS)-1:0] way_hit_i,
    input  logic [$clog2(WAYS)-1:0] way_filled_i,

    input logic isthere_hit_i,
    input logic isthere_miss_i,
    input logic isfilled_i,

    output logic [$clog2(WAYS)-1:0] way_to_evict_o
);

  logic [$clog2(WAYS)-1:0] mru_way[SETS]; // stores index of MRU way

  always_comb begin
    way_to_evict_o = '0;
    logic invalid_found = 1'b0;

    if (isthere_miss_i) begin
      for (int i = 0; i < WAYS; i++) begin
        if (!isWay_valid_i[i] && !invalid_found) begin
          way_to_evict_o = i; // look for invalid way to evict first
          invalid_found = 1'b1;
        end
      end

      if (!invalid_found) begin // if no invalid, evict first way that isn't MRU
        for (int i = 0; i < WAYS; i++) begin
          if (i != mru_way[set_index_i]) begin
            way_to_evict_o = i;
            break;
          end
        end
      end

    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin

    if (!rst_ni) begin // reset logic
      for (int i = 0; i < SETS; i++) begin
        mru_way[i] <= '0;
      end
    end else begin
      if (isthere_hit_i) begin
        mru_way[set_index_i] <= way_hit_i; // if there's a hit, way was used -- MRU
      end else if (isfilled_i) begin
        mru_way[set_index_i] <= way_filled_i; // if a way is filled, way will soon be used -- MRU
      end
    end

  end

endmodule
