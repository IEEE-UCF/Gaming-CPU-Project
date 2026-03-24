# GamingCPU — Boot ROM

```
Owner: [Evan Eichholz] | RTL Target: rtl/mem/boot_rom.sv | Version: v0.
```
## Purpose & Role

```
Initial boot code storage and CPU initialization. Contains the first instructions executed by
the processor after reset, handling early system setup, peripheral initialization, and FSBL
(First Stage Boot Loader) loading from storage.
```
## Design Specifications

```
Read-Only Memory - Pre-programmed content, no write capability
Fixed Address Range - 4KB memory space at hardware-defined base address
Minimal Latency - Single-cycle read access for immediate execution
Synchronous Interface - Clocked read operations only
```
## Implementation Tasks

```
Task Decision Deliverable
Memory Initialization $readmemh from hex file Pre-programmed boot code
Interface Design Simple read-only port Clean CPU interface
Address Decoding Full 4KB range No external decoding needed
Timing Optimization Combinational read Zero-wait-state access
```
## INTERFACE DEFINITION



```
module boot_rom #( parameter int ADDR_W = 12, // 4KB address space
parameter int DATA_W = 32 // 32-bit instruction width
)(
input logic clk_i, input logic rst_ni,
input logic [ADDR_W-1:0] addr_i,
output logic [DATA_W-1:0] data_o, output logic valid_o
);
