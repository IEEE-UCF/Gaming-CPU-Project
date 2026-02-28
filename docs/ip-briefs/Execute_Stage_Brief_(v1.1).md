**Author:** Sebastian Candelaria
**RTL:** *rtl/cpu/core/execute.sv*

---
#### **Purpose & Role**
- The Execute (EX) stage is the 3rd stage in a standard 5-stage RISC-V pipeline. At each clock cycle, the execute stage performs arithmetic and logic operations on operand values. 
	- Conditional statement evaluation (thus redirects) occurs here
	- Contains Arithmetic & Logic Unit (ALU) for basic operations (add, sub, shift, etc.) + multiplier and divider

---
#### **Parameters**
- Parameters in Verilog/SystemVerilog are similar to constants and #define directives seen in C/C++ that are reused many times across a module to avoid magic numbers and promote reusability
- Note: Inherited from `rv32_pkg.sv` and `rv32_core` top-level. See CPU Core Brief for HAS_M/HAS_A configuration.

| Name        | Default | Description                                          |
|-------------|---------|------------------------------------------------------|
| MUL_CYCLES  | 3       | Multiplier latency in cycles                         |
| DIV_CYCLES  | 5       | Divider latency in cycles                            |
| HAS_M       | 1       | Enable mul/div hardware                              |

---
#### **Interfaces (Ports)**
- Any external input or output signal that will be used by the EX stage
- Subject to change

| Signal Name     | Direction | Width | Description                                         |
| --------------- | --------- | ----- | --------------------------------------------------- |
| clk_i           | In        | 1     | Main clock input                                    |
| rst_ni          | In        | 1     | Active-low asynchronous reset                       |
| ctrl_i          | In        | 17    | Control signals to execute                          |
| alu_op          | In        | 5     | ALU operation selector                              |
| op_a_i          | In        | 32    | Register A operand (data) from RF                   |
| op_b_i          | In        | 32    | Register B operand (data) from RF                   |
| alu_res_o       | Out       | 32    | ALU result from processing operands                 |
| branch_taken_o  | Out       | 1     | Control signal for whether branch should be taken   |
| stall_o         | Out       | 1     | EX processing stall flag                            |
|                 |           |       |                                                     |

---
#### **Reset/Init**
- When performing a reset, the signal rst_ni becomes LOW (0), the CPU enters its default state
	- All registers are flushed
	- Control signals enter default values
---
#### **Behavior & Timing**
- One-Cycle ALU: All ALU outputs should be available within one cycle of processing request
- Multi-Cycle Mul/Div: Multiplier and divider should take multiple cycles, requiring stalls until processing is finished
	- Stalls should occur under busy/ready internal handshake signals (aka while working on operation, stall)
- Unique-Case FSM: A finite state machine (FSM), a sequential logic model for paths of outputs depending on inputs, should control output signals depending on specific operationctrl_*_os, such as initiating stalls upon multiply/divide and releasing at operation finish
- Redirect Signal: Upon determining branch output in one cycle, EX should send the result directly back to the fetch stage (IF) for the redirect to occur on the next cycle
- Memory Operations: All memory control signals and operations, unless needing execute, should bypass to MM stage on next cycle
	- FENCE.I Side-Effects: Since FENCE.I replaces old instructions with new ones, this instruction should bypass to MM stage
---
#### **Errors/IRQs**
- Division By Zero
- Overflow Handling
---
#### **Performance Targets**
- CPU should stall for at most five cycles due to EX
	- 1-cycle ALU, <= 5-cycle Mul/Div
---
#### **Dependencies**
- Memory (MM): *rtl/bus/core/mem_stage.sv*
- Writeback (WB): *rtl/bus/core/writeback.sv*
- RV32 Package: *rtl/cpu/pkg/rv32_pkg.sv*
---
#### **Verification Links**
- *sim/uvm/test_execute.sv*
	- SystemVerilog simulation environment to verify execute stage