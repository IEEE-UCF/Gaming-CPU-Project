import rv32_pkg::*;

module hazard_unit (
    // IF/ID
    
    // ID/EX 
    input logic [DATA_WIDTH-1:0] id_ex_rs1_i,
    input logic [DATA_WIDTH-1:0] id_ex_rs2_i,
    input logic [DATA_WIDTH-1:0] imm_i,

    // EX/MM
    input logic [DATA_WIDTH-1:0] ex_mm_rd_i,
    input reg_ex_we,    
    input logic ex_result_i,

    // MM/WB
    input logic [DATA_WIDTH-1:0] mm_wb_rd_i,
    input reg_mm_we,   // Also used in hazard detection unit
    input logic wb_result_i,    // Also used in hazard detection unit

    // Forwarding MUX 
    input logic [DATA_WIDTH-1:0] ex_result_i,
    input logic [DATA_WIDTH-1:0] wb_result_i,
    output logic [DATA_WIDTH-1:0] op_a_o,
    output logic [DATA_WIDTH-1:0] op_b_o,

    // ALUSrc select signals from control unit
    input logic alu_src_i, // 0 = rs2, 1 = imm

    // Hazard Detection Unit
    input logic [DATA_WIDTH-1:0] instr_i,  
    output logic if_id_we_o,    // IF/ID pipeline register write enable 
    output logic pc_we_o,   // PC write enable 
    output logic cu_select_stall_o,   // Control Unit select (0 = normal, 1 = stall)

);

    // Forwarding controls (EX stage muxes)
    // ID/EX = 00, EX/MM = 10, MM/WB = 01
    logic [1:0] forward_a, 
    logic [1:0] forward_b,

    // Forwarding Unit
    always_comb begin 
        // rs1:
        if (reg_ex_we && (ex_mm_rd_i == id_ex_rs1_i)) begin // Check with EX/MM rd
            orward_a = 2'b10;
        end else if (reg_mm_we && (mm_wb_rd_i == id_ex_rs1_i)) begin  // Check with MM/WB rd
                forward_a = 2'b01;
            end

        // rs2:
        if (reg_ex_we && (ex_mm_rd_i == id_ex_rs2_i)) begin // Check with EX/MM rd
            forward_b = 2'b10;
        end else if (reg_mm_we && (mm_wb_rd_i == id_ex_rs2_i)) begin  // Check with MM/WB rd
                forward_b = 2'b01; 
            end
    end

    // Forwading MUX 
    always_comb begin
        op_a_o = 2'b00;
        op_b_o = 2'b00;

        unique case (forward_a)
            2'b10: op_a_o = ex_result_i;    // Forward from EX/MM
            2'b01: op_a_o = wb_result_i;    // Forward from MM/WB
            default: op_a_o = id_ex_rs1_i;  // No forwarding, use ID/EX rs1
        endcase

        // ALUSrc MUX
        if (alu_src_i)
            op_b_o = imm_i; // ALUSrc override for rs2 -> imm
        else begin
            unique case (forward_b)
                2'b10: op_b_o = ex_result_i;    // Forward from EX/MM
                2'b01: op_b_o = wb_result_i;    // Forward from MM/WB
                default: op_b_o = id_ex_rs2_i;  // No forwarding, use ID/EX rs2 (overridden by ALUSrc MUX if imm)
            endcase
        end
    end

    // Hazard Detection Unit


