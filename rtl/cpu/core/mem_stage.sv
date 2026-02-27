`timescale 1ns / 1ps

import rv32_pkg::*; 

module mem_stage #(

    // Clock and Reset
    input logic clk_i,
    input logic rst_ni,

    // Load/Store Control
    input logic ls_ctrl_load_i,
    input logic ls_ctrl_store_i,
    input logic ls_ctrl_size_i,
    input logic ls_ctrl_unsigned_i,
    input logic ls_ctrl_write_en_i,

    // Execution Stage Results
    input logic [DATA_WIDTH-31:0] ex_data_i,

    // Data Cache Interface
    output logic dc_req_o,
    input logic dc_rsp_i,

    // MMU Interface
    output logic mmu_access_o,
    input logic mmu_ready_i
    input logic mmu_page_fault_i,
    input logic mmu_access_fault_i,

    // Data to Writeback Stage 
    output logic [DATA_WIDTH-1:0] wb_data_o,

    // Memory Operation
    output logic mem_stall_o,
    output logic mem_exception_o,
    output logic [1:0] mem_exception_type_o,
<<<<<<< HEAD
);

=======
    );
>>>>>>> 8c4cc7e7a78e339b7538c4aa64d65b26ffc3b6a8
    
    // Rest of Signals
    logic [DATA_WIDTH-1:0] load_data;
    logic [DATA_WIDTH-1:0] store_data;
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

    logic [DATA_WIDTH-1:0] address_reg;
    logic [DATA_WIDTH-1:0] store_data_reg;
    logic [1:0] size_reg;
    logic sign_reg;
    logic is_load_reg;
    logic is_store_reg;

    //
    // Reset/Initialization
    //

    always_ff @(posedge clk_i or negedge rst_ni) begin // On reset, initialize all registers and signals
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

            if (mem_state == MEM_IDLE && (ls_ctrl_load_i || ls_ctrl_store_i)) begin // Register Inputs at Start
                address_reg <= ex_res_i;
                store_data_reg <= ex_res_i; // Assuming data is in ex_res_i for stores
                size_reg <= ls_ctrl_size_i;
                sign_reg <= ls_ctrl_sign_i;
                is_load_reg <= ls_ctrl_load_i;
                is_store_reg <= ls_ctrl_store_i;
            end

            if (mem_state == MEM_COMPLETE && !mem_exception_o) begin // Update writeback data upon completion
                if (is_load_reg && dc_rsp_i) begin
                    wb_data_o <= load_data;
                end else begin
                    wb_data_o <= address_reg; // For stores and non-memory operations
                end
            end
        end
    end

    //
    // Memory Allignment 
    //

    always_comb begin // Default values
        misalignment_error = 1'b0;
        aligned_addr = address_reg;
        
        if (mem_access_valid) begin // Check alignment only if valid memory access
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
                default: begin // If invalid size, treat as misaligned
                    misalignment_error = 1'b0;
                end
            endcase
        end
    end

    //
    // Atomic Pass-Through
    //

    generate
        if (HAS_A) begin : atomic_support // If atomic instructions supported, and if the current memory access is atomic, sets request signals accordingly
            assign atomic_req_o = mem_access_valid && 
                                 ((ls_ctrl_load_i && ls_ctrl_store_i) || 
                                  (|ls_ctrl_size_i));
            
            assign dc_req_o = mem_access_valid && !atomic_req_o && !cache_miss;
            
        end else begin : no_atomic_support // If atomic NOT supported, simply pass through memory request signals without atomic check
            assign atomic_req_o = 1'b0;
            assign dc_req_o = mem_access_valid && !cache_miss;
        end
    endgenerate
 
    // 
    // Store Byte-Enable Generation
    //

    always_comb begin
        byte_enable = 4'b0000; // Default to no bytes enabled

        if (store_operation && ls_ctrl_write_en_i) begin
            case (size_reg)
                2'b00: begin // Byte store
                    unique case (address_reg[1:0]) // Use address offset to determine which bytes to enable
                        2'b00: byte_enable = 4'b0001 << address_reg[1:0]; 
                        2'b01: byte_enable = 4'b0011 << address_reg[1:0]; 
                        2'b10: byte_enable = 4'b1111; 
                        default: byte_enable = 4'b0000; // Invalid size, no bytes enabled
                    endcase
                end 
                    2'b01: begin // Half-word store
                        unique case (address_reg[1]) // Use bit 1 of address to determine which half-word to enable
                            1'b0: byte_enable = 4'b0011; 
                            1'b1: byte_enable = 4'b1100; 
                            default: byte_enable = 4'b0000; // Invalid size, no bytes enabled
                        endcase
                    end
                    2'b10: begin; // Word store
                        byte_enable = 4'b1111; 
                    end
                endcase
            end
        end
    
    //
    // Load Bit-Extension
    //

    always_comb begin
        load_data = dc_rsp_i; // Default to raw data from cache

        if (load_operation && dc_rsp_i) begin
            logic [DATA_WIDTH-1:0] raw_data;

            case (size_reg)
                2'b00: begin // Byte load
                    unique case (address_reg[1:0]) // Use address offset to determine which byte to extract
                        2'b00: raw_data = {24'b0, dc_rsp_i[7:0]}; 
                        2'b01: raw_data = {24'b0, dc_rsp_i[15:8]}; 
                        2'b10: raw_data = {24'b0, dc_rsp_i[23:16]}; 
                        2'b11: raw_data = {24'b0, dc_rsp_i[31:24]}; 
                        default: raw_data = 32'b0; // Invalid size, return zero
                    endcase

                    if (sign_reg) begin // If signed load, perform sign-extension
                        load_data = {{24{raw_data[7]}}, raw_data[7:0]};
                    end else begin // If unsigned load, zero-extend
                        load_data = {24'b0, raw_data[7:0]};
                    end
                end
                2'b01: begin // Half-word load
                    unique case (address_reg[1]) // Use bit 1 of address to determine which half-word to extract
                        2'b0: raw_data = {16'b0, dc_rsp_i[15:0]}; 
                        2'b1: raw_data = {16'b0, dc_rsp_i[31:16]}; 
                        default: raw_data = 32'b0; // Invalid size, return zero
                    endcase

                    if (sign_reg) begin // If signed load, perform sign-extension
                        load_data = {{16{raw_data[15]}}, raw_data[15:0]};
                    end else begin // If unsigned load, zero-extend
                        load_data = {16'b0, raw_data[15:0]};
                    end
                end
                2'b10: begin // Word load, no extension needed
                    load_data = dc_rsp_i;
                end
                `default: begin
                    load_data: '0;
                end
            endcase
        end
    end

    //
    // Error Handling
    //

        always_comb begin
            mem_exception_o = 1'b0; // Default to no exception
            mem_exception_type_o = 2'b00;

            if (misalignment_error) begin
                mem_exception_o = 1'b1;
                mem_exception_type_o = 2'b01; // Misalignment exception code
            end else if (mmu_page_fault_i) begin
                mem_exception_o = 1'b1;
                mem_exception_type_o = 2'b10; // Page fault exception code
            end else if (mmu_access_fault_i) begin
                mem_exception_o = 1'b1;
                mem_exception_type_o = 2'b11; // Access fault exception code
            end
        end

    //
    // Cache Miss Handling
    //

    input logic state


    
endmodule : mem_stage