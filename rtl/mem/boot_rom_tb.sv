//when the reset is active, data_o should just be all zeroes.  Then every reset is inactive and now every 4th period (40 ns) it should first read 
//@0000 at addr_i = 12h'000, 
//0000006F at addr_i = 12h'004,
//00000013 at addr_i = 12h'008.

`timescale 1ns / 1ps

module boot_rom_tb();
   localparam ADDR_W = 12;
   localparam DATA_W = 32;
    
    logic clk_i, rst_ni, valid_o;
    logic [ADDR_W-1: 0] addr_i;
    logic [DATA_W-1:0] data_o;
    
    boot_rom UTT(.clk_i(clk_i), .rst_ni(rst_ni), .valid_o(valid_o), .addr_i(addr_i), .data_o(data_o));
    
    initial begin
    forever #10 clk_i = ~clk_i;
    end
    
    initial begin
    rst_ni = 0;
    addr_i = 0;
    
    @(posedge clk_i); 
    @(posedge clk_i);
    @(posedge clk_i);
    @(posedge clk_i);
    
    rst_ni = 1;
    
    @(posedge clk_i); 
    @(posedge clk_i);
    @(posedge clk_i);
    @(posedge clk_i);
    
    addr_i = 12'h000;
    
    @(posedge clk_i); 
    @(posedge clk_i);
    @(posedge clk_i);
    @(posedge clk_i);
    
    addr_i = 12'h004;
    
    @(posedge clk_i); 
    @(posedge clk_i);
    @(posedge clk_i);
    @(posedge clk_i);
    
    addr_i = 12'h008;
    
    end
    
    
endmodule
