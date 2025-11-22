/*
    axi_crossbar.sv

    Purpose & Role
    Central AXI4 interconnect between managers and subordinates.
    Performs address decode, per-subordinate channel arbitration, and ID-based routing so multiple transactions can be outstanding concurrently.
    Common widths/IDs are defined in rtl/bus/interconnect_pkg.sv
*/

module axi_crossbar #(
    // TODO: add parameters subject to change (managers/subordinates, widths)
    parameter int unsigned N_M = 4, // number of managers
    parameter int unsigned N_S = 2, // number of slaves
    parameter int unsigned ADDR_WIDTH = 32, // address width 
    parameter int unsigned DATA_WIDTH = 64, 
    parameter int unsigned ID_WIDTH = 4, // ID of original source of contact
)(
    // TODO: add ports
    input logic clk_i, // clock input
    input logic rst_ni, // active-low reset?
    
    // Manager-side AXI ports (I$, D$, DMA, PTW, etc)
    // Amount of Manager-side AXI ports subject to change
    output [ADDR_WIDTH-1:0] m_axi_I$, // manager instruction cache
    // Signal/Bundle: I$ CPU Side (fetch←→I$) Direction: I/O
        // PC/line request, hit/miss return, redirect flush on branch/exception
            // what does pc mean...
    output [ADDR_WIDTH-1:0] m_axi_D$, // manager data cache
    // Signal/Bundle: D$ CPU Side (mem_stage←→D$) Direction: I/O
        // Load/store request with byte readings; data return; misalign/atomic handling
    output [ADDR_WIDTH-1:0] m_axi_DMA, // manager direct memory address
    output [ADDR_WIDTH-1:0] m_axi_PTW, // manager page table walker 
    // Subordinate-side AXI ports (DDR, AXI-Lite bridge, etc.)
    // Amount and size of Subordinate-side AXi ports subject to change 
    input [ADDR_WIDTH-1:0] s_axi_DDR, // slave double data rate
    input [ADDR_WIDTH-1:0] s_axi_LiteB // slave lite bridge into peripheral shell

    // 


    
);

    // TODO: address decode
    // TODO: per-subordinate arbitration
    // TODO: ID-based routing
    // TODO: ready/valid handling
    
endmodule





