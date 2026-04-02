`timescale 1ns / 1ps

module timer64(
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] CPU_bus,
    input  logic        setTimer,
    output logic        interrupt_irq 
);
  
    logic [1:0]  stateReg;
    logic [63:0] timerAccumulator; 
    logic [63:0] timerConstant; 
    
    localparam IDLE=0, LOAD=1, SECOND=2, INCREMENT=3;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin 
            stateReg         <= IDLE;
            timerAccumulator <= '0;
            timerConstant    <= '0;
            interrupt_irq    <= 1'b0;
        end else if (setTimer) begin 
            stateReg <= LOAD;
        end else begin
            case (stateReg)
                IDLE: begin 
                    interrupt_irq <= 1'b0; 
                    if (setTimer) stateReg <= LOAD;
                end
                LOAD: begin
                    timerConstant[63:32] <= CPU_bus; // Store Upper 32
                    stateReg             <= SECOND; 
                end
                SECOND: begin
                    timerConstant[31:0]  <= CPU_bus; // Store Lower 32
                    stateReg             <= INCREMENT;
                    timerAccumulator     <= '0; 
                end
                INCREMENT: begin
                    if(timerAccumulator < timerConstant) begin
                      interrupt_irq <= 1'b0;
                        timerAccumulator <= timerAccumulator + 1'b1;
                    end else begin 
                        interrupt_irq    <= 1'b1; 
                          timerAccumulator <= '0;
                    end
                end
                default: stateReg <= IDLE;
            endcase
        end 
    end 
endmodule