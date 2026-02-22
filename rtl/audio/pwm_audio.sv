module pwm_audio #(
  parameter int unsigned SAMPLE_W       = 16,
  parameter int unsigned PWM_CNT_W      = 3,
  parameter int unsigned CLK_HZ         = 100_000_000,
  parameter int unsigned PWM_CARRIER_HZ = 25_600,
  parameter int unsigned SAMPLE_HZ      = 11_025
) (
  input  logic                clk_i,
  input  logic                rst_ni,

  input  logic                enable_i,

  // Sample stream in (valid/ready)
  input  logic [SAMPLE_W-1:0] sample_i,
  input  logic                sample_valid_i,
  output logic                sample_ready_o,

  // Output + status
  output logic                pwm_o,
  output logic                underrun_o,
  output logic                irq_o
);

  localparam int unsigned PWM_STEPS   = 1 << PWM_CNT_W;                  // 2^PWM_CNT_W
  localparam int unsigned PWM_STEP_HZ = PWM_CARRIER_HZ * PWM_STEPS;      // step clock
  localparam int unsigned PWM_DIV     = CLK_HZ / PWM_STEP_HZ;            // cycles per step
  localparam int unsigned SAMPLE_DIV  = CLK_HZ / SAMPLE_HZ;              // cycles per sample

  logic [$clog2(PWM_DIV)-1:0]    pwm_div_cnt_q;
  logic [PWM_CNT_W-1:0]          pwm_step_q;        // 0..PWM_STEPS-1

  logic [$clog2(SAMPLE_DIV)-1:0] sample_div_cnt_q;
  logic                         sample_tick;       // 1-cycle strobe

  // Sample buffer / duty
  logic [PWM_CNT_W-1:0]          duty_q;           // duty in PWM steps

  // Status
  logic                          underrun_q;       // sticky
  logic                          irq_q;            // pulse or sticky (define)

  // Divider tick generation
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
         sample_div_cnt_q <= 0;
        sample_tick <= 0; 
    end
    else if (enable_i) begin
        if (sample_div_cnt_q == SAMPLE_DIV-1) begin
            sample_div_cnt_q <= 0;
            sample_tick <= 1;
        end else begin
            sample_div_cnt_q <= sample_div_cnt_q + 1;
            sample_tick <= 0;
        end
    end else begin
        sample_div_cnt_q <= 0;
        sample_tick <= 0;
    end 
  end

  //  PWM step counter + output compare
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        pwm_step_q <= 0;
        pwm_div_cnt_q <= 0;
        pwm_o <= 0;
    end else if (!enable_i) begin
        pwm_div_cnt_q <= 0;
        pwm_step_q <= 0;
        pwm_o <= 0;
    end else begin
        if (pwm_div_cnt_q == PWM_DIV - 1) begin
            pwm_div_cnt_q <= 0;
             if (pwm_step_q == PWM_STEPS-1) begin
                pwm_step_q <= '0;
            end else begin
                pwm_step_q <= pwm_step_q + 1'b1;
            end
        end else begin
            pwm_div_cnt_q <= pwm_div_cnt_q + 1'b1;
        end
        pwm_o <= (pwm_step_q < duty_q); 
      end
  end


// Sample stream handshake + buffering
assign sample_ready_o = enable_i && sample_tick;

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    underrun_q <= 1'b0;
    irq_q      <= 1'b0;
  end else if (!enable_i) begin
    // clear-on-disable 
    underrun_q <= 1'b0;
    irq_q      <= 1'b0;
  end else begin
    irq_q <= 1'b0;
    if (sample_tick && !sample_valid_i) begin
      underrun_q <= 1'b1;   // sticky flag
      irq_q      <= 1'b1;   // pulse this cycle
    end
  end
end

  // Sample -> duty mapping (unsigned)
always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        duty_q <= 0;
    end else if (!enable_i) begin
        duty_q <= 0;
    end else if (sample_valid_i && sample_ready_o) begin
        duty_q <= sample_i[SAMPLE_W-1 -:PWM_CNT_W];
    end 
end

assign underrun_o = underrun_q;
assign irq_o      = irq_q;

endmodule