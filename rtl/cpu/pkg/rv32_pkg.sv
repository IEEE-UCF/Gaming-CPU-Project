package rv32_pkg;

  parameter int unsigned HAS_M = 1; // Enable Multiply/Divide (RV32M) instructions
  parameter int unsigned HAS_A = 1; // Enable Atomic (RV32A) instructions

  parameter int unsigned RESET_ADDR = 32'h0000_0000; //  PC value on reset (BootROM start address)
  parameter int unsigned BTB_ENTRIES = 16; // Branch Target Buffer (BTB) size (0 to disable)
  
  parameter int unsigned DATA_WIDTH = 32; // Data bus / operand width
  parameter int unsigned ADDR_WIDTH = 32; // Address bus width

  parameter int unsigned MUL_CYCLES = 3; // Multiply latency in cycles
  parameter int unsigned DIV_CYCLES = 5; // Divide latency in cycles

  parameter int unsigned RF_ADDR_WIDTH = 5; // Register File address width
  parameter int unsigned RF_COUNT = 32; // Number of registers in the Register File


  // For future use: instruction encodings
  /*
  // RV32I Base Integer Instruction Set Funct3 Codes for ALU Register-Register Instructions
  localparam logic [2:0]
    FUNCT3_ADD   = 3'b000,
    FUNCT3_SUB   = 3'b000,
    FUNCT3_SLL   = 3'b001,
    FUNCT3_SLT   = 3'b010,
    FUNCT3_SLTU  = 3'b011,
    FUNCT3_XOR   = 3'b100,
    FUNCT3_SRL   = 3'b101,
    FUNCT3_OR    = 3'b110,
    FUNCT3_AND   = 3'b111;

  // RV32I Base Integer Instruction Set Funct3 Codes for ALU Immediate Instructions
  localparam logic [2:0]
    FUNCT3_ADDI  = 3'b000,
    FUNCT3_SLTI  = 3'b010,
    FUNCT3_SLTIU = 3'b011,
    FUNCT3_XORI  = 3'b100,
    FUNCT3_ORI   = 3'b110,
    FUNCT3_ANDI  = 3'b111,
    FUNCT3_SLLI  = 3'b001,
    FUNCT3_SRLI_SRAI = 3'b101;

  // RV32I Base Integer Instruction Set Funct7 Codes
  localparam logic [6:0]
    FUNCT7_ADD_SUB = 7'b0000000,
    FUNCT7_SLL     = 7'b0000000,
    FUNCT7_SLT     = 7'b0000000,
    FUNCT7_SLTU    = 7'b0000000,
    FUNCT7_XOR     = 7'b0000000,
    FUNCT7_SRL     = 7'b0000000,
    FUNCT7_OR      = 7'b0000000,
    FUNCT7_AND     = 7'b0000000,
    FUNCT7_SUB     = 7'b0100000,
    FUNCT7_SRA     = 7'b0100000;

  // RV32I Base Integer Instruction Set Funct3 Codes
  localparam logic [2:0]
    FUNCT3_BEQ   = 3'b000,
    FUNCT3_BNE   = 3'b001,
    FUNCT3_BLT   = 3'b100,
    FUNCT3_BGE   = 3'b101,
    FUNCT3_BLTU  = 3'b110,
    FUNCT3_BGEU  = 3'b111;

  // RV32I Base Integer Instruction Set Opcodes
  localparam logic [6:0]
    OPCODE_LUI    = 7'b0110111,
    OPCODE_AUIPC  = 7'b0010111,
    OPCODE_JAL    = 7'b1101111,
    OPCODE_JALR   = 7'b1100111,
    OPCODE_BRANCH = 7'b1100011,
    OPCODE_LOAD   = 7'b0000011,
    OPCODE_STORE  = 7'b0100011,
    OPCODE_ALUI   = 7'b0010011,
    OPCODE_ALUR   = 7'b0110011,
    OPCODE_FENCE  = 7'b0001111,
    OPCODE_SYSTEM = 7'b1110011;
*/

  // Decode Stage Control Signals
  typedef struct packed { 
    logic alu_src; // ALU source select (0 = rs2, 1 = imm)
    logic [7:0] alu_op; // ALU operation code 
    logic mem_read; // Memory read enable (to load)
    logic mem_write;  // Memory write enable (to store)
    logic mem_size; // Memory access size (00 = byte, 01 = halfword, 10 = word)
    logic branch; // Branch instruction
    logic jump; // Jump instruction
    logic csr;  // CSR instruction
    logic reg_ex_we;  // Register file write enable for EX stage result
    logic reg_mm_we;  // Register file write enbale for MM stage result
  } rv32_ctrl_s;

endpackage : rv32_pkg
