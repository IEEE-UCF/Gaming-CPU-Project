'`timescale 1ns / 1ps

import rv32_pkg::*;#(
    parameter int unsigned DATA_W = 32
)

module wb_stage #(
    parameter RF_ADDR_WIDTH = 5,
    parameter DATA_WIDTH = 32,
) (

    // Clock and Reset
    input logic clk_i,
    input logic rst_ni,

    // Designation Register
    input logic [RF_ADDR_WIDTH-1:0] rd_addr_i,
    input logic [DATA_W-1:0] rd_data_i,
    input logic rd_valid_i,
    input logic rd_exeption_i,

    // Outputs to Register File
    output logic rd_we_o,
    output logic [RF_ADDR_WIDTH-1:0] rd_waddr_o,
    output logic [DATA_W-1:0] rd_wdata_o,

    // CSR Interface
    output logic csr_we_o,
    output logic [11:0] csr_addr_o,
    output logic [DATA_W-1:0] csr_wdata_o,
    output logic [DATA_W-1:0] csr_rdata_o,

    // Registers and Signals
    logic [DATA_W-1:0] wb_data_reg;
    logic [DATA_W-1:0] wb_exception_reg;
    logic wb_addr_reg;
    logic wb_valid_reg;
    logic wb_exception_pending;

    // Unique Case FSM
    typedef enum logic [1:0] {
        WB_IDLE,
        WB_COMMIT,
        WB_EXCEPTION,
        WB_CSR_ACCESS
    } wb_state_e;

    wb_state_e current_state, next_state;

    //
    // Reset/Initialization
    //

    always_ff @(posedge clk_i or negedge rst_ni) begin // On reset, initialize all registers and signals
        if (!rst_ni) begin
            current_state <= WB_IDLE;
            wb_data_reg <= '0;
            wb_exception_reg <= '0;
            wb_addr_reg <= '0;
            wb_valid_reg <= 1'b0;
            wb_exception_pending <= 1'b0;

            rd_we_o <= 1'b0; // All control signals
            csr_we_o <= 1'b0;
            trap_o <= 1'b0;
            pipeline_flush_o <= 1'b0;
            wb_stall_o <= 1'b0;
        end else begin
            current_state <= next_state;

            if (rd_valid_i) begin // Update registers only if we have a valid writeback from the memory stage
                wb_data_reg <= rd_data_i;
                wb_addr_reg <= rd_addr_i;
                wb_valid_reg <= rd_valid_i;
                wb_exception_pending <= rd_exception_i;
            end

            if (rd_exception_i) begin // If an exception is signaled, store the exception code
                wb_exception_pending <= 1'b1;   
                wb_exception_reg <= rd_data_i;
            end

            if (wb_state_e == WB_COMMIT) begin  // Clears Flags after commit
                 wb_exception_pending <= 1'b0;
                wb_exception_pending <= 1'b0;
            end
        end
    end

    //
    // Next State Logic
    //

    always_comb begin
        next_state = current_state;
        case(current_state)
            WB_IDLE: begin 
                if (wb_exception_pending) begin // If an exception is pending, commmit to execption state
                    next_state = WB_EXCEPTION; 
                end else if (wb_valid_reg && rd_we_i) begin // If valid writeback register, commit to register state
                    next_state = WB_COMMIT; 
                end

                else if (csr_access_i) begin // If there's a CSR access request, go to CSR access state
                    next_state = WB_CSR_ACCESS;
                end
            end

            WB_COMMIT: begin // After committing, return to idle
                next_state = WB_IDLE;
            end

            WB_EXCEPTION: begin // Remain in this state until cleared, then return to idle
                if (!wb_exception_pending) begin
                    next_state = WB_IDLE;
                end
            end

            WB_CSR_ACCESS: begin // Stay in CSR access state until completion, then return to idle
                if (!csr_access_i) begin
                    next_state = WB_IDLE;
                end
            end
        endcase
    end

    // 
    // Register File and CSR Writeback
    //

    input logic zero_division_exception_i;
    output logic divide_flag_o; 

    always_comb begin // Default outputs
        rd_we_o = 1'b0;  
        rd_waddr_o = '0; 
        rd_wdata_o = '0; 


        if(current_state == WB_COMMIT && wb_valid_reg) begin // Commits to register file only if valid
            rd_we_o = 1'b1;

            if(wb_addr_reg == 5'b00000) begin
                rd_we_o = 1'b0; // x0 is hardwired to 0
            end
        end

        // Check with Adrian about division by zero flag
        always_ff @(posedge clk_i) begin
            if (zero_division_exception_i) begin
                divide_flag_o <= 1'b1; // Set divide flag on division by zero exception
            end else begin
                divide_flag_o <= 1'b0; // Clear it otherwise
            end
        end
    end

    //
    // Exception Commit Behavior
    //

    always_ff @(posedge clk_i) begin
        if (current_state == WB_EXCEPTION) begin // If in exception state, commit exception to CSR and flush the pipeline
            csr_we_o <= 1'b1; 
            csr_addr_o <= CSR_MCAUSE; 
            csr_wdata_o <= wb_exception_reg; 
        end else if (current_state == WB_COMMIT && wb_exception_pending) begin // If committing an instruction but exception pending, commit exception
            csr_we_o <= 1'b1; 
            csr_addr_o <= CSR_MCAUSE; 
            csr_wdata_o <= wb_exception_reg; 
        end else begin
            csr_we_o <= 1'b0; // Default to no CSR write
        end
    end

    //
    // Trap Detection and Pipeline Control
    //

    always_comb begin
        trap_o = 1'b0;
        pipeline_flush_o = 1'b0;
        wb_stall_o = 1'b0;

        if (current_state == WB_EXCEPTION) begin // If we're in the exception state, signal a trap and flush the pipeline
            trap_o = 1'b1; 
            pipeline_flush_o = 1'b1; 
        end else if (current_state == WB_COMMIT && wb_exception_pending) begin // If exception pending, signal a trap and flush on commit
            trap_o = 1'b1; 
            pipeline_flush_o = 1'b1; 
        end else if (current_state == WB_CSR_ACCESS) begin // If accessing a CSR, stall until it's complete
            wb_stall_o = 1'b1; 
        end
    end
)
endmodule : wb_stage

