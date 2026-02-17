// Most Recently Used (Assuming two-way cache)

module mru #(
    parameter int SETS = 128,
    parameter int WAYS = 2
) (
    input logic clk_i,
    input logic rst_ni,

    input logic [$clog2(SETS)-1:0] set_index_i,
    input logic isWay0_valid_i,
    input logic isWay1_valid_i,

    input logic isthere_hit_i,
    input logic isthere_miss_i,
    input logic isfilled_i,
    input logic way_filled_i,
    input logic way_hit_i,

    output logic way_to_evict_o

);

  logic mru_bits[SETS];

  always_comb begin
    way_to_evict_o = 1'b0;  // way 0 to be evicted by default

    // if there's a cache miss, a way will need to be used (evicted)
    if (isthere_miss_i) begin

      if (!isWay0_valid_i) way_to_evict_o = 1'b0;  // if way 0 is empty, use it
      else if (!isWay1_valid_i)
        way_to_evict_o = 1'b1;  // if way 0 isn't empty, but way 1 is, use way 1
      else
        // both ways aren't empty, evict way marked by inverted flag
        way_to_evict_o = ~mru_bits[set_index_i];

    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin

    if (!rst_ni) begin
      foreach (mru_bits[i]) mru_bits[i] <= 1'b0;

    end else if (isthere_hit_i) begin

      // if there's a hit, MRU bit is updated to the way that was hit
      mru_bits[set_index_i] <= way_hit_i;

    end else if (isfilled_i) begin

      // if a way is filled, use that way as the victim way
      mru_bits[set_index_i] <= way_filled_i;

    end
  end

endmodule
