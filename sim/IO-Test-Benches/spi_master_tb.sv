`timescale 1ns/1ps

module spi_master_tb;

    // Parameters
    parameter DATA_WIDTH = 8;
    parameter CLK_DIV    = 4;
    parameter CLK_PERIOD = 10; // 100MHz

    // Signals
    logic clk;
    logic rst_n;
    logic [DATA_WIDTH-1:0] tx_data;
    logic start;
    logic [DATA_WIDTH-1:0] rx_data;
    logic busy;
    logic done;

    logic sclk;
    logic mosi;
    logic miso;
    logic cs_n;

    // Instantiate the Unit Under Test (UUT)
    spi_master #(
        .DATA_WIDTH(DATA_WIDTH),
        .CLK_DIV(CLK_DIV)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(tx_data),
        .start(start),
        .rx_data(rx_data),
        .busy(busy),
        .done(done),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .cs_n(cs_n)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

 
    logic [DATA_WIDTH-1:0] slave_shift_reg;
    
    always_ff @(negedge sclk or posedge cs_n) begin
        if (cs_n) begin
            // Instead of 1'bz, drive 0 or a pull-up value (1'b1)
            miso <= 1'b0; 
            slave_shift_reg <= 8'hA5; // Reset slave data for next run
        end else begin
            // Shift out MSB on falling edge
            miso <= slave_shift_reg[DATA_WIDTH-1];
            slave_shift_reg <= {slave_shift_reg[DATA_WIDTH-2:0], mosi};
        end
    end
  
  
    // Stimulus
    initial begin
        // Initialize
        rst_n = 0;
        start = 0;
        tx_data = 8'h00;
        miso = 0;

        // Reset
        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 5);

        // Test Case 1: Send 0xC3 (11000011)
        @(posedge clk);
        tx_data = 8'hC3;
        start = 1;
        @(posedge clk);
        start = 0;

        // Wait for completion
        wait(done);
        $display("Transfer 1 Complete. Received from Slave: 0x%h", rx_data);

        #(CLK_PERIOD * 20);

        // Test Case 2: Send 0x5A (01011010)
        @(posedge clk);
        tx_data = 8'h5A;
        start = 1;
        @(posedge clk);
        start = 0;

        wait(done);
        $display("Transfer 2 Complete. Received from Slave: 0x%h", rx_data);

        #(CLK_PERIOD * 50);
        $finish;
    end

    // Monitor
    initial begin
        $monitor("Time: %t | CS_N: %b | SCLK: %b | MOSI: %b | MISO: %b | State: %s", 
                 $time, cs_n, sclk, mosi, miso, uut.state.name());
    end
  
  // Waveform Generation
    initial begin
      $dumpfile("spi_test.vcd");
      $dumpvars(0, spi_master_tb);
    end

endmodule