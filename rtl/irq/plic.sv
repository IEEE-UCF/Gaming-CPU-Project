module plic #(
    parameter NSOURCES = 32,
    parameter PRIO_WIDTH = 3
)(
    input  logic clk_i,
    input  logic rst_ni,
    input  logic [NSOURCES-1:0] src_i,       // External interrupt sources

    // Simple register interface (bus-free)
    input  logic [NSOURCES*PRIO_WIDTH-1:0] priority_wdata,
    input  logic priority_we,
    input  logic [NSOURCES-1:0] enable_wdata,
    input  logic enable_we,
    input  logic [$clog2(NSOURCES)-1:0] claim_wdata,
    input  logic claim_we,

    output logic ext_irq_o,
    output logic [$clog2(NSOURCES)-1:0] claim_o
);

    // -------------------------
    // Registers / Internal state
    // -------------------------
    logic [NSOURCES*PRIO_WIDTH-1:0] priorities;   // Interrupt priorities
    logic [NSOURCES-1:0] enable;                  // Enable bits for sources
    logic [$clog2(NSOURCES)-1:0] claim;          // Claim register
    logic [NSOURCES-1:0] pending;                // Pending interrupts
    logic [$clog2(NSOURCES)-1:0] highestPriorIndex;
    logic [PRIO_WIDTH-1:0] tempHighestValue;
    logic activeClaim;

    assign claim_o = claim;

    // -------------------------
    // Active low reset
    // -------------------------
    always_ff @(negedge rst_ni) begin
        if (!rst_ni) begin
            priorities <= 0;
            enable <= 0;
            claim <= 0;
            pending <= 0;
            highestPriorIndex <= 0;
            tempHighestValue <= 0;
            activeClaim <= 0;
        end
    end

    // -------------------------
    // Simple register writes
    // -------------------------
    always_ff @(posedge clk_i) begin
        if (priority_we) begin
            priorities <= priority_wdata;
        end
        if (enable_we) begin
            enable <= enable_wdata;
        end
        if (claim_we) begin
            activeClaim <= 0;      // Claim complete
        end
    end

    // -------------------------
    // Pending interrupt latching
    // -------------------------
    always_ff @(posedge clk_i) begin
        for (int i = 0; i < NSOURCES; i++) begin
            pending[i] <= pending[i] | (src_i[i] & enable[i]);
        end
    end

    // -------------------------
    // Priority selector
    // -------------------------
    always_ff @(posedge clk_i) begin
        tempHighestValue <= 0;
        highestPriorIndex <= 0;
        for (int i = 0; i < NSOURCES; i++) begin
            if (pending[i] && priorities[i*PRIO_WIDTH +: PRIO_WIDTH] > tempHighestValue) begin
                tempHighestValue <= priorities[i*PRIO_WIDTH +: PRIO_WIDTH];
                highestPriorIndex <= i[$clog2(NSOURCES)-1:0];
            end
        end
    end

    // -------------------------
    // Claim logic
    // -------------------------
    always_ff @(posedge clk_i) begin
        if (!activeClaim && tempHighestValue != 0) begin
            claim <= highestPriorIndex;
            pending[highestPriorIndex] <= 0;
            activeClaim <= 1;
        end
    end

    // -------------------------
    // IRQ output
    // -------------------------
    always_ff @(posedge clk_i) begin
        ext_irq_o <= activeClaim;
    end

endmodule
