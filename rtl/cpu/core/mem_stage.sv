module mem_stage import rv32_pkg::*; #(
    parameter int unsigned DATA_W = 32
) (
    // Clock and Reset
    input logic clk_i,
    input logic rst_ni,

    // Load/Store Control
    input logic ls_ctrl_i,

    // Data Cache Request/Response
    inout logic dc_req_, 
    inout logic dc_rsp_,

    // Data to Writeback Stage
    output logic [DATA_W-31:0] wb_data_o
    
);
endmodule : mem_stage