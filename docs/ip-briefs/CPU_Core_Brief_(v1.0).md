**Author:** Sebastian Candelaria
**RTL:** *rtl/cpu/core/rv32_core.sv*

---
#### **Purpose & Role**
- The CPU Core is the main processing unit of the SoC, in charge of running all instructions from a given program and storing/loading memory data as needed
	- 5-stage pipeline in RV32IMA (ISA-format) with M/S-mode (privilege levels)
	- Built for a single-core system
---
#### **Parameters**
- Parameters in Verilog/SystemVerilog are similar to constants and #define directives seen in C/C++ that are reused many times across a module to avoid magic numbers and promote reusability

| Name       | Default         | Description                                                                                            |
| ---------  | --------------- | ------------------------------------------------------------------------------------------------------ |
| HAS_M      | 1               | Enable RV32M mul/div instructions                                                                      |
| HAS_A      | 1               | Enable LR/SC atomic instructions                                                                       |

---
#### **Interfaces (Ports)**
- Any external input or output signal that will be used by the IF stage
- AXI, IRQ, and debug signal sizes must be defined
- Subject to change

| Signal Name              | Direction | Width | Description                                                            |
| ------------------------ | --------- | ----- | ---------------------------------------------------------------------- |
| **Global Signals**       |           |       |                                                                        |
| clk_i                    | In        | 1     | Main clock input                                                       |
| rst_ni                   | In        | 1     | Active-low reset                                                       |
|                          |           |       |                                                                        |
| **PLIC/CLINT Interface** |           |       |                                                                        |
| irq_ext_i                | In        | 1     | Interrupt request from external device(s) (controller, keyboard, etc.) |
| irq_timer_i              | In        | 1     | Interrupt request from timer                                           |
| irq_soft_i               | In        | N/A   |                                                                        |
|                          |           |       |                                                                        |
| **AXI Interface**        |           |       |                                                                        |
| i_axi_*                  | I/O       | N/A   | Instruction AXI: Communicates with instruction cache                   |
| d_axi_*                  | I/O       | N/A   | Data AXI: Communicates with data cache                                 |
|                          |           |       |                                                                        |
| **Debug Interface**      |           |       |                                                                        |
| dbg_*                    | I/O       | N/A   | JTAG Signals for checking CPU behavior (Test Clock, Test Data, etc.)   |
|                          |           |       |                                                                        |

---
#### **Reset/Init**
- When performing a reset, the signal rst_ni becomes LOW (0), the CPU enters its default program ready state
	- The program counter (PC) is set to the BootROM's beginning instruction
	- The control-status registers (CSRs) are set to initial values, such as # of cycles elapsed = 0
	- All data in the pipeline, including intermediate registers and the register file, is flushed (cleared)
---
#### **Behavior & Timing**
- Instruction Execution Order: The pipeline executes the instructions in-order, or in the sequence given by the program
	- Data forwarding, consisting of signals backtracking to Decode (ID) stage, is used to handle dependencies between instructions (EX: Instruction 2 needs data provided by Instruction 1)
	- Hazard/flush control is needed for when hazards become issues, such as an instruction 
- Control Components: The core needs to minimize cycle losses from control flow changes (i.e. jumping instructions)
	- Branch Target Buffer (BTB, optional): Table of instruction addresses recently visited, indicating whether they are more likely to be visited again upon a branch (if condition is true, jump to instruction) instruction
	- Trap Vector Exception: Upon encountering a trap/error (EX: Division by zero), the CPU should immediately execute a subroutine at a vector (function's address) given by a table
---
#### **Programming Model**
- CLINT: *specs/registers/clint.yaml*
- PLIC: *specs/registers/plic.yaml*
---
#### **Errors/IRQs**
- Trap Vector Handling
- Exception Causes
- MCAUSE/MEPC Behavior
---
#### **Performance Targets**
- CPI: Average number of clock cycles taken to execute an instruction (>= 1)
	- Goal: <= 2 cycles per instruction
- MIPS: # of millions of instructions per second
	- Dependent on CPI and clock frequency
	- Goal: >= 126.5 MIPS
---
#### **Dependencies**
- AXI: *rtl/bus/axi/axi_crossbar.sv*
	- AXI connection to fetch instructions and data from memory hierarchy (ideally cache, main memory upon miss)
- PLIC/CLINT: *rtl/irq/clint.sv*, *rtl/irq/plic.sv*
	- PLIC/CLINT send interrupts, signals for CPU to temporarily switch to execution of a function's instructions in the program, based on controller inputs, timer values, etc.
- MMU: *rtl/cpu/mmu/sv32_mmu.sv*
	- Controls where/how instructions and data are loaded and stored
- RV32 Package: *rtl/cpu/pkg/rv32_pkg.sv*
---
#### **Verification Links**
- *sim/uvm/test_core.sv*
	- SystemVerilog simulation environment to verify CPU core