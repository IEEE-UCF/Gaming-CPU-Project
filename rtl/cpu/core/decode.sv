// Control Signals
typedef struct packed { 
  logic alu_src; // ALU source select (0 = rs2, 1 = imm)
  logic [7:0] alu_op; // ALU operation code 
  logic mem_read; // Memory read enable (to load)
  logic mem_write;  // Memory write enable (to store)
  logic mem_size; // Memory access size (00 = byte, 01 = halfword, 10 = word)
  logic branch; // Branch instruction
  logic jump; // Jump instruction
  logic csr;  // CSR instruction
  logic reg_wb;  // Register file writeback enable 
} rv32_ctrl_s;

// Functional Unit Selection
typedef enum logic [2:0] {
  FU_ALU = 3'd0,  // Arithmetic Logic Unit
  FU_SHIFT = 3'd1,  // Shifter Unit
  FU_LSU = 3'd2,  // Load Store Unit
  FU_BRANCH = 3'd3, // Branch Unit
  FU_MUL = 3'd4,  // Multiplier Unit
  FU_DIV = 3'd5,  // Divider Unit
  FU_CSR = 3'd6 // CSR Unit
} fu_selec_e;
  
// Atomic Memory Operations
typedef enum logic [3:0] {
  AMO_LR = 4'd0, // Load-Reserved
  AMO_SC = 4'd1,  // Store-Conditional
  AMO_SWAP = 4'd2,
  AMO_ADD = 4'd3,
  AMO_XOR = 4'd4,
  AMO_AND = 4'd5,
  AMO_OR = 4'd6,
  AMO_MIN = 4'd7,
  AMO_MAX = 4'd8,
  AMO_MINU = 4'd9,
  AMO_MAXU = 4'd10,
  AMO_NONE = 4'd11 // No AMO
} amo_op_e;

// Decode Module
module decode import rv32_pkg::*; #(
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
  output rv32_ctrl_s ctrl_o, 
  output logic [DATA_W-1:0] imm_o,
  output fu_selec_e fu_selec_o, 

  // AMO Outputs
  output logic amo_aq_o,
  output logic amo_rl_o,
  output amo_op_e amo_op_o

  // Forwarding Inputs (from EX and MM)
  input logic [4:0] rd_ex_i,
  input logic reg_wb_ex_i,
  input logic [DATA_W-1:0] forward_ex_i,
  input logic [4:0] rd_mm_i,
  input logic reg_wb_mm_i,
  input logic [DATA_W-1:0] forward_mm_i,

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
  logic [4:0] shamt;  // Shift Instruction
  logic [3:0] pred; // Fence (predecessor)
  logic [3:0] succ; // Fence (successor)

  assign opcode = instr_i[6:0];
  assign rd     = instr_i[11:7];
  assign funct3 = instr_i[14:12];
  assign rs1    = instr_i[19:15];
  assign rs2    = instr_i[24:20];
  assign funct7 = instr_i[31:25];
  assign shamt = instr_i [24:20];
  assign pred = instr_i[27:24]; // Input/Output/Read/Write before fence
  assign succ = instr_i[23:20]; // Input/Output/Read/Write after fence

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
  localparam logic [6:0] OPCODE_MISC_MEM = 7'b0001111; // Fence Instructions 

  // Control
  rv32_ctrl_s ctrl_sig_n; // Next control signals
  logic [31:0] imm_n; // Next immediate value
  fu_selec_e fu_selec_n;  // Next functional unit select
  amo_op_e amo_op_n;  // Next AMO operation
  logic amo_aq_n; // Next AMO acquire 
  logic amo_rl_n;
  logic illegal_instr;


  // Combinational Logic (Check every possible instruction encoding and generate the correct control signals)
  always_comb begin
    // Default Values
    ctrl_sig_n = '0;
    imm_n = '0;
    fu_selec_n = FU_ALU;
    amo_op_n = AMO_NONE;
    amo_aq_n = 1'b0;
    amo_rl_n = 1'b0;
    illegal_instr = 1'b0;

    unique case (opcode)
      // Load Instructions (I-Type)
      OPCODE_LOAD: begin
        imm_n = imm_i_type;
        ctrl_sig_n.alu_src = 1'b1; 
        ctrl_sig_n.alu_op = 5'b00000; // ADD
        ctrl_sig_n.mem_read = 1'b1; 
        ctrl_sig_n.reg_wb = 1'b1;
        fu_selec_n = FU_LSU; 
        unique case (funct3) 
          3'b000: ctrl_sig_n.mem_size = 2'b00; // Byte
          3'b001: ctrl_sig_n.mem_size = 2'b01; // Halfword
          3'b010: ctrl_sig_n.mem_size = 2'b10; // Word
          3'b100: ctrl_sig_n.mem_size = 2'b00; // Byte Unsigned
          3'b101: ctrl_sig_n.mem_size = 2'b01; // Halfword Unsigned
          default: ctrl_sig_n.mem_size = 2'b10;
        endcase
      end

      // ALU Immediate (I-Type)
      OPCODE_OP_IMM: begin
        ctrl_sig_n.alu_src = 1'b1;
        ctrl_sig_n.reg_wb = 1'b1;
        fu_select_n = FU_ALU;
        imm_n = imm_i_type;
        unique case (funct3)
          3'b000: ctrl_sig_n.alu_op = 5'b00111; // ADDI
          3'b010: ctrl_sig_n.alu_op = 5'b01000; // SLTI
          3'b011: ctrl_sig_n.alu_op = 5'b01001; // SLTIU
          3'b100: ctrl_sig_n.alu_op = 5'b01010; // XORI
          3'b110: ctrl_sig_n.alu_op = 5'b01011; // ORI
          3'b111: ctrl_sig_n.alu_op = 5'b01100; // ANDI
          3'b001 begin:
            if (funct7 == 7'b0000000)
              imm_n = {{27{1'b0}}, shamt}; // Shamt for shift
              ctrl_sig_n.alu_op = 5'b01101; // SLLI
            else 
              illegal_instr = 1'b1;
          end
          3'b101: begin
            if (funct7 == 7'b0000000)
              imm_n = {{27{1'b0}}, shamt}; // Shamt for shift
              ctrl_sig_n.alu_op = 5'b01101; // SRLI
            else if (funct7 == 7'b0100000)
              imm_n = {{27{1'b0}}, shamt}; // Shamt for shift
              ctrl_sig_n.alu_op = 5'b01110; // SRAI
            else
              illegal_instr = 1'b1;
          end
          default: illegal_instr = 1'b1; 
        endcase
      end

      // Stores (S-Type)
      OPCODE_STORE: begin
        imm_n = imm_s_type;
        ctrl_sig_n.alu_src = 1'b1;
        ctrl_sig_n.alu_op = 5'b00111; // ADD
        ctrl_sig_n.mem_write = 1'b1;
        fu_select_n = FU_LSU;
        unique case (funct3)
          3'b000: ctrl_sig_n.mem_size = 2'b00; // Byte
          3'b001: ctrl_sig_n.mem_size = 2'b01; // Halfword
          3'b010: ctrl_sig_n.mem_size = 2'b10; // Word
          default: ctrl_sig_n.mem_size = 2'b10;
        endcase
      end

      // Register-Register ALU (R-Type)
      OPCODE_OP: begin
        ctrl_sig_n.alu_src = 1'b0;
        ctrl_sig_n.reg_wb = 1'b1;
        fu_selec_n = FU_ALU; 
        // M Extension 
        if (HAS_M && (funct7 == 7'b0000001)) begin
          unique case (funct3)
            3'b000: begin 
              ctrl_sig_n.alu_op = 5'b10000; fu_selec_n = FU_MUL; end // MUL
            3'b001: begin
              ctrl_sig_n.alu_op = 5'b10001; fu_selec_n = FU_MUL; end // MULH
            3'b010: begin 
              ctrl_sig_n.alu_op = 5'b10010; fu_selec_n = FU_MUL; end // MULHSU
            3'b011: begin
              ctrl_sig_n.alu_op = 5'b10011; fu_selec_n = FU_MUL; end // MULHU
            3'b100: begin
              ctrl_sig_n.alu_op = 5'b10100; fu_selec_n = FU_DIV; end // DIV
            3'b101: begin
              ctrl_sig_n.alu_op = 5'b10101; fu_selec_n = FU_DIV; end // DIVU
            3'b110: begin
              ctrl_sig_n.alu_op = 5'b10110; fu_selec_n = FU_DIV; end // REM
            3'b111: begin
              ctrl_sig_n.alu_op = 5'b10111; fu_selec_n = FU_DIV; end // REMU
            default: illegal_instr = 1'b1;
          endcase
        end else begin
          unique case ({funct7, funct3})
            {7'b0000000, 3'b000}: ctrl_sig_n.alu_op = 5'b00111; // ADD
            {7'b0100000, 3'b000}: ctrl_sig_n.alu_op = 5'b01111; // SUB
            {7'b0000000, 3'b001}: ctrl_sig_n.alu_op = 5'b01101; // SLL 
            {7'b0000000, 3'b010}: ctrl_sig_n.alu_op = 5'b01000; // SLT
            {7'b0000000, 3'b011}: ctrl_sig_n.alu_op = 5'b01001; // SLTU
            {7'b0000000, 3'b100}: ctrl_sig_n.alu_op = 5'b01010; // XOR
            {7'b0000000, 3'b101}: ctrl_sig_n.alu_op = 5'b01101; // SRL 
            {7'b0100000, 3'b101}: ctrl_sig_n.alu_op = 5'b01110; // SRA 
            {7'b0000000, 3'b110}: ctrl_sig_n.alu_op = 5'b01011; // OR
            {7'b0000000, 3'b111}: ctrl_sig_n.alu_op = 5'b01100; // AND
            default: illegal_instr = 1'b1;
          endcase
        end
      end

      // AUIPC (U-Type)
      OPCODE_AUIPC: begin
        imm_n = imm_u_type;
        ctrl_sig_n.alu_src = 1'b1;
        ctrl_sig_n.alu_op = 5'b00111; // ADD
        ctrl_sig_n.reg_wb = 1'b1;
        fu_select_n = FU_ALU;
      end 

      // LUI (U-Type)
      OPCODE_LUI: begin
        imm_n = imm_u_type;
        ctrl_sig_n.alu_src = 1'b1;
        ctrl_sig_n.alu_op = 5'b11111; // Pass-through 
        ctrl_sig_n.reg_wb = 1'b1;
        fu_selec_n = FU_ALU;
      end

      // REMINDER: Branch target is calculated externally by imm_b_type + pc or imm_j_type
      // Branches (B-Type)
      OPCODE_BRANCH: begin
        imm_n = imm_b_type;
        ctrl_sig_n.branch = 1'b1;
        ctrl_sig_n.alu_src = 1'b0;
        fu_selec_n = FU_BRANCH;
        unique case (funct3)
          3'b000: ctrl_sig_n.alu_op = 5'b00001; // BEQ (rs1 == rs2)
          3'b001: ctrl_sig_n.alu_op = 5'b00010; // BNE (rs1 != rs2)
          3'b100: ctrl_sig_n.alu_op = 5'b00011; // BLT (rs1 < rs2, signd)
          3'b101: ctrl_sig_n.alu_op = 5'b00100; // BGE (rs1 >= rs2, signed)
          3'b110: ctrl_sig_n.alu_op = 5'b00101; // BLTU (rs1 < rs2, unsigned)
          3'b111: ctrl_sig_n.alu_op = 5'b00110; // BGEU (rs1 >= rs2, unsigned)
          default: illegal_instr = 1'b1;
        endcase
      end

      // JAL (J-Type)
      OPCODE_JAL: begin
        imm_n = imm_j_type;
        ctrl_sig_n.jump = 1'b1;
        ctrl_sig_n.reg_wb = 1'b1;
        fu_selec_n = FU_ALU;
      end 

      // JALR (I-Type) 
      OPCODE_JALR: begin
        imm_n = imm_i_type;
        ctrl_sig_n.jump = 1'b1;
        ctrl_sig_n.reg_wb = 1'b1;
        ctrl_sig_n.alu_src = 1'b1;
        ctrl_sig_n.alu_op = 5'b00111; // ADD
        fu_selec_n = FU_ALU; 
      end

      // INCOMPLETE:
      // SYSTEM (I-Type)
      OPCODE_SYSTEM: begin
        ctrl_sig_n.csr = 1'b1;
        fu_selec_n = FU_CSR;
      end

      // INCOMPLETE:
      // Fence (I-Type)
      OPCODE_MISC_MEM: begin
        ctrl_s
        unique case (funct3)
          3'b000: begin // FENCE
          end
          3'b001: begin // FENCE.I
          end 
          default: illegal_instr = 1'b1;
        endcase
      end 

      // AMO (R-Type)
      OPCODE_AMO: begin
        if (HAS_A) begin
          ctrl_sig_n.mem_read = 1'b1;
          ctrl_sig_n.mem_write = 1'b1;
          ctrl_sig_n.reg_wb = 1'b1;
          fu_selec_n = FU_LSU;
          amo_aq_n = instr_i[26];
          amo_rl_n = instr_i[27];
          unique case (funct3)
            3'b010: begin
              unique case (funct7[6:2])
                5'b00010: amo_op_n = AMO_LR;
                5'b00011: amo_op_n = AMO_SC;
                5'b00001: amo_op_n = AMO_SWAP;
                5'b00000: amo_op_n = AMO_ADD;
                5'b00100: amo_op_n = AMO_XOR;
                5'b01100: amo_op_n = AMO_AND;
                5'b01010: amo_op_n = AMO_OR;
                5'b10000: amo_op_n = AMO_MIN;
                5'b10100: amo_op_n = AMO_MAX;   
                5'b11000: amo_op_n = AMO_MINU;
                5'b11100: amo_op_n = AMO_MAXU;             
                default: amo_op_n = AMO_NONE;
              endcase
            end
            default: begin
              amo_op_n = AMO_NONE;
            end
          endcase
        end else begin
          illegal_instr = 1'b1;
        end 
      end 

      default: begin
        illegal_instr = 1'b1;
      end
    endcase
  end

  // Output Assignments
  assign ctrl_o = ctrl_sig_n;
  assign imm_o = imm_n;
  assign fu_selec_o = fu_selec_n;
  assign amo_op_o = amo_op_n;
  assign amo_aq_o = amo_aq_n;
  assign amo_rl_o = amo_rl_n;

  // Hazard Control Output
  assign control_hazard_o = 
    illegal_instr ? 2'b11 :   // flush
    hazard_stall_i ? 2'b01 :  // stall
    2'b00;  // normal

    // Forwarding Logic
    always_comb begin
      rf_a_o = rf_a_i;
      rf_b_o = rf_b_i;

      // rs1:
      if (reg_wb_ex_i && (rd_ex_i == rs1)) begin // Check EX stage
        rf_a_o = forward_ex_i;
      end else if (reg_wb_mm_i && (rd_mm_i == rs1)) begin  // Check MM stage
        rf_a_o = forward_mm_i;
      end

      // rs2:
      if (reg_wb_ex_i && (rd_ex_i == rs2)) begin // Check EX stage
        rf_b_o = forward_ex_i;
      end else if (reg_wb_mm_i && (rd_mm_i == rs2)) begin  // Check MM stage
        rf_b_o = forward_mm_i; 
      end
    end
    
endmodule

// Register File
module register_file import rv32_pkg::*; #(
) (

  // Clock 
  input logic clk_i,
  input logic rst_ni,

  // Read
  input logic [4:0] rs1_i,
  input logic [4:0] rs2_i,
  output logic [DATA_W-1:0] rd1_o,
  output logic [DATA_W-1:0] rd2_o,

  // Write
  input logic [4:0] rd_i,
  input logic [DATA_W-1:0] wb_data_i,
  input logic wb_en_i
);

  logic [DATA_W-1:0] rf_mem [0:31];
  
  always_ff @(negedge clk_i) begin
    if (!rst_ni) begin  // Resets the registers to 0 (Initialization)
      integer i;
      for (i = 0; i < 32; i = i + 1) rf_mem[i] <= '0;
    end else begin  // Writeback behavior
      if (wb_en_i && (rd_i != 5'd0)) begin
        rf_mem[rd_i] <= wb_data_i;
      end
      rf_mem[0] <= '0; // x0 is always zero
    end
  end

  // Combinational read ports
  assign rd1_o = (rs1_i == 5'd0) ? '0 : rf_mem[rs1_i];
  assign rd2_o = (rs2_i == 5'd0) ? '0 : rf_mem[rs2_i];

endmodule
