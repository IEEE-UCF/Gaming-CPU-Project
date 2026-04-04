**Author:** Sebastian Candelaria
**RTL:** *rtl/cpu/core/mem_stage.sv*

---
#### **Purpose & Role**
- The Memory (MM) stage is the 4th stage in a standard 5-stage RISC-V pipeline. At each clock cycle, if given a memory instruction, the memory stage requests a load (CPU data receive) or store (CPU data send) from the data cache (D$).
	- MM stage must interface with the D$ and memory management unit (MMU)
	- Should at best take two cycles total: One for memory request, and one for any data send (similar to IF stage with instruction cache)

---
#### **Parameters**
- Parameters in Verilog/SystemVerilog are similar to constants and #define directives seen in C/C++ that are reused many times across a module to avoid magic numbers and promote reusability
- Note: Inherited from `rv32_pkg.sv` and `rv32_core` top-level. See CPU Core Brief for HAS_M/HAS_A configuration.

| Name        | Default | Description                                          |
|-------------|---------|------------------------------------------------------|
| HAS_A       | 1       | Enable LR/SC atomic support                          |
| ADDR_WIDTH  | 32      | Address bus width                                    |
| DATA_WIDTH  | 32      | Data bus width                                       |

---
#### **Interfaces (Ports)**
- Any external input or output signal that will be used by the MM stage (subject to change)

| Signal Name              | Direction | Width | Description                                              |
| ------------------------ | --------- | ----- | -------------------------------------------------------- |
| clk_i                    | In        | 1     | Main clock input                                         |
| rst_ni                   | In        | 1     | Active-low asynchronous reset                            |
| ls_ctrl_load_i           | In        | 1     | Load control signal                                      |
| ls_ctrl_store_i          | In        | 1     | Store control signal                                     |
| ls_ctrl_size_i           | In        | 1     | Load/store size control signal                           |
| ls_ctrl_unsigned_i       | In        | 1     | Load/store unsigned control signal                       |
| ls_ctrl_write_en_i       | In        | 1     | Load/store write-enable control signal                   |
| ex_res_i                 | In        | 32    | EX stage result, typically used as memory address        |
| dc_req_o                 | In        | 1     | Data cache request                                       |
| dc_rsp_i                 | Out       | 1     | Data cache response                                      |
| mmu_access_o             | Out       | 1     |                                                          |
| mmu_ready_i              | In        | 1     |                                                          |
| mmu_page_fault_i         | In        | 1     |                                                          |
| mmu_access_fault_i       | In        | 1     |                                                          |
| wb_data_o                | Out       | 32    | Resulting data from cache or EX for writeback (WB) stage |
| mem_stall_o              | Out       | 1     |                                                          |
| mem_exception_o          | Out       | 1     | Cache exception flag                                     |
| mem_exception_type_o     | Out       | 2     |                                                          |
|                          |           |       |                                                          |

---
#### **Reset/Init**
- When performing a reset, the signal rst_ni becomes LOW (0), the CPU enters its default state
	- All registers are flushed
	- Control signals enter default values
---
#### **Behavior & Timing**
- Miss Handling: Upon cache missing data (not finding it), issue AXI for memory request from RAM (communicate on how this should work)
	- Pipeline will need to stall as a result, thus have signal for this
- Memory Alignment: Cache or MMU should be able to align data in memory as needed, but communicate with sub-groups (Cache & MMU) on how this will work
- Atomic Pass-Through: Atomic (A) instructions, indivisible/top-priority memory operations, should pass-through/bypass cache directly to MMU
	- Deal with any consequences/processes involving atomics, including aborting operation on reservation loss
- Store Byte-Enable Generation: When storing values of different sizes (half-words, bytes, etc.), you should indicate which bytes need to be written by cache (communicate on how this should work)
- Load Bit-Extension: For unsigned/signed values smaller than word-size, extend sign-bit as needed
---
#### **Errors/IRQs**
- Load/Store Access Fault
- Page Fault
- Misalignment Exception
---
#### **Performance Targets**
- Aim to handle most memory operations in <= 2 cycles (mostly on cache and MMU to accomplish)
---
#### **Dependencies**
- Writeback (WB): *rtl/bus/core/writeback.sv*
- AXI: *rtl/bus/axi/axi_crossbar.sv*
	- AXI connection to fetch instructions and data from memory hierarchy (ideally cache, main memory upon miss)
- Cache: *rtl/mem/cache/dcache.sv*
- MMU: *rtl/cpu/mmu/sv32_mmu.sv*
- RV32 Package: *rtl/cpu/pkg/rv32_pkg.sv*
---
#### **Verification Links**
- *sim/uvm/test_memory.sv*
	- SystemVerilog simulation environment to verify memory stage