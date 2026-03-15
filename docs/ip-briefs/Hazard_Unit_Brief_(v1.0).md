**Author:** Matias Yezzi
**RTL:** *rtl/cpu/core/hazard_unit.sv*

---

#### **Purpose & Role**

The Hazard Unit is the pipeline control and data forwarding subsystem for the 5-stage RISC-V CPU. It operates combinationally detect and resolve pipeline hazards:
- Data hazard detection: Load-use dependencies, multi-cycle ALU operation (divide)
- Control hazard detection: Illegal instructions
- Data forwarding: Bypass results from EX/MM and MM/WB directly to operands, eliminating unnecessary stalls
- Pipeline control: Generate stall/flush signals to freeze or remove instructions when hazards are detected

---

#### **Parameters**
- Parameters in Verilog/SystemVerilog are similar to constants and #define directives seen in C/C++ that are reused many times across a module to avoid magic numbers and promote reusability
- Note: Inherited from `rv32_pkg.sv` and `rv32_core` top-level

| Name        | Default | Description                                          |
|-------------|---------|------------------------------------------------------|
| DATA_WIDTH  | 32      | Operand width                                        |

---

#### **Interfaces (Ports)**

| Signal Name              | Direction | Width | Description                             |
| ------------------------ | --------- | ----- | ----------------------------------------|
| id_ex_rs1_i              | In        | 32    | Source register 1 from ID/EX            |
| id_ex_rs2_i              | In        | 32    | Source register 2 from ID/EX            |
| imm_i                    | In        | 32    | Immediate operand                       |
| ex_mm_rd_i               | In        | 32    | Destination register from EX/MM         |
| reg_ex_we                | In        | 1     | Register write enable (EX stage)        |
| mm_wb_rd_i               | In        | 32    | Destination register from MM/WB         |
| reg_mm_we                | In        | 1     | Register write enable (MM stage)        |
| ex_result_i              | In        | 32    | Result from (EX stage)                  |
| wb_result_i              | In        | 32    | Result from (WB stage)                  |
| alu_src_i                | In        | 1     | ALU operand B select (0=rs2, 1=imm)     |
| alu_stall_i              | In        | 1     | ALU busy flag                           |
| ex_mm_load_i             | In        | 1     | Load-use instruction flag from EX/MM    |
| ex_mm_fu_i               | In        | 3     | Functional unit type from EX/MM         |
| op_a_o                   | Out       | 32    | Operand A to EX (with forwarding)       |
| op_b_o                   | Out       | 32    | Operand B to EX (with forwarding)       |
| if_id_we_o               | Out       | 1     | IF/ID Register write enable (0=stall)   |
| pc_we_o                  | Out       | 1     | Program counter write enable (0=stall)  |
| cu_flush_o               | Out       | 1     | Control unit flush signal (1=stall)     |
| cu_stall_o               | Out       | 1     | Control unit stall signal (1=stall)     |

---

#### **Reset/Init**

- No sequential logic in hazard unit. All outputs are combinational and reset automatically when inputs change in accordance to pipeline registers

---

#### **Behavior & Timing**

All hazard detection and forwarding logic operates combinationally on pipeline register inputs, settling within one clock cycle:
- Hazard Detection: Compare register addresses and functional unit types across pipeline stages to identify data dependencies
- Data Forwarding: Read output values from execute (EX) and memory (MM) stages and, if meant for register needed to read from, substitute values for next instruction's register data output. If data cannot be forwarded yet (EX: waiting on memory cache), stall until it can
- Pipeline Control Decision: Determine if stall, flush, or normal operation is required; generate write-enable signals

---

#### **Errors/IRQs**

- Illegal Instruction Trap: Detected in decode, flag propagates through pipeline, hazard unit flushes ID/EX control signals

---

#### **Performance Targets**
- The entire hazard detection unit requires 0 additional cycles, but the divider stall takes more cycles due to execute divisor cycle length (5 cycles)

---

#### **Dependencies**

- ID/EX Pipeline Register: 
- EX/MM Pipeline Register: 
- MM/WB Pipeline Register:
- Divider Module: *rtl/cpu/core/division.sv*
- RV32 Package: *rtl/cpu/pkg/rv32_pkg.sv*

---

#### **Verification Links**
- SystemVerilog simulation environment to verify hazard unit 