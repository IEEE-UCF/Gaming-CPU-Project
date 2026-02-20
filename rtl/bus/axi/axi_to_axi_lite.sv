/*
// 
// Written by: Arnold Stauffer
// Purpose:
// Receive either a read or write request from a Master to reduce the complexity of 
// bursts of instructions. This will provide an interface for the Master to reduce workload
// and handle register access for multiple transactions, etc.
// 
*/

module axi_to_axi_lite import interconnect_pkg::*(
    input logic clk_i,
    input logic rst_ni,
    
    // Write Command Block
    // Write Address (WR)
    input logic [ADDR_WIDTH-1:0] awaddr_i,
    input logic awvalid_i,
    output logic awready_o,
    // Write (W)
    input logic [DATA_WIDTH-1:0] wdata_i,
    input logic [(DATA_WIDTH/8)-1:0] wstrb,  // Bytes valid to write
    input logic wvalid_i,
    output logic wready_o,
    // Write Response (B)
    output logic bready_o,
    input logic bready_i,
  
    // Read Command Block
    // Read Address (R)
    input logic [ADDR_WIDTH-1:0] araddr_i,
    input logic arvalid_i,
    output logic arready_o,
    // Read Response (R)
    output logic [DATA_WIDTH-1:0] rdata_o,
    output logic rvalid_o,
    input logic rready_i
);

    // Captures Writing Requests
    logic [ADDR_WIDTH-1:0] awaddr_reg;
    logic [DATA_WIDTH-1:0] wdata_reg;
    logic [[(DATA_WIDTH/8)-1:0] wstrb_reg;
  
    // Captures Reading Requests
    logic [ADDR_WIDTH-1:0] raddr_reg;
  
    function automatic int unsigned indexing(input logic [ADDR_WIDTH-1:0] addr);
      indexing = addr[ADDR_WIDTH-1:2];
    endfunction

    
endmodule

