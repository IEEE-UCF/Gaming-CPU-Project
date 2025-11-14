//Fetch Module
'include "rv32_pgk.cv"
module fetch(
    input logic [31:0] pc_q,          //Program Counter, Tells I-Cache where to look
    input logic redir_i,              //Tells Fetch to redirect the PC
    input logic clk, rst              //Clock, Reset 
    //I-cache interface: stores instructions for quick access
    //req: asks for instruction
    input logic ic_req_valid,        //Fetch requests instruction from I-cache
    input logic [31:0] ic_req_addr,  //Address of the instruction being requested

    //rsp: recieves the instruction
    output logic ic_rsp_valid,         //Fetch receives the instruction
    output logic [31:0] ic_rsp_data,   //Fetch takes the data from instruction and uses it

    //Outputs for Decode
    //IN PROGRESS
    output logic [31:0] instr_i,      //Contents of instruction
    output logic [31:0] rf_rdata1,    //Address of the instruction
);

endmodule