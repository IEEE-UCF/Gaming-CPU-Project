module decode import rv32_pkg::*; #(
  parameter int unsigned DATA_W = 32;
) (

  // Clock 
  input logic clk_i,
  input logic rst_ni,

  input logic [DATA_W-1:0] instr_i, 
  output logic [DATA_W-1:0] rf_a,
  output logic [DATA_W-1:0] rf_b,

  input logic hazard_stall,
  
  output logic ctrl_o, 
  output logic imm_o,
  output logic fu_selec,
  output logic [6:0] opcode,
  output logic [1:0] control_hazard
);

module register_file import rv32_pkg::*; #(
    parameter int unsigned DATA_W = 32;
) ();