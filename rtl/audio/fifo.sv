module fifo #(
    //Parameters 
    parameter WIDTH = 32,
    parameter DEPTH = 16
)(
    //Ports
    input logic clk_i,
    input logic rst_ni,

    //Write 
    input logic [WIDTH-1:0] wdata_i,
    input logic wr_en_i,
    output logic full_o,

    //Read
    output logic [WIDTH-1:0] rdata_o,
    input logic rd_en_i,
    output logic empty_o
);

    timeunit 1ns; timeprecision 100ps;

    //local parameters
    localparam ADDR_W = $clog2(DEPTH);

    //local signals 
    logic [ADDR_W-1:0] rptr, wptr;
    logic full, empty;
    logic last_was_read;

    //Register Array
    logic [WIDTH-1:0] mem [0:DEPTH-1];

    //Write operation
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            wptr <= 0;
        end else begin
            if (wr_en_i && !full) begin
                mem[wptr] <= wdata_i;
                wptr <= wptr + 1'b1;
            end
        end  
    end 

    //Read operation
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rptr <= 0;
        end else begin
            if (rd_en_i && !empty) begin
                rptr <= rptr + 1'b1;
                rdata_o <= mem[rptr];
            end 
    end
    end
    //Last operation tracker 
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            last_was_read <= 1;
        end else begin
            if (rd_en_i && !empty) begin
                last_was_read <= 1;
            end else if (wr_en_i && !full) begin
                last_was_read <= 0;
            end else begin
                last_was_read <= last_was_read;
            end 
        end
    end

        //Full and empty flags 

    assign full = (wptr == rptr) && !last_was_read;
    assign empty = (wptr == rptr) && last_was_read;

    assign full_o = full;
    assign empty_o = empty;


endmodule