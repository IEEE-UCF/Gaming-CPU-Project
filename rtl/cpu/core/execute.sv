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
 input  logic  [DATA_WIDTH-1:0]         op_b_i, // Register B operand (data) from RF
 input  logic  [3:0]                    ALU_select, // Is driven by decoder Funct 3 & 7 bundled together
 output logic  [DATA_WIDTH-1:0]         alu_res_o, // ALU result from procesing operands 
 output logic  [DATA_WIDTH-1:0]         ALU_OUTPUT,
 output logic                           branch_taken_o, // Control signal for whether branch should be taken
 output logic                           branch_target_o // Address for branch to redirect program counter        
);



    //TODO 1: Need ALU operation control input for combinational case statement
    //TODO 2: signed Overflow detection, we need to extend operands to 32 bits, and do overflow = Carryin ^ Carryout; All of sum MSB
    //TODO 3: sign extension or zero padding
    //TODO 4: Figure out signed vs unsigned addition subtration etc
    //TODO 5: Division
    //TODO 6: Stall FSM for division, and figure out division unit
    //TODO 7: data forwarding
    //TODO 8: invariarnts
    //TODO 9: Divides could take up to 32 cycles with naive shift right divider

    
    always_comb begin // ALU selection OPCODE
        ALU_OUTPUT = 32'b0; // Defaults
        
        case(ALU_select)
            FUNCT3_ADD: ALU_OUTPUT = op_a_i + op_b_i; // I need to know if to sign extend or not to detect unsigned/signed overflow
            FUNCT3_SUB: ALU_OUTPUT = op_a_i - op_b_i; 
       
       
       endcase
            
    
    end
    
    
    
endmodule
