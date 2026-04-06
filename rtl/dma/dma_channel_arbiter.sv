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
    logic [N_CHANNELS-1:0] grant_next;

    // fixed priority logic
    always_comb begin
        grant_next = '0;

        // Channel 0 has highest priority
        for (int i = 0; i < N_CHANNELS; i++) begin
            if (req_i[i]) begin
                grant_next[i] = 1'b1;
                break;
            end
        end
    end

    // reg outputs
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            current_channel <= '0;
            grant_o <= '0;
        end 
        else begin
            grant_o <= grant_next;

            // track which channel got granted
            for (int i = 0; i < N_CHANNELS; i++) begin
                if (grant_next[i])
                    current_channel <= i;
            end
        end
    end

endmodule
