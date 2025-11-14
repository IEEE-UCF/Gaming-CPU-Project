module axi_crossbar #(
    // TODO: add parameters subject to change (managers/subordinates, widths)
    parameter int unsigned N_M = 4;
    parameter int unsigned N_S = 2;
    parameter int unsigned ADDR_WIDTH = 32;
    parameter int unsigned DATA_WIDTH = 64;
    parameter int unsigned ID_WIDTH = 4;
)(
    // TODO: add ports
    input logic clk_i,
    input logic rst_ni
    
    // Manager-side AXI ports (I$, D$, DMA, PTW, etc)
    // ...
    
    // Subordinate-side AXI ports (DDR, AXI-Lite bridge, etc.)
    // ...
);

    // TODO: address decode
    // TODO: per-subordinate arbitration
    // TODO: ID-based routing
    // TODO: ready/valid handling
    
endmodule
