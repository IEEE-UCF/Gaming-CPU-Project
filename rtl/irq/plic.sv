module plic #(
    parameter NSOURCES     = 32,
    parameter PRIO_WIDTH   = 3,
    parameter SRC_ID_WIDTH = 5
)(
    input  logic clk_i,
    input  logic rst_ni,
    input  logic [NSOURCES-1:0] src_i,       // External interrupt sources

    input  logic [NSOURCES*PRIO_WIDTH-1:0] priority_wdata,
    input  logic priority_we,
    input  logic [NSOURCES-1:0] enable_wdata,
    input  logic enable_we,
    input  logic claim_we,

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

    assign claim_o   = claim;
    assign ext_irq_o = (tempHighestValue != 0);

    // -------------------------
    // Priority selector
    // -------------------------
    always_comb begin
        tempHighestValue  = 0;
        highestPriorIndex = 0;

        for (int i = 0; i < NSOURCES; i++) begin
            if (pending[i] &&
                priorities[i*PRIO_WIDTH +: PRIO_WIDTH] > tempHighestValue) begin
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

            if (claim_we)
                activeClaim <= 0;   // Claim complete

            // Pending interrupt latching
            for (int i = 0; i < NSOURCES; i++) begin
                pending[i] <= pending[i] | (src_i[i] & enable[i]);
            end

            // Claim logic
            if (!activeClaim && tempHighestValue != 0) begin
                claim <= highestPriorIndex;
                pending[highestPriorIndex] <= 0;
                activeClaim <= 1;
            end
        end
    end
endmodule
