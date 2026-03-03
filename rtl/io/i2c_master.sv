module i2c_master (
    input  logic       clk,      // System Clock
    input  logic       rst_n,    // Active Low Reset
    input  logic [6:0] addr,     // Target Slave Address
    input  logic [7:0] data_in,  // Data to write
    input  logic       enable,   // Trigger transaction
    input  logic       rw,       // 0 for Write, 1 for Read
    
    output logic [7:0] data_out, // Data read from slave
  	output logic       ready,    // Controller is idle (Bus released for slave ACK or finished transmission
    output logic       error,    // NACK detected
    
    // I2C Physical Interface
    output logic       scl,
    inout  wire        sda
);

    // I2C States
    typedef enum logic [3:0] {
      	IDLE        = 4'd0, //Waiting to recieve or to send
        START       = 4'd1, //Signal to all other slaves a transmission is starting
        ADDRESS     = 4'd2, //Sending an address using a loop + Read/Write Bit
        ACK_ADDR    = 4'd3, //Wait for acknowledge response
        WRITE_DATA  = 4'd4, //If RW Bit 0, send bits from data in one by one
      	READ_DATA   = 4'd5, //if RW bit is 1 release bus for slave to send bits
        ACK_DATA    = 4'd6, //Data recieved acknowledge
        STOP        = 4'd7 //Return master to idle state. 
    } state_t;

    state_t state;
    
    // Internal signals
  	logic [2:0] bit_cnt; //Bit Counter
    logic sda_out;
    logic sda_en; // 1 = Drive Low, 0 = High-Z (Released)
    
    // SDA Tri-state logic
    assign sda = (sda_en == 0) ? 1'bz : sda_out;
    logic sda_in;
    assign sda_in = sda;

    
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin //If reset, set to IDLE State
            state   <= IDLE;
            ready   <= 1'b1;
            sda_en  <= 0;
            sda_out <= 1;
            bit_cnt <= 0;
            error   <= 0;
        end else begin
          case (state) 
                IDLE: begin //If in Idle state
                    ready <= 1'b1;
                  if (enable) begin //Was enable activated? Go into start
                        state <= START;
                        ready <= 1'b0;
                    end
                end

                START: begin //If Start go into Address mode
                    sda_en  <= 1;
                    sda_out <= 0; // Pull SDA low while SCL is high
                    bit_cnt <= 7;
                    state   <= ADDRESS;
                end

                ADDRESS: begin
                    // Shift out 7-bit address + RW bit, will be stuck in this if statement until done
                    if (bit_cnt > 0) begin
                        sda_out <= addr[bit_cnt-1];
                        bit_cnt <= bit_cnt - 1;
                    end else begin //move to acknowledge address 
                        sda_out <= rw;
                        state   <= ACK_ADDR;
                    end
                end

                ACK_ADDR: begin
                    sda_en <= 0; // Release SDA to listen for ACK
                    if (sda_in == 0) begin // Slave pulled SDA low
                        state <= (rw) ? READ_DATA : WRITE_DATA;
                        bit_cnt <= 7;
                    end else begin
                        error <= 1;
                        state <= STOP;
                    end
                end

                WRITE_DATA: begin
                    sda_en <= 1;
                    sda_out <= data_in[bit_cnt];
                    if (bit_cnt == 0) state <= ACK_DATA;
                    else bit_cnt <= bit_cnt - 1;
                end

            	READ_DATA: begin 
                  sda_en <= 0;
                  data_out[bit_cnt] <= sda_in;
                  
                  if (bit_cnt == 0) begin
                    state <= ACK_DATA;
                  end else begin
                    bit_cnt <= bit_cnt - 1;
            		state <= READ_DATA;
            	  end
                end
            
            	ACK_DATA: begin
                  sda_en <= 1; //Take control of bus
                  sda_out <= 1'b1;  //Send NACK -> Done sending data
                  state <= STOP;
                end
            
                STOP: begin
                    sda_en  <= 1;
                    sda_out <= 0;
                    // Then release SDA while SCL is high
                    state   <= IDLE;
                end
              
                default : begin
                  	state <= IDLE;
                end
            endcase
        end
    end
endmodule