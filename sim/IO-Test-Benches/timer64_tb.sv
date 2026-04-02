`timescale 1ns / 1ps

module timer64_tb;
    // Signals
    logic        clk;
    logic        rst_n;
    logic [31:0] CPU_bus;
    logic        setTimer;
    wire         interrupt_irq;

    
    timer64 uut (
        .clk(clk),
        .rst_n(rst_n),
        .CPU_bus(CPU_bus),
        .setTimer(setTimer),
        .interrupt_irq(interrupt_irq)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    
    initial begin
        rst_n = 1; 
        CPU_bus = 'b0;
        setTimer = 1'b0; 
        #10; 
        setTimer = 1'b1; 
        CPU_bus = 32'h0000_0000; 
        #10; 
        setTimer = 1'b0; 
        #10;
        CPU_bus = 32'h0000_0002;
          #200; 
      	//Set the timer to a different value
      	setTimer = 1'b0; 
        #10; 
        setTimer = 1'b1; 
        CPU_bus = 32'h0000_0000; 
        #10; 
        setTimer = 1'b0; 
        #10;
        CPU_bus = 32'h0000_0004;
        #200; 
          $finish;
    end

    
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, testbench);
    end
endmodule