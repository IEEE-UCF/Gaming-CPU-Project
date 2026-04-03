    Memory Final
    
    `timescale 1ns/1ps

    import rv32_pkg::*;

    module mem_stage(

        // Clock and Reset
        input logic clk_i,
        input logic rst_ni,

        // Pipeline Control
        input logic flush_i,
        output logic stall_o,

        // Load/Store Control
        input logic ls_ctrl_load_i,
        input logic ls_ctrl_store_i,
        input logic [1:0] ls_ctrl_size_i, // 00 = Byte, 01 = Half-word, 10 = Word
        input logic ls_ctrl_sign_i, // 1 = Sign extend, 0 = Zero extend
        // Atomic Control
        input logic ls_atomic_i,
        input logic ls_lr_i,
        input logic ls_sc_i,

        // EX Stage Results
        input logic [DATA_WIDTH-1:0] ex_result_i,
        input logic [DATA_WIDTH-1:0] ex_data_i,
        input logic [4:0] rd_addr_i,
        input logic reg_we_i,

        // MMU Interface
        input logic mmu_page_fault_i,
        input logic mmu_access_fault_i,

        // Data Cache Request
        output logic dc_req_o,
        output logic dc_we_o,
        output logic [ADDR_WIDTH-1:0] dc_addr_o,
        output logic [DATA_WIDTH-1:0] dc_wdata_o,
        output logic [3:0] dc_be_o,
        output logic dc_atomic_o,
        // Data Cache Response
        input logic [DATA_WIDTH-1:0] dc_rsp_data_i,
        input logic dc_rsp_valid_i,
        input logic dc_rsp_error_i,

        // Data to WB
        output logic [DATA_WIDTH-1:0] wb_data_o,
        output logic [4:0] wb_rd_addr_o,
        output logic wb_we_o,

        // Exception Outputs
        output logic exception_o,
        output logic [1:0] exception_type_o // 01=misalign, 10=page fault, 11=access fault
    );

        // Internal Wires
        logic misaligned;
        logic [3:0] byte_en;
        logic [DATA_WIDTH-1:0] shifted_wdata;
        logic [DATA_WIDTH-1:0] extended_rdata;
        // Saved Signals - "we latch these when we start a memory op because the EX stage inputs could change on the next clock cycle while we're still waiting on the cache"
        logic [DATA_WIDTH-1:0] saved_addr;
        logic [DATA_WIDTH-1:0] saved_store_data;
        logic [1:0] saved_size;
        logic saved_signed;
        logic saved_is_load;
        logic saved_is_store;
        logic saved_we;
        logic [4:0] saved_rd;
        logic saved_atomic;
        logic saved_lr;
        logic saved_sc;
        // LR/SC Reservation
        logic resv_valid;
        logic [ADDR_WIDTH-1:0] resv_addr;
        logic sc_pass;

        // FSM
        typedef enum logic [1:0] {
            MEM_IDLE = 2'b00,
            MEM_REQUEST = 2'b01,
            MEM_WAIT_RESPONSE = 2'b10
        } state_t;
        state_t state, next_state;

        //
        // Reset/Initlization
        //

        always_ff @(posedge clk_i or negedge rst_ni) begin
            if (!rst_ni) begin
                state <= IDLE;
                saved_addr <= '0;
                saved_store_data <= '0;
                saved_size <= 2'b00;
                saved_signed <= 1'b0;
                saved_is_load <= 1'b0;
                saved_is_store <= 1'b0;
                saved_we <= 1'b0;
                saved_rd <= 5'b0;
                saved_atomic <= 1'b0;
                saved_lr <= 1'b0;
                saved_sc <= 1'b0;
            end else if (flush_i) begin
                state <= MEM_IDLE;
            end else begin
                state <= next_state;
                if (state == MEM_IDLE && (ls_ctrl_load_i || ls_ctrl_store_i)) begin // latch inputs when transitioning from MEM_IDLE to MEM_REQUEST
                    saved_addr <= ex_result_i;
                    saved_store_data <= shifted_wdata;
                    saved_size <= ls_ctrl_size_i;
                    saved_signed <= ls_ctrl_sign_i;
                    saved_is_load <= ls_ctrl_load_i;
                    saved_is_store <= ls_ctrl_store_i;
                    saved_we <= reg_we_i;
                    saved_rd <= rd_addr_i;
                    saved_atomic <= ls_atomic_i;
                    saved_lr <= ls_lr_i;
                    saved_sc <= ls_sc_i;
                end
            end
        end

        //
        // Memory Allignment  
        //

        always_comb begin
            case (mem_size_i)
                2'b00: misaligned = 1'b0;              // Byte
                2'b01: misaligned = ex_result_i[0];    // Half-Word, check bit 0
                2'b10: misaligned = |ex_result_i[1:0]; // Word, check bits 1:0
                default: misaligned = 1'b0;
            endcase
        end

        //
        // Atomic Pass-Through
        //

        generate
            if (HAS_A) begin : atomic_support
                always_ff @(posedge clk_i or negedge rst_ni) begin
                    if (!rst_ni) begin
                        resv_valid <= 1'b0;
                        resv_addr  <= '0;
                    end else if (flush_i) begin
                        resv_valid <= 1'b0;
                    end else begin
                        if (ls_lr_i && dc_rsp_valid_i && !dc_rsp_error_i) begin // LR sets reservation on successful cache response
                            resv_valid <= 1'b1;
                            resv_addr  <= ex_result_i;
                        end
                        else if (ls_sc_i && state == MEM_REQUEST) begin // SC clears reservation no matter what
                            resv_valid <= 1'b0;
                        end
                        else if (ls_ctrl_store_i && !ls_sc_i && resv_valid && (ex_result_i == resv_addr)) begin // Normal store to reserved addr also clears it
                            resv_valid <= 1'b0;
                        end
                    end
                end
                assign sc_pass = resv_valid && (ex_result_i == resv_addr);
            end else begin : no_atomic_support
                assign resv_valid = 1'b0;
                assign resv_addr = '0;
                assign sc_pass = 1'b0;
            end
        endgenerate

        //
        // Store Byte-Enable Generation
        // 

        always_comb begin
            byte_en = 4'b0000;
            case (ls_ctrl_size_i)
                2'b00: begin // Byte - 1/4 bytes based on offset
                    case (ex_result_i[1:0])
                        2'b00: byte_en = 4'b0001;
                        2'b01: byte_en = 4'b0010;
                        2'b10: byte_en = 4'b0100;
                        2'b11: byte_en = 4'b1000;
                    endcase
                end
                2'b01: begin // Half-word - upper/ lower 2 bytes
                    if (ex_result_i[1])
                        byte_en = 4'b1100;
                    else
                        byte_en = 4'b0011;
                end
                2'b10: begin // Word - all 4 bytes
                    byte_en = 4'b1111;
                end
                default: byte_en = 4'b0000;
            endcase
        end

        // Stored Data Shifting           
        always_comb begin
            case (ls_ctrl_size_i)
                2'b00: shifted_wdata = {4{ex_data_i[7:0]}};
                2'b01: shifted_wdata = {2{ex_data_i[15:0]}};
                2'b10: shifted_wdata = ex_data_i;
                default: shifted_wdata = ex_data_i;
            endcase
        end

        //         
        // Load Bit Extension 
        //

        always_comb begin
            extended_rdata = dc_rsp_data_i;
            case (saved_size)
                2'b00: begin // Byte Load
                    case (saved_addr[1:0])
                        2'b00: begin
                            if (saved_signed)
                                extended_rdata = {{24{dc_rsp_data_i[7]}}, dc_rsp_data_i[7:0]};
                            else
                                extended_rdata = {24'b0, dc_rsp_data_i[7:0]};
                        end
                        2'b01: begin
                            if (saved_signed)
                                extended_rdata = {{24{dc_rsp_data_i[15]}}, dc_rsp_data_i[15:8]};
                            else
                                extended_rdata = {24'b0, dc_rsp_data_i[15:8]};
                        end
                        2'b10: begin
                            if (saved_signed)
                                extended_rdata = {{24{dc_rsp_data_i[23]}}, dc_rsp_data_i[23:16]};
                            else
                                extended_rdata = {24'b0, dc_rsp_data_i[23:16]};
                        end
                        2'b11: begin
                            if (saved_signed)
                                extended_rdata = {{24{dc_rsp_data_i[31]}}, dc_rsp_data_i[31:24]};
                            else
                                extended_rdata = {24'b0, dc_rsp_data_i[31:24]};
                        end
                    endcase
                end
                2'b01: begin // Half-word load
                    if (saved_addr[1]) begin
                        if (saved_signed)
                            extended_rdata = {{16{dc_rsp_data_i[31]}}, dc_rsp_data_i[31:16]};
                        else
                            extended_rdata = {16'b0, dc_rsp_data_i[31:16]};
                    end else begin
                        if (saved_signed)
                            extended_rdata = {{16{dc_rsp_data_i[15]}}, dc_rsp_data_i[15:0]};
                        else
                            extended_rdata = {16'b0, dc_rsp_data_i[15:0]};
                    end
                end
                2'b10: begin // Word load, no extension needed
                    extended_rdata = dc_rsp_data_i;
                end
                default: extended_rdata = dc_rsp_data_i;
            endcase
        end

        //
        // Error Detection and Handling       
        //

        always_comb begin
            exception_o = 1'b0;
            exception_type_o = 2'b00;
            if (misaligned && (ls_ctrl_load_i || ls_ctrl_store_i)) begin
                exception_o = 1'b1;
                exception_type_o = 2'b01;
            end else if (mmu_page_fault_i) begin
                exception_o = 1'b1;
                exception_type_o = 2'b10;
            end else if (mmu_access_fault_i || cache_rsp_error_i) begin
                exception_o = 1'b1;
                exception_type_o = 2'b11;
            end
        end

        //
        // Cache Miss Detection and Handling
        //

        always_comb begin 
            next_state = state;
            dc_req_o = 1'b0;
            dc_we_o = 1'b0;
            dc_addr_o = '0;
            dc_wdata_o = '0;
            dc_be_o = 4'b0;
            dc_atomic_o = 1'b0;
            stall_o = 1'b0;
            wb_data_o = ex_result_i;
            wb_rd_addr_o = rd_addr_i;
            wb_we_o = reg_we_i;
            case (state)
                MEM_IDLE: begin // Check if Load or Store is needed, if so, send request to cache
                    if (ls_ctrl_load_i || ls_ctrl_store_i) begin
                        if (misaligned) begin // Misaligned address, raise exception, don't send request
                            wb_we_o = 1'b0;
                            next_state = MEM_IDLE;
                        end else if (HAS_A && ls_sc_i && !sc_pass) begin // SC failed (reservation lost), write 1 to rd, o mem op
                            wb_data_o = 32'd1;
                            next_state = MEM_IDLE;
                        end else begin // Valid memory request, send to cache
                            dc_req_o = 1'b1;
                            dc_we_o = ls_ctrl_store_i;
                            dc_addr_o = {ex_result_i[ADDR_WIDTH-1:2], 2'b00}; 
                            dc_wdata_o = shifted_wdata;
                            dc_be_o = byte_en;
                            dc_atomic_o = ls_atomic_i;
                            stall_o = 1'b1;
                            next_state = MEM_REQUEST;
                        end
                    end
                end
                MEM_REQUEST: begin // Check if cache responded this cycle
                    stall_o = 1'b1;
                    wb_rd_addr_o = saved_rd;
                    wb_we_o = 1'b0; 
                    if (dc_rsp_valid_i) begin
                        if (dc_rsp_error_i || mmu_page_fault_i || mmu_access_fault_i) begin // Error, Don't write to register file
                            wb_we_o = 1'b0;
                            stall_o = 1'b0;
                            next_state = MEM_IDLE;
                        end else begin // Cache hit
                            stall_o = 1'b0;
                            next_state = MEM_IDLE;
                            if (saved_is_load) begin
                                wb_data_o = extended_rdata;
                                wb_we_o = saved_we;
                            end else if (saved_is_store && saved_sc && HAS_A) begin // SC success = write 0 to rd
                                wb_data_o = 32'd0;
                                wb_we_o = saved_we;
                            end else begin
                                wb_data_o = saved_addr;
                                wb_we_o = saved_we;
                            end
                        end
                    end else begin // Cache miss, have to wait for AXI to bring data from memory
                        next_state = MEM_WAIT_RESPONSE;
                    end
                end
                MEM_WAIT_RESPONSE: begin // Cache miss, stall pipeline until the fill comes back
                    stall_o = 1'b1;
                    wb_rd_addr_o = saved_rd;
                    wb_we_o = 1'b0;
                    if (dc_rsp_valid_i) begin
                        if (dc_rsp_error_i || mmu_page_fault_i || mmu_access_fault_i) begin
                            wb_we_o = 1'b0;
                        end else begin
                            if (saved_is_load) begin
                                wb_data_o = extended_rdata;
                                wb_we_o = saved_we;
                            end else if (saved_is_store && saved_sc && HAS_A) begin
                                wb_data_o = 32'd0;
                                wb_we_o = saved_we;
                            end else begin
                                wb_data_o = saved_addr;
                                wb_we_o = saved_we;
                            end
                        end
                        stall_o = 1'b0;
                        next_state = MEM_IDLE;
                    end
                end
                default: next_state = MEM_IDLE;
            endcase
        end
    endmodule