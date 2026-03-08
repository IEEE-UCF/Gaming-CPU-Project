import rv32_pkg::*;

// Decode Module
module decode (

  // Clock 
  input logic clk_i,
  input logic rst_ni,

  // Register File 
  input logic [DATA_WIDTH-1:0] rf_a_i,
  input logic [DATA_WIDTH-1:0] rf_b_i,
  output logic [DATA_WIDTH-1:0] rf_a_o,
  output logic [DATA_WIDTH-1:0] rf_b_o,

  // Illegal Instruction (Control Hazard)
  output logic control_hazard_o,

  // Execute Inputs (includes rf_a_o and rf_b_o)
  output rv32_ctrl_s ctrl_o, 
  output logic [DATA_WIDTH-1:0] imm_o,
  output fu_selec_e fu_selec_o, 

  output logic [3:0] pred_o, 
  output logic [3:0] succ_o,
  output logic fence_o,

  // AMO Outputs
  output logic amo_aq_o,
  output logic amo_rl_o,
  output amo_op_e amo_op_o

  // Instruction 
  input logic [DATA_WIDTH-1:0] instr_i

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
  logic fence; // Fence instruction flag

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
  logic [DATA_WIDTH-1:0] imm_i_type;
  logic [DATA_WIDTH-1:0] imm_s_type;
  logic [DATA_WIDTH-1:0] imm_b_type;
  logic [DATA_WIDTH-1:0] imm_u_type;
  logic [DATA_WIDTH-1:0] imm_j_type;

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
  logic amo_rl_n; // Next AMO release
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
    fence = 1'b0;
    illegal_instr = 1'b0;

    unique case (opcode)
      // Load Instructions (I-Type)
      OPCODE_LOAD: begin
        imm_n = imm_i_type;
        ctrl_sig_n.alu_src = 1'b1; 
        ctrl_sig_n.alu_op = ALU_ADD; // ADD
        ctrl_sig_n.mem_read = 1'b1; 
        ctrl_sig_n.reg_wb = 1'b1;
        fu_selec_n = FU_LSU; 
        unique case (funct3) 
          3'b000: ctrl_sig_n.mem_size = 2'b00; // LB
          3'b001: ctrl_sig_n.mem_size = 2'b01; // LH
          3'b010: ctrl_sig_n.mem_size = 2'b10; // LW
          3'b100: ctrl_sig_n.mem_size = 2'b00; // LBU
          3'b101: ctrl_sig_n.mem_size = 2'b01; // LHU
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
          3'b000: ctrl_sig_n.alu_op = ALU_ADD; // ADDI
          3'b010: ctrl_sig_n.alu_op = ALU_SLT; // SLTI
          3'b011: ctrl_sig_n.alu_op = ALU_SLTU; // SLTIU
          3'b100: ctrl_sig_n.alu_op = ALU_XOR; // XORI
          3'b110: ctrl_sig_n.alu_op = ALU_OR; // ORI
          3'b111: ctrl_sig_n.alu_op = ALU_AND; // ANDI
          3'b001 begin:
            if (funct7 == 7'b0000000)
              imm_n = {{27{1'b0}}, shamt}; // Shamt for shift
              ctrl_sig_n.alu_op = ALU_SLL; // SLLI
            else 
              illegal_instr = 1'b1;
          end
          3'b101: begin
            if (funct7 == 7'b0000000)
              imm_n = {{27{1'b0}}, shamt}; // Shamt for shift
              ctrl_sig_n.alu_op = ALU_SRL; // SRLI
            else if (funct7 == 7'b0100000)
              imm_n = {{27{1'b0}}, shamt}; // Shamt for shift
              ctrl_sig_n.alu_op = ALU_SRA; // SRAI
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
        ctrl_sig_n.alu_op = ALU_ADD; // ADD
        ctrl_sig_n.mem_write = 1'b1;
        fu_select_n = FU_LSU;
        unique case (funct3)
          3'b000: ctrl_sig_n.mem_size = 2'b00; // SB
          3'b001: ctrl_sig_n.mem_size = 2'b01; // SH
          3'b010: ctrl_sig_n.mem_size = 2'b10; // SW
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
            // Multiply Operations
            3'b000: begin 
              ctrl_sig_n.alu_op = ALU_MUL; fu_selec_n = FU_MUL; end // MUL
            3'b001: begin
              ctrl_sig_n.alu_op = ALU_MULH; fu_selec_n = FU_MUL; end // MULH
            3'b010: begin 
              ctrl_sig_n.alu_op = ALU_MULHSU; fu_selec_n = FU_MUL; end // MULHSU
            3'b011: begin
              ctrl_sig_n.alu_op = ALU_MULHU; fu_selec_n = FU_MUL; end // MULHU
            // Division Operations
            3'b100: begin
              ctrl_sig_n.alu_op = ALU_DIV; fu_selec_n = FU_DIV; end // DIV
            3'b101: begin
              ctrl_sig_n.alu_op = ALU_DIVU; fu_selec_n = FU_DIV; end // DIVU
            3'b110: begin
              ctrl_sig_n.alu_op = ALU_REM; fu_selec_n = FU_DIV; end // REM
            3'b111: begin
              ctrl_sig_n.alu_op = ALU_REMU; fu_selec_n = FU_DIV; end // REMU
            default: illegal_instr = 1'b1;
          endcase
        end else begin
          // Base I Instructions 
          unique case ({funct7, funct3})
            {7'b0000000, 3'b000}: ctrl_sig_n.alu_op = ALU_ADD; // ADD
            {7'b0100000, 3'b000}: ctrl_sig_n.alu_op = ALU_SUB; // SUB
            {7'b0000000, 3'b001}: ctrl_sig_n.alu_op = ALU_SLL; // SLL 
            {7'b0000000, 3'b010}: ctrl_sig_n.alu_op = ALU_SLT; // SLT
            {7'b0000000, 3'b011}: ctrl_sig_n.alu_op = ALU_SLTU; // SLTU
            {7'b0000000, 3'b100}: ctrl_sig_n.alu_op = ALU_XOR; // XOR
            {7'b0000000, 3'b101}: ctrl_sig_n.alu_op = ALU_SRL; // SRL 
            {7'b0100000, 3'b101}: ctrl_sig_n.alu_op = ALU_SRA; // SRA 
            {7'b0000000, 3'b110}: ctrl_sig_n.alu_op = ALU_OR; // OR
            {7'b0000000, 3'b111}: ctrl_sig_n.alu_op = ALU_AND; // AND
            default: illegal_instr = 1'b1;
          endcase
        end
      end

      // AUIPC (U-Type)
      OPCODE_AUIPC: begin
        imm_n = imm_u_type;
        ctrl_sig_n.alu_src = 1'b1;
        ctrl_sig_n.alu_op = ALU_ADD; // ADD (PC + imm)
        ctrl_sig_n.reg_wb = 1'b1;
        ctrl_sig_n.auipc = 1'b1; // Signal to execute stage to use PC as operand A
        fu_selec_n = FU_ALU;
      end 

      // LUI (U-Type)
      OPCODE_LUI: begin
        imm_n = imm_u_type;
        ctrl_sig_n.alu_src = 1'b1;
        ctrl_sig_n.alu_op = ALU_PASS; // Pass-through immediate
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
          3'b000: ctrl_sig_n.alu_op = ALU_BEQ; // BEQ 
          3'b001: ctrl_sig_n.alu_op = ALU_BNE; // BNE
          3'b100: ctrl_sig_n.alu_op = ALU_BLT; // BLT 
          3'b101: ctrl_sig_n.alu_op = ALU_BGE; // BGE 
          3'b110: ctrl_sig_n.alu_op = ALU_BLTU; // BLTU 
          3'b111: ctrl_sig_n.alu_op = ALU_BGEU; // BGEU 
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
        ctrl_sig_n.alu_op = ALU_ADD; // ADD
        fu_selec_n = FU_ALU; 
      end

      // SYSTEM (I-Type)
      OPCODE_SYSTEM: begin
        ctrl_sig_n.csr = 1'b1;
        fu_selec_n = FU_CSR;
        unique case (funct3)
          // Enviroment System Instructions
          3'b000: begin 
            if (instr_i[31:20] == 12'h000) begin  // ECALL
              ctrl_sig_n.ecall = 1'b1;
            end else if (instr_i[31:20] == 12'h001) begin // EBREAK
              ctrl_sig_n.ebreak = 1'b1; 
            end else begin
              illegal_instr = 1'b1;
            end
          end
          // CSR Instructions
          3'b001: begin // CSRRW
            ctrl_sig_n.reg_wb = 1'b1;
            imm_n = {20'b0, instr_i[31:20]};  // CSR address encoded in immediate field
          end
          3'b010: begin // CSRRS
            ctrl_sig_n.reg_wb = 1'b1;
            imm_n = {20'b0, instr_i[31:20]}; 
          end
          3'b011: begin // CSRRC
            ctrl_sig_n.reg_wb = 1'b1;
            imm_n = {20'b0, instr_i[31:20]}; 
          end
          3'b101: begin // CSRRWI
            ctrl_sig_n.reg_wb = 1'b1;
            imm_n = {27'b0, rs1}; // zimm[4:0] encoded in rs1 field
          end
          3'b110: begin // CSRRSI
            ctrl_sig_n.reg_wb = 1'b1;
            imm_n = {27'b0, rs1};
          end
          3'b111: begin // CSRRCI
            ctrl_sig_n.reg_wb = 1'b1;
            imm_n = {27'b0, rs1};
          end
          default: illegal_instr = 1'b1;
        endcase
      end

      // Fence (I-Type)
      OPCODE_MISC_MEM: begin
        unique case (funct3)
          3'b000: begin // FENCE
          ctrl_sig_n.fence = 1'b1;
          fence = 1'b1;
          end
          3'b001: begin // FENCE.I
          ctrl_sig_n.fence = 1'b1;
          fence = 1'b1;
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
          amo_rl_n = instr_i[25];
          unique case (funct3)
            3'b010: begin
              unique case (funct7[6:2])
                5'b00010: begin // LR.W
                  ctrl_sig_n.mem_write = 1'b0;
                  amo_op_n = AMO_LR;
                end
                5'b00011: begin // SC.W
                  ctrl_sig_n.mem_read = 1'b0;
                  amo_op_n = AMO_SC;
                end
                5'b00001: begin amo_op_n = AMO_SWAP; end  // AMOSWAP.W
                5'b00000: begin amo_op_n = AMO_ADD; end // AMOADD.W
                5'b00100: begin amo_op_n = AMO_XOR; end // AMOXOR.W
                5'b01100: begin amo_op_n = AMO_AND; end // AMOAND.W
                5'b01010: begin amo_op_n = AMO_OR; end  // AMOOR.W 
                5'b10000: begin amo_op_n = AMO_MIN; end // AMOMIN.W
                5'b10100: begin amo_op_n = AMO_MAX; end // AMOMAX.W
                5'b11000: begin amo_op_n = AMO_MINU; end // AMOMINU.W
                5'b11100: begin amo_op_n = AMO_MAXU; end // AMOMAXU.W           
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

      // Illegal Instruction (Opcode not recognized)
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
  assign pred_o = pred;
  assign succ_o = succ;
  assign fence_o = fence;

  // Illegal Instruction Output
  assign control_hazard_o = illegal_instr;

  assign rf_a_o = rf_a_i;
  assign rf_b_o = rf_b_i;

    // NOTES:
    // ALU src rs2/imm value mux (in hazard_unit)
    // control signals to ex
    
endmodule

// Register File
module register_file (

  // Clock 
  input logic clk_i,
  input logic rst_ni,

  // Read
  input logic [4:0] rs1_i,
  input logic [4:0] rs2_i,
  output logic [DATA_WIDTH-1:0] rd1_o,
  output logic [DATA_WIDTH-1:0] rd2_o,

  // Write
  input logic [4:0] rd_i,
  input logic [DATA_WIDTH-1:0] wb_data_i,
  input logic wb_en_i
);

  logic [DATA_WIDTH-1:0] rf_mem [0:31];
  
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
