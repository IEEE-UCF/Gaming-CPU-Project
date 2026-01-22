//Fetch Module

module fetch(
//Global Signals
        input  logic         clk_i, rst_ni,    //Clock, Reset(Active-Low)
    
//Local Signals
    reg input  logic [31:0]  pc_q,             //Program Counter (address of next instruction of I-cache)
        input  logic         redir_i,          //Redirects PC to a different address

    //I-cache interface: stores instructions for quick access
    //req: Request to I-cache
    reg output logic         ic_req_valid_o,   //Fetch requests instruction from I-cache
    reg output logic [31:0]  ic_req_addr_o,    //Address of the instruction being requested

    //rsp: Response from I-cache
        input  logic         ic_rsp_valid_i,   //Fetch receives the instruction from I-cache
        input  logic [31:0]  ic_rsp_data_i,    //The actual 32-bit instruction returned by I-cache

    //Outputs to Decode
        output logic [31:0] inst_o             //Sends instruction to the Decode Stage
);
    //PC logic
        //reset    ->PC goes to reset address
        //redirect ->PC redirects to new address ???
        //PC increments by 4 by default
    always_ff @(posedge clk_i)begin 
        if(!rst_ni) pc_q <= 32'b0;

        else if(redir_i) pc_q <= //??

        else pc_q <= pc_q + 4;
    end

    //Cache Request Logic: Instruction is requested by default, unless reset or redirect occurs
    always_comb() begin
        if(!rst_ni || redir_i)begin //Doesn't request an instruction
            ic_req_valid_o = 0;
            ic_req_addr_o = pc_q;
        end
        else begin
            ic_req_valid_o = 1;     //Instruction is requested
            ic_req_addr_o = pc_q;
        end
    end
    //Cache Response Logic: if cache responds, then instruction sent to decode
    //Otherwise, ???
    always_comb()begin
         if(ic_rsp_valid_i) inst_o = ic_rsp_data_i;
         else inst_o =  //????
    end

endmodule