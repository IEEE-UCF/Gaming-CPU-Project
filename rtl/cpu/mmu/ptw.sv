module ptw #(
    // main parameters for widths and timeouts
    parameter int TIMEOUT_CYCLES = 256,
    parameter int ADDR_WIDTH     = 32,
    parameter int DATA_WIDTH     = 64,
    parameter int PPN_WIDTH      = 32
)(
    input  logic                  clk_i,
    input  logic                  rst_ni,

    // flush from sfence.vma to clear any in-flight walk
    input  logic                  flush_i,

    // walk request from mmu
    input  logic                  walk_req_valid_i,
    output logic                  walk_req_ready_o,
    input  logic [ADDR_WIDTH-1:0] walk_req_addr_i,   // l1 table base address
    input  logic [19:0]           walk_req_vpn_i,    // full vpn {vpn1, vpn0}

    // walk response back to mmu
    output logic                  walk_rsp_valid_o,
    output logic [DATA_WIDTH-1:0] walk_rsp_pte_o,
    output logic                  walk_rsp_error_o,

    // axi-lite read interface for pte fetches
    output logic                  axi_ar_valid_o,
    output logic [ADDR_WIDTH-1:0] axi_ar_addr_o,
    input  logic                  axi_ar_ready_i,
    input  logic                  axi_r_valid_i,
    input  logic [DATA_WIDTH-1:0] axi_r_data_i,
    input  logic [1:0]            axi_r_resp_i
);

    // two-level walk fsm
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

    // timeout handling
    logic [31:0] timeout_cnt_q, timeout_cnt_d;
    logic        timeout_expired;

    // computed pte addresses
    logic [ADDR_WIDTH-1:0] l1_addr;
    logic [ADDR_WIDTH-1:0] l2_base_addr;
    logic [ADDR_WIDTH-1:0] l2_addr;

    // alignment helpers based on pte size
    localparam int PTE_SIZE_BYTES = DATA_WIDTH / 8;
    localparam int PTE_ALIGN_BITS = (PTE_SIZE_BYTES > 1) ? $clog2(PTE_SIZE_BYTES) : 1;

    logic l1_addr_misaligned;
    logic l2_addr_misaligned;

    // pte helper functions
    // basic sv32 legality checks
    function automatic logic pte_invalid(input logic [DATA_WIDTH-1:0] pte);
        logic v, r, w;
        begin
            v = pte[0];
            r = pte[1];
            w = pte[2];

            // invalid if v = 0, w = 1 while r = 0, or upper bits are set
            pte_invalid = (!v) ||
                          (!r && w) ||
                          ((DATA_WIDTH > 32) && (|pte[DATA_WIDTH-1:32]));
        end
    endfunction

    // pte points to next level
    function automatic logic pte_is_pointer(input logic [DATA_WIDTH-1:0] pte);
        logic v, r, x;
        begin
            v = pte[0];
            r = pte[1];
            x = pte[3];
            pte_is_pointer = v && !r && !x;
        end
    endfunction

    // pte is a valid leaf mapping
    function automatic logic pte_is_leaf(input logic [DATA_WIDTH-1:0] pte);
        logic v, r, x;
        begin
            v = pte[0];
            r = pte[1];
            x = pte[3];
            pte_is_leaf = v && (r || x);
        end
    endfunction

    // check the A bit (ptw doesn't set A/D, so treat A=0 as fault)
    function automatic logic pte_has_ad_fault(input logic [DATA_WIDTH-1:0] pte);
        begin
            pte_has_ad_fault = !pte[6];
        end
    endfunction

    // superpage alignment check for l1 leaf
    function automatic logic pte_superpage_misaligned(input logic [DATA_WIDTH-1:0] pte);
        logic [PPN_WIDTH-1:0] ppn;
        begin
            ppn = pte[PPN_WIDTH-1:10];
            pte_superpage_misaligned = |ppn[9:0];
        end
    endfunction

    // detect axi read access faults
    function automatic logic axi_access_fault(input logic [1:0] resp);
        begin
            axi_access_fault = (resp != 2'b00);
        end
    endfunction

    // vpn splits + address generation
    assign vpn_l1 = vpn_q[19:10];
    assign vpn_l2 = vpn_q[9:0];

    assign timeout_expired = (timeout_cnt_q >= TIMEOUT_CYCLES);

    // l1 pte address
    assign l1_addr =
        base_addr_q + {{(ADDR_WIDTH-($bits(vpn_l1)+PTE_ALIGN_BITS)){1'b0}},
                       vpn_l1, {PTE_ALIGN_BITS{1'b0}}};

    // l2 table base address (from l1 ppn)
    assign l2_base_addr = {pte_l1_q[PPN_WIDTH-1:10], 12'b0};

    // l2 pte address
    assign l2_addr =
        l2_base_addr + {{(ADDR_WIDTH-($bits(vpn_l2)+PTE_ALIGN_BITS)){1'b0}},
                        vpn_l2, {PTE_ALIGN_BITS{1'b0}}};

    assign l1_addr_misaligned = |l1_addr[PTE_ALIGN_BITS-1:0];
    assign l2_addr_misaligned = |l2_addr[PTE_ALIGN_BITS-1:0];

    // fsm + outputs
    always_comb begin
        state_d          = state_q;

        walk_req_ready_o = (state_q == IDLE);

        walk_rsp_valid_o = 1'b0;
        walk_rsp_pte_o   = '0;
        walk_rsp_error_o = 1'b0;

        axi_ar_valid_o   = 1'b0;
        axi_ar_addr_o    = '0;

        timeout_cnt_d    = timeout_cnt_q;

        // timeout increases only while waiting for mem
        if (state_q == WAIT_L1 || state_q == WAIT_L2) begin
            if (!timeout_expired)
                timeout_cnt_d = timeout_cnt_q + 1;
        end else begin
            timeout_cnt_d = '0;
        end

        unique case (state_q)

            IDLE: begin
                // accept request only when ready
                if (walk_req_valid_i && walk_req_ready_o)
                    state_d = SEND_L1;
            end

            SEND_L1: begin
                // l1 address must be aligned
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
                    if (axi_access_fault(axi_r_resp_i))
                        state_d = ERROR;
                    else if (pte_invalid(axi_r_data_i))
                        state_d = ERROR;
                    else if (pte_is_leaf(axi_r_data_i)) begin
                        // superpage case
                        if (pte_superpage_misaligned(axi_r_data_i) ||
                            pte_has_ad_fault(axi_r_data_i))
                            state_d = ERROR;
                        else
                            state_d = DONE;
                    end else if (pte_is_pointer(axi_r_data_i)) begin
                        // go to l2
                        state_d = SEND_L2;
                    end else begin
                        state_d = ERROR;
                    end
                end else if (timeout_expired) begin
                    state_d = ERROR;
                end
            end

            SEND_L2: begin
                // l2 address must be aligned
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
                    if (axi_access_fault(axi_r_resp_i))
                        state_d = ERROR;
                    else if (pte_invalid(axi_r_data_i))
                        state_d = ERROR;
                    else if (pte_is_leaf(axi_r_data_i)) begin
                        if (pte_has_ad_fault(axi_r_data_i))
                            state_d = ERROR;
                        else
                            state_d = DONE;
                    end else begin
                        state_d = ERROR;
                    end
                end else if (timeout_expired) begin
                    state_d = ERROR;
                end
            end

            DONE: begin
                walk_rsp_valid_o = 1'b1;
                walk_rsp_pte_o   = (pte_l2_q != '0) ? pte_l2_q : pte_l1_q;
                walk_rsp_error_o = 1'b0;
                state_d          = IDLE;
            end

            ERROR: begin
                walk_rsp_valid_o = 1'b1;
                walk_rsp_pte_o   = '0;
                walk_rsp_error_o = 1'b1;
                state_d          = IDLE;
            end
        endcase

        // flush overrides the walk immediately
        if (flush_i) begin
            state_d          = IDLE;
            walk_rsp_valid_o = 1'b0;
            walk_rsp_error_o = 1'b0;
            axi_ar_valid_o   = 1'b0;
        end
    end

    // sequential pipeline regs
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q       <= IDLE;
            base_addr_q   <= '0;
            vpn_q         <= '0;
            pte_l1_q      <= '0;
            pte_l2_q      <= '0;
            timeout_cnt_q <= '0;
        end else if (flush_i) begin
            // reset everything on flush
            state_q       <= IDLE;
            base_addr_q   <= '0;
            vpn_q         <= '0;
            pte_l1_q      <= '0;
            pte_l2_q      <= '0;
            timeout_cnt_q <= '0;
        end else begin
            state_q       <= state_d;
            timeout_cnt_q <= timeout_cnt_d;

            // latch new walk request
            if (state_q == IDLE && walk_req_valid_i && walk_req_ready_o) begin
                base_addr_q <= walk_req_addr_i;
                vpn_q       <= walk_req_vpn_i;
                pte_l1_q    <= '0;
                pte_l2_q    <= '0;
            end

            // latch ptes on valid read
            if (state_q == WAIT_L1 && axi_r_valid_i && !axi_access_fault(axi_r_resp_i))
                pte_l1_q <= axi_r_data_i;

            if (state_q == WAIT_L2 && axi_r_valid_i && !axi_access_fault(axi_r_resp_i))
                pte_l2_q <= axi_r_data_i;
        end
    end

endmodule