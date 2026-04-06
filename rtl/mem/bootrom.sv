module boot_rom #(
    parameter ADDR_W = 12,
    parameter DATA_W = 32
)(
input logic clk_i,
input logic rst_ni,
    input  logic [ADDR_W-1:0] addr_i,
    output logic [DATA_W-1:0] data_o,
    output logic valid_o
);

    logic [DATA_W-1:0] rom [0:2**ADDR_W-1];
    
    initial begin
      $readmemh("boot_code.mem", rom);
    end

logic [DATA_W-1:0] data_q;
logic valid_q;

   always_ff @(posedge clk_i) begin
   if (!rst_ni) begin
   data_q <= '0;
   valid_q <= 1'b0;
   end else begin
   data_q <= rom[addr_i[ADDR_W-1: 2]];
   valid_q <= 1'b1;
   end
   end

assign data_o = data_q;
assign valid_o = valid_q;

endmodule
