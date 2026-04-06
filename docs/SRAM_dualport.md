# GamingCPU — SRAM Dualport

**Owner:** Evan Eichholz **RTL Target:** rtl/mem/sram_dualport.sv
**Version:** v0.

## Purpose & Role

GamingCPU will implement true dual-port SRAM macro using FPGA block RAM (BRAM)
primitives. This block will serve as the fundamental building block for all shared,
concurrent-access memory structures in the SoC by creating a reliable, area-efficient
memory block that two independent clients can use simultaneously

## Design

**True Dual-Port** - Both ports operate simultaneously, no arbitration
**FPGA BRAM Mapping** - Use dedicated memory blocks, not flip-flops
**Byte-Level Writes** - Modify individual bytes without read-modify-write penalty
**Timing Closure** - Add output registers for better timing

## Implementation Tools

Creating a resource, area-efficient memory block that two independent clients can use
simultaneously

## Design Specifications

**True Dual-Port** - Both ports operate simultaneously, no arbitration
**FPGA BRAM Mapping** - Use dedicated memory blocks, not flip-flops
**Byte-Level Writes** - Modify individual bytes without read-modify-write penalty
**Timing Closure** - Add output registers for better timing

# Implementation Tasks

| **BRAM Instantiation** | Inference vs Direct | Vendor-agnostic RTL | **Port Wiring** |
Independent access | No coordination logic | **Byte Enables** | Native BRAM support | Per-
byte write capability | **Output Registers** | OUT_REG=0 vs 1 | Timing vs latency
trade-off | **Collision Handling** | Read-old-data vs read-new-data | Documented behavior

# Integration

| **RAM Handler** | Bus interface wrapper | AXI/TL-UL conversion | **Video Pipeline** | Line
buffers, framebuffers | Direct memory access | **Audio System** | Sample buffers |
Streaming data | **CPU/Coprocessors** | Shared data structures | Concurrent access

# Interface

```
module sram_dualport #(
parameter int DATA_W = 32,
parameter int ADDR_W = 10,
parameter bit OUT_REG = 0


 )(

input logic clk_i,
// Port A
input logic [ADDR_W-1:0] port_a_addr_i,
input logic [DATA_W-1:0] port_a_wdata_i,
input logic port_a_we_i,
input logic [(DATA_W/8)-1:0] port_a_be_i,
output logic [DATA_W-1:0] port_a_rdata_o,
// Port B
input logic [ADDR_W-1:0] port_b_addr_i,
input logic [DATA_W-1:0] port_b_wdata_i,
input logic port_b_we_i,
input logic [(DATA_W/8)-1:0] port_b_be_i,
output logic [DATA_W-1:0] port_b_rdata_o
);
```
