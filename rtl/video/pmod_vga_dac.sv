module pmod__DAC(
    input logic clk_i, 
    input logic rst_ni,
    input logic active_video_i, 
    input logic [3:0] R_i, 
    input logic [3:0] G_i, 
    input logic [3:0]  B_i,
    input logic hsync_i, vsync_i, 
    output logic [3:0] vga_r_o,
    output logic  [3:0] vga_g_o,
    output logic [3:0] vga_b,
    output logic hsync_o,
    output logic vsync_o
);

assign vsync_o = vsync_i; 
assign hsync_o = hsync_i; 

always @(posedge clk_i) begin 
    if (~rst_ni) begin
        vga_r_o <= 0;
        vga_g_o <= 0;
        vga_b_o <= 0;
    end
  
 
    if (active_video_i == 1'b1) begin //active video enable nothing will happen if it is at zero 
      // if (active_video_i) begin
        vga_r_o <= R_i;
        vga_g_o <= G_i;
        vga_b_o <= B_i;  
    end
end
endmodule
