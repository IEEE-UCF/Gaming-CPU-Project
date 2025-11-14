/*
    axi_crossbar.sv

    Purpose & Role
    Central AXI4 interconnect between managers and subordinates.
    Performs address decode, per-subordinate channel arbitration, and ID-based routing so multiple transactions can be outstanding concurrently.
    Common widths/IDs are defined in rtl/bus/interconnect_pkg.sv
*/

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
    // Amount of Manager-side AXI ports subject to change
    output [ADDR_WIDTH-1:0] m_axi_I$,
    output [ADDR_WIDTH-1:0] m_axi_D$,
    output [ADDR_WIDTH-1:0] m_axi_DMA,
    output [ADDR_WIDTH-1:0] m_axi_PTW,
    // Subordinate-side AXI ports (DDR, AXI-Lite bridge, etc.)
    // Amount and size of Subordinate-side AXi ports subject to change 
    input [ADDR_WIDTH-1:0] s_axi_DDR,
    input [ADDR_WIDTH-1:0] s_axi_LiteB
);

    // TODO: address decode
    // TODO: per-subordinate arbitration
    // TODO: ID-based routing
    // TODO: ready/valid handling
    
endmodule



