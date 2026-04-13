module clint(
    input  logic        clk_i,
    input  logic        rst_ni,
    // write ports
    input  logic        msip_we,
    input  logic        msip_wdata,
    
    input  logic        mtimecmp_we,
    input  logic [63:0] mtimecmp_wdata,
    
    // outputs
    output logic [63:0] mtime_o,
    output logic        timer_irq_o,
    output logic        soft_irq_o
    );
    
    //----------------------------------------
    // Internal Registers
    //----------------------------------------
    logic [63:0] mtimecmp;
    logic        msip;
    
     always_ff @(posedge clk_i or negedge rst_ni) begin
           if (!rst_ni) begin
              mtime_o     <= 64'd0;
              mtimecmp  <= 64'd0;
              msip      <= 1'b0;
              timer_irq_o <= 1'b0;
              soft_irq_o  <= 1'b0;
           end else begin
           //free running timer
               mtime_o     <= mtime_o + 1;
               
             // register writes
                if (mtimecmp_we) mtimecmp <= mtimecmp_wdata;
                if (msip_we)     msip     <= msip_wdata;
                
                // irq outputs (compare against "next" mtime to avoid 1-cycle lag)
                timer_irq_o <= ((mtime_o + 64'd1) >= (mtimecmp_we ? mtimecmp_wdata : mtimecmp));
                soft_irq_o  <= (msip_we ? msip_wdata : msip);
           end
       end
endmodule
