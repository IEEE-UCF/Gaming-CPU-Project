`timescale 1ns / 1ps

module VGA_timing(
    input clk,
    input reset,
    output hsync, 
    output vsync,
    output reg [9:0] x,
    output reg [9:0] y,
    output reg active_video 
); 

localparam  H_RES = 640, 
            V_RES = 480, 
            H_FP = 16,
            H_SYNC = 98, 
            H_BP = 48,
            V_FP = 10, 
            V_SYNC = 2,
            V_BP = 2; 


reg [2:0] counter; 
reg pixel_clk; 
initial begin
    counter = 0; 
end 

always@ (posedge clk) begin
    if (counter == 2'd2) begin 
        pixel_clk <= ~pixel_clk;
        counter <= 0;
    end
    else begin
        counter <= counter + 1;
    end
end 
    
   
    
    always@ (posedge pixel_clk) begin
        if (reset) begin
            x <= 0;
            y <= 0;
            active_video <= 0; 
        end
        
        if (active_video == 1'b1) begin
            //video logic 
            x <= x + 1;
            y <= y + 1; 
        end  
    end


                
endmodule
