module ptw #(
  parameter int unsigned TIMEOUT_CYCLES = 256,
  parameter int unsigned ADDR_WIDTH     = 32,
  parameter int unsigned DATA_WIDTH     = 32,  // Sv32 PTE width
  parameter int unsigned PPN_WIDTH      = 22   // Sv32 PTE stores 22-bit PPN in bits [31:10]
) (
  input  logic                  clk_i,
  input  logic                  rst_ni,

  // flush from sfence.vma to clear any in-flight walk
  input  logic                  flush_i,

  // walk request from mmu
  input  logic                  walk_req_valid_i,
  output logic                  walk_req_ready_o,
  input  logic [ADDR_WIDTH-1:0] walk_req_addr_i,   // L1 table base address
  input  logic [19:0]           walk_req_vpn_i,    // full VPN {vpn1,vpn0}

  // walk response back to mmu
  output logic                  walk_rsp_valid_o,
  output logic [DATA_WIDTH-1:0] walk_rsp_pte_o,    // 32-bit leaf PTE
  output logic                  walk_rsp_error_o,  // fault/timeout

  // axi-lite read interface for pte fetches
  output logic                  axi_ar_valid_o,
  output logic [ADDR_WIDTH-1:0] axi_ar_addr_o,
  input  logic                  axi_ar_ready_i,
  input  logic                  axi_r_valid_i,
  input  logic [DATA_WIDTH-1:0] axi_r_data_i,
  input  logic [1:0]            axi_r_resp_i
);

  typedef enum logic [2:0] {
    IDLE,
    SEND_L1,
    WAIT_L1,
    SEND_L2,
    WAIT_L2,
    DONE,
    ERROR
  } ptw_state_e;

  ptw_state_e state_q, state_d;

  // latched request info
  logic [ADDR_WIDTH-1:0] base_addr_q;
  logic [19:0]           vpn_q;

  // split vpn for l1 / l2 table indexing
  logic [9:0] vpn_l1;
  logic [9:0] vpn_l2;

  // pte registers
  logic [DATA_WIDTH-1:0] pte_l1_q;
  logic [DATA_WIDTH-1:0] pte_l2_q;

  // track whether final leaf came from L2
  logic used_l2_q, used_l2_d;

  // timeout handling
  logic [31:0] timeout_cnt_q, timeout_cnt_d;
  logic        timeout_expired;

  // computed pte addresses
  logic [ADDR_WIDTH-1:0] l1_addr;
  logic [ADDR_WIDTH-1:0] l2_base_addr;
  logic [ADDR_WIDTH-1:0] l2_addr;

  // alignment helpers based on pte size
  localparam int unsigned PTE_SIZE_BYTES = (DATA_WIDTH / 8); // 4 for Sv32
  localparam int unsigned PTE_ALIGN_BITS = (PTE_SIZE_BYTES > 1) ? $clog2(PTE_SIZE_BYTES) : 1;

  logic l1_addr_misaligned;
  logic l2_addr_misaligned;

  // combinational PTE / AXI decode signals
  logic axi_pte_invalid;
  logic axi_pte_is_pointer;
  logic axi_pte_is_leaf;
  logic axi_pte_has_ad_fault;
  logic axi_pte_superpage_misaligned;
  logic axi_resp_access_fault;

  // vpn splits
  assign vpn_l1 = vpn_q[19:10];
  assign vpn_l2 = vpn_q[9:0];

  assign timeout_expired = (timeout_cnt_q >= TIMEOUT_CYCLES);

  // invalid if V == 0, or if R == 0 and W == 1
  assign axi_pte_invalid = !axi_r_data_i[0] || (!axi_r_data_i[1] && axi_r_data_i[2]);

  // pointer if valid and both R/X are clear
  assign axi_pte_is_pointer = axi_r_data_i[0] && !axi_r_data_i[1] && !axi_r_data_i[3];

  // leaf if valid and either R or X is set
  assign axi_pte_is_leaf = axi_r_data_i[0] && (axi_r_data_i[1] || axi_r_data_i[3]);

  // PTW does not set A/D; treat A==0 as fault
  assign axi_pte_has_ad_fault = !axi_r_data_i[6];

  // For an L1 superpage leaf, lower 10 bits of the PPN must be zero.
  // Full Sv32 PPN field is bits [31:10], so lower 10 PPN bits are PTE[19:10].
  assign axi_pte_superpage_misaligned = |axi_r_data_i[19:10];

  // AXI read access fault
  assign axi_resp_access_fault = (axi_r_resp_i != 2'b00);

  // l1 pte address: base_addr_q + (vpn_l1 * PTE_SIZE_BYTES)
  assign l1_addr = base_addr_q + (ADDR_WIDTH'(vpn_l1) << PTE_ALIGN_BITS);

  // l2 table base address from full 22-bit Sv32 PPN field.
  // This produces a 34-bit physical base internally, but PTW address port is ADDR_WIDTH wide.
  // Truncate explicitly to avoid implicit-width warnings.
  assign l2_base_addr = ADDR_WIDTH'({pte_l1_q[31:10], 12'b0});

  // l2 pte address
  assign l2_addr = l2_base_addr + (ADDR_WIDTH'(vpn_l2) << PTE_ALIGN_BITS);

  assign l1_addr_misaligned = |l1_addr[PTE_ALIGN_BITS-1:0];
  assign l2_addr_misaligned = |l2_addr[PTE_ALIGN_BITS-1:0];

  // FSM + outputs
  always_comb begin
    state_d          = state_q;

    walk_req_ready_o = (state_q == IDLE);

    walk_rsp_valid_o = 1'b0;
    walk_rsp_pte_o   = '0;
    walk_rsp_error_o = 1'b0;

    axi_ar_valid_o   = 1'b0;
    axi_ar_addr_o    = '0;

    timeout_cnt_d    = timeout_cnt_q;
    used_l2_d        = used_l2_q;

    if (state_q == WAIT_L1 || state_q == WAIT_L2) begin
      if (!timeout_expired)
        timeout_cnt_d = timeout_cnt_q + 1;
    end else begin
      timeout_cnt_d = '0;
    end

    unique case (state_q)
      IDLE: begin
        if (walk_req_valid_i && walk_req_ready_o) begin
          used_l2_d = 1'b0;
          state_d   = SEND_L1;
        end
      end

      SEND_L1: begin
        if (l1_addr_misaligned) begin
          state_d = ERROR;
        end else begin
          axi_ar_valid_o = 1'b1;
          axi_ar_addr_o  = l1_addr;
          if (axi_ar_ready_i)
            state_d = WAIT_L1;
        end
      end

      WAIT_L1: begin
        if (axi_r_valid_i) begin
          if (axi_resp_access_fault)
            state_d = ERROR;
          else if (axi_pte_invalid)
            state_d = ERROR;
          else if (axi_pte_is_leaf) begin
            if (axi_pte_superpage_misaligned || axi_pte_has_ad_fault)
              state_d = ERROR;
            else begin
              used_l2_d = 1'b0;
              state_d   = DONE;
            end
          end else if (axi_pte_is_pointer) begin
            state_d = SEND_L2;
          end else begin
            state_d = ERROR;
          end
        end else if (timeout_expired) begin
          state_d = ERROR;
        end
      end

      SEND_L2: begin
        if (l2_addr_misaligned) begin
          state_d = ERROR;
        end else begin
          axi_ar_valid_o = 1'b1;
          axi_ar_addr_o  = l2_addr;
          if (axi_ar_ready_i)
            state_d = WAIT_L2;
        end
      end

      WAIT_L2: begin
        if (axi_r_valid_i) begin
          if (axi_resp_access_fault)
            state_d = ERROR;
          else if (axi_pte_invalid)
            state_d = ERROR;
          else if (axi_pte_is_leaf) begin
            if (axi_pte_has_ad_fault)
              state_d = ERROR;
            else begin
              used_l2_d = 1'b1;
              state_d   = DONE;
            end
          end else begin
            state_d = ERROR;
          end
        end else if (timeout_expired) begin
          state_d = ERROR;
        end
      end

      DONE: begin
        walk_rsp_valid_o = 1'b1;
        walk_rsp_pte_o   = used_l2_q ? pte_l2_q : pte_l1_q;
        walk_rsp_error_o = 1'b0;
        state_d          = IDLE;
      end

      ERROR: begin
        walk_rsp_valid_o = 1'b1;
        walk_rsp_pte_o   = '0;
        walk_rsp_error_o = 1'b1;
        state_d          = IDLE;
      end

      default: begin
        state_d = IDLE;
      end
    endcase

    if (flush_i) begin
      state_d          = IDLE;
      walk_rsp_valid_o = 1'b0;
      walk_rsp_error_o = 1'b0;
      axi_ar_valid_o   = 1'b0;
      used_l2_d        = 1'b0;
      timeout_cnt_d    = '0;
    end
  end

  // sequential state
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q       <= IDLE;
      base_addr_q   <= '0;
      vpn_q         <= '0;
      pte_l1_q      <= '0;
      pte_l2_q      <= '0;
      used_l2_q     <= 1'b0;
      timeout_cnt_q <= '0;
    end else if (flush_i) begin
      state_q       <= IDLE;
      base_addr_q   <= '0;
      vpn_q         <= '0;
      pte_l1_q      <= '0;
      pte_l2_q      <= '0;
      used_l2_q     <= 1'b0;
      timeout_cnt_q <= '0;
    end else begin
      state_q       <= state_d;
      timeout_cnt_q <= timeout_cnt_d;
      used_l2_q     <= used_l2_d;

      if (state_q == IDLE && walk_req_valid_i && walk_req_ready_o) begin
        base_addr_q <= walk_req_addr_i;
        vpn_q       <= walk_req_vpn_i;
        pte_l1_q    <= '0;
        pte_l2_q    <= '0;
      end

      if (state_q == WAIT_L1 && axi_r_valid_i && !axi_resp_access_fault)
        pte_l1_q <= axi_r_data_i;

      if (state_q == WAIT_L2 && axi_r_valid_i && !axi_resp_access_fault)
        pte_l2_q <= axi_r_data_i;
    end
  end

endmodule