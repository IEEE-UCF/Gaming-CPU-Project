module clint(
    input  logic        clk_i,
    input  logic        rst_ni,
    output logic        Timer_irq_o,
    input  logic [63:0] user_time, //
    output logic [63:0] mtime_o,   // 
    output logic        msip
);
    logic [63:0] mtimecmp;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            mtime_o     <= 16'd0;
            mtimecmp    <= 16'd0;
            Timer_irq_o <= 1'b0;
            msip        <= 1'b0;
        end else begin
            mtime_o     <= mtime_o + 1;
            mtimecmp    <= user_time;
            Timer_irq_o <= (mtime_o >= mtimecmp);
            msip        <= Timer_irq_o;
        end
    end
endmodule

