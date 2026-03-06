/*
// 
// Written by: Arnold Stauffer
// Purpose:
// Receive either a read or write request from a Master to reduce the complexity of 
// bursts of instructions. This will provide an interface for the Master to reduce workload
// and handle register access for multiple transactions, etc.
// 
*/

module axi_to_axi_lite import interconnect_pkg::*(
    input logic clk_i,
    input logic rst_ni,
    
    // Write Command Block
    // Write Address (WR)
    input logic [ADDR_WIDTH-1:0] awaddr_i,
    input logic awvalid_i,
    output logic awready_o,
    // Write (W)
    input logic [DATA_WIDTH-1:0] wdata_i,
    input logic [(DATA_WIDTH/8)-1:0] wstrb,  // Bytes valid to write
    input logic wvalid_i,
    output logic wready_o,
    // Write Response (B)
    output logic bvalid_o,
    input logic bready_i,
  
    // Read Command Block
    // Read Address (R)
    input logic [ADDR_WIDTH-1:0] araddr_i,
    input logic arvalid_i,
    output logic arready_o,
    // Read Response (R)
    output logic [DATA_WIDTH-1:0] rdata_o,
    output logic rvalid_o,
    input logic rready_i
);

    // Captures Writing Requests
    logic [ADDR_WIDTH-1:0] awaddr_reg;
    logic [DATA_WIDTH-1:0] wdata_reg;
    logic [[(DATA_WIDTH/8)-1:0] wstrb_reg;
    logic aw_captured;
    logic w_captured;
  
    // Captures Reading Requests
    logic [ADDR_WIDTH-1:0] raddr_reg;
    logic ar_captured;
    
  
    function automatic int unsigned indexing(input logic [ADDR_WIDTH-1:0] addr);
      indexing = addr[ADDR_WIDTH-1:2];
    endfunction

    logic [REG_INDEX_W-1:0] wr_index;
    logic [REG_INDEX_W-1:0] rd_index;

    assign wr_index = indexing(awaddr_reg)[REG_INDEX_W-1:0];
    assign rd_index = indexing(raddr_reg)[REG_INDEX_W-1:0];

    // Write address channel ready
    assign awready_o = rst_ni && !aw_captured && !bvalid_o;

    // Write data channel ready
    assign wready_o  = rst_ni && !w_captured && !bvalid_o;

    // Read address channel ready
    assign arready_o = rst_ni && !ar_captured && !rvalid_o;

    // Main code for timing and accessing storage
    integer i, b;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            awaddr_reg  <= '0;
            wdata_reg   <= '0;
            wstrb_reg   <= '0;
            raddr_reg   <= '0;

            aw_captured <= 1'b0;
            w_captured  <= 1'b0;
            ar_captured <= 1'b0;

            bvalid_o    <= 1'b0;
            rvalid_o    <= 1'b0;
            rdata_o     <= '0;

            for (i = 0; i < REG_COUNT; i++) begin
                regfile[i] <= '0;
            end
        end
        else begin
            // Capture write address
            if (awvalid_i && awready_o) begin
                awaddr_reg  <= awaddr_i;
                aw_captured <= 1'b1;
            end

            // Capture write data
            if (wvalid_i && wready_o) begin
                wdata_reg   <= wdata_i;
                wstrb_reg   <= wstrb_i;
                w_captured  <= 1'b1;
            end

            // Once both Write chucks are captured, validate it
            if (aw_captured && w_captured && !bvalid_o) begin
                if (wr_index < REG_COUNT) begin
                    for (b = 0; b < STRB_WIDTH; b++) begin
                        if (wstrb_reg[b]) begin
                            regfile[wr_index][8*b +: 8] <= wdata_reg[8*b +: 8];
                        end
                    end
                end

                bvalid_o    <= 1'b1;
                aw_captured <= 1'b0;
                w_captured  <= 1'b0;
            end

            // Complete write response handshake
            if (bvalid_o && bready_i) begin
                bvalid_o <= 1'b0;
            end

            // Capture read address
            if (arvalid_i && arready_o) begin
                raddr_reg   <= araddr_i;
                ar_captured <= 1'b1;
            end

            // Once captured, return data and validate
            if (ar_captured && !rvalid_o) begin
                if (rd_index < REG_COUNT) begin
                    rdata_o <= regfile[rd_index];
                end
                else begin
                    rdata_o <= '0;
                end

                rvalid_o    <= 1'b1;
                ar_captured <= 1'b0;
            end

            // Complete read response handshake
            if (rvalid_o && rready_i) begin
                rvalid_o <= 1'b0;
            end
        end
    end 
endmodule


