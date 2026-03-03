`timescale 1ns/1ps

module i2c_master_tb;
    logic       clk;
    logic       rst_n;
    logic [6:0] addr;
    logic [7:0] data_in;
    logic       enable;
    logic       rw;
    logic [7:0] data_out;
    logic       ready;
    logic       error;
    // Bidirectional SDA logic
    wire        sda;
    logic       scl;
    logic       sda_drive_low; // Simular slave ACK
    
    // Drive SDA to 0 if slave wants to ACK, otherwise let it float (pull-up)
    assign sda = (sda_drive_low) ? 1'b0 : 1'bz;


    i2c_master uut (
        .clk(clk),
        .rst_n(rst_n),
        .addr(addr),
        .data_in(data_in),
        .enable(enable),
        .rw(rw),
        .data_out(data_out),
        .ready(ready),
        .error(error),
        .scl(scl),
        .sda(sda)
    );

    // Generate clock (100Mhrz)
    initial clk = 0;
    always #5 clk = ~clk;

    // Emulate Slave ACK
    initial sda_drive_low = 0;
    task automatic simulate_slave_ack();
        @(negedge scl); // Wait for address/data bits to finish
      	wait(uut.state == 4'd3);
        sda_drive_low = 1;
        @(negedge scl);
        sda_drive_low = 0;
    endtask

    // --- Main Test Stimulus ---
    initial begin
        // Initialize
        rst_n = 0;
        enable = 0;
        addr = 7'h00;
        data_in = 8'h00;
        rw = 0;

        // Reset Pulse
        #100;
        rst_n = 1;
        #50;

        $display("Starting I2C Write Transaction...");
        
        // Setup Transaction: Write 0xAC to Address 0x50
        @(posedge clk);
        addr    = 7'h50;
        data_in = 8'hAC;
        rw      = 0;      // Write mode
        enable  = 1;
        
        @(posedge clk);
        enable  = 0;      // Pulse enable

        // Monitor for completion
        wait(ready == 0);
        $display("Transaction Busy...");
        
        // Force an ACK from the slave side
        fork
            simulate_slave_ack(); 
        join_none

        wait(ready == 1);
        
        if (error) 
            $display("Test Failed: Received NACK");
        else 
            $display("Test Passed: Write Transaction Complete");

        #500;
        $finish;
    end

    // Waveform Generation
    initial begin
        $dumpfile("i2c_test.vcd");
        $dumpvars(0, i2c_master_tb);
    end

endmodule
