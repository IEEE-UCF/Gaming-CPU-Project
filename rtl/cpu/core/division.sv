`timescale 1ns / 1ps

// Restoring division, divisor initially left-shifted by 32, quotient built MSB→LSB, divisor shifted right each iteration."


module division
import rv32_pkg::*;
(
    input logic clk, 
    input logic rst,
    input logic Division_START, // Start Division
    input logic [31:0] dividend, // numerator
    input logic [31:0] divisor, // denominator
    output logic [63:0] remainder, // Mod 
    output logic Division_DONE, // done flag
    output logic [31:0] quotient // result
    );
    
    logic [31:0] dividend_reg; // internal registers driven by inputs
    logic signed [63:0] divisor_reg;
    logic signed [63:0] remainder_reg;
    logic [31:0] quotient_reg;
    logic [5:0] counter;
    logic Division_DONE_reg;

    
    
    enum {IDLE,STALL} current_state, next_state; // Division FSM states 0 or 1
 
 
 always_ff @(posedge clk) begin // Division Stall FSM
    if(rst==1'b0) begin // Active low reset
        current_state <= IDLE;
    end else begin
        current_state <= next_state;  
        end
              
 end

 always_comb begin // Combinational part of state FSM
   next_state = current_state;
    
    unique case(current_state)
        IDLE:next_state = (Division_START) ? STALL : IDLE; // When Division_start gets asserted by mux, go to STALL
        STALL: next_state = (Division_DONE_reg) ? IDLE : STALL; // When Division circuit is done on last clk edge, it will assert Division_DONE 1 to indicate DONE STATE
        default: next_state = current_state;
    endcase
 
 end
 
 
 
 
   enum {GREATER_EQUAL_THAN_ZERO,LESS_THAN_ZERO} Test_remainder_flag; // Flags used for test comparison case
  
   // Test combinational logic interface  that will be used for testing.
   logic signed [63:0] remainder_test_comparison; 
   logic [63:0] remainder_test_mux;
   logic [63:0] divisor_comb;
   logic [31:0] quotient_comb; 
   
   assign  remainder_test_comparison = remainder_reg - divisor_reg; // will subtract remainder from divisor
   
   assign Test_remainder_flag = (remainder_test_comparison[63]) ? LESS_THAN_ZERO : GREATER_EQUAL_THAN_ZERO; // will assign a flag based on the remainder
   
   
    always_comb begin
     // Restoring division step:
     // Try subtracting divisor from remainder.
     // If result >= 0  keep subtraction and append 1 to quotient.
     // If result < 0  restore old remainder and append 0 to quotient.
     // Then shift divisor for next bit position.
 
    
        case(Test_remainder_flag) // Comparison case case 
            GREATER_EQUAL_THAN_ZERO: begin
                remainder_test_mux = remainder_test_comparison; // Accept trial remainder (subtract succeeded)
                quotient_comb = (quotient_reg << 1) | 1'b1; // shift left, add quotient bit = 1
                divisor_comb = divisor_reg >> 1; // next alignment (shift divisor) we are basically doing long division and comparing bit positions to see if they match
            end
            LESS_THAN_ZERO: begin
                quotient_comb = (quotient_reg << 1) | 1'b0; // Restore remainder (subtract failed)
                remainder_test_mux = remainder_reg; // Shift left, add quotient bit = 0
                divisor_comb = divisor_reg >> 1; // Next alignment (shift divisor)
            end
            default: begin // default should never happen but keeps tools happy
                quotient_comb = (quotient_reg << 1) | 1'b0;
                remainder_test_mux = remainder_reg; // Restore remainder (subtract failed)
                divisor_comb = divisor_reg >> 1;// next alignment (shift divisor) we are basically doing long division and comparing bit positions to see if they match
            
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
                    divisor_reg <= divisor << 32;   // Divisor is aligned to the top 32 bits, divisor_reg is 64 Bit reg
                    remainder_reg <= {32'd0,dividend};  // remainder_reg will be initialized with numerator            
                    Division_DONE_reg <= 1'b0;
                    counter <= 6'd0;
                    quotient_reg <=  32'd0; 
                                              
                end
                STALL: begin
                    remainder_reg <= remainder_test_mux; 
                    quotient_reg <= quotient_comb;                                  
                    divisor_reg <= divisor_comb;
                    counter <= counter + 1'b1;
                    
                    if(counter == 6'd32) begin
                        Division_DONE_reg <= 1'b1;
                        
                    end else begin
                        
                        Division_DONE_reg <= 1'b0;
                    
                    end
                    
                                                                                    
                end
          
            endcase
            
        end 
         
    end
    
    always_ff @(posedge clk) begin
    
        if(counter == 32'd33) begin
            $display("Quotient: %0d",quotient);
            $display("Remainder: %0d",remainder);
            $display("Counter: %0d",counter);
            $display("Done Signal: %0d", Division_DONE);
            $display("Current State: %s", current_state);
            $display("next State: %s", next_state);
            $display("Division Start flag: %d", Division_START);
            $display("\n");
        end
        
       
    
    
    
    end
    
    
    assign remainder = remainder_reg;
    assign quotient = quotient_reg;
    assign Division_DONE = Division_DONE_reg;
   

       
    
endmodule
