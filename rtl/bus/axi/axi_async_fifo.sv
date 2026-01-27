//
// Asynchronous FIFO (First In, First Out) RTL
//
// Uses Gray codes for synchronizing pointers across asynchronous clock domains
// to prevent instability issues when calculating states (full/empty).
// Use of N + 1 bit pointers for a 2^N deep FIFO to distinguish correctly
// between full and empty states.
//

module axi_async_fifo #(
    // Width of data stored in FIFO
    parameter int unsigned DATA_WIDTH = 64,
    
    // Depth of FIFO needs to be a power of 2 (2, 4, 8, etc)
    parameter int unsigned FIFO_DEPTH = 8
)(
    // Write side (Source/Slave)
    input logic s_clk_i,
    input logic s_rst_ni, // Active-low reset
    input logic wr_en, // Write Enable
    input logic [DATA_WIDTH-1:0] wr_data, // Write Data
    output logic full, // FIFO full flag (registered)
    
    // Read side (Master/Sink)
    input logic m_clk_i,
    input logic m_rst_ni, // Active-low reset
    input logic rd_en, // Read Enable
    output logic [DATA_WIDTH-1:0] rd_data, // Read Data (registered)
    output logic empty // FIFO Empty flag (registered)
);
    // Local Parameters
    localparam int PTR_WIDTH = $clog2(FIFO_DEPTH);

    // Pointer size (N + 1 bits)
    localparam int PTR_SIZE = PTR_WIDTH + 1;

    // Memory address width (N bits)
    localparam int ADDR_WIDTH = PTR_WIDTH
    
    // Ensure that FIFO_DEPTH is a power of 2 (for simulation)
    initial begin
        if ((1 << PTR_WIDTH) != FIFO_DEPTH)
        begin
            $error(1, "axi_async_fifo: FIFO_DEPTH (%0d) is not a power of 2", FIFO_DEPTH);
        end
    end
    
    // Memory array (Single port, written in s_clk_i domain, read in m_clk_i domain)
    logic [DATA_WIDTH-1:0] memory [0:FIFO_DEPTH-1];
    
    // Gray <-> Binary Conversion Functions
    // These functions operate with the N + 1 bit pointers.
    function automatic logic [PTR_SIZE-1:0] BinaryToGray(input logic [PTR_SIZE-1:0] binary); 
        BinaryToGray = (binary >> 1) ^ binary;
    endfunction
    
    function automatic logic [PTR_SIZE-1:0] GrayToBinary(input logic [PTR_SIZE-1:0] gray);
        logic [PTR_SIZE-1:0] binary;
        automatic integer i;
        begin
            binary[PTR_WIDTH] = gray[PTR_WIDTH];
            for (i = PTR_WIDTH-1; i >= 0; i--) 
                begin
                binary[i] = binary[i + 1] ^ gray[i];
            end
            GrayToBinary = binary;
        end
    endfunction
    
    // Write Domain Signals (s_clk_i)
    // Write Pointer Registers (N + 1 bits)
    logic [PTR_SIZE-1:0] writePtrBinary, writePtrBinaryNext;
    logic [PTR_SIZE-1:0] writePtrGray, writePtrGrayNext;
    
    // Syncronized read pointer (gray) into write domain (2 flop synchronizer)
    logic [PTR_SIZE-1:0] readPtrGraySync1W, readPtrGraySync2W;
    
    logic fullNext; // Combinational Full Status
    
    // Write pointer next-state logic (Binary and Gray)
    assign writePtrBinaryNext = (wr_en && !full)
                                  ? (writePtrBinary + 1'b1) 
                                  : writePtrBinary;
                                    
    assign writePtrGrayNext = binaryToGray(writePtrBinaryNext);
    
    // Write pointer & memory update register block
    always_ff @(posedge s_clk_i or negedge s_rst_ni) 
        begin
        if (!s_rst_ni) 
            begin
            writePtrBinary <= '0;
            writePtrGray <= '0;
        end else 
            begin
            writePtrBinary <= writePtrBinaryNext;
            writePtrGray <= writePtrGrayNext;
    
            if (wr_en && !full) 
                begin
                memory[writePtrBinary[PTR_WIDTH-1:0]] <= wr_data;
            end
        end
    end
    
    // Synchronize read pointer (Gray) into write domain (s_clk_i)
    // readPtrGray is sourced from the m_clk_i domain (see the read domain below)
    always_ff @(posedge s_clk_i or negedge s_rst_ni) 
        begin
        if (!s_rst_ni) 
            begin
            readPtrGraySync1W <= '0;
            readPtrGraySync2W <= '0;
        end else 
            begin
            readPtrGraySync1W <= readPtrGray;
            readPtrGraySync2W <= readPtrGraySync1W;
        end
    end
    
    // Full flag logic (Combinational)
    // Full Condition: next write gray pointer matches synchronized read gray pointer,
    // except for MSB and MSB - 1, which are inverted.
    always_comb 
        begin
        fullNext =
            (writePtrGrayNext == {
                ~readPtrGraySync2W[PTR_WIDTH], // MSB inverted
                ~readPtrGraySync2W[PTR_WIDTH-1], // MSB - 1 inverted
                readPtrGraySync2W[PTR_WIDTH-2:0] // Lower N - 1 bits matched
            });
    end

    // Full flag register
    always_ff @(posedge s_clk_i or negedge s_rst_ni) 
        begin
        if (!s_rst_ni) 
            begin
            full <= 1'b0;
        end else 
            begin
            full <= fullNext;
        end
    end
    
    // Read Domain Signals (m_clk_i)
    // Read pointer registers (N + 1 bits)
    logic [PTR_SIZE-1:0] readPtrBinary, readPtrBinaryNext;
    logic [PTR_SIZE-1:0] readPtrGray, readPtrGrayNext;
        
    // Syncronized read pointer (gray) into write domain (2-flop synchronizer)
    logic [PTR_SIZE-1:0] writePtrGraySync1R, writePtrGraySync2R;
        
    logic emptyNext; // Combinational Empty Status

    // Read pointer next-state logic (binary and gray)
    assign readPtrBinaryNext = (rd_en && !empty) 
                                ? (readPtrBinary + 1'b1) 
                                : readPtrBinary;
                                
    assign readPtrGrayNext = binaryToGray(readPtrBinaryNext);
    
    // Read pointer & data output register block
    always_ff @(posedge m_clk_i or negedge m_rst_ni) 
        begin
        if (!m_rst_ni) 
            begin
            readPtrBinary <= '0;
            readPtrGray <= '0;
            rd_data <= '0;
        end else 
            begin
            readPtrBinary <= readPtrBinaryNext;
            readPtrGray <= readPtrGrayNext;

            // Read data from the location pointed to by the current binary pointer index
            // Data is registered into rd_data on the clock edge.
            if (rd_en && !empty) 
                begin
                    rd_data <= memory[readPtrBinary[ADDR_WIDTH-1:0]];
            end
        end
    end
    
    // Synchronize write pointer (Gray) into read domain (m_clk_i)
    // writePtrGray is sourced from the s_clk_i domain (see write domain above)
    always_ff @(posedge m_clk_i or negedge m_rst_ni) 
        begin
        if (!m_rst_ni) 
            begin
            writePtrGraySync1R <= '0;
            writePtrGraySync2R <= '0;
        end else 
            begin
            writePtrGraySync1R <= writePtrGray;
            writePtrGraySync2R <= writePtrGraySync1R;
        end
    end
    
    // Empty flag logic: (Combinational)
    // Empty condition: next read gray pointer equals synchronized write gray pointer.
    always_comb 
        begin
        emptyNext = (readPtrGrayNext == writePtrGraySync2R);
    end

    // Empty flag register
    always_ff @(posedge m_clk_i or negedge m_rst_ni) 
        begin
        if (!m_rst_ni) begin
            empty <= 1'b1;
        end else 
            begin
            empty <= emptyNext;
        end
    end

endmodule    
    


