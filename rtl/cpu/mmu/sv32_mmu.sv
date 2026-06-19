// -----------------------------------------------------------------------------
// sv32_mmu.sv
// Sv32 Memory Management Unit (MMU)
// One-pager implementation skeleton
// -----------------------------------------------------------------------------
//
// Module performs Sv32 virtual to physical translation using an external
// PTW (Page Table Walker) and a TLB. This file is an early state template
// based on the one pager specification.
//
// -----------------------------------------------------------------------------

module sv32_mmu #(
    parameter int TLB_ENTRIES = 16,
    parameter int PAGE_SIZE = 4096,
    parameter int PTW_TIMEOUT_CYCLES = 256,
    parameter int ADDR_WIDTH = 32,
    parameter int PADDR_WIDTH = 34
)(
    input logic clk_i,
    input logic rst_ni,

    // Translation request from CPU
    input logic [ADDR_WIDTH-1:0] va_i,
    input logic valid_i,
    output logic ready_o,

    // Translated physical address to CPU
    output logic [PADDR_WIDTH-1:0]   pa_o,

    // PTW interface (external module)
    output logic ptw_req_valid_o,
    output logic [ADDR_WIDTH-1:0] ptw_req_addr_o,
    input logic ptw_rsp_valid_i,
    input logic [63:0] ptw_rsp_data_i,

    // CSR / privilege inputs
    input logic [31:0] satp_i,
    input logic [1:0] priv_i
);

    // Internal Types & Signals
    // -------------------------

    typedef enum logic [1:0] {
        IDLE,
        TLB_LOOKUP,
        PTW_WAIT,
        OUTPUT_RESULT
    } mmu_state_e;

    mmu_state_e state_d, state_q;

    logic tlb_hit;
    logic [PADDR_WIDTH-1:0] tlb_pa;

    logic miss_detected;

    // TLB Instance (placeholder)
    // --------------------------

    // NOTE:
    // Replace this with the actual TLB module
    // from rtl/cpu/mmu/tlb.sv and hook up ports accordingly.

    // tlb #(.ENTRIES(TLB_ENTRIES)) u_tlb (
    //     .clk_i(clk_i),
    //     .rst_ni(rst_ni),
    //     .lookup_va_i(va_i),
    //     .lookup_valid_i(valid_i),
    //     .lookup_ready_o(),
    //     .lookup_hit_o(tlb_hit),
    //     .lookup_pa_o(tlb_pa),
    //     .miss_o(miss_detected),
    //     .insert_valid_i(),
    //     .insert_vpn_i(),
    //     .insert_ppn_i(),
    //     .insert_perm_i(),
    //     .flush_i(1'b0)
    // );

    // PTW Interface Logic (template)
    // ------------------------------

    // For assignment submission:
    // MMU will assert ptw_req_valid_o on a miss and wait for ptw_rsp_valid_i.
    //
    // Real logic will be added later by your PTW / MMU teammates.

    assign ptw_req_valid_o = (state_q == PTW_WAIT);
    assign ptw_req_addr_o = va_i; // placeholder: real implementation extracts VPN

    // State Machine
    // -------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q <= IDLE;
        end else begin
            state_q <= state_d;
        end
    end

    always_comb begin
        state_d  = state_q;
        ready_o  = 1'b0;
        pa_o = '0;

        case (state_q)

            IDLE: begin
                if (valid_i)
                    state_d = TLB_LOOKUP;
            end

            TLB_LOOKUP: begin
                if (tlb_hit) begin
                    pa_o = tlb_pa;
                    ready_o = 1'b1;
                    state_d = OUTPUT_RESULT;
                end else begin
                    state_d = PTW_WAIT; // TLB miss -> request PTW
                end
            end

            PTW_WAIT: begin
                if (ptw_rsp_valid_i) begin
                    // Placeholder: real code inserts into TLB + checks permissions
                    ready_o = 1'b1;
                    state_d = OUTPUT_RESULT;
                end
            end

            OUTPUT_RESULT: begin
                // End of translation, ready for next request
                state_d = IDLE;
            end
        endcase
    end
endmodule
