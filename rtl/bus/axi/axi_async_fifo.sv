module axi_async_fifo #(
    // TODO: add parameters, subject to change (widths, depth)
    parameter int unsigned ADDR_WIDTH = 32;
    parameter int unsigned DATA_WIDTH = 64;
    parameter int unsigned ID_WIDTH = 4;
    parameter int unsigned FIFO_DEPTH = 8;
)(
    // Source clock domain
    input logic s_clk_i,
    input logic s_rst_ni,
    
    // Destination clock domain
    input logic m_clck_i,
    input logic m_rst_ni
    
    // TODO: add AXI ports for source and destination
);

    // TODO:
    // Define request/response structs or AXI channel ports
    // Implement async FIFOs between source and destination clocks
    // Preserve AXI valid/ready handshake and ordering

endmodule    
    
