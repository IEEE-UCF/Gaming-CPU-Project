module plic ( 
    input clk_i, 
    input rst_ni, 
    input[31:0] src_i, 
    output ext_irq_o
    );

    reg[95:0] priorities;
    reg[31:0] enable;
    reg[31:0] claim;

    always_ff @(negedge clk_i) begin

        if(!rst_ni) begin
            for(int i = 0; i < 32; i++)
                priorities[i] <= 0;
        end

        if(!rst_ni) begin
            for(int i = 0; i < 32; i++)
                enable[i] <= 0;
        end

        if(!rst_ni) begin
            for(int i = 0; i < 32; i++)
                claim[i] <= 0;
        end
    end
endmodule
