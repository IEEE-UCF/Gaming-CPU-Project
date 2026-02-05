`timescale 1ns / 1ps

// Restoring division, divisor initially left-shifted by 32, quotient built MSB→LSB, divisor shifted right each iteration."
// refactor and clarify intent, only working version is 7/2 unsigned

module division
import rv32_pkg::*;
(
    input logic clk, 
    input logic rst,
    input logic Division_START, // Start Division
    input logic [31:0] dividend, // numerator
    input logic [31:0] divisor, // denominator
    output logic [63:0] remainder, // result
    output logic Division_DONE // done flag
    );
    
    logic [31:0] dividend_reg; // internal registers driven by inputs
    logic signed [63:0] divisor_reg;
    logic signed [63:0] remainder_reg;
    logic [31:0] quotient_reg;
    logic [5:0] counter;
    logic Division_DONE_reg;

    
    
    enum {IDLE,STALL,DONE} current_state, next_state; // Division FSM states 0 or 1
 
 
 always_ff @(posedge clk) begin // Division Stall FSM
    if(rst==1'b0) begin
        current_state <= IDLE;
    end else begin
        current_state <= next_state;  
        end
         
        $display("Current State is: %0s",current_state,);
        $display("next State is: %0s",next_state,);
        $display("Division_START : %0b",Division_START,);
        $display("remainder : %0d",remainder_reg,);
        $display("divisor : %0d",divisor_reg,);       
 end

 always_comb begin // Combinational part of state FSM
   next_state = current_state;
    
    unique case(current_state)
        IDLE: next_state = (Division_START) ? STALL : IDLE; // When Division_start gets asserted by mux, go to STALL
        STALL: next_state = (Division_DONE_reg) ? DONE : STALL; // When Division circuit is done on last clk edge, it will assert Division_DONE 1 to indicate DONE STATE
        DONE: next_state = IDLE;
        default: next_state = current_state;
    endcase
 
 end
 
 
 
 
   enum {GREATER_EQUAL_THAN_ZERO,LESS_THAN_ZERO} Test_remainder_flag; // Flags used for test comparison case
  
   logic signed [63:0] remainder_test_comparison; // Test combinational logic that will be used for testing.
   logic [63:0] remainder_test_mux;
   logic [63:0] divisor_comb;
   logic [31:0] quotient_comb; // Comnbinational logic that will b driven by always_comb case and then latched on in sequential always_ff
   
   assign  remainder_test_comparison = remainder_reg - divisor_reg; // Combinational Test remainder case
   
   assign Test_remainder_flag = (remainder_test_comparison[63]) ? LESS_THAN_ZERO : GREATER_EQUAL_THAN_ZERO; // Will assign a flag if Remainder >= 0 or remainder <0
   
   
    always_comb begin // This always combinational block will assign the sequential remainder register that is clocked

    
        case(Test_remainder_flag) // Comparison case case to see if test remainder is less than zero or equal to zero
            GREATER_EQUAL_THAN_ZERO: begin
                remainder_test_mux = remainder_test_comparison; // If Remainder >= zero, assign remainder_reg(clocked ff) to be Test_remainder_reg
                quotient_comb = (quotient_reg << 1) | 1'b1; // shift quotient_reg left and set LSB to 1'b1
                divisor_comb = divisor_reg >> 1;
            end
            LESS_THAN_ZERO: begin
                quotient_comb = (quotient_reg << 1) | 1'b0; // if Remainder <0, shift quotient register left and set LSB to 1'b0
                remainder_test_mux = remainder_reg;
                divisor_comb = divisor_reg >> 1;
            end
            default: begin
                quotient_comb = (quotient_reg << 1) | 1'b0;
                remainder_test_mux = remainder_reg;
                divisor_comb = divisor_reg >> 1;
            
            end
        endcase
    
    end
 
    
    always_ff @(posedge clk) begin
        if(rst == 1'b0) begin
            dividend_reg <= 32'd0;
            divisor_reg <= 64'd0;
            remainder_reg <= 64'd0;
            quotient_reg <=  32'd0;
            Division_DONE_reg <= 1'b0; 
            counter <= 6'd0;
                 
        end else begin
            case(current_state)
                IDLE: begin
                    dividend_reg <= dividend; // dividend_reg will latch on to dividend input
                    divisor_reg <= divisor << 32;   // Divisor_reg will latch on to divisor input
                    remainder_reg <= {32'd0,dividend};  // remainder_reg will latch on to remainder input            
                    Division_DONE_reg <= 1'b0;
                    counter <= 6'd0;
                    quotient_reg <=  32'd0;                
                
                end
                STALL: begin
                    remainder_reg <= remainder_test_mux; 
                    quotient_reg <= quotient_comb;                                  
                    divisor_reg <= divisor_comb;
                    counter <= counter + 1'b1;
                    $display("result : %0",remainder_reg);
                    $display("quotient : %0d",quotient_reg);
                    $display("counter : %0d",counter);
                    $display("denominator : %0d",divisor_reg);
                    
                    if(counter == 6'd32)
                        Division_DONE_reg <= 1'b1;
                                                                                    
                end
                DONE: begin                   
                    Division_DONE_reg <= 1'b0;
                
                end           
            endcase
            
        end 
         
    end
    

    assign remainder = remainder_reg;
    assign Division_DONE = Division_DONE_reg;
   

       
    
endmodule
