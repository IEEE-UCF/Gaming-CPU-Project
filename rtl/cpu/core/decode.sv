module decode import rv32_pkg::*; #(
  parameter int unsigned DATA_W = 32;
) (

  // Clock 
  input logic clk_i,
  input logic rst_ni,

  // Register File 
  output logic [DATA_W-1:0] rf_a_o,
  output logic [DATA_W-1:0] rf_b_o,

  // Hazard Control
  input logic hazard_stall_i,
  output logic [1:0] control_hazard_o,

  // Execute Inputs (includes rf_a_o and rf_b_o)
  output logic ctrl_o, 
  output logic imm_o,
  output logic fu_selec_o,

  // Instruction 
  input logic [DATA_W-1:0] instr_i

);

  // Instruction Fields (local wires)
  logic [6:0] opcode;
  logic [4:0] rd;
  logic [2:0] funct3;
  logic [4:0] rs1;
  logic [4:0] rs2;
  logic [6:0] funct7;

  assign opcode = instr_i[6:0];
  assign rd     = instr_i[11:7];
  assign funct3 = instr_i[14:12];
  assign rs1    = instr_i[19:15];
  assign rs2    = instr_i[24:20];
  assign funct7 = instr_i[31:25];

endmodule

module register_file import rv32_pkg::*; #(
    parameter int unsigned DATA_W = 32;
) (

);

endmodule