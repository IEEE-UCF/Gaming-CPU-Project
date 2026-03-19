module sv32_mmu #(
    parameter int TLB_ENTRIES        = 16,
    parameter int PAGE_SIZE          = 4096,
    parameter int PTW_TIMEOUT_CYCLES = 256,
    parameter int ADDR_WIDTH         = 32,
    parameter int PADDR_WIDTH        = 34
)(
    input  logic                     clk_i,
    input  logic                     rst_ni,

    input  logic [ADDR_WIDTH-1:0]    va_i,
    input  logic                     valid_i,
    output logic                     ready_o,

    input  logic [1:0]               access_i,

    output logic [PADDR_WIDTH-1:0]   pa_o,

    output logic                     fault_o,
    output logic [1:0]               fault_cause_o,
    output logic                     fault_timeout_o,
    output logic [ADDR_WIDTH-1:0]    fault_va_o,

    // Clean PTW interface
    output logic                     ptw_req_valid_o,
    input  logic                     ptw_req_ready_i,
    output logic [ADDR_WIDTH-1:0]    ptw_req_root_addr_o,
    output logic [19:0]              ptw_req_vpn_o,

    input  logic                     ptw_rsp_valid_i,
    input  logic [31:0]              ptw_rsp_pte_i,
    input  logic                     ptw_rsp_error_i,

    input  logic [31:0]              satp_i,
    input  logic [1:0]               priv_i,

    input  logic                     sum_i,
    input  logic                     mxr_i,
    input  logic                     uxn_i,

    input  logic                     sfence_vma_i
);

    localparam int OFFSET_BITS = 12;
    localparam int VPN_BITS    = ADDR_WIDTH  - OFFSET_BITS;   // 20 for Sv32
    localparam int PPN_BITS    = PADDR_WIDTH - OFFSET_BITS;   // 22 for 34-bit PA

    localparam logic [1:0] PRIV_U = 2'b00;
    localparam logic [1:0] PRIV_S = 2'b01;
    localparam logic [1:0] PRIV_M = 2'b11;

    localparam logic [1:0] ACC_LOAD  = 2'b00;
    localparam logic [1:0] ACC_STORE = 2'b01;
    localparam logic [1:0] ACC_FETCH = 2'b10;

    wire satp_mode_sv32 = satp_i[31];

    localparam int TO_W = $clog2(PTW_TIMEOUT_CYCLES + 1);
    localparam logic [TO_W-1:0] TIMEOUT_MAX = TO_W'(PTW_TIMEOUT_CYCLES);

    typedef enum logic [1:0] {
        IDLE,
        TLB_LOOKUP,
        PTW_REQ,
        PTW_WAIT
    } mmu_state_e;

    mmu_state_e state_q, state_d;

    logic [ADDR_WIDTH-1:0]  va_q;
    logic [1:0]             access_q;

    logic [PADDR_WIDTH-1:0] pa_q;
    logic                   fault_q;
    logic [1:0]             cause_q;
    logic                   timeout_q;

    logic [TO_W-1:0]        to_cnt_q, to_cnt_d;

    // TLB signals
    logic                   tlb_lookup_ready_o_w;
    logic                   tlb_lookup_hit_o_w;
    logic [PADDR_WIDTH-1:0] tlb_lookup_pa_o_w;
    logic                   tlb_miss_o_w;

    logic                   tlb_insert_valid_i_w;
    logic [VPN_BITS-1:0]    tlb_insert_vpn_i_w;
    logic [PPN_BITS-1:0]    tlb_insert_ppn_i_w;
    logic [7:0]             tlb_insert_perm_i_w;

    // PTW response decode
    logic [31:0]            pte_rsp_w;
    logic                   ptw_leaf_ok_w;
    logic                   ptw_needs_ad_w;

    // Latched request fields
    wire [VPN_BITS-1:0]     vpn_q = va_q[ADDR_WIDTH-1:OFFSET_BITS];
    wire [OFFSET_BITS-1:0]  off_q = va_q[OFFSET_BITS-1:0];

    // SATP root page table base address
    // Sv32: root PPN in SATP[21:0], page aligned
    wire [ADDR_WIDTH-1:0] satp_root_addr_w = {satp_i[19:0], 12'b0};

    tlb #(
        .ENTRIES     (TLB_ENTRIES),
        .PAGE_SIZE   (PAGE_SIZE),
        .ADDR_WIDTH  (ADDR_WIDTH),
        .PADDR_WIDTH (PADDR_WIDTH)
    ) tlb_i (
        .clk_i          (clk_i),
        .rst_ni         (rst_ni),
        .lookup_va_i    (va_q),
        .lookup_valid_i (state_q == TLB_LOOKUP),
        .lookup_ready_o (tlb_lookup_ready_o_w),
        .lookup_hit_o   (tlb_lookup_hit_o_w),
        .lookup_pa_o    (tlb_lookup_pa_o_w),
        .miss_o         (tlb_miss_o_w),
        .insert_valid_i (tlb_insert_valid_i_w),
        .insert_vpn_i   (tlb_insert_vpn_i_w),
        .insert_ppn_i   (tlb_insert_ppn_i_w),
        .insert_perm_i  (tlb_insert_perm_i_w),
        .flush_i        (sfence_vma_i)
    );

    function automatic logic [PADDR_WIDTH-1:0] make_pa(
        input logic [PPN_BITS-1:0] ppn,
        input logic [OFFSET_BITS-1:0] off_i
    );
        logic [PADDR_WIDTH-1:0] tmp;
        begin
            tmp = '0;
            tmp[PADDR_WIDTH-1:OFFSET_BITS] = ppn;
            tmp[OFFSET_BITS-1:0]           = off_i;
            make_pa = tmp;
        end
    endfunction

    function automatic logic [1:0] pf_cause(input logic [1:0] acc);
        begin
            case (acc)
                ACC_FETCH: pf_cause = 2'b00;
                ACC_LOAD:  pf_cause = 2'b01;
                default:   pf_cause = 2'b10;
            endcase
        end
    endfunction

    function automatic logic sv32_leaf_ok(
        input logic [7:0] flags,
        input logic [1:0] priv,
        input logic [1:0] acc,
        input logic       sum,
        input logic       mxr,
        input logic       uxn,
        output logic      needs_ad_fault
    );
        logic V, R, W, X, U, G, A, D;
        logic ok;
        begin
            {D, A, G, U, X, W, R, V} = flags[7:0];
            ok = 1'b1;
            needs_ad_fault = 1'b0;

            if (!V) ok = 1'b0;
            if (W && !R) ok = 1'b0;

            if (priv == PRIV_U) begin
                if (!U) ok = 1'b0;
            end
            else if (priv == PRIV_S) begin
                if (U && (acc != ACC_FETCH) && !sum) ok = 1'b0;
                if (U && (acc == ACC_FETCH) && uxn) ok = 1'b0;
            end

            if (acc == ACC_FETCH) begin
                if (!X) ok = 1'b0;
            end
            else if (acc == ACC_STORE) begin
                if (!W) ok = 1'b0;
            end
            else begin
                if (!(R || (mxr && X))) ok = 1'b0;
            end

            if (!A) begin
                ok = 1'b0;
                needs_ad_fault = 1'b1;
            end
            if ((acc == ACC_STORE) && !D) begin
                ok = 1'b0;
                needs_ad_fault = 1'b1;
            end

            sv32_leaf_ok = ok;
        end
    endfunction

    // PTW request outputs

    assign ptw_req_valid_o     = (state_q == PTW_REQ);
    assign ptw_req_root_addr_o = satp_root_addr_w;
    assign ptw_req_vpn_o       = vpn_q;

    // PTW response decode

    assign pte_rsp_w            = ptw_rsp_pte_i;
    assign ptw_leaf_ok_w        = sv32_leaf_ok(pte_rsp_w[7:0], priv_i, access_q, sum_i, mxr_i, uxn_i, ptw_needs_ad_w);
    assign tlb_insert_valid_i_w = (state_q == PTW_WAIT) && ptw_rsp_valid_i && !ptw_rsp_error_i && ptw_leaf_ok_w;
    assign tlb_insert_vpn_i_w   = vpn_q;
    assign tlb_insert_ppn_i_w   = pte_rsp_w[31:10];
    assign tlb_insert_perm_i_w  = pte_rsp_w[7:0];

    // Sequential state / result registers

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q      <= IDLE;
            va_q         <= '0;
            access_q     <= '0;
            pa_q         <= '0;
            fault_q      <= 1'b0;
            cause_q      <= 2'b00;
            timeout_q    <= 1'b0;
            to_cnt_q     <= '0;
        end
        else begin
            state_q  <= state_d;
            to_cnt_q <= to_cnt_d;

            // Latch a new request
            if (state_q == IDLE && valid_i) begin
                va_q      <= va_i;
                access_q  <= access_i;
                fault_q   <= 1'b0;
                timeout_q <= 1'b0;
                cause_q   <= pf_cause(access_i);
            end

            // TLB hit or bypass
            if (state_q == TLB_LOOKUP) begin
                if (!satp_mode_sv32 || (priv_i == PRIV_M)) begin
                    pa_q    <= {{(PADDR_WIDTH-ADDR_WIDTH){1'b0}}, va_q};
                    fault_q <= 1'b0;
                end
                else if (tlb_lookup_hit_o_w) begin
                    // Assumption: a TLB hit implies an already validated translation.
                    pa_q    <= tlb_lookup_pa_o_w;
                    fault_q <= 1'b0;
                end
            end

            // PTW response handling
            if (state_q == PTW_WAIT && ptw_rsp_valid_i) begin
                logic [31:0] pte;
                logic        ok, needs_ad;

                pte = ptw_rsp_pte_i;
                ok  = sv32_leaf_ok(pte[7:0], priv_i, access_q, sum_i, mxr_i, uxn_i, needs_ad);

                if (ptw_rsp_error_i) begin
                    pa_q      <= '0;
                    fault_q   <= 1'b1;
                    timeout_q <= 1'b0;
                end
                else if (ok) begin
                    pa_q      <= make_pa(pte[31:10], off_q);
                    fault_q   <= 1'b0;
                    timeout_q <= 1'b0;
                end
                else begin
                    pa_q      <= '0;
                    fault_q   <= 1'b1;
                    timeout_q <= 1'b0;
                end
            end

            // PTW timeout
            if (state_q == PTW_WAIT && (to_cnt_q == TIMEOUT_MAX)) begin
                pa_q      <= '0;
                fault_q   <= 1'b1;
                timeout_q <= 1'b1;
            end
        end
    end

    // Timeout counter

    always_comb begin
        to_cnt_d = to_cnt_q;

        if (state_q != PTW_WAIT) begin
            to_cnt_d = '0;
        end
        else begin
            if (to_cnt_q != TIMEOUT_MAX)
                to_cnt_d = to_cnt_q + 1'b1;
        end
    end

    // Next-state / outputs

    always_comb begin
        state_d = state_q;
        ready_o = 1'b0;

        pa_o            = pa_q;
        fault_o         = fault_q;
        fault_cause_o   = cause_q;
        fault_timeout_o = timeout_q;
        fault_va_o      = va_q;

        unique case (state_q)
            IDLE: begin
                if (valid_i)
                    state_d = TLB_LOOKUP;
            end

            TLB_LOOKUP: begin
                if (!satp_mode_sv32 || (priv_i == PRIV_M) || tlb_lookup_hit_o_w) begin
                    ready_o = 1'b1;
                    state_d = IDLE;
                end
                else begin
                    state_d = PTW_REQ;
                end
            end

            PTW_REQ: begin
                if (ptw_req_ready_i)
                    state_d = PTW_WAIT;
            end

            PTW_WAIT: begin
                if (ptw_rsp_valid_i || (to_cnt_q == TIMEOUT_MAX)) begin
                    ready_o = 1'b1;
                    state_d = IDLE;
                end
            end

            default: begin
                state_d = IDLE;
            end
        endcase
    end

endmodule