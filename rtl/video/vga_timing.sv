module VGA_timing(
    input clk_i, //clock to control porject 
    input rst_ni, //active low reset 
    output hsync, //horizotal sync 
    output vsync, //vertical sync 
    
    /****/
    //not in ond pager added after fact
    output reg [9:0] pos_in_row, //current position in row
    output reg [9:0] pos_in_col, //current position in col
    /****/
   
    output reg [9:0] x, //x coordinate to display pixel data
    output reg [9:0] y, //y coordinate to display pixel data
    output reg active_video //determines whether we have active video or not 
); 

//parameters for VGA window 
localparam  H_RES = 640, 
            V_RES = 480, 
            H_FP = 16,
            H_SYNC = 98, 
            H_BP = 48,
            V_FP = 10, 
            V_SYNC = 2,
            V_BP = 2,
            H_ACTIVE_START = H_SYNC + H_BP, //this parameter list the start of the valid horizontal output
            H_ACTIVE_END = H_ACTIVE_START + H_RES, //this parameter contains when to stop output data
            V_ACTIVE_START = V_SYNC + V_BP,
            V_ACTIVE_END = V_SYNC + 480; 
            
            
/*     STUFF TO CONTROL and MAKE VGA CLOCK */           
reg [2:0] counter; 
reg pixel_clk; 
initial begin
    counter = 0; 
end 

always@ (posedge clk_i) begin
    if (counter == 2'd2) begin 
        pixel_clk <= ~pixel_clk;
        counter <= 0;
    end
    else begin
        counter <= counter + 1;
    end
end 

/* clock end */



/* STUFF TO CONTROL VGA DISPLAY */  
    assign hsync = (x < H_SYNC) ? 1'b0 : 1'b1;  //while this is less than the HSYNC value (98) it is going to not write valid data (black) 
    assign vsync = (y < V_SYNC) ? 1'b0 : 1'b1; //while this is less than the VSYNC value (2) it is going to not write valid data (black) 
    
    
    always@ (posedge pixel_clk) begin
        if (rst_ni) begin
            x <= 0;
            y <= 0;
            active_video <= 0; 
        end
        
        if (active_video == 1'b1) begin
           if ((pos_in_row >= H_ACTIVE_START) && (pos_in_row < H_ACTIVE_END) && 
                (pos_in_col >= V_ACTIVE_START) && (pos_in_col < V_ACTIVE_END)) begin
                    x <= pos_in_row - H_ACTIVE_START;
                    y <= pos_in_col - V_ACTIVE_START;
        end
        end
        else begin //not within valid data window 
            x <= 0;
            y <= 0;
        end
    end
 /* VGA STUFF */      
endmodule
