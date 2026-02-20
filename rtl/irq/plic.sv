`timescale 1ns / 1ps

module PLIC #(
    parameter NSOURCES     = 8,
    parameter PRIO_WIDTH   = 3,
    parameter SRC_ID_WIDTH = 3
)(
    input logic clk_i,
    input logic rst_ni,
    input logic claim_req_i,
    input logic complete_i,
    input logic [NSOURCES-1:0] src_i,       // External interrupt sources

    input logic [NSOURCES*PRIO_WIDTH-1:0] priority_wdata,
    input logic priority_we,
    input logic [NSOURCES-1:0] enable_wdata,
    input logic enable_we,

    output logic ext_irq_o,
    output logic [SRC_ID_WIDTH-1:0] claim_o
);

    // -------------------------
    // Registers / Internal state
    // -------------------------
    logic [NSOURCES*PRIO_WIDTH-1:0] priorities;   // Interrupt priorities
    logic [NSOURCES-1:0] enable;                  // Enable bits for sources
    logic [SRC_ID_WIDTH-1:0] claim;               // Claim register
    logic [NSOURCES-1:0] pending;                 // Pending interrupts
    logic [SRC_ID_WIDTH-1:0] highestPriorIndex;
    logic [PRIO_WIDTH-1:0] tempHighestValue;
    logic activeClaim;

    assign claim_o   = activeClaim ? (claim + 1'b1) : '0;
    assign ext_irq_o = (!activeClaim) && (tempHighestValue != 0);

    // -------------------------
    // Priority selector
    // -------------------------
    always_comb begin
        tempHighestValue  = 0;
        highestPriorIndex = 0;

        for (int i = 0; i < NSOURCES; i++) begin
            if (pending[i] && enable[i] && priorities[i*PRIO_WIDTH +: PRIO_WIDTH] > tempHighestValue) begin
                tempHighestValue  = priorities[i*PRIO_WIDTH +: PRIO_WIDTH];
                highestPriorIndex = i[SRC_ID_WIDTH-1:0];
            end
        end
    end

    // -------------------------
    // Sequential logic
    // -------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            priorities  <= 0;
            enable      <= 0;
            claim       <= 0;
            pending     <= 0;
            activeClaim <= 0;
        end else begin

            // Register writes
            if (priority_we)
                priorities <= priority_wdata;

            if (enable_we)
                enable <= enable_wdata;

            // Pending interrupt latching
            for (int i = 0; i < NSOURCES; i++) begin
                pending[i] <= pending[i];
                if(!(activeClaim && (i == claim))) begin
                    pending[i] <= pending[i] | src_i[i];
                end
            end

            //Complete logic
            if (complete_i && activeClaim) begin
                activeClaim <= 0;
            end
            
            // Claim logic
            if (claim_req_i && !activeClaim && tempHighestValue != 0) begin
                claim <= highestPriorIndex;
                pending[highestPriorIndex] <= 0;
                activeClaim <= 1;
            end
        end
    end
endmodule

