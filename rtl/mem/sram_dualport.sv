model sram_dualport #(
  parameter int DATA_W = 32, // data width
  parameter int ADDR_W = 10, // address width
  parameter bit OUT_REG = 0 // out register
) (
  input logic                    clk_i, // shared clock for both ports
  // Port A
  input logic [ADDR_W-1:0]       port_a_addr_i, // port a address input
  input logic [DATA_W-1:0]       port_a_wdata_i, // port a write data
  input logic                    port_a_we_i, // port a write enable input, 1 = write, 0 = read
  input logic [(DATA_W/8)-1:0]   port_a_be_i, // port a byte enable input
  output logic [DATA_W-1:0]      port_a_rdata_o, // read data output
  // Port B
  input logic [ADDR_W-1:0]       port_b_addr_i, // port b address input
  input logic [DATA_W-1:0]       port_b_wdata_i, // port b write data
  input logic                    port_b_we_i, // port b write enable input, 1 = write, 0 = read
  input logic [(DATA_W/8)-1:0]   port_b_be_i, // port b byte enable input
  output logic [DATA_W-1:0]      port_b_rdata_o, // read data output
);


// blabla notes to myself
// focus on one port first

// port a section?
logic [DATA_W-1:0] mem [0:(1<<ADDR_W)-1]; // gotten from youtube video
// write block
always_ff @  (posedge clk_i) begin
  if (port_a_we_i) begin
    // write to a memory?
    // documentation says "use dedicated memory blocks, not flip-flops"
      mem[port_a_addr_i] <= port_a_wdata_i;
  end
// read block
     port_a_rdata_o <= mem[port_a_addr_i];
   end

endmodule
