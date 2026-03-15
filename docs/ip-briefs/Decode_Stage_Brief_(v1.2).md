**Author:** Sebastian Candelaria
**RTL:** *rtl/cpu/core/decode.sv*

---
#### **Purpose & Role**
- The Instruction Decode (ID) stage is the 2nd stage in a standard 5-stage RISC-V pipeline. At each clock cycle, the decode stage translates an instruction into data values and control signals to direct the rest of the pipeline
	- For any instructions involving register-reading, the decode stage will retrieve the data from the register file (RF) 
	- Any instruction operation codes (opcodes) or encoded immediate/constant values (imm values) are translated into control signals and real, usable values

---
#### **Parameters**
- Parameters in Verilog/SystemVerilog are similar to constants and #define directives seen in C/C++ that are reused many times across a module to avoid magic numbers and promote reusability
- Note: Inherited from `rv32_pkg.sv` and `rv32_core` top-level. See CPU Core Brief for HAS_M/HAS_A configuration.

| Name        | Default | Description                                          |
|-------------|---------|------------------------------------------------------|
| HAS_M       | 1       | Enable RV32M instruction decoding                    |
| HAS_A       | 1       | Enable RV32A instruction decoding                    |
| DATA_WIDTH  | 32      | Operand width                                        |

---
#### **Interfaces (Ports)**
- Any external input or output signal that will be used by the ID stage
- Subject to change

| Signal Name              | Direction | Width | Description                              |
| ------------------------ | --------- | ----- | -----------------------------------------|
| clk_i                    | In        | 1     | Main clock input                         |
| rst_ni                   | In        | 1     | Active-low asynchronous reset            |
| instr_i                  | In        | 32    | Fetched instruction                      |
| rf_a_i                   | In        | 32    | Register A operand from RF               |
| rf_b_i                   | In        | 32    | Register B operand from RF               |
| rf_a_o                   | Out       | 32    | Register A operand to EX stage           |
| rf_b_o                   | Out       | 32    | Register B operand to EX stage           |
| imm_o                    | Out       | 32    | Immediate operand to EX stage            |
| trap_o		           | Out       | 1     | Illegal Instruction signal               |
| ctrl_o                   | Out       | 17    | Control signals for later stages         |
| fu_selec_o               | Out       | 3     | Functional unit selector to EX stage     |
| amo_aq_o                 | Out       | 1     | Atomic memory acquire flag               |
| amo_rl_o                 | Out       | 1     | Atomic memory release flag               |
| amo_op_o                 | Out       | 4     | Atomic memory operation flag             |
| pred_o                   | Out       | 4     | Fence predecessor                        |
| succ_o				   | Out	   | 4	   | Fence successor						  |
| fence_o				   | Out	   | 1	   | Fence instruction flag				      |


---
#### **Reset/Init**
- When performing a reset, the signal rst_ni becomes LOW (0), the CPU enters its default state
	- All registers are flushed
	- Control signals enter default values
---
#### **Behavior & Timing**
- One-Cycle Decode: Entire decode process should occur within one cycle
	- Control Signals: Decode stage must produce control signals for following stages based on given instruction, likely through a control unit (CU) or FSM if needed
- Hazard/Flush: Upon encountering a pipeline hazard, such as branch calculation, decode should flush execute/memory stage
	- Illegal instructions should raise a trap(error) cause, leading into trap subroutine execution
---
#### **Errors/IRQs**
- Illegal Instruction Trap
---
#### **Performance Targets**
- 1-cycle execution
---
#### **Dependencies**
- Execute (EX): *rtl/bus/core/execute.sv*
- Memory (MM): *rtl/bus/core/mem_stage.sv*
- RV32 Package: *rtl/cpu/pkg/rv32_pkg.sv*
---
#### **Verification Links**
- *sim/uvm/test_decode.sv*
	- SystemVerilog simulation environment to verify decode stage