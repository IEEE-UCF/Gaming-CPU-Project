module i2s_tx #(
    parameter int unsigned CLK_HZ = 100_000_000,
    parameter int unsigned SAMPLE_HZ = 48_000, 
    parameter int unsigned SAMPLE_W = 16,
    parameter int unsigned CHNL_CNT = 2
)(
    input logic clk_i,
    input logic rst_ni,
    input logic enable_i, 

    //Sample steam input (from audio_dma)
    input logic [SAMPLE_W-1:0] sample_i,
    input logic sample_valid_i,
    output logic sample_ready_o,

    //I2S output 
    output logic i2s_sdata_o,
    output logic i2s_bclk_o,
    output logic i2s_lrclk_o, 


    //Status / interrupts 
    output logic underrun_o,
    output logic irq_o
);

localparam int unsigned BCLK_HZ = SAMPLE_HZ * CHNL_CNT * SAMPLE_W;
localparam int unsigned LRCLK_HZ = SAMPLE_HZ;
localparam int unsigned BCLK_TOGGLE = 2 * BCLK_HZ; 
localparam int unsigned DIV = CLK_HZ / (2 * BCLK_HZ);

//clock generation and timing
logic bclk_q; 
logic lrclk_q;
logic [8:0] div_cnt_q; 
logic bclk_rise;
logic bclk_fall;
logic bclk_fall_q; 
logic [3:0] bit_idx_q; 
logic channel_q; 

//sample bufferinf (valid/ready)
logic [SAMPLE_W-1:0] samp_buf_q; 
logic have_buf_q; 

//shift engine 
logic [SAMPLE_W-1:0] shreg_q;
logic sdata_q;

//staus / interrupts
logic underrun_q;
logic irq_q; 

//state machine logic 
typedef enum logic [2:0] { 
    IDLE,
    LOAD,
    SHIFT,
    ERROR
} state_e;

state_e state_q, state_d; 
//state variable reset and initalization 
always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        state_q <= IDLE;
    end else begin
        state_q <= state_d; 
    end
end

always_comb begin
    state_d = state_q;
    case (state_q)
        IDLE: begin 
            if (enable_i) begin

                state_d = LOAD; 
            end
        end 
        LOAD: begin
            if (bclk_fall) begin
                state_d = SHIFT;
            end 
        end
        SHIFT: begin
            if (bclk_fall && (bit_idx_q == SAMPLE_W - 1)) begin
                state_d = LOAD; 
            end
        end
        ERROR: begin
            state_d = IDLE; 
        end 
        default: state_d = IDLE;  
    endcase 
end

assign sample_ready_o = enable_i && !have_buf_q;

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        channel_q <= 0; 
        have_buf_q <= 0;
        samp_buf_q <= 0;
        bit_idx_q <= 0;
        underrun_q <= 0;
        irq_q <= 0;
        lrclk_q <= 0;
        shreg_q <= 0;
        sdata_q <= 0; 
    end else begin

         if (sample_valid_i && sample_ready_o) begin
            samp_buf_q <= sample_i;
            have_buf_q <= 1'b1;
        end

        if (bclk_fall) begin
            case (state_q)
                LOAD: begin
                    bit_idx_q <= 0; 
                    if (have_buf_q) begin
                        shreg_q <= samp_buf_q; 
                        have_buf_q <= 0;
                    end else begin
                        shreg_q <= 0;
                        underrun_q <= 1;
                        irq_q <= 1; 
                    end
                    lrclk_q <= channel_q; 
                    sdata_q <= 0;

                end
                SHIFT: begin
                   // if (bclk_fall) begin
                        if (bit_idx_q == SAMPLE_W-1) begin
                            bit_idx_q <= 0; //reset to zero when the max value it should hold is reach ...
                            channel_q <= ~channel_q; //switch channels when the word is complete 
                        end else begin
                            bit_idx_q <= bit_idx_q + 1; //... keep climbing till it reaches max value 
                        end
                    //end 
                    sdata_q <= shreg_q[SAMPLE_W-1];
                    shreg_q <= {shreg_q[SAMPLE_W-2:0], 1'b0};
                end 
            endcase
        end
    end 
end

//clock stuff
always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        bclk_q <= 0;
        bclk_fall_q <= 0;
        div_cnt_q <= 0;
    end else begin
        if (div_cnt_q == DIV-1) begin
            bclk_fall_q <= bclk_q; 
            bclk_q <= ~bclk_q; 
            div_cnt_q <= 0;
        end else begin
            div_cnt_q <= div_cnt_q + 1;
            bclk_fall_q <= 0;
        end  
    end
end 

assign bclk_fall = bclk_fall_q;
assign i2s_lrclk_o = lrclk_q;
assign i2s_bclk_o = bclk_q; 
assign i2s_sdata_o = sdata_q; 
assign underrun_o = underrun_q;
assign irq_o = irq_q;

endmodule