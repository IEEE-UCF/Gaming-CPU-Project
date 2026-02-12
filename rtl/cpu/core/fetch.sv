//Fetch Module

module fetch(
//Global Signals
        input  logic         clk_i, rst_ni,    //Clock, Reset(Active-Low)
    
//Local Signals
        input  logic [31:0]  pc_q,             //Program Counter (address of next instruction of I-cache)
        input  logic         redir_i,          //Redirects PC to a different address

    //I-cache interface: stores instructions for quick access
    //req: Request to I-cache
        output logic         ic_req_valid_o,   //Fetch requests instruction from I-cache
        output logic [31:0]  ic_req_addr_o,    //Address of the instruction being requested

    //rsp: Response from I-cache
        input  logic         ic_rsp_valid_i,   //Fetch receives the instruction from I-cache
        input  logic [31:0]  ic_rsp_data_i,    //The actual 32-bit instruction returned by I-cache

    //Outputs to Decode
        output logic [31:0]  inst_o            //Sends instruction to the Decode Stage
);
    parameter NOP = 32'b0; //Invalid state for Decode

    //Cache Request Logic: Instruction is requested by default, unless reset or redirect occurs
    always_comb begin
        if(!rst_ni || redir_i)      ic_req_valid_o = 0; //Doesn't request an instruction   
        else                        ic_req_valid_o = 1; //Instruction is requested
    end

    assign ic_req_addr_o = pc_q; //request address is permanently assigned to pc_q

    //Cache Response Logic: if cache responds, then instruction sent to decode
    //Otherwise, then send decode invalid data (32'b0)
        //flush and stall old instruction through NOP
    always_ff(posedge clk_i)begin
         if(redir_i || !ic_rsp_valid_i)     inst_o <= NOP; 
         else                               inst_o <= ic_rsp_data_i;
    end
endmodule

/*CORE DEALS WITH THIS
    //PC logic
    always_ff @(posedge clk_i)begin 
        if(!rst_ni) pc_q <= 32'b0;                      //reset    ->PC goes to reset address
        else if(redir_i) pc_q <= Branch/jump address;   //redirect ->PC redirects to Branch/jump address
        else pc_q <= pc_q + 4;                          //PC increments by 4 by default
    end
*/