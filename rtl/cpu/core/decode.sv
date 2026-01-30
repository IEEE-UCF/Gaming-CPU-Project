typedef struct packed {

} type_name;


module decode import rv32_pkg::*; #(
  parameter int unsigned HAS_M = 1, // RV32M  
  parameter int unsigned HAS_A = 1, // RV32A 
  parameter int unsigned DATA_W = 32
) (

  // Clock 
  input logic clk_i,
  input logic rst_ni,

  // Register File 
  input logic [DATA_W-1:0] rf_a_i,
  input logic [DATA_W-1:0] rf_b_i,
  output logic [DATA_W-1:0] rf_a_o,
  output logic [DATA_W-1:0] rf_b_o,

  // Hazard Control
  input logic hazard_stall_i,
  output logic [1:0] control_hazard_o,

  // Execute Inputs (includes rf_a_o and rf_b_o)
  output logic ctrl_o, 
  output logic [DATA_W-1:0] imm_o,
  output logic [2:0] fu_selec_o, 

  // Instruction 
  input logic [DATA_W-1:0] instr_i

);

  // Instruction Fields (local wires)
  logic [6:0] opcode;
  logic [4:0] rd;       // Destination Register
  logic [2:0] funct3;
  logic [4:0] rs1;     // Source Register 1 
  logic [4:0] rs2;    // Source Register 2
  logic [6:0] funct7;

  assign opcode = instr_i[6:0];
  assign rd     = instr_i[11:7];
  assign funct3 = instr_i[14:12];
  assign rs1    = instr_i[19:15];
  assign rs2    = instr_i[24:20];
  assign funct7 = instr_i[31:25];


  // Immediate Types
  logic [DATA_W-1:0] imm_i_type;
  logic [DATA_W-1:0] imm_s_type;
  logic [DATA_W-1:0] imm_b_type;
  logic [DATA_W-1:0] imm_u_type;
  logic [DATA_W-1:0] imm_j_type;

  // Sign Extensions & Immediates Produced
  // I_Type Immediate
  assign imm_i_type = {{20{instr_i[31]}}, instr_i[31:20]};
  // S_Type Immediate
  assign imm_s_type = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
  // B_Type Immediate
  assign imm_b_type = {{19{instr_i[31]}}, instr_i[31], instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0}; // LSB = 0
  // U_Type Immediate
  assign imm_u_type = {instr_i[31:12], 12'b0};  // Upper 20 bits, lower 12 bits = 0
  // J_Type Immediate
  assign imm_j_type = {{11{instr_i[31]}}, instr_i[31], instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0}; // LSB = 0


  // Opcode
  localparam logic [6:0] OPCODE_LOAD = 7'b0000011;  // Reads memory into register
  localparam logic [6:0] OPCODE_STORE = 7'b0100011; // Writes register to memory
  localparam logic [6:0] OPCODE_OP = 7'b0110011;  // ALU operations using registers including "M" extension (MUl/DIV)
  localparam logic [6:0] OPCODE_OP_IMM = 7'b0010011;  // ALU operations using immediate
  localparam logic [6:0] OPCODE_LUI = 7'b0110111; // Load Upper Immediate
  localparam logic [6:0] OPCODE_BRANCH = 7'b1100011;  // Conditioanl branches
  localparam logic [6:0] OPCODE_JALR = 7'b1100111;  // Jump and Link Register 
  localparam logic [6:0] OPCODE_JAL = 7'b1101111; // Jump and Link
  localparam logic [6:0] OPCODE_AUIPC = 7'b0010111; // Add Upper Immediate to PC
  localparam logic [6:0] OPCODE_SYSTEM = 7'b1110011;  // System Instructions
  localparam logic [6:0] OPCODE_AMO = 7'b0101111; // Atomic Memory Operations, "A" extension

  // Control Signals

endmodule


module register_file import rv32_pkg::*; #(
    parameter int unsigned DATA_W = 32;
) (
  int logic clk_i,
  int logic rst_ni,

);

endmodule
