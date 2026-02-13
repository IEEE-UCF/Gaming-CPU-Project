'`timescale 1ns / 1ps

module wb_stage #(
    parameter RF_ADDR_WIDTH = 5,
    parameter DATA_WIDTH = 32,
) 
import rv32_pkg::*;#(
    parameter int unsigned DATA_W = 32
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

    //
    // Signals and Registers 
    //

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

    always_ff @(posedge clk_i or negedge rst_ni) begin 
        if (!rst_ni) begin
            current_state <= WB_IDLE;
            wb_data_reg <= '0;
            wb_exception_reg <= '0;
            wb_addr_reg <= '0;
            wb_valid_reg <= 1'b0;
            wb_exception_pending <= 1'b0;

            // Control Signals
            rd_we_o <= 1'b0;
            csr_we_o <= 1'b0;
            trap_o <= 1'b0;
            pipeline_flush_o <= 1'b0;
            wb_stall_o <= 1'b0;
        end else begin
            current_state <= next_state;

            // Register Updates
            if (rd_valid_i) begin
                wb_data_reg <= rd_data_i;
                wb_addr_reg <= rd_addr_i;
                wb_valid_reg <= rd_valid_i;
                wb_exception_pending <= rd_execption_i;
            end

            // Register Exceptions
            if (rd_execption_i) begin   
                wb_exception_pending <= 1'b1;   
                wb_exception_reg <= rd_data_i;
            end

            // Clear Flags
            if (wb_state_e == WB_COMMIT) begin
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
                if (wb_exception_pending) begin
                    next_state = WB_EXCEPTION;
                end else if (wb_valid_reg && rd_we_i) begin
                    next_state = WB_COMMIT;
                end

                // CSR Access
                else if (csr_access_i) begin
                    next_state = WB_CSR_ACCESS;
                end
            end

            WB_COMMIT: begin
                next_state = WB_IDLE;
            end

            WB_EXCEPTION: begin
                if (!wb_exception_pending) begin
                    next_state = WB_IDLE;
                end
            end

            WB_CSR_ACCESS: begin
                if (!csr_access_i) begin
                    next_state = WB_IDLE;
                end
            end
        endcase
    end

    // 
    // Register File and CSR Writeback
    //

    always_comb begin 
        rd_we_o = 1'b0;  
        rd_waddr_o = '0; 
        rd_wdata_o = '0; 


        if(current_state == WB_COMMIT && wb_valid_reg) begin // Commits only if valid
            rd_we_o = 1'b1;

            if(wb_addr_reg == 5'b00000) begin
                rd_we_o = 1'b0; // x0 is hardwired to 0
            end
        end
    end
    
    

)
endmodule : wb_stage

