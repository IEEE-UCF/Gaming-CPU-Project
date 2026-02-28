**Author:** Sebastian Candelaria
**RTL:** *rtl/cpu/core/writeback.sv*

---
#### **Purpose & Role**
- The Writeback (WB) stage is the 5th stage in a standard 5-stage RISC-V pipeline. At each clock cycle, if given data to send, WB sends the data directly data to the register file (RF) and adjusts the control-status registers (CSRs) as needed
	- Any exceptions found must take priority and be committed (noted in CSRs, handled by flushing pipeline and resetting)

---
#### **Parameters**
- Parameters in Verilog/SystemVerilog are similar to constants and #define directives seen in C/C++ that are reused many times across a module to avoid magic numbers and promote reusability
- Note: Inherited from `rv32_pkg.sv` and `rv32_core` top-level. See CPU Core Brief for HAS_M/HAS_A configuration.

| Name          | Default | Description                                        |
|---------------|---------|--------------------------------------------------  |
| DATA_WIDTH    | 32      | Writeback data width                               |
| RF_ADDR_WIDTH | 5       | Register file address width (32 regs)              |

---
#### **Interfaces (Ports)**
- Any external input or output signal that will be used by the MM stage (subject to change)

| Signal Name    | Direction | Width | Description                                      |
| -------------- | --------- | ----- | ------------------------------------------------ |
| clk_i          | In        | 1     | Main clock input                                 |
| rst_ni         | In        | 1     | Active-low asynchronous reset                    |
| rd_addr_i      | In        | 5     | Destination register address to send data to     |
| rd_data_i      | In        | 32    | Data for destination register                    |
| rd_valid_i     | In        | 1     | Data write valid flag (mem we)                   |
| rd_exception_i | In        | 1     |                                                  |
| rd_we_o        | Out       | 1     | Control signal for writing to register file (RF) |
| rd_waddr_o     | Out       | 5     | Destination register address                     |
| csr_we_o       | Out       | 1     | Control-status register write enable             |
| csr_addr_o     | Out       | 12    | Control-status register address                  |
| csr_wdata_o    | Out       | 32    | Control-stautus data to write                    |
| csr_rdata_o    | Out       | 32    |                                                  |

---
#### **Reset/Init**
- When performing a reset, the signal rst_ni becomes LOW (0), the CPU enters its default state
	- All registers are flushed
	- Control signals enter default values
---
#### **Behavior & Timing**
- 1-Cycle Commit: All values should be written back by next cycle
- CSR/exceptions are routed to trap logic in core
	- Stalls should occur under busy/ready internal handshake signals (aka while working on operation, stall)
- Unique-Case FSM: A finite state machine (FSM), a sequential logic model for paths of outputs depending on inputs, should control output
---
#### **Errors/IRQs**
- Exception Commit Behavior
- Trap Delegation
---
#### **Performance Targets**
- Each data or exception committed in 1 cycle
---
#### **Dependencies**
- Memory (MM): *rtl/bus/core/mem_stage.sv*
- Execute (EX): *rtl/bus/core/execute.sv*
- RV32 Package: *rtl/cpu/pkg/rv32_pkg.sv*
---
#### **Verification Links**
- *sim/uvm/test_writeback.sv*
	- SystemVerilog simulation environment to verify writeback stage