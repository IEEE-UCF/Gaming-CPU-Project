//======================================================================
// DMA Channel Arbiter
// Author: Evan Eichholz
// Description: Fixed-priority channel arbitration
//======================================================================

module dma_channel_arbiter import dma_pkg::*; (
    input  logic                    clk_i,
    input  logic                    rst_ni,
    input  logic [N_CHANNELS-1:0]   req_i,
    output logic [N_CHANNELS-1:0]   grant_o
);

    logic [CHANNEL_W-1:0] current_channel;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            current_channel <= '0;
            grant_o <= '0;
        end else begin
            // Fixed priority arbitration (Channel 0 highest priority)
            grant_o <= '0;
            for (int i = 0; i < N_CHANNELS; i++) begin
                if (req_i[i]) begin
                    grant_o[i] <= 1'b1;
                    break;
                end
            end
        end
    end

endmodule