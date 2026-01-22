// Top Core File
'include "rv32_pkg.sv"
module rv32_core #(
    parameter int unsigned DATA_W = 32;
    parameter int unsigned HAS_M = 1;
    parameter int unsigned HAS_A = 1;
) (
    input  logic              clk_i, rst_ni,                      //Clock, Reset
    input  logic              irq_ext_i, irq_timer_i, irq_soft_i, // PLIC/CLINT lines
    input  logic              dbg_i,                              // Debug module / JTAG (input)
    input  logic [DATA_W-1:0] i_axi_i, d_axi_i,                   // AXI via I/D lines (input)
    output logic              dbg_o,                              // Debug module / JTAG (input)
    output logic [DATA_W-1:0] i_axi_o, d_axi_o                    // AXI via I/D lines (output)
);

endmodule
