module plic #(
parameter NSOURCES = 32
)(
input clk_i,
input rst_ni,
input[NSOURCES-1:0] src_i,
output logic ext_irq_o
);

// -------------------------
// Registers / Internal state
// -------------------------
logic [NSOURCES*3-1:0] priorities;                  // Interrupt priorities
logic [NSOURCES-1:0] enable;                        // Enable bits for sources
logic [$clog2(NSOURCES)-1:0] claim;                 // Claim/complete bits
logic [NSOURCES-1:0] pending;                       // Pending interrupts
logic [$clog2(NSOURCES)-1:0] highestPriorIndex;     // Index of highest-priority pendin
logic [2:0] tempHighestValue;                       // Temporary max priority valueg
logic activeClaim;                                  // Track if a interrupt is being handled
logic plicComplete;                                 // Track if current interrupt has been handled

//Bus Interface Logic
logic [31:0] cpu_rdata;                             // Data returned on CPU reads
logic cpu_write;                                    // High if CPU is writing
logic cpu_read;                                     // High if CPU is reading
logic [31:0] cpu_wdata;                             // Data CPU wants to write
logic [31:0] cpu_addr;                              // CPU address for access

// -------------------------
// Active low reset
// -------------------------
always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
        priorities <= 0;
        enable <= 0;
        claim <= 0;
        activeClaim <= 0;
        plicComplete <= 0;

        cpu_read <= 0;
        cpu_write <= 0;
        cpu_wdata <= 0;
        cpu_addr <= 0;
    end
end

// -------------------------
// Pending interrupt latching
// -------------------------
always_ff @(posedge clk_i) begin
    for(int i = 0; i < NSOURCES; i++) begin
        pending[i] <= pending[i] | (src_i[i] & enable[i]);
    end
end

// -------------------------
// Priority selector
// -------------------------
always_ff @(posedge clk_i) begin
    tempHighestValue <= -1;
    highestPriorIndex <= -1;
    for (int i = 0; i < NSOURCES; i++) begin
        if (pending[i] && priorities[i*3 +: 3] > tempHighestValue) begin 
            tempHighestValue <= priorities[i*3 +: 3];
            highestPriorIndex <= i[4:0];
        end
    end
end

// -------------------------
// Claim and Complete interface
// -------------------------
always_ff @(posedge clk_i) begin
    if(highestPriorIndex != -1 && !activeClaim) begin
        claim <= highestPriorIndex;
        pending[highestPriorIndex] <= 0;
        activeClaim <= 1;
    end

    if(plicComplete) begin
        activeClaim <= 0;
    end
end

// -------------------------
// IRQ output logic
// -------------------------
always_ff @(posedge clk_i) begin
    ext_irq_o <= activeClaim;
end

// -------------------------
// Memory-mapped register interface
// -------------------------
always_ff @(posedge clk_i) begin
    if(cpu_read) begin
        case (cpu_addr)
            32'h0: cpu_rdata <= enable;
            32'h4: cpu_rdata <= {27'd0, claim};
            32'h8: cpu_rdata <= pending;
            32'h12: cpu_rdata <= priorities[31:0];
            32'h16: cpu_rdata <= priorities[63:32];
            32'h20: cpu_rdata <= priorities[95:64];
            default: cpu_rdata <= 0;
        endcase
    end else begin
        cpu_rdata <= 0;
    end

    if(cpu_write) begin
        case (cpu_addr)
            32'h0: enable <= cpu_wdata[NSOURCES-1:0];
            32'h4: plicComplete <= cpu_wdata[0];
            32'h8: pending <= cpu_wdata[NSOURCES-1:0];
            default: plicComplete <= plicComplete;
        endcase
    end
end

endmodule
