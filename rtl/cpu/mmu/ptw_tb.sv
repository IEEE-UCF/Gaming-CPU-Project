`timescale 1ns/1ps

module testbench;

    localparam int TIMEOUT_CYCLES = 8;
    localparam int ADDR_WIDTH     = 32;
    localparam int DATA_WIDTH     = 32;
    localparam int PPN_WIDTH      = (ADDR_WIDTH - 12);

    logic                  clk_i;
    logic                  rst_ni;
    logic                  flush_i;
    logic                  walk_req_valid_i;
    logic                  walk_req_ready_o;
    logic [ADDR_WIDTH-1:0] walk_req_addr_i;
    logic [19:0]           walk_req_vpn_i;
    logic                  walk_rsp_valid_o;
    logic [DATA_WIDTH-1:0] walk_rsp_pte_o;
    logic                  walk_rsp_error_o;
    logic                  axi_ar_valid_o;
    logic [ADDR_WIDTH-1:0] axi_ar_addr_o;
    logic                  axi_ar_ready_i;
    logic                  axi_r_valid_i;
    logic [DATA_WIDTH-1:0] axi_r_data_i;
    logic [1:0]            axi_r_resp_i;

    int tests_run;
    int tests_passed;

    ptw #(
        .TIMEOUT_CYCLES(TIMEOUT_CYCLES),
        .ADDR_WIDTH    (ADDR_WIDTH),
        .DATA_WIDTH    (DATA_WIDTH),
        .PPN_WIDTH     (PPN_WIDTH)
    ) dut (
        .clk_i           (clk_i),
        .rst_ni          (rst_ni),
        .flush_i         (flush_i),
        .walk_req_valid_i(walk_req_valid_i),
        .walk_req_ready_o(walk_req_ready_o),
        .walk_req_addr_i (walk_req_addr_i),
        .walk_req_vpn_i  (walk_req_vpn_i),
        .walk_rsp_valid_o(walk_rsp_valid_o),
        .walk_rsp_pte_o  (walk_rsp_pte_o),
        .walk_rsp_error_o(walk_rsp_error_o),
        .axi_ar_valid_o  (axi_ar_valid_o),
        .axi_ar_addr_o   (axi_ar_addr_o),
        .axi_ar_ready_i  (axi_ar_ready_i),
        .axi_r_valid_i   (axi_r_valid_i),
        .axi_r_data_i    (axi_r_data_i),
        .axi_r_resp_i    (axi_r_resp_i)
    );

    always #5 clk_i = ~clk_i;

    task automatic clear_inputs;
    begin
        flush_i           = 1'b0;
        walk_req_valid_i  = 1'b0;
        walk_req_addr_i   = '0;
        walk_req_vpn_i    = '0;
        axi_ar_ready_i    = 1'b0;
        axi_r_valid_i     = 1'b0;
        axi_r_data_i      = '0;
        axi_r_resp_i      = 2'b00;
    end
    endtask

    task automatic tick;
    begin
        @(posedge clk_i);
        #1;
    end
    endtask

    task automatic reset_dut;
    begin
        clear_inputs();
        rst_ni = 1'b0;
        repeat (3) tick();
        rst_ni = 1'b1;
        repeat (2) tick();
    end
    endtask

    task automatic check_bit;
        input string name;
        input logic actual;
        input logic expected;
    begin
        if (actual !== expected) begin
            $display("FAIL: %s expected=%0b actual=%0b at t=%0t", name, expected, actual, $time);
            $fatal(1);
        end
    end
    endtask

    task automatic check_word;
        input string name;
        input logic [31:0] actual;
        input logic [31:0] expected;
    begin
        if (actual !== expected) begin
            $display("FAIL: %s expected=0x%08x actual=0x%08x at t=%0t", name, expected, actual, $time);
            $fatal(1);
        end
    end
    endtask

    task automatic start_walk;
        input logic [31:0] base_addr;
        input logic [19:0] vpn;
    begin
        check_bit("walk_req_ready before request", walk_req_ready_o, 1'b1);
        walk_req_addr_i  = base_addr;
        walk_req_vpn_i   = vpn;
        walk_req_valid_i = 1'b1;
        tick();
        walk_req_valid_i = 1'b0;
        walk_req_addr_i  = '0;
        walk_req_vpn_i   = '0;
    end
    endtask

    task automatic expect_ar_handshake;
        input logic [31:0] expected_addr;
        input int stall_cycles;
    begin
        repeat (stall_cycles) begin
            check_bit("axi_ar_valid during stall", axi_ar_valid_o, 1'b1);
            check_word("axi_ar_addr during stall", axi_ar_addr_o, expected_addr);
            axi_ar_ready_i = 1'b0;
            tick();
        end

        check_bit("axi_ar_valid before handshake", axi_ar_valid_o, 1'b1);
        check_word("axi_ar_addr before handshake", axi_ar_addr_o, expected_addr);
        axi_ar_ready_i = 1'b1;
        tick();
        axi_ar_ready_i = 1'b0;
    end
    endtask

    task automatic drive_read;
        input logic [31:0] data;
        input logic [1:0]  resp;
        input int wait_cycles;
    begin
        repeat (wait_cycles) tick();
        axi_r_data_i  = data;
        axi_r_resp_i  = resp;
        axi_r_valid_i = 1'b1;
        tick();
        axi_r_valid_i = 1'b0;
        axi_r_data_i  = '0;
        axi_r_resp_i  = 2'b00;
    end
    endtask

    task automatic expect_response;
        input logic expected_error;
        input logic [31:0] expected_pte;
    begin
        check_bit("walk_rsp_valid", walk_rsp_valid_o, 1'b1);
        check_bit("walk_rsp_error", walk_rsp_error_o, expected_error);
        check_word("walk_rsp_pte", walk_rsp_pte_o, expected_pte);
        tick();
        check_bit("walk_req_ready after response", walk_req_ready_o, 1'b1);
        check_bit("walk_rsp_valid cleared", walk_rsp_valid_o, 1'b0);
    end
    endtask

    task automatic expect_no_response_for;
        input int cycles;
    begin
        repeat (cycles) begin
            check_bit("walk_rsp_valid should stay low", walk_rsp_valid_o, 1'b0);
            tick();
        end
    end
    endtask

    function automatic [31:0] mk_pointer_pte;
        input logic [21:0] next_ppn;
    begin
        // valid pointer: V=1, R=0, W=0, X=0
        mk_pointer_pte = {next_ppn, 10'b0000000001};
    end
    endfunction

    function automatic [31:0] mk_leaf_pte;
        input logic [21:0] ppn;
        input logic r;
        input logic w;
        input logic x;
        input logic a;
        input logic d;
    begin
        // [31:10]=PPN, low bits include D A G U X W R V at [7:0]
        mk_leaf_pte = {ppn, 2'b00, d, a, 1'b0, 1'b0, x, w, r, 1'b1};
    end
    endfunction

    task automatic run_test_two_level_success;
        logic [31:0] base_addr;
        logic [19:0] vpn;
        logic [9:0]  vpn1;
        logic [9:0]  vpn0;
        logic [31:0] l1_addr;
        logic [31:0] l2_addr;
        logic [31:0] l1_pte;
        logic [31:0] l2_pte;
    begin
        $display("TEST: two_level_success");
        tests_run = tests_run + 1;
        reset_dut();

        base_addr = 32'h0000_4000;
        vpn       = 20'h155AA;
        vpn1      = vpn[19:10];
        vpn0      = vpn[9:0];
        l1_addr   = base_addr + (32'(vpn1) << 2);
        l1_pte    = mk_pointer_pte(22'h00080);
        l2_addr   = {l1_pte[29:10], 12'b0} + (32'(vpn0) << 2);
        l2_pte    = mk_leaf_pte(22'h2ABCD, 1'b1, 1'b0, 1'b0, 1'b1, 1'b1);

        start_walk(base_addr, vpn);
        check_bit("busy after request", walk_req_ready_o, 1'b0);
        expect_ar_handshake(l1_addr, 2);
        drive_read(l1_pte, 2'b00, 2);
        expect_ar_handshake(l2_addr, 1);
        drive_read(l2_pte, 2'b00, 1);
        expect_response(1'b0, l2_pte);
        tests_passed = tests_passed + 1;
    end
    endtask

    task automatic run_test_l1_superpage_success;
        logic [31:0] base_addr;
        logic [19:0] vpn;
        logic [9:0]  vpn1;
        logic [31:0] l1_addr;
        logic [31:0] l1_pte;
    begin
        $display("TEST: l1_superpage_success");
        tests_run = tests_run + 1;
        reset_dut();

        base_addr = 32'h0000_8000;
        vpn       = 20'h0C321;
        vpn1      = vpn[19:10];
        l1_addr   = base_addr + (32'(vpn1) << 2);
        l1_pte    = mk_leaf_pte(22'h154000, 1'b1, 1'b0, 1'b0, 1'b1, 1'b1);

        start_walk(base_addr, vpn);
        expect_ar_handshake(l1_addr, 0);
        drive_read(l1_pte, 2'b00, 0);
        expect_response(1'b0, l1_pte);
        tests_passed = tests_passed + 1;
    end
    endtask

    task automatic run_test_invalid_v_on_l1;
        logic [31:0] base_addr;
        logic [19:0] vpn;
        logic [9:0]  vpn1;
        logic [31:0] l1_addr;
        logic [31:0] bad_pte;
    begin
        $display("TEST: invalid_v_on_l1");
        tests_run = tests_run + 1;
        reset_dut();

        base_addr = 32'h0000_A000;
        vpn       = 20'h11111;
        vpn1      = vpn[19:10];
        l1_addr   = base_addr + (32'(vpn1) << 2);
        bad_pte   = 32'h0000_0000;

        start_walk(base_addr, vpn);
        expect_ar_handshake(l1_addr, 0);
        drive_read(bad_pte, 2'b00, 0);
        expect_response(1'b1, 32'h0000_0000);
        tests_passed = tests_passed + 1;
    end
    endtask

    task automatic run_test_invalid_r0w1_on_l1;
        logic [31:0] base_addr;
        logic [19:0] vpn;
        logic [9:0]  vpn1;
        logic [31:0] l1_addr;
        logic [31:0] bad_pte;
    begin
        $display("TEST: invalid_r0w1_on_l1");
        tests_run = tests_run + 1;
        reset_dut();

        base_addr = 32'h0000_B000;
        vpn       = 20'h22222;
        vpn1      = vpn[19:10];
        l1_addr   = base_addr + (32'(vpn1) << 2);
        bad_pte   = 32'h0000_0005; // V=1, R=0, W=1

        start_walk(base_addr, vpn);
        expect_ar_handshake(l1_addr, 0);
        drive_read(bad_pte, 2'b00, 0);
        expect_response(1'b1, 32'h0000_0000);
        tests_passed = tests_passed + 1;
    end
    endtask

    task automatic run_test_axi_fault_on_l1;
        logic [31:0] base_addr;
        logic [19:0] vpn;
        logic [9:0]  vpn1;
        logic [31:0] l1_addr;
    begin
        $display("TEST: axi_fault_on_l1");
        tests_run = tests_run + 1;
        reset_dut();

        base_addr = 32'h0000_C000;
        vpn       = 20'h33333;
        vpn1      = vpn[19:10];
        l1_addr   = base_addr + (32'(vpn1) << 2);

        start_walk(base_addr, vpn);
        expect_ar_handshake(l1_addr, 1);
        drive_read(32'hDEAD_BEEF, 2'b10, 0);
        expect_response(1'b1, 32'h0000_0000);
        tests_passed = tests_passed + 1;
    end
    endtask

    task automatic run_test_ad_fault_on_l1_leaf;
        logic [31:0] base_addr;
        logic [19:0] vpn;
        logic [9:0]  vpn1;
        logic [31:0] l1_addr;
        logic [31:0] l1_pte;
    begin
        $display("TEST: ad_fault_on_l1_leaf");
        tests_run = tests_run + 1;
        reset_dut();

        base_addr = 32'h0000_D000;
        vpn       = 20'h44444;
        vpn1      = vpn[19:10];
        l1_addr   = base_addr + (32'(vpn1) << 2);
        l1_pte    = mk_leaf_pte(22'h088000, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1);

        start_walk(base_addr, vpn);
        expect_ar_handshake(l1_addr, 0);
        drive_read(l1_pte, 2'b00, 0);
        expect_response(1'b1, 32'h0000_0000);
        tests_passed = tests_passed + 1;
    end
    endtask

    task automatic run_test_superpage_misaligned_error;
        logic [31:0] base_addr;
        logic [19:0] vpn;
        logic [9:0]  vpn1;
        logic [31:0] l1_addr;
        logic [31:0] l1_pte;
    begin
        $display("TEST: superpage_misaligned_error");
        tests_run = tests_run + 1;
        reset_dut();

        base_addr = 32'h0000_E000;
        vpn       = 20'h55555;
        vpn1      = vpn[19:10];
        l1_addr   = base_addr + (32'(vpn1) << 2);
        l1_pte    = mk_leaf_pte(22'h000123, 1'b1, 1'b0, 1'b0, 1'b1, 1'b1);

        start_walk(base_addr, vpn);
        expect_ar_handshake(l1_addr, 0);
        drive_read(l1_pte, 2'b00, 0);
        expect_response(1'b1, 32'h0000_0000);
        tests_passed = tests_passed + 1;
    end
    endtask

    task automatic run_test_l2_ad_fault;
        logic [31:0] base_addr;
        logic [19:0] vpn;
        logic [9:0]  vpn1;
        logic [9:0]  vpn0;
        logic [31:0] l1_addr;
        logic [31:0] l2_addr;
        logic [31:0] l1_pte;
        logic [31:0] l2_pte;
    begin
        $display("TEST: l2_ad_fault");
        tests_run = tests_run + 1;
        reset_dut();

        base_addr = 32'h0001_0000;
        vpn       = 20'h66666;
        vpn1      = vpn[19:10];
        vpn0      = vpn[9:0];
        l1_addr   = base_addr + (32'(vpn1) << 2);
        l1_pte    = mk_pointer_pte(22'h00090);
        l2_addr   = {l1_pte[29:10], 12'b0} + (32'(vpn0) << 2);
        l2_pte    = mk_leaf_pte(22'h012345, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1);

        start_walk(base_addr, vpn);
        expect_ar_handshake(l1_addr, 0);
        drive_read(l1_pte, 2'b00, 0);
        expect_ar_handshake(l2_addr, 0);
        drive_read(l2_pte, 2'b00, 0);
        expect_response(1'b1, 32'h0000_0000);
        tests_passed = tests_passed + 1;
    end
    endtask

    task automatic run_test_invalid_l2_nonleaf;
        logic [31:0] base_addr;
        logic [19:0] vpn;
        logic [9:0]  vpn1;
        logic [9:0]  vpn0;
        logic [31:0] l1_addr;
        logic [31:0] l2_addr;
        logic [31:0] l1_pte;
        logic [31:0] l2_pte;
    begin
        $display("TEST: invalid_l2_nonleaf");
        tests_run = tests_run + 1;
        reset_dut();

        base_addr = 32'h0001_1000;
        vpn       = 20'h77777;
        vpn1      = vpn[19:10];
        vpn0      = vpn[9:0];
        l1_addr   = base_addr + (32'(vpn1) << 2);
        l1_pte    = mk_pointer_pte(22'h000A0);
        l2_addr   = {l1_pte[29:10], 12'b0} + (32'(vpn0) << 2);
        l2_pte    = mk_pointer_pte(22'h000B0);

        start_walk(base_addr, vpn);
        expect_ar_handshake(l1_addr, 0);
        drive_read(l1_pte, 2'b00, 1);
        expect_ar_handshake(l2_addr, 0);
        drive_read(l2_pte, 2'b00, 0);
        expect_response(1'b1, 32'h0000_0000);
        tests_passed = tests_passed + 1;
    end
    endtask

    task automatic run_test_axi_fault_on_l2;
        logic [31:0] base_addr;
        logic [19:0] vpn;
        logic [9:0]  vpn1;
        logic [9:0]  vpn0;
        logic [31:0] l1_addr;
        logic [31:0] l2_addr;
        logic [31:0] l1_pte;
    begin
        $display("TEST: axi_fault_on_l2");
        tests_run = tests_run + 1;
        reset_dut();

        base_addr = 32'h0001_2000;
        vpn       = 20'h88888;
        vpn1      = vpn[19:10];
        vpn0      = vpn[9:0];
        l1_addr   = base_addr + (32'(vpn1) << 2);
        l1_pte    = mk_pointer_pte(22'h000C0);
        l2_addr   = {l1_pte[29:10], 12'b0} + (32'(vpn0) << 2);

        start_walk(base_addr, vpn);
        expect_ar_handshake(l1_addr, 0);
        drive_read(l1_pte, 2'b00, 0);
        expect_ar_handshake(l2_addr, 2);
        drive_read(32'hCAFE_BABE, 2'b11, 0);
        expect_response(1'b1, 32'h0000_0000);
        tests_passed = tests_passed + 1;
    end
    endtask

    task automatic run_test_timeout_on_l1;
        logic [31:0] base_addr;
        logic [19:0] vpn;
        logic [9:0]  vpn1;
        logic [31:0] l1_addr;
        int i;
    begin
        $display("TEST: timeout_on_l1");
        tests_run = tests_run + 1;
        reset_dut();

        base_addr = 32'h0001_3000;
        vpn       = 20'h99999;
        vpn1      = vpn[19:10];
        l1_addr   = base_addr + (32'(vpn1) << 2);

        start_walk(base_addr, vpn);
        expect_ar_handshake(l1_addr, 0);
        for (i = 0; i < TIMEOUT_CYCLES + 1; i = i + 1)
            expect_no_response_for(1);
        expect_response(1'b1, 32'h0000_0000);
        tests_passed = tests_passed + 1;
    end
    endtask

    task automatic run_test_timeout_on_l2;
        logic [31:0] base_addr;
        logic [19:0] vpn;
        logic [9:0]  vpn1;
        logic [9:0]  vpn0;
        logic [31:0] l1_addr;
        logic [31:0] l2_addr;
        logic [31:0] l1_pte;
        int i;
    begin
        $display("TEST: timeout_on_l2");
        tests_run = tests_run + 1;
        reset_dut();

        base_addr = 32'h0001_4000;
        vpn       = 20'hAAAAA;
        vpn1      = vpn[19:10];
        vpn0      = vpn[9:0];
        l1_addr   = base_addr + (32'(vpn1) << 2);
        l1_pte    = mk_pointer_pte(22'h000D0);
        l2_addr   = {l1_pte[29:10], 12'b0} + (32'(vpn0) << 2);

        start_walk(base_addr, vpn);
        expect_ar_handshake(l1_addr, 0);
        drive_read(l1_pte, 2'b00, 0);
        expect_ar_handshake(l2_addr, 0);
        for (i = 0; i < TIMEOUT_CYCLES + 1; i = i + 1)
            expect_no_response_for(1);
        expect_response(1'b1, 32'h0000_0000);
        tests_passed = tests_passed + 1;
    end
    endtask

    task automatic run_test_flush_while_waiting_l1;
        logic [31:0] base_addr;
        logic [19:0] vpn;
        logic [9:0]  vpn1;
        logic [31:0] l1_addr;
    begin
        $display("TEST: flush_while_waiting_l1");
        tests_run = tests_run + 1;
        reset_dut();

        base_addr = 32'h0001_5000;
        vpn       = 20'hBBBBB;
        vpn1      = vpn[19:10];
        l1_addr   = base_addr + (32'(vpn1) << 2);

        start_walk(base_addr, vpn);
        expect_ar_handshake(l1_addr, 0);
        check_bit("no response before flush", walk_rsp_valid_o, 1'b0);
        flush_i = 1'b1;
        tick();
        flush_i = 1'b0;
        check_bit("ready after flush l1", walk_req_ready_o, 1'b1);
        check_bit("no response generated by flush l1", walk_rsp_valid_o, 1'b0);
        tests_passed = tests_passed + 1;
    end
    endtask

    task automatic run_test_flush_while_waiting_l2;
        logic [31:0] base_addr;
        logic [19:0] vpn;
        logic [9:0]  vpn1;
        logic [9:0]  vpn0;
        logic [31:0] l1_addr;
        logic [31:0] l2_addr;
        logic [31:0] l1_pte;
    begin
        $display("TEST: flush_while_waiting_l2");
        tests_run = tests_run + 1;
        reset_dut();

        base_addr = 32'h0001_6000;
        vpn       = 20'hCCCCC;
        vpn1      = vpn[19:10];
        vpn0      = vpn[9:0];
        l1_addr   = base_addr + (32'(vpn1) << 2);
        l1_pte    = mk_pointer_pte(22'h000E0);
        l2_addr   = {l1_pte[29:10], 12'b0} + (32'(vpn0) << 2);

        start_walk(base_addr, vpn);
        expect_ar_handshake(l1_addr, 0);
        drive_read(l1_pte, 2'b00, 0);
        expect_ar_handshake(l2_addr, 0);
        flush_i = 1'b1;
        tick();
        flush_i = 1'b0;
        check_bit("ready after flush l2", walk_req_ready_o, 1'b1);
        check_bit("no response generated by flush l2", walk_rsp_valid_o, 1'b0);
        tests_passed = tests_passed + 1;
    end
    endtask

    task automatic run_test_single_outstanding_request;
        logic [31:0] base_addr_1;
        logic [31:0] base_addr_2;
        logic [19:0] vpn_1;
        logic [19:0] vpn_2;
        logic [9:0]  vpn1_1;
        logic [9:0]  vpn0_1;
        logic [31:0] l1_addr_1;
        logic [31:0] l2_addr_1;
        logic [31:0] l1_pte_1;
        logic [31:0] l2_pte_1;
    begin
        $display("TEST: single_outstanding_request");
        tests_run = tests_run + 1;
        reset_dut();

        base_addr_1 = 32'h0001_7000;
        base_addr_2 = 32'h0002_7000;
        vpn_1       = 20'h12345;
        vpn_2       = 20'h54321;
        vpn1_1      = vpn_1[19:10];
        vpn0_1      = vpn_1[9:0];
        l1_addr_1   = base_addr_1 + (32'(vpn1_1) << 2);
        l1_pte_1    = mk_pointer_pte(22'h000F0);
        l2_addr_1   = {l1_pte_1[29:10], 12'b0} + (32'(vpn0_1) << 2);
        l2_pte_1    = mk_leaf_pte(22'h01ABCDE, 1'b1, 1'b0, 1'b0, 1'b1, 1'b1);

        start_walk(base_addr_1, vpn_1);
        expect_ar_handshake(l1_addr_1, 0);

        // Try to present a second request while busy. DUT should not accept it.
        walk_req_addr_i  = base_addr_2;
        walk_req_vpn_i   = vpn_2;
        walk_req_valid_i = 1'b1;
        check_bit("not ready while busy", walk_req_ready_o, 1'b0);
        tick();
        walk_req_valid_i = 1'b0;
        walk_req_addr_i  = '0;
        walk_req_vpn_i   = '0;

        drive_read(l1_pte_1, 2'b00, 0);
        expect_ar_handshake(l2_addr_1, 0);
        drive_read(l2_pte_1, 2'b00, 0);
        expect_response(1'b0, l2_pte_1);

        // Confirm DUT can accept a new request only after finishing.
        check_bit("ready for next request", walk_req_ready_o, 1'b1);
        tests_passed = tests_passed + 1;
    end
    endtask

    initial begin
        clk_i        = 1'b0;
        rst_ni       = 1'b0;
        tests_run    = 0;
        tests_passed = 0;
        clear_inputs();

        run_test_two_level_success();
        run_test_l1_superpage_success();
        run_test_invalid_v_on_l1();
        run_test_invalid_r0w1_on_l1();
        run_test_axi_fault_on_l1();
        run_test_ad_fault_on_l1_leaf();
        run_test_superpage_misaligned_error();
        run_test_l2_ad_fault();
        run_test_invalid_l2_nonleaf();
        run_test_axi_fault_on_l2();
        run_test_timeout_on_l1();
        run_test_timeout_on_l2();
        run_test_flush_while_waiting_l1();
        run_test_flush_while_waiting_l2();
        run_test_single_outstanding_request();

        $display("----------------------------------------");
        $display("PTW extensive testbench complete: %0d/%0d tests passed", tests_passed, tests_run);
        $display("----------------------------------------");
        $finish;
    end

endmodule