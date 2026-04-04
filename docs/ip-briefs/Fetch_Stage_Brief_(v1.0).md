**Author:** Sebastian Candelaria
**RTL:** *rtl/cpu/core/fetch.sv*

---
#### **Purpose & Role**
- The Instruction Fetch (IF) stage is the 1st stage in a standard 5-stage RISC-V pipeline. At each clock cycle, the fetch stage attempts to request an instruction from the cache via the AXI and sends that instruction down the pipeline.
	- Program Counter (PC): Register holding memory address of next instruction to execute. Increments by 4 or changes to a new address given by a jump/branch instruction after each cycle.
	- IF will stall if next PC address is not known yet or has not received an instruction yet.
---
#### **Parameters**
- Parameters in Verilog/SystemVerilog are similar to constants and #define directives seen in C/C++ that are reused many times across a module to avoid magic numbers and promote reusability
- Note: Inherited from `rv32_pkg.sv` and `rv32_core` top-level. See CPU Core Brief for HAS_M/HAS_A configuration.

| Name        | Default        | Description                                   |
|-------------|----------------|-----------------------------------------------|
| RESET_ADDR  | 32'h0000_0000  | PC value on reset (BootROM entry)             |
| BTB_ENTRIES | 16             | Branch target buffer size (0 to disable)      |
| ADDR_WIDTH  | 32             | Address bus width                             |

---
#### **Interfaces (Ports)**
- Any external input or output signal that will be used by the IF stage
- AXI burst parameters must be defined later
- Subject to change

| Signal Name              | Direction | Width | Description                                                            |
| ------------------------ | --------- | ----- | ---------------------------------------------------------------------- |
| **Global Signals**       |           |       |                                                                        |
| clk_i                    | In        | 1     | Main clock input                                                       |
| rst_ni                   | In        | 1     | Active-low asynchronous reset                                          |
|                          |           |       |                                                                        |
| **Semi-Global Signals**  |           |       |                                                                        |
| pc_q                     | In        | 32    | Program counter signal                                                 |
| ic_req_o                 | Out       | N/A   | Instruction cache request + valid                                      |
| ic_rsp_i                 | In        | N/A   | Instruction cache response + valid                                     |
| redir_i                  | In        | 1     | Indicator to redirect PC to branch/jump address                        |
| inst_o                   | Out       | 32    | Fetched instruction to decode (ID) stage                               |
|                          |           |       |                                                                        |

---
#### **Reset/Init**
- When performing a reset, the signal rst_ni becomes LOW (0), the CPU enters its default state
	- All registers are flushed
---
#### **Behavior & Timing**
- Sequential Fetch: Since the pipeline executes the instructions in-order, fetch always grabs instructions in sequence from first to last address (except as directed by jump/branch instructions)
	- Branch Target Buffer (BTB, optional) is used when the branch address is known but not the conditional outcome, predicting whether a branch should be taken (aka the branch address should be the next PC).
	- Upon requesting an instruction from cache, it should be ready to send in the next clock cycle (therefore, the current instruction is sent out while the next instruction is requested)
	- Upon miss/redirect, a one-cycle stall must happen to prevent an incorrect instruction from being sent
	- Upon FENCE.I, an instruction that flushes the current instructions and inserts new ones, the instruction cache uses an invalidate hook to tell the fetch stage to wait until the new instructions are ready
---
#### **Programming Model**
- N/A
---
#### **Errors/IRQs**
- Instruction Access Fault
- Page Fault
---
#### **Performance Targets**
- 1-cycle hit path: Expect instruction within one cycle always (moreso AXI and cache issue)
---
#### **Dependencies**
- AXI: *rtl/bus/axi/axi_crossbar.sv*
	- AXI connection to fetch instructions and data from memory hierarchy (ideally cache, main memory upon miss)
- Decode (ID): *rtl/bus/core/decode.sv*
- RV32 Package: *rtl/cpu/pkg/rv32_pkg.sv*
---
#### **Verification Links**
- *sim/uvm/test_fetch.sv*
	- SystemVerilog simulation environment to verify fetch stage