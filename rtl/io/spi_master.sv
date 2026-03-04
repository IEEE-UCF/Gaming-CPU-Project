module spi_master #(
    parameter DATA_WIDTH = 8, //System bus size
    parameter CLK_DIV    = 4    //System Clock Parameter
)
  (
    input  logic                   clk,
    input  logic                   rst_n,
    
    // Device -> SPI
    input  logic [DATA_WIDTH-1:0]  tx_data,
    input  logic                   start,
    output logic [DATA_WIDTH-1:0]  rx_data,
    output logic                   busy,
    output logic                   done,

    // SPI Interface
    output logic                   sclk,
    output logic                   mosi,
    input  logic                   miso,
    output logic                   cs_n
);

    // State machine states. 
  typedef enum logic [1:0] {IDLE,  //No data being transmitted
                              TRANSFER,  //Transfer data
                              FINISH //Finished transmitting data, return to idle
    } state_t;
    state_t state;

    logic [DATA_WIDTH-1:0] shift_reg;
    logic [$clog2(DATA_WIDTH):0] bit_cnt;
    logic [$clog2(CLK_DIV):0]   clk_cnt;
    logic sclk_en;

    // Generate clock and chip select
    assign cs_n = (state == IDLE);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk    <= 1'b0;
            clk_cnt <= '0;
        end else if (state == TRANSFER) begin
            if (clk_cnt == CLK_DIV - 1) begin
                sclk    <= !sclk;
                clk_cnt <= '0;
            end else begin
                clk_cnt <= clk_cnt + 1'b1;
            end
        end else begin
            sclk    <= 1'b0;
            clk_cnt <= '0;
        end
    end

    // State Machine Logic
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin    //If reset signal active wipe SPI
            state     <= IDLE;
            busy      <= 1'b0;
            done      <= 1'b0;
            bit_cnt   <= '0;
            mosi      <= 1'b0;
            shift_reg <= '0;
            rx_data   <= '0;
        end else begin
            case (state)
                IDLE: begin //If in idle state, done set to 1. 
                    done <= 1'b0;
                  if (start) begin //If start has been enabled begin transmission
                        shift_reg <= tx_data;
                        busy      <= 1'b1;
                        state     <= TRANSFER;
                        bit_cnt   <= '0;
                    end
                end

                TRANSFER: begin
                    // Sample on Rising Edge, Shift on Falling Edge (Mode 0)
                    if (clk_cnt == CLK_DIV - 1) begin
                        if (sclk == 1'b0) begin // About to go High
                            mosi <= shift_reg[DATA_WIDTH-1];
                        end else begin          // About to go Low
                            shift_reg <= {shift_reg[DATA_WIDTH-2:0], miso};
                            if (bit_cnt == DATA_WIDTH - 1) begin
                                state   <= FINISH;
                            end else begin
                                bit_cnt <= bit_cnt + 1'b1;
                            end
                        end
                    end
                end

                FINISH: begin
                    busy    <= 1'b0;
                    done    <= 1'b1;
                  rx_data <= shift_reg; //send slave inputs to outputs 
                    state   <= IDLE;
                end
              
              	default: begin
                  state     <= IDLE;
            	  busy      <= 1'b0;
            	  done      <= 1'b0;
            	  bit_cnt   <= '0;
            	  mosi      <= 1'b0;
            	  shift_reg <= '0;
            	  rx_data   <= '0;
                end
            endcase
        end
    end

endmodule