import rv32_pkg::*;

module hazard_unit (
    // IF/ID

    // ID/EX 
    input logic [4:0] id_ex_rs1_i,
    input logic [4:0] id_ex_rs2_i,

    // EX/MM
    input logic [4:0] ex_mm_rd_i,
    input reg_ex_we,

    // MM/WB
    input logic [4:0] mm_wb_rd_i,
    input reg_mm_we,

    // Forwarding controls (EX stage muxes)
    // ID/EX = 00, EX/MM = 10, MM/WB = 01
    output logic [1:0] forward_a_o, 
    output logic [1:0] forward_b_o,

);

always_comb begin 
    // rs1:
    if (reg_ex_we && (ex_mm_rd_i == id_ex_rs1_i)) begin // Check with EX/MM rd
        forward_a_o = 2'b10;
    end else if (reg_mm_we && (mm_wb_rd_i == id_ex_rs1_i)) begin  // Check with MM/WB rd
            forward_a_o = 2'b01;
        end

    // rs2:
    if (reg_ex_we && (ex_mm_rd_i == id_ex_rs2_i)) begin // Check with EX/MM rd
        forward_b_o = 2'b10;
    end else if (reg_mm_we && (mm_wb_rd_i == id_ex_rs2_i)) begin  // Check with MM/WB rd
            forward_b_o = 2'b01; 
        end
end
