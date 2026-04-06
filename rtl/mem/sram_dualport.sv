module sram_dualport #(
  parameter int DATA_W = 32,
  parameter int ADDR_W = 10,
  parameter bit OUT_REG = 0
) (
  input logic                    clk_i,
  // Port A
  input logic [ADDR_W-1:0]       port_a_addr_i, // port a address input
  input logic [DATA_W-1:0]       port_a_wdata_i, // port a write data
  input logic                    port_a_we_i, // port a write enable input, 1 = write, 0 = read
  input logic [(DATA_W/8)-1:0]   port_a_be_i, // port a byte write enable input, corresponds to which bytes in mem to be overwritten
  output logic [DATA_W-1:0]      port_a_rdata_o, // read data output
  // Port B
  input logic [ADDR_W-1:0]       port_b_addr_i, // port b address input
  input logic [DATA_W-1:0]       port_b_wdata_i, // port b write data
  input logic                    port_b_we_i, // port b write enable input, 1 = write, 0 = read
  input logic [(DATA_W/8)-1:0]   port_b_be_i, // port b byte write enable input, corresponds to which bytes in mem to be overwritten
  output logic [DATA_W-1:0]      port_b_rdata_o // read data output
);

  // Shared memory array
  logic [DATA_W-1:0] mem_a [0:(1<<ADDR_W)-1];

  // Port A - write block
  always_ff @(posedge clk_i) begin
    if (port_a_we_i) begin
      for (int i = 0; i < DATA_W/8; i = i + 1) begin
        if (port_a_be_i[i]) begin
          mem_a[port_a_addr_i][8*i +: 8] <= port_a_wdata_i[8*i +: 8];
        end
      end
    end
    // Port A - read block
    port_a_rdata_o <= mem_a[port_a_addr_i];
  end


// Shared memory array
  logic [DATA_W-1:0] mem_b [0:(1<<ADDR_W)-1];

  // Port B - write block
  always_ff @(posedge clk_i) begin
    if (port_b_we_i) begin
      for (int i = 0; i < DATA_W/8; i = i + 1) begin
        if (port_b_be_i[i]) begin
          mem_b[port_b_addr_i][8*i +: 8] <= port_b_wdata_i[8*i +: 8];
        end
      end
    end
    // Port B - read block
    port_b_rdata_o <= mem_b[port_b_addr_i];
  end

endmodule
