// fixing this very soon

module lru (
    input logic clk_i,
    input logic rst_ni,
    input logic way_accessed,
    output logic way_replaced
);


    always_ff @(posedge clk_i) begin

        // at the reset, by default, the replaced way will be the first one (0)
        if (!rst_ni) begin
            way_replaced <= 1'b0;
        end

        // if the reset is low, then its a normal process, and the replaced way will be the other one that's not currently being accessed
        else begin
            way_replaced <= !way_accessed;
        end

    end



endmodule;
