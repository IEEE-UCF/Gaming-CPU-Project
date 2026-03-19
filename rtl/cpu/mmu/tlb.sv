`timescale 1ns / 1ps



// tlb.sv Translation Lookaside Buffer
// RTL path: rtl/cpu/mmu/tlb.sv
//
// Purpose:
// - Cache virtual to physical translations for Sv32 MMU to avoid PTW walks.
// - Compare VPN tags against all entries.
// - On hit: returns physical address (PPN + page offset) in 1 cycle.
// - On miss: asserts miss_o so sv32_mmu can trigger external PTW.
// - Supports insert path (from sv32_mmu after PTW completes).
// - Supports global flush (SFENCE.VMA / SATP write).
//
// Notes:
// - Fully associative CAM-style lookup.
// - Uses true LRU with age counters.
// - Single clock domain.
// - Vivado-friendly SystemVerilog.

module tlb #(

    // Parameters (from one-pager)
    parameter int ENTRIES     = 16,    // # of cached entries
    parameter int PAGE_SIZE   = 4096,  // base page size of 4 KB
    parameter int ADDR_WIDTH  = 32,    // VA width
    parameter int PADDR_WIDTH = 34     // PA width
    // ASSOCIATIVE = FULL (implied by CAM approach in this specific design)
    // REPL_POLICY = LRU in this implementation
) (
    // Clock / Reset
    input  logic                   clk_i,
    input  logic                   rst_ni,

    // Lookup interface, our MMU pipeline
    input  logic [ADDR_WIDTH-1:0]  lookup_va_i,
    input  logic                   lookup_valid_i,
    output logic                   lookup_ready_o,

    output logic                   lookup_hit_o,
    output logic [PADDR_WIDTH-1:0] lookup_pa_o,

    // Miss indication to MMU
    output logic                   miss_o,

    // Insert interface from sv32_mmu after PTW completion
    input  logic                   insert_valid_i,
    input  logic [19:0]            insert_vpn_i,   // Sv32 VPN[19:0]
    input  logic [21:0]            insert_ppn_i,   // PPN width (22)
    input  logic [7:0]             insert_perm_i,  // R/W/X/U/S/A/D etc.

    // Flush, SFENCE.VMA / SATP write
    input  logic                   flush_i
);

    // Constants / Derived fields
    localparam int PAGE_OFFSET_BITS = 12;                     // 4 KB page -> 12-bit offset
    localparam int VPN_BITS         = 20;                     // Sv32 VPN width
    localparam int PPN_BITS         = 22;                     // Sv32 PPN width
    localparam int INDEX_BITS       = (ENTRIES <= 1) ? 1 : $clog2(ENTRIES);
    localparam int AGE_BITS         = (ENTRIES <= 2) ? 1 : $clog2(ENTRIES);

    // Storage arrays, one entry per slot
    logic [ENTRIES-1:0] valid_q;                             // valid bit
    logic [VPN_BITS-1:0] tag_vpn_q  [0:ENTRIES-1];          // tag: VPN[19:0]
    logic [PPN_BITS-1:0] data_ppn_q [0:ENTRIES-1];          // data: PPN
    logic [7:0]          perm_q     [0:ENTRIES-1];          // permissions

    // True LRU bookkeeping
    logic [AGE_BITS-1:0] age_q      [0:ENTRIES-1];

    // Lookup combinational signals
    logic [VPN_BITS-1:0]            lookup_vpn;
    logic [PAGE_OFFSET_BITS-1:0]    lookup_offset;

    logic [ENTRIES-1:0]             hit_vec;
    logic                           any_hit;
    logic [INDEX_BITS-1:0]          hit_index;
    logic                           found_hit;

    // Victim selection signals
    logic                           found_invalid;
    logic [INDEX_BITS-1:0]          invalid_index;
    logic [INDEX_BITS-1:0]          lru_index;
    logic [INDEX_BITS-1:0]          victim_index;
    logic [AGE_BITS-1:0]            max_age;

    integer idx;

    // Split incoming VA into VPN + offset
    always_comb begin
        lookup_offset = lookup_va_i[PAGE_OFFSET_BITS-1:0];
        lookup_vpn    = lookup_va_i[ADDR_WIDTH-1:PAGE_OFFSET_BITS];
    end

    // Hit detection, CAM compare
    // hit_vec[i] = valid_q[i] && (tag_vpn_q[i] == lookup_vpn)
    always_comb begin
        hit_vec = '0;
        for (int i = 0; i < ENTRIES; i++) begin
            hit_vec[i] = valid_q[i] && (tag_vpn_q[i] == lookup_vpn);
        end
    end

    // Reduce OR to get any_hit; find first hit_index
    always_comb begin
        any_hit   = |hit_vec;
        hit_index = '0;
        found_hit = 1'b0;

        for (int i = 0; i < ENTRIES; i++) begin
            if (!found_hit && hit_vec[i]) begin
                hit_index = INDEX_BITS'(i);
                found_hit = 1'b1;
            end
        end
    end

    // Lookup protocol behavior
    // Always ready unless flush is active
    always_comb begin
        lookup_ready_o = ~flush_i;
    end

    // Output formation:
    // - On hit: PA = {PPN, offset}
    // - On miss: lookup_hit_o=0, miss_o=1, when lookup_valid_i & ready
    always_comb begin
        lookup_hit_o = 1'b0;
        lookup_pa_o  = '0;
        miss_o       = 1'b0;

        if (lookup_valid_i && lookup_ready_o) begin
            if (any_hit) begin
                lookup_hit_o = 1'b1;
                lookup_pa_o  = {data_ppn_q[hit_index], lookup_offset};
                miss_o       = 1'b0;
            end else begin
                lookup_hit_o = 1'b0;
                lookup_pa_o  = '0;
                miss_o       = 1'b1;
            end
        end
    end

    // Victim selection:
    // Prefer an invalid entry first, else choose the oldest LRU age
    always_comb begin
        found_invalid = 1'b0;
        invalid_index = '0;

        for (int i = 0; i < ENTRIES; i++) begin
            if (!found_invalid && !valid_q[i]) begin
                found_invalid = 1'b1;
                invalid_index = INDEX_BITS'(i);
            end
        end
    end

    always_comb begin
        lru_index = '0;
        max_age   = age_q[0];

        for (int i = 1; i < ENTRIES; i++) begin
            if (age_q[i] > max_age) begin
                max_age   = age_q[i];
                lru_index = INDEX_BITS'(i);
            end
        end
    end

    always_comb begin
        if (found_invalid) begin
            victim_index = invalid_index;
        end else begin
            victim_index = lru_index;
        end
    end

    // Sequential state updates, reset/flush/insert/replacement state
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            // Reset values
            valid_q <= '0;

            // Optional clear arrays for simulation clarity
            for (idx = 0; idx < ENTRIES; idx++) begin
                tag_vpn_q[idx]  <= '0;
                data_ppn_q[idx] <= '0;
                perm_q[idx]     <= '0;
                age_q[idx]      <= '0;
            end

        end else begin
            // Flush has highest priority
            if (flush_i) begin
                valid_q <= '0;

                // Optional clears
                for (idx = 0; idx < ENTRIES; idx++) begin
                    tag_vpn_q[idx]  <= '0;
                    data_ppn_q[idx] <= '0;
                    perm_q[idx]     <= '0;
                    age_q[idx]      <= '0;
                end

            end else begin
                // Insert handling
                // - pick victim (invalid first, else LRU)
                // - write arrays and valid bit
                // - update replacement bookkeeping
                if (insert_valid_i) begin
                    tag_vpn_q[victim_index]  <= insert_vpn_i;
                    data_ppn_q[victim_index] <= insert_ppn_i;
                    perm_q[victim_index]     <= insert_perm_i;
                    valid_q[victim_index]    <= 1'b1;

                    // Mark inserted entry as most recently used
                    for (idx = 0; idx < ENTRIES; idx++) begin
                        if (INDEX_BITS'(idx) == victim_index) begin
                            age_q[idx] <= '0;
                        end else if (valid_q[idx]) begin
                            if (age_q[idx] != {AGE_BITS{1'b1}})
                                age_q[idx] <= age_q[idx] + AGE_BITS'(1);
                        end else begin
                            age_q[idx] <= '0;
                        end
                    end
                end

                // Replacement bookkeeping updates on lookup hit (touch)
                else if (lookup_valid_i && lookup_ready_o && any_hit) begin
                    for (idx = 0; idx < ENTRIES; idx++) begin
                        if (INDEX_BITS'(idx) == hit_index) begin
                            age_q[idx] <= '0;
                        end else if (valid_q[idx]) begin
                            if (age_q[idx] != {AGE_BITS{1'b1}})
                                age_q[idx] <= age_q[idx] + AGE_BITS'(1);
                        end else begin
                            age_q[idx] <= '0;
                        end
                    end
                end

                // Optional parity/ECC error detection + invalidate entry
                // not implemented in this version
            end
        end
    end

endmodule
