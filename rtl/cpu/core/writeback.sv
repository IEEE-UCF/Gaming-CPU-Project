Writeback Final

`timescale 1ns/1ps

import rv32_pkg::*;

module wb_stage(
    
    // Clock and Reset
    input logic clk_i,
    input logic rst_ni,

    // Pipeline Control
    output logic wb_flush_o,
    output logic [DATA_WIDTH-1:0] wb_flush_pc_o,
    output logic wb_stall_o

    // MEM/WB Pipeline Inputs
    input logic [RF_ADDR_WIDTH-1:0] rd_addr_i,
    input logic [DATA_WIDTH-1:0] rd_data_i,
    input logic reg_we_i,

    // Exception Inputs
    input logic ex_valid_i, // exception pending from MEM
    input logic [3:0] ex_cause_i, // exception cause code (mcause)
    input logic [DATA_WIDTH-1:0] ex_trap_i, // trap value (faulting addr/instr)
    input logic [DATA_WIDTH-1:0] ex_pc_i, // PC of excepting instruction

    // Interrupt Inputs
    input logic irq_valid_i,
    input logic [3:0] irq_cause_i,

    // Outputs to Register File
    output logic rd_we_o,
    output logic [RF_ADDR_WIDTH-1:0] rd_waddr_o,
    output logic [DATA_WIDTH-1:0] rd_wdata_o,

    // CSR Interface
    input logic csr_we_i, // CSR write request from instruction
    input logic [11:0] csr_addr_i, // CSR address from instruction
    input logic [DATA_WIDTH-1:0] csr_wdata_i, // CSR write data from instruction
    output logic csr_we_o,
    output logic [11:0] csr_addr_o,
    output logic [DATA_WIDTH-1:0] csr_wdata_o,

    // Trap Interface 
    output logic trap_valid_o,
    output logic [DATA_WIDTH-1:0] trap_cause_o,
    output logic [DATA_WIDTH-1:0] trap_tval_o,
    output logic [DATA_WIDTH-1:0] trap_epc_o,
    input logic [DATA_WIDTH-1:0] trap_vec_i, // Mtvec from CSR file

);
    // Unique-Case FSM
    typedef enum logic [1:0] {
        WB_IDLE = 2'b00,
        WB_COMMIT = 2'b01,
        WB_EXCEPTION = 2'b10
    } wb_state_e;
    wb_state_e current_state, next_state;

    // Internal Signals
    logic [RF_ADDR_WIDTH-1:0] saved_rd_addr;
    logic [DATA_WIDTH-1:0] saved_rd_data;
    logic saved_rd_we;
    logic saved_ex_valid;
    logic [3:0] saved_ex_cause;
    logic [DATA_WIDTH-1:0] saved_ex_tval;
    logic [DATA_WIDTH-1:0] saved_ex_pc;
    logic saved_irq_valid;
    logic [3:0] saved_irq_cause;
    logic saved_csr_we;
    logic [11:0] saved_csr_addr;
    logic [DATA_WIDTH-1:0] saved_csr_wdata;
    // Check if we have a trap to commit (either exception or interrupt)
    logic commit_trap;
    assign commit_trap = saved_exc_valid || saved_irq_valid;

    //
    // Reset/Initialization
    //

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            current_state <= WB_IDLE;
            saved_rd_addr <= '0;
            saved_rd_data <= '0;
            saved_rd_we <= 1'b0;
            saved_exc_valid <= 1'b0;
            saved_exc_cause <= 4'b0;
            saved_exc_tval <= '0;
            saved_exc_pc <= '0;
            saved_irq_valid <= 1'b0;
            saved_irq_cause <= 4'b0;
            saved_csr_we <= 1'b0;
            saved_csr_addr <= 12'b0;
            saved_csr_wdata <= '0;
        end else begin
            current_state <= next_state;
            if (current_state == WB_IDLE) begin // Latch inputs when in IDLE so they're stable during COMMIT/EXCEPTION
                saved_rd_addr <= rd_addr_i;
                saved_rd_data <= rd_data_i;
                saved_rd_we <= rd_we_i;
                saved_exc_valid <= exc_valid_i;
                saved_exc_cause <= exc_cause_i;
                saved_exc_tval <= exc_tval_i;
                saved_exc_pc <= exc_pc_i;
                saved_irq_valid <= irq_valid_i;
                saved_irq_cause <= irq_cause_i;
                saved_csr_we <= csr_we_i;
                saved_csr_addr <= csr_addr_i;
                saved_csr_wdata <= csr_wdata_i;
            end
        end
    end

    //
    // Next-State Logic
    //

    always_comb begin
        next_state = current_state;
        unique case (current_state)
            WB_IDLE: begin
                if (exc_valid_i || irq_valid_i) begin // Exceptions and interrupts take priority over normal commit
                    next_state = WB_EXCEPTION;
                end else if (rd_we_i || csr_we_i) begin
                    next_state = WB_COMMIT;
                end
            end
            WB_COMMIT: begin  // 1-cycle commit, return to idle immediately
                next_state = WB_IDLE;
            end
            WB_EXCEPTION: begin  // 1-cycle exception commit, return to idle immediately
                next_state = WB_IDLE;
            end
            default: next_state = WB_IDLE;
        endcase
    end

    //
    // Register File, CSR, Trap, and Pipeline Control
    //

    always_comb begin  // Defaults
        rd_we_o = 1'b0;
        rd_waddr_o = '0;
        rd_wdata_o = '0;
        csr_we_o = 1'b0;
        csr_addr_o = 12'b0;
        csr_wdata_o = '0;
        trap_valid_o = 1'b0;
        trap_cause_o = '0;
        trap_tval_o = '0;
        trap_epc_o = '0;
        wb_flush_o = 1'b0;
        wb_flush_pc_o = '0;
        wb_stall_o = 1'b0;
        unique case (current_state)
            WB_IDLE: begin  // Stall for one cycle while we latch and decide
                if (exc_valid_i || irq_valid_i || rd_we_i || csr_we_i) begin
                    wb_stall_o = 1'b1;
                end
            end
            WB_COMMIT: begin // Write to register file (suppress x0 writes)
                if (saved_rd_we && (saved_rd_addr != '0)) begin
                    rd_we_o = 1'b1;
                    rd_waddr_o = saved_rd_addr;
                    rd_wdata_o = saved_rd_data;
                end
                if (saved_csr_we) begin // Write to CSR if this was a CSR instruction
                    csr_we_o = 1'b1;
                    csr_addr_o = saved_csr_addr;
                    csr_wdata_o = saved_csr_wdata;
                end
            end
            WB_EXCEPTION: begin // Exceptions suppress register writeback
                trap_valid_o = 1'b1; // Interrupts take priority when both are pending
                if (saved_irq_valid) begin
                    trap_cause_o = {1'b1, {(DATA_WIDTH-5){1'b0}}, saved_irq_cause};
                    trap_tval_o = '0;
                    trap_epc_o = saved_exc_pc;
                end else begin
                    trap_cause_o = {{(DATA_WIDTH-4){1'b0}}, saved_exc_cause};
                    trap_tval_o = saved_exc_tval;
                    trap_epc_o = saved_exc_pc;
                end
                wb_flush_o = 1'b1; // Flush pipeline and redirect to trap vector
                wb_flush_pc_o = trap_vec_i;
            end
            default: begin // Should never hit this state, but if we do, just do nothing
            end
        endcase
    end
endmodule