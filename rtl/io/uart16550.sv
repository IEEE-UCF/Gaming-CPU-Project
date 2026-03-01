/***************************TRANSMIT tx_o******************************/
// It expects clk, rst, DLM, DLL, fifo_data_out, fifo_empty,
// tx_o, and fifo_rd_en to already be declared.

// 1. Transmit State Machine
typedef enum logic [1:0] {
    IDLE      = 2'b00,  // Line idle (high)
    START_BIT = 2'b01,  // Send start bit (0)
    DATA_BITS = 2'b10,  // Send 8 data bits (LSB first)
    STOP_BIT  = 2'b11   // Send stop bit (1)
} tx_state_e;

tx_state_e tx_state_c, tx_state_n;

logic [7:0] tx_shift_reg;   
logic [2:0] tx_bit_counter; 

// 2. Baud Rate Generator (creates 1-cycle pulse per bit)
wire [15:0] baud_divisor = {DLM, DLL};
wire [31:0] rate_limit = (baud_divisor == 16'd0) ? 32'd1 : {16'd0, baud_divisor};

reg  [31:0] clk_counter;
logic       tx_bit_clk_en;  

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        clk_counter   <= 32'd0;
        tx_bit_clk_en <= 1'b0;
    end
    else begin
        if (clk_counter >= rate_limit - 1) begin
            clk_counter   <= 32'd0;
            tx_bit_clk_en <= 1'b1;  
        end
        else begin
            clk_counter   <= clk_counter + 1;
            tx_bit_clk_en <= 1'b0;
        end
    end
end

// 3. FIFO Read Controller
typedef enum logic {
    RD_IDLE = 1'b0,
    RD_WAIT = 1'b1
} rd_state_e;

rd_state_e rd_state_c;

logic [7:0] fifo_data_reg;   
logic       fifo_data_valid; 

wire fifo_data_consumed = (tx_state_c == START_BIT) && tx_bit_clk_en;

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        rd_state_c      <= RD_IDLE;
        fifo_rd_en      <= 1'b0;
        fifo_data_reg   <= 8'd0;
        fifo_data_valid <= 1'b0;
    end
    else begin
        fifo_rd_en <= 1'b0;

        case (rd_state_c)
            RD_IDLE: begin
                if ((tx_state_c == IDLE) && (!fifo_empty) && (!fifo_data_valid)) begin
                    fifo_rd_en <= 1'b1;
                    rd_state_c <= RD_WAIT;
                end

                if (fifo_data_consumed)
                    fifo_data_valid <= 1'b0;
            end

            RD_WAIT: begin
                fifo_data_reg   <= fifo_data_out;
                fifo_data_valid <= 1'b1;
                rd_state_c      <= RD_IDLE;
            end
        endcase

        if (fifo_data_consumed)
            fifo_data_valid <= 1'b0;
    end
end

// 4. State + Shift Logic
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        tx_state_c     <= IDLE;
        tx_shift_reg   <= 8'b0;
        tx_bit_counter <= 3'd0;
    end
    else if (tx_bit_clk_en) begin
        tx_state_c <= tx_state_n;

        case (tx_state_c)
            IDLE: begin
                tx_bit_counter <= 3'd0;
            end

            START_BIT: begin
                tx_shift_reg   <= fifo_data_reg;
                tx_bit_counter <= 3'd0;
            end

            DATA_BITS: begin
                tx_shift_reg   <= {1'b0, tx_shift_reg[7:1]};
                tx_bit_counter <= tx_bit_counter + 1;
            end

            STOP_BIT: begin
                tx_bit_counter <= 3'd0;
            end
        endcase
    end
end

// 5. Next-State Logic
always_comb begin
    tx_state_n = tx_state_c;

    if (tx_bit_clk_en) begin
        case (tx_state_c)
            IDLE:
                if (fifo_data_valid)
                    tx_state_n = START_BIT;

            START_BIT:
                tx_state_n = DATA_BITS;

            DATA_BITS:
                if (tx_bit_counter == 3'd7)
                    tx_state_n = STOP_BIT;

            STOP_BIT:
                tx_state_n = IDLE;

            default:
                tx_state_n = IDLE;
        endcase
    end
end

// 6. Serial Output Logic
assign tx_o =
    (tx_state_c == START_BIT) ? 1'b0 :
    (tx_state_c == DATA_BITS) ? tx_shift_reg[0] :
    1'b1;
