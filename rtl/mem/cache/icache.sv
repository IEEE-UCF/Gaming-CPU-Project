module icache #(
    //subject to change
    parameter int INSTR_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter LINE_SIZE = 64,
    parameter WAYS = 4,
    parameter IMEM_SIZE = 32768
) (
    input logic clk_i,
    input logic rst_ni,

    //CPU Interface
    input logic cpu_req_valid_i,
    input logic [ADDR_WIDTH-1:0] cpu_addr_i,
    input logic cpu_resp_ready_i,
    input logic icache_flush_i,

    output logic icache_req_ready_o,
    output logic icache_resp_valid_o,
    output logic [INSTR_WIDTH-1:0] icache_resp_instr_o
);


endmodule
