`timescale 1ns/1ps

module tb;

  logic clk = 0;
  logic rst_n = 0;

  always #5 clk = ~clk;

  // MMU-side stimulus

  logic [31:0] va;
  logic        valid;
  logic        ready;
  logic [1:0]  access;
  logic [33:0] pa;

  logic        fault;
  logic [1:0]  cause;
  logic        timeout;
  logic [31:0] fault_va;

  logic [31:0] satp;
  logic [1:0]  priv;
  logic        sum, mxr, uxn;
  logic        sfence;

  // MMU <-> PTW

  logic        ptw_req_valid;
  logic        ptw_req_ready;
  logic [31:0] ptw_req_root_addr;
  logic [19:0] ptw_req_vpn;

  logic        ptw_rsp_valid;
  logic [31:0] ptw_rsp_pte;
  logic        ptw_rsp_error;

  // PTW <-> fake AXI memory

  logic        axi_ar_valid;
  logic [31:0] axi_ar_addr;
  logic        axi_ar_ready;
  logic        axi_r_valid;
  logic [31:0] axi_r_data;
  logic [1:0]  axi_r_resp;

  // real MMU

  sv32_mmu dut (
    .clk_i(clk),
    .rst_ni(rst_n),

    .va_i(va),
    .valid_i(valid),
    .ready_o(ready),
    .access_i(access),

    .pa_o(pa),

    .fault_o(fault),
    .fault_cause_o(cause),
    .fault_timeout_o(timeout),
    .fault_va_o(fault_va),

    .ptw_req_valid_o(ptw_req_valid),
    .ptw_req_ready_i(ptw_req_ready),
    .ptw_req_root_addr_o(ptw_req_root_addr),
    .ptw_req_vpn_o(ptw_req_vpn),

    .ptw_rsp_valid_i(ptw_rsp_valid),
    .ptw_rsp_pte_i(ptw_rsp_pte),
    .ptw_rsp_error_i(ptw_rsp_error),

    .satp_i(satp),
    .priv_i(priv),
    .sum_i(sum),
    .mxr_i(mxr),
    .uxn_i(uxn),

    .sfence_vma_i(sfence)
  );


  // Real PTW

  ptw ptw_i (
    .clk_i(clk),
    .rst_ni(rst_n),
    .flush_i(sfence),

    .walk_req_valid_i(ptw_req_valid),
    .walk_req_ready_o(ptw_req_ready),
    .walk_req_addr_i(ptw_req_root_addr),
    .walk_req_vpn_i(ptw_req_vpn),

    .walk_rsp_valid_o(ptw_rsp_valid),
    .walk_rsp_pte_o(ptw_rsp_pte),
    .walk_rsp_error_o(ptw_rsp_error),

    .axi_ar_valid_o(axi_ar_valid),
    .axi_ar_addr_o(axi_ar_addr),
    .axi_ar_ready_i(axi_ar_ready),
    .axi_r_valid_i(axi_r_valid),
    .axi_r_data_i(axi_r_data),
    .axi_r_resp_i(axi_r_resp)
  );

  // Fake memory for PTW AXI reads

  localparam logic [31:0] ROOT_BASE = 32'h0000_1000;
  localparam logic [31:0] L2_BASE   = 32'h0000_2000;

  logic        mem_pending;
  logic [31:0] mem_addr_q;
  logic [1:0]  mem_delay_q;

  assign axi_ar_ready = 1'b1;

  function automatic [31:0] make_l1_pointer();
    logic [21:0] ppn;
    logic [7:0]  flags;
    begin
      // pointer to level-2 page table at 0x2000
      ppn   = L2_BASE[31:10];
      flags = 8'b00000001; // V=1, non-leaf pointer
      make_l1_pointer = {ppn, 2'b00, flags};
    end
  endfunction

  function automatic [31:0] make_l2_leaf(input [31:0] req_addr);
    logic [21:0] ppn;
    logic [7:0]  flags;
    begin
      // identity-like mapping based on PTW read address page
      ppn = req_addr[31:10];

      // V,R,W,X,U,G,A,D = [0]..[7] packed into low 8 bits
      // choose a valid readable/executable leaf with A/D set
      flags = 8'b11001111;

      make_l2_leaf = {ppn, 2'b00, flags};
    end
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mem_pending <= 1'b0;
      mem_addr_q  <= '0;
      mem_delay_q <= '0;
      axi_r_valid <= 1'b0;
      axi_r_data  <= '0;
      axi_r_resp  <= 2'b00;
    end else begin
      axi_r_valid <= 1'b0;

      if (!mem_pending && axi_ar_valid && axi_ar_ready) begin
        mem_pending <= 1'b1;
        mem_addr_q  <= axi_ar_addr;
        mem_delay_q <= 2;
      end else if (mem_pending) begin
        if (mem_delay_q != 0) begin
          mem_delay_q <= mem_delay_q - 1'b1;
        end else begin
          axi_r_valid <= 1'b1;
          axi_r_resp  <= 2'b00;

          if ((mem_addr_q >= ROOT_BASE) && (mem_addr_q < ROOT_BASE + 32'h1000))
            axi_r_data <= make_l1_pointer();
          else
            axi_r_data <= make_l2_leaf(mem_addr_q);

          mem_pending <= 1'b0;
        end
      end
    end
  end

  // Request helper

  task automatic send_req(input [31:0] addr, input [1:0] acc);
    int cycles;
    begin
      va     = addr;
      access = acc;
      valid  = 1'b1;

      cycles = 0;
      while (!ready && cycles < 300) begin
        @(posedge clk);
        cycles++;
      end

      if (!ready) begin
        $display("FAIL: timeout waiting for MMU ready on VA=%h", addr);
        $finish;
      end

      @(posedge clk);
      $display("VA=%h PA=%h fault=%0d cause=%0d timeout=%0d",
               addr, pa, fault, cause, timeout);

      valid = 1'b0;
      @(posedge clk);
    end
  endtask

  // Test sequence

  initial begin
    va     = 32'h0;
    valid  = 1'b0;
    access = 2'b00;

    satp   = 32'h8000_0001; // MODE=1, root PPN=1 => root base 0x1000
    priv   = 2'b01;         // S-mode
    sum    = 1'b1;
    mxr    = 1'b0;
    uxn    = 1'b0;
    sfence = 1'b0;

    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);

    // first access: TLB miss -> PTW walk
    send_req(32'h0000_0123, 2'b10);

    // second access same page: should hit TLB
    send_req(32'h0000_0128, 2'b10);

    // different page
    send_req(32'h0000_2456, 2'b00);

    // flush and force another PTW walk
    sfence = 1'b1;
    @(posedge clk);
    sfence = 1'b0;
    @(posedge clk);

    send_req(32'h0000_0123, 2'b10);

    $display("TB DONE");
    #20;
    $finish;
  end

endmodule