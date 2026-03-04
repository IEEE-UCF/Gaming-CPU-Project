// least recently used replacement policy

module lru #(
    parameter int LINE_BYTES = 64,
    parameter int SETS = 128,
    parameter int WAYS = 2,
    parameter int AGE_COUNTER_BITS = $clog2(WAYS)
) (
    input logic clk_i,
    input logic rst_ni,

    input logic [$clog2(SETS)-1:0] set_index_i,
    input logic [(WAYS-1):0] isWay_valid_i, // is way valid, for N ways

    input logic [(LINE_BYTES * 8)-1:0] way_lines_i[WAYS], // array of lines, for N ways

    input logic [$clog2(WAYS)-1:0] way_hit_i, // index of way hit
    input logic isthere_hit_i,
    input logic isthere_miss_i,

    output logic [$clog2(WAYS)-1:0] way_to_evict_o, // index of way to evict
    output logic [(LINE_BYTES * 8)-1:0] evicted_line_o
);

  // 2d array of ages (0 - WAYS-1), with SETS rows and WAYS columns
  logic [AGE_COUNTER_BITS-1:0] way_age[SETS][WAYS];

  always_comb begin

    way_to_evict_o = 0; // default value
    logic [AGE_COUNTER_BITS-1:0] highest_age = '0; // current highest age found
    logic invalid_found = 1'b0;

    // find invalid way, evict it and stop loop
    for (int i = 0; i < WAYS; i++) begin
      if (!isWay_valid_i[i] && !invalid_found) begin

        way_to_evict_o  = i;
        invalid_found = 1'b1;

      end
    end

    // if there's no invalid way, find oldest way and evict it
    if (!invalid_found) begin
      for (int i = 0; i < WAYS; i++) begin
        if (way_age[set_index_i][i] > highest_age) begin

          highest_age = way_age[set_index_i][i];
          way_to_evict_o = i;

        end
      end
    end

  end

  assign evicted_line_o = way_lines_i[way_to_evict_o];

  always_ff @(posedge clk_i or negedge rst_ni) begin // reset logic

    if (!rst_ni) begin
      for (int i = 0; i < SETS; i++) begin
        for (int z = 0; z < WAYS; z++) begin
          way_age[i][z] <= '0;
        end
      end
    end

  end

  always_ff @(posedge clk_i) begin

    if (rst_ni && (isthere_hit_i || isthere_miss_i)) begin
      for (int i = 0; i < WAYS; i++) begin
        if (way_hit_i == i) begin
          way_age[set_index_i][i] <= '0; // makes accessed way the youngest
        end else begin
          // if non-accessed age isn't at highest age, increment
          if (way_age[set_index_i][i] != WAYS-1) begin way_age[set_index_i][i]++; end
        end
      end
    end

  end

endmodule
