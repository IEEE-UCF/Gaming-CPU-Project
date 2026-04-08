module fb_ctrl_basic #(
  parameter int unsigned H_RES        = 640,
  parameter int unsigned V_RES        = 480,

  // Source framebuffer format (GamingCPU uses 320x200 8bpp; start here even if VGA is 640x480)
  parameter int unsigned FB_W         = 320,
  parameter int unsigned FB_H         = 200,
  parameter int unsigned INDEX_W      = 8,     // 8bpp index
  parameter int unsigned RGB_W        = 24,    // 8:8:8 output for now

  // Addressing
  parameter int unsigned ADDR_W       = 32,
  parameter int unsigned STRIDE_W     = 16     // stride in BYTES
) (
  input  logic                    clk_i,
  input  logic                    rst_ni,
  input  logic                    enable_i,

  // "Registers" (programming model)
  input  logic [ADDR_W-1:0]       fb_base_i,     // base address (byte address, even for BRAM emulation)
  input  logic [STRIDE_W-1:0]     fb_stride_i,   // bytes per row (>= FB_W)

  // From timing generator
  input  logic [$clog2(H_RES)-1:0] pixel_x_i,
  input  logic [$clog2(V_RES)-1:0] pixel_y_i,
  input  logic                    active_video_i,
  input logic vsync_i,

  //for double buffering
  input logic swap_req_i, //signal from CPU to request buffer swap (can be a simple pulse)
  output logic swap_done_o, //signal to CPU to indicate swap is done (can be a pulse on the next vsync after swap)

  // frame sync intrrupt (to CPU / interrupt controller)
  output logic vsync_irq_o,

  // Output pixel stream
  output logic [INDEX_W-1:0]      pixel_index_o,
  output logic [RGB_W-1:0]        pixel_rgb_o,
  output logic                    pixel_valid_o

);

//enable 
logic enable_q;
logic enable_rise;

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        enable_q <= 1'b0;
    end else begin
        enable_q <= enable_i;
    end
end

assign enable_rise = enable_i && !enable_q; //detect rising edge of enable to reset state if needed
  // --------------------------------------------------------------------------
  //Coordinate mapping (OUTPUT space -> SOURCE framebuffer space)
  // --------------------------------------------------------------------------
    
    logic [$clog2(FB_W)-1:0] src_x;
    logic [$clog2(FB_H)-1:0] src_y;
    logic src_in_range;

    always_comb begin

        src_x = pixel_x_i[$clog2(H_RES)-1:1]; //scale the x down by 2 640 -> 320 
        src_y = (pixel_y_i * FB_H) / V_RES;  //scale the y down 480 -> 200
        src_in_range = (src_x < FB_W) && (src_y < FB_H); // a simple bounds check

    end




// --------------------------------------------------------------------------
// Memory backend (BRAM emulation for now)
//    We'll model framebuffer as a simple array indexed by "byte offset from base"
// --------------------------------------------------------------------------
localparam int unsigned FB_BYTES = FB_W * FB_H; // 1 byte per pixel 
localparam int unsigned FB_TOTAL_BYTES = 2 * FB_BYTES; //total size for double buffering

logic [$clog2(FB_TOTAL_BYTES)-1:0] bram_addr; 
logic [INDEX_W-1:0] bram_rdata_q;

//replace this line with actual BRAM instantiation in the future
logic [INDEX_W-1:0] framebuffer [0:FB_TOTAL_BYTES-1];

//page offsets 
localparam int unsigned FB_PAGE_BYTES = FB_BYTES;
logic [$clog2(FB_TOTAL_BYTES)-1:0] front_page_off_q, back_page_off_q;


//read address uses front page
always_comb begin
    bram_addr = front_page_off_q + (src_y * FB_W) + src_x; 
end

//1 cycle registered read 
always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        bram_rdata_q <= '0;
    end else begin
        bram_rdata_q <= framebuffer[bram_addr];
    end
end

// --------------------------------------------------------------------------
//Valid alignment (because memory read has latency)
// --------------------------------------------------------------------------

logic valid_q;

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        valid_q <= 1'b0;
    end else begin
        valid_q <= enable_i && src_in_range && active_video_i;
    end
end

always_comb begin
    pixel_index_o = bram_rdata_q;
    pixel_valid_o = valid_q;
end

// --------------------------------------------------------------------------
//Palette lookup 
// --------------------------------------------------------------------------

logic [RGB_W-1:0] palette [0:(1<<INDEX_W)-1]; //256-entry palette for 8bpp

always_comb begin 
    pixel_rgb_o = {pixel_index_o, pixel_index_o, pixel_index_o}; //grayscale palette for now

    if (!pixel_valid_o) begin
        pixel_rgb_o = 0; //black when not valid
    end
end


///vsync irq logic
    logic vsync_q;
    logic vsync_rising;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            vsync_q <= 1'b0;
        end else begin
            vsync_q <= vsync_i;
        end
    end

    assign vsync_rising = vsync_i && !vsync_q; //rising edge detection

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            vsync_irq_o <= 1'b0;
        end else begin
            vsync_irq_o <= vsync_rising; //interrupt generation
        end
    end




//double buffering logic

logic swap_pending_q;

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        
         front_page_off_q <= '0;                 // page 0 is front
         back_page_off_q  <= FB_PAGE_BYTES[$clog2(FB_TOTAL_BYTES)-1:0]; // page 1 is back
        swap_pending_q <= 1'b0;
        swap_done_o    <= 1'b0;
    end
   else begin
    swap_done_o <= 1'b0;                  // default: no pulse

     if (enable_rise) begin
        swap_done_o <= 1'b0;                  // default: no pulse
        front_page_off_q <= '0;
      back_page_off_q  <= FB_PAGE_BYTES[$clog2(FB_TOTAL_BYTES)-1:0];
    end 

    // Latch request
    if (swap_req_i)
      swap_pending_q <= 1'b1;

    // Execute swap only on VSYNC boundary
    if (vsync_rising && swap_pending_q) begin

      // swap pages on VSYNC
      front_page_off_q <= back_page_off_q;
      back_page_off_q  <= front_page_off_q;

      swap_pending_q <= 1'b0;
      swap_done_o    <= 1'b1;
    end
  end
end

endmodule
