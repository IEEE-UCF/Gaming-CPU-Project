// least recently used replacement policy

module lru #(
    parameter int LINE_WIDTH = 512,
    parameter int SETS = 128,
    parameter int AGE_COUNTER_BITS = 2  // to track which is least recently used
) (
    input logic clk_i,
    input logic rst_ni,

    input logic [$clog2(SETS)-1:0] set_index_i,
    input logic isWay1_valid_i,
    input logic isWay2_valid_i,

    input logic [LINE_WIDTH-1:0] way1_line_i,
    input logic [LINE_WIDTH-1:0] way2_line_i,

    input logic isthere_hit_i,
    input logic isthere_miss_i,
    input logic way_hit_i,

    output logic way_to_evict_o,
    output logic [LINE_WIDTH-1:0] evicted_line_o
);

  logic [AGE_COUNTER_BITS-1:0] way1_age[SETS];
  logic [AGE_COUNTER_BITS-1:0] way2_age[SETS];

  logic [AGE_COUNTER_BITS-1:0] temp_age_set_way1;
  logic [AGE_COUNTER_BITS-1:0] temp_age_set_way2;

  always_comb begin
    temp_age_set_way1 = way1_age[set_index_i];
    temp_age_set_way2 = way2_age[set_index_i];
  end

  always_comb begin

    if (isthere_miss_i) begin

      if (!isWay1_valid_i) way_to_evict_o = 1'b0;
      else if (!isWay2_valid_i) way_to_evict_o = 1'b1;
      else if (temp_age_set_way1 < temp_age_set_way2) way_to_evict_o = 1'b0;
      else way_to_evict_o = 1'b1;
    end

  end

  assign evicted_line_o = (way_to_evict_o == 1'b0) ? way1_line_i : way2_line_i;

  always_ff @(posedge clk_i or negedge rst_ni) begin

    if (!rst_ni) begin

      foreach (way1_age[i]) begin
        way1_age[i] <= 1'b0;
      end
      foreach (way2_age[i]) begin
        way2_age[i] <= 1'b0;
      end

    end else if (isthere_hit_i || isthere_miss_i) begin  // if there's a cache access, update ages

      if (way_hit_i == 1'b0) begin
        way1_age[set_index_i] <= '1;
        if (temp_age_set_way2 != 0) begin
          way2_age[set_index_i] <= temp_age_set_way2 - 1;
        end
      end else begin
        way2_age[set_index_i] <= '1;
        if (temp_age_set_way1 != 0) begin
          way1_age[set_index_i] <= temp_age_set_way1 - 1;
        end
      end
    end
  end

endmodule
