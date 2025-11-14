//Fetch Module

module fetch(
    input [31:0] pc_q,          //Program Counter, Tells I-Cache where to look
    input redir_i,              //Tells Fetch to redirect the PC

    //I-cache interface: stores instructions for quick access
    //req: asks for instruction
    output ic_req_valid,        //Fetch requests instruction from I-cache
    output [31:0] ic_req_addr,  //Address of the instruction being requested

    //rsp: recieves the instruction
    input ic_rsp_valid,         //Fetch receives the instruction
    input [31:0] ic_rsp_data,   //Fetch takes the data from instruction and uses it

    //Outputs for Decode
    //IN PROGRESS
    output [31:0] instr_i,      //Contents of instruction
    output [31:0] rf_rdata1,    //Address of the instruction
);

endmodule