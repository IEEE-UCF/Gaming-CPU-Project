`timescale 1ns / 1ps

module mem_stage #(
    parameter HAS_A = 1,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
)
import rv32_pkg::*; #(
    parameter int unsigned DATA_W = 32
) (
    // Clock and Reset
    input logic clk_i,
    input logic rst_ni,

    // Load/Store Control
    input logic ls_ctrl_load_i
    input logic ls_ctrl_store_i,
    input logic ls_ctrl_size_i,
    input logic ls_ctrl_unsigned_i,
    input logic ls_ctrl_write_en_i,

    // Execution Stage Results
    input logic [DATA_W-31:0] ex_data_i,

    // Data Cache Interface
    output logic dc_req_o,
    input logic dc_rsp_i,

    // MMU Interface
    output logic mmu_access_o,
    input logic mmu_ready_i
    input logic mmu_page_fault_i,
    input logic mmu_access_fault_i,

    // Data to Writeback Stage 
    output logic [DATA_W-1:0] wb_data_o

    // Memory Operation
    output logic mem_stall_o,
    output logic mem_exception_o,
    output logic [1:0] mem_exception_type_o,

    
    // Rest of Signals
    logic [DATA_W-1:0] load_data;
    logic {DATA_W-1:0} store_data;
    logic mem_op_valid;
    logic mem_access_valid;
    logic cache_miss;
    logic misaligned_error;
    logic store_operation;
    logic load_operation;
    logic [ADDR_WIDTH-1:0] aligned_address;

    typedef enum logic [1:0] {
        MEM_IDLE,
        MEM_REQUEST,
        MEM_WAIT_RESPONSE,
        MEM_COMPLETE
    } mem_state_t;

    mem_state_t current_state, next_state;
    
    //
    // Registers
    //

    logic [DATA_W-1:0] address_reg;
    logic [DATA_W-1:0] store_data_reg;
    logic {1:0} size_reg;
    logic sign_reg;
    logic is_load_reg;
    logic is_store_reg;

    //
    // Reset/Initialization
    //

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            current_state <= MEM_IDLE;
            address_reg <= '0;
            store_data_reg <= '0;
            size_reg <= '0;
            sign_reg <= 1'b0;
            is_load_reg <= 1'b0;
            is_store_reg <= 1'b0;
        end else begin
            current_state <= next_state;

            // Register Inputs at Start
            if (mem_state == MEM_IDLE && (ls_ctrl_load_i || ls_ctrl_store_i)) begin
                address_reg <= ex_res_i;
                store_data_reg <= ex_res_i; // Assuming data is in ex_res_i for stores
                size_reg <= ls_ctrl_size_i;
                sign_reg <= ls_ctrl_sign_i;
                is_load_reg <= ls_ctrl_load_i;
                is_store_reg <= ls_ctrl_store_i;
            end

            // Update Writeback Data on Completion
            if (mem_state == MEM_COMPLETE && !mem_exception_o) begin
                if (is_load_reg && dc_rsp_i) begin
                    wb_data_o <= load_data;
                end else begin
                    wb_data_o <= address_reg; // For stores and non-memory ops
                end
            end
        end
    end

    //
    // Memory Allignment 
    //
        always_comb begin
        misalignment_error = 1'b0;
        aligned_addr = address_reg;
        
        if (mem_access_valid) begin
            case (size_reg)
                2'b00: begin 
                    misalignment_error = 1'b0;
                end
                2'b01: begin 
                    if (address_reg[0] != 1'b0) begin
                        misalignment_error = 1'b1;
                    end
                    aligned_addr = {address_reg[31:1], 1'b0};
                end
                2'b10: begin 
                    if (address_reg[1:0] != 2'b00) begin
                        misalignment_error = 1'b1;
                    end
                    aligned_addr = {address_reg[31:2], 2'b00};
                end
                default: begin
                    misalignment_error = 1'b0;
                end
            endcase
        end
    end


    //
    // Atomic Pass-Through
    //
        generate
        if (HAS_A) begin : atomic_support
            assign atomic_req_o = mem_access_valid && 
                                 ((ls_ctrl_load_i && ls_ctrl_store_i) || 
                                  (|ls_ctrl_size_i));
            
            assign dc_req_o = mem_access_valid && !atomic_req_o && !cache_miss;
            
        end else begin : no_atomic_support
            assign atomic_req_o = 1'b0;
            assign dc_req_o = mem_access_valid && !cache_miss;
        end
    endgenerate
 
    // 
    // Store Byte-Enable Generation
    //

    //
    // Load Bit-Extension
    //

    //
    // Error Handling
    //

    //
    // Cache Miss Handling
    //

)   
    
endmodule : mem_stage