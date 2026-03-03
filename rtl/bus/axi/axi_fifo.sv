/*
    Asynchronous FIFO

    Synchronizes data flow between two different clock domains with Gray-coded pointers
    to greatly reduce metastability.
*/

module axi_fifo #(
    parameter int DATA_WIDTH = 32,
    parameter int FIFO_DEPTH = 8
)(
    input  logic                  wr_clk_i,
    input  logic                  rd_clk_i,
    input  logic                  rst_ni,
    input  logic                  wr_en_i,
    input  logic                  rd_en_i,
    input  logic [DATA_WIDTH-1:0] wr_data_i,

    output logic [DATA_WIDTH-1:0] rd_data_o,
    output logic                  full_o,
    output logic                  empty_o
);

    localparam int PTR_WIDTH = $clog2(FIFO_DEPTH);
    localparam int PTR_SIZE  = PTR_WIDTH + 1; // extra bit to differentiate between full, empty

    logic [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];

    // Write domain pointers
    logic [PTR_SIZE-1:0] wr_ptr_bin,  wr_ptr_bin_next;
    logic [PTR_SIZE-1:0] wr_ptr_gray, wr_ptr_gray_next;

    // Read domain pointers
    logic [PTR_SIZE-1:0] rd_ptr_bin,  rd_ptr_bin_next;
    logic [PTR_SIZE-1:0] rd_ptr_gray, rd_ptr_gray_next;

    // 2-flop synchronizers
    // first is risky, second is much safer: 2 flip/flops prevent use of unsafe signals
    logic [PTR_SIZE-1:0] rd_ptr_gray_sync [2];
    logic [PTR_SIZE-1:0] wr_ptr_gray_sync [2];

    // Write Domain

    // next write pointer, if write signal high and isn't full
    assign wr_ptr_bin_next  = (wr_en_i && !full_o) ? (wr_ptr_bin + 1'b1) : wr_ptr_bin;

    assign wr_ptr_gray_next = wr_ptr_bin_next ^ (wr_ptr_bin_next >> 1); // binary -> gray conversion

    always_ff @(posedge wr_clk_i or negedge rst_ni) begin
        if (!rst_ni) begin // reset logic
            wr_ptr_bin  <= '0;
            wr_ptr_gray <= '0;
        end else begin
            wr_ptr_bin  <= wr_ptr_bin_next;
            wr_ptr_gray <= wr_ptr_gray_next; // pointer progression

            if (wr_en_i && !full_o)
                mem[wr_ptr_bin[PTR_WIDTH-1:0]] <= wr_data_i; // if write signal high and isn't full, write memory
        end
    end

    // Synchronize read pointer to write clock
    always_ff @(posedge wr_clk_i or negedge rst_ni) begin
        if (!rst_ni) begin // reset logic
            rd_ptr_gray_sync[0] <= '0;
            rd_ptr_gray_sync[1] <= '0;
        end else begin
            rd_ptr_gray_sync[0] <= rd_ptr_gray;
            rd_ptr_gray_sync[1] <= rd_ptr_gray_sync[0]; // two flip flop against metastability
        end
    end

    // full check
    always_ff @(posedge wr_clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            full_o <= 1'b0; // reset logic: not full
        end
        // if write pointer has wrapped around, there is no room left
        // lower bits equal, upper two bits inverted: write is one cycle ahead of read: full
        else full_o <= (wr_ptr_gray_next[PTR_SIZE-1]   != rd_ptr_gray_sync[1][PTR_SIZE-1]) &&
                       (wr_ptr_gray_next[PTR_SIZE-2]   != rd_ptr_gray_sync[1][PTR_SIZE-2]) &&
                       (wr_ptr_gray_next[PTR_SIZE-3:0] == rd_ptr_gray_sync[1][PTR_SIZE-3:0]);
    end

    // Read Domain

    // next read pointer, if read signal is high and isn't empty
    assign rd_ptr_bin_next  = (rd_en_i && !empty_o) ? (rd_ptr_bin + 1'b1) : rd_ptr_bin;

    assign rd_ptr_gray_next = rd_ptr_bin_next ^ (rd_ptr_bin_next >> 1); // binary -> gray conversion

    always_ff @(posedge rd_clk_i or negedge rst_ni) begin
        if (!rst_ni) begin // reset logic
            rd_ptr_bin  <= '0;
            rd_ptr_gray <= '0;
            rd_data_o   <= '0;
        end else begin
            rd_ptr_bin  <= rd_ptr_bin_next;
            rd_ptr_gray <= rd_ptr_gray_next; // pointer progression

            if (rd_en_i && !empty_o) // if read signal high and isn't empty, read memory
                rd_data_o <= mem[rd_ptr_bin[PTR_WIDTH-1:0]];
        end
    end

    // synchronize write pointer to read clock
    always_ff @(posedge rd_clk_i or negedge rst_ni) begin
        if (!rst_ni) begin // reset logic
            wr_ptr_gray_sync[0] <= '0;
            wr_ptr_gray_sync[1] <= '0;
        end else begin
            wr_ptr_gray_sync[0] <= wr_ptr_gray;
            wr_ptr_gray_sync[1] <= wr_ptr_gray_sync[0]; // two flip flop against metastability
        end
    end

    // empty check
    always_ff @(posedge rd_clk_i or negedge rst_ni) begin
        if (!rst_ni)
            empty_o <= 1'b1; // reset logic: empty
        else empty_o <= (rd_ptr_gray_next == wr_ptr_gray_sync[1]); // read, write synced: empty
    end

endmodule
