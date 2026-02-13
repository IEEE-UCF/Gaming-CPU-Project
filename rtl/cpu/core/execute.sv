`timescale 1ns / 1ps

/* Assumptions:

1) All immediates are sign-extended, no zero extension AT ALL unless the ISA specifies it for special instructions
2) No overflow detection at the hardware level, we have to check at the software level
3) No integer computational instructions cause arithmetic exceptions, No overflow, underflow, carryout, or trap ever
4) unsigned instructions still get signed extended and instructions like SLTU will compare raw bit pattern, so SLTU -1 > 32 is TRUE for example, and not interpret the sign bit unlike SLT which is signed
5) divide (div), divide unsigned (divu), remainder (rem), and remainder unsigned (remu), see pg 390
6) multiply (mul), multiply high(mulh), multiply high unsigned(mulhu) multiply high signed-unsigned(mulhsu) are supported 384



*/

module execute
import rv32_pkg::*;
(
 input  logic                           clk, // Main clk input
 input  logic                           rst, // Active-low asynchronous reset
 input  logic                           ctrl_i, // Control signals to execute
 input  logic  [DATA_WIDTH-1:0]         op_a_i, // Register A operand (data) from RF
 input  logic  [DATA_WIDTH-1:0]         op_b_i, // Register B operand (data) or sign extended immediate 32'b values
 input  logic  [4:0]                    ALU_OP,
 output logic  [DATA_WIDTH-1:0]         alu_res_o, // ALU result from procesing operands 
 output logic                           branch_taken_o, // Control signal for whether branch should be taken
 output logic                           state // used for stalling the pipeline when division module enters STALL state
 //output logic  [DATA_WIDTH-1:0]         branch_target_o // Address for branch to redirect program counter deleted because decode will produce branch target in a registered state     
);


    // TEMP parameters
    parameter FUNCT7_MUL = 5'd13;
    parameter FUNCT7_MULH = 5'd14;
    parameter FUNCT7_MULHSU = 5'd15;
    parameter FUNCT_MULHU = 5'd16;
    parameter FUNCT_XOR = 5'd17;
    parameter FUNCT_BEQ = 5'd18;
    parameter FUNCT_BNE = 5'd19;
    parameter FUNCT_BLT = 5'd20;
    parameter FUNCT_BGE = 5'd21;
    parameter FUNCT_BLTU = 5'd22;
    parameter FUNCT_BGEU = 5'd23;
    parameter FUNCT_DIVU = 5'd24;
    parameter FUNCT_REMU = 5'd25;
    parameter FUNCT_DIV = 5'd26;
    parameter FUNCT_REM = 5'd27;
    
    logic [DATA_WIDTH*2:0] MULTIPLY_REG; // Used for M instructions
    logic [DATA_WIDTH-1:0] ALU_OUTPUT_COMB;

    
    always_ff @(posedge clk) begin
        if(rst == 1'b0) 
            alu_res_o <= 32'd0;
        else begin
            alu_res_o <= ALU_OUTPUT_COMB;           
        end
       
    end
    
    // Division interface
    logic Division_START; 
    logic Division_DONE;
    logic [DATA_WIDTH-1:0] divisor; // numberator
    logic [DATA_WIDTH-1:0] dividend; // denominator
    logic [DATA_WIDTH-1:0] quotient; //result
    logic [DATA_WIDTH-1:0] result_fix; // Will decide if quotient should be signed
    logic [DATA_WIDTH-1:0] remainder; // mod
    logic sign_bit;
    logic signed_overflow;
    logic state; // used for stalling the pipeline when division module enters STALL state
    
    division Unit(
    .clk(clk),
    .rst(rst),
    .Division_START(Division_START),
    .dividend(dividend),
    .divisor(divisor),
    .remainder(remainder),
    .Division_DONE(Division_DONE),
    .quotient(quotient),
    .state(state)
    );
    
    //TODO: for division we have to add the stalling and only latch on to values when they are valid, right now they are always being driven,
    // so garbage values are seen throughout the cycles
    
    
    always_comb begin // ALU selection OPCODE
        ALU_OUTPUT_COMB = 32'b0; // Defaults
        MULTIPLY_REG = 64'b0;
        branch_taken_o = 1'b0;
        divisor = 32'b0;
        dividend = 32'b0;
        Division_START = 1'b0;
        sign_bit = 1'b0;
        result_fix = 32'b0;
        signed_overflow = 1'b0;

        case(ALU_OP)
        
            // Assumption that all Immediate versions of the instructions will be included in op_b_i sign extended already
            // For shamt instructions, I need only the raw 5 bit unsigned shamt value, no zero extension or zero padding. see how decoder is interfacing to me
            FUNCT3_ADD: ALU_OUTPUT_COMB = op_a_i + op_b_i; 
            
            FUNCT3_SUB: ALU_OUTPUT_COMB = $signed(op_a_i) - $signed(op_b_i); 
            
            FUNCT3_SLL: ALU_OUTPUT_COMB = op_a_i << op_b_i;
            
            FUNCT3_SLT: ALU_OUTPUT_COMB = ($signed(op_a_i) < $signed(op_b_i)) ? 32'd1 : 32'd0; // if A < b return 1 else 0 SIGNED
            
            FUNCT3_SLTU: ALU_OUTPUT_COMB = (op_a_i < op_b_i) ? 32'd1 : 32'd0; // if A < b return 1 else 0 UNSIGNED
            
            FUNCT3_XOR: ALU_OUTPUT_COMB = op_a_i ^ op_b_i; // will XOR every individual bit
            
            FUNCT3_SRL: ALU_OUTPUT_COMB = op_a_i >> op_b_i;
            
            FUNCT3_OR: ALU_OUTPUT_COMB = op_a_i | op_b_i;
            
            FUNCT3_AND: ALU_OUTPUT_COMB = op_a_i & op_b_i;
            
            FUNCT7_SRA: ALU_OUTPUT_COMB = op_a_i >>> op_b_i;
            
            FUNCT_XOR: ALU_OUTPUT_COMB = op_a_i ^ op_b_i;
            
            FUNCT_BEQ: branch_taken_o = ($signed(op_a_i) == $signed(op_b_i)) ? 32'd1 : 32'd0;
            
            FUNCT_BNE: branch_taken_o = ($signed(op_a_i) != $signed(op_b_i)) ? 32'd1 : 32'd0;
            
            FUNCT_BLT: branch_taken_o = ($signed(op_a_i) < $signed(op_b_i)) ? 32'd1 : 32'd0;
            
            FUNCT_BLTU: branch_taken_o = (op_a_i < op_b_i) ? 32'd1 : 32'd0;
            
            FUNCT_BGE: branch_taken_o = ($signed(op_a_i) >= $signed(op_b_i)) ? 32'd1 : 32'd0;
            
            FUNCT_BGEU: branch_taken_o = (op_a_i >= op_b_i) ? 32'd1 : 32'd0;
            
            FUNCT7_MUL: begin // Will return lower  XLEN x XLEN bits in ALU_OUTPUT, same for signed/unsigned XLEN
                MULTIPLY_REG = op_a_i * op_b_i; 
                ALU_OUTPUT_COMB = MULTIPLY_REG[31:0];      
            end
            
            FUNCT7_MULH: begin
                MULTIPLY_REG = $signed(op_a_i) * $signed(op_b_i);  // Will return upper signed(XLEN) x signed(XLEN) bits in ALU_OUTPUT
                ALU_OUTPUT_COMB = MULTIPLY_REG[63:32];             
            
            end
            
            FUNCT7_MULHSU: begin // Will return Signed(XLEN) x Unsigned(XLEN) upper bits
                MULTIPLY_REG = $signed(op_a_i) * (op_b_i); // In the RISC-V spec, rs2 is multiplier, rs1 is multiplicand, im assuming rs1 is op_a_i and op_b_i is multiplicand
                ALU_OUTPUT_COMB = MULTIPLY_REG[63:32]; 
            end
            
            FUNCT_MULHU: begin // will return return unsigned x unsigned upper XLEN bits
                MULTIPLY_REG = op_a_i * op_b_i; 
                ALU_OUTPUT_COMB = MULTIPLY_REG[63:32]; 
            
            end
            
            FUNCT_DIVU: begin
                dividend = op_a_i;
                divisor =  op_b_i;
                Division_START = (op_b_i != 32'd0) ? 1'b1 : 1'b0; // if no division by zero start division
                ALU_OUTPUT_COMB = (op_b_i != 32'd0) ? quotient : 32'hFFFF_FFFF; // zero edge case ALU will output all ones
            
            end
            
            FUNCT_REMU: begin
                dividend = op_a_i;
                divisor =  op_b_i;
                Division_START = (op_b_i != 32'd0) ? 1'b1 : 1'b0; // if no division by zero start division
                ALU_OUTPUT_COMB = (op_b_i != 32'd0) ? remainder : op_a_i; // zero edge case ALU will output dividend           
                        
            end
            FUNCT_REM: begin
            
                signed_overflow = (op_a_i == 32'h8000_0000) && (op_b_i == 32'hFFFF_FFFF); // signed overflow will only occur with -1 and -2^31
                
                dividend = (op_a_i[31] == 1'b1) ? ~op_a_i + 1'b1 : op_a_i; // convert to unsigned magnitude if negative
                
                divisor =  (op_b_i[31] == 1'b1) ? ~op_b_i + 1'b1 : op_b_i; // convert to unsigned magnitude if negative
                
                Division_START = (op_b_i != 32'd0 && signed_overflow == 1'b0) ? 1'b1 : 1'b0; // start Division if no signed overflow or division by zero
                
                sign_bit = op_a_i[31]; // For remiander, the sign follows the dividend only
                
                result_fix = (sign_bit == 1'b1) ? ~remainder + 1'b1 : remainder; // sign fixing logic that will fix unsigned remainder coming out of divider       
                       
                if(op_b_i == 32'd0) begin  
                
                    ALU_OUTPUT_COMB = op_a_i; // ALU output stays the dividend if div by 0
                    
                end else if(signed_overflow) begin
                
                        ALU_OUTPUT_COMB = 32'b0; // ALU will output 32'b0 if signed overflow
                        
                    end else begin
                    
                    ALU_OUTPUT_COMB = result_fix; // if no signed overflow or div by 0 assign remainder
                    
                    end            
            
            end
            
            FUNCT_DIV: begin            
            
                signed_overflow = (op_a_i == 32'h8000_0000) && (op_b_i == 32'hFFFF_FFFF); // signed overflow will only occur with -1 and -2^31
                
                dividend = (op_a_i[31] == 1'b1) ? ~op_a_i + 1'b1 : op_a_i; // convert to unsigned magnitude if negative
                
                divisor =  (op_b_i[31] == 1'b1) ? ~op_b_i + 1'b1 : op_b_i; // convert to unsigned magnitude if negative
                
                Division_START = (op_b_i != 32'd0 && signed_overflow == 1'b0) ? 1'b1 : 1'b0; // start Division if no signed overflow or division by zero
                
                sign_bit = op_a_i[31] ^ op_b_i[31]; // check sign of dividend and divisor see if quotient needs to be fixed
                
                result_fix = (sign_bit == 1'b1) ? ~quotient + 1'b1 : quotient; // sign fixing logic that will fix unsigned quotient coming out of divider     
                       
                if(op_b_i == 32'd0) begin  // signed overflow and div by 0 cases
                
                    ALU_OUTPUT_COMB = 32'hFFFF_FFFF; //ALU output stays -1 if div by zero
                    
                end else if(signed_overflow) begin
                
                        ALU_OUTPUT_COMB = 32'h8000_0000; //ALU output stays -2^31 if signed overflow 
                        
                    end else begin
                    
                    ALU_OUTPUT_COMB = result_fix; // if no overflow or div by zero then ALU will be the result)fix
                    
                    end
                    
            end
            
            default: begin
                ALU_OUTPUT_COMB = 32'b0; // Defaults
                MULTIPLY_REG = 64'b0;
                branch_taken_o = 1'b0;
                divisor = 32'b0;
                dividend = 32'b0;
                Division_START = 1'b0;
                sign_bit = 1'b0;
                result_fix = 32'b0;
                signed_overflow = 1'b0;
            end
            
            
       endcase
            
    
    end
    
    
    
endmodule
