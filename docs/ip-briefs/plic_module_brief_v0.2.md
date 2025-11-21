# PLIC - Module Brief (v0.2)

**Owner:** Gavin Wiese  
**RTL:** rtl/irq/plic.sv

### Purpose & Role
The Platform-Level Interrupt Controller (PLIC) is placed near the CPU core, connected via the memory-mapped AXI bus. The PLIC manages and prioritizes external interrupt requests from up to 32 sources, forwarding only the highest-priority pending interrupt to the CPU. This allows the processor to efficiently handle asynchronous external events.

### Parameters  

- Number of interrupt sources: 32 (`N_SOURCES`)  
- Number of target contexts (CPU cores): 1 (`N_TARGETS`)  
- Priority field width per source: 3 bits (`PRIO_WIDTH`)  
- Interrupt ID width for claim/complete operations: 6 bits (`ID_WIDTH`)  

### Interfaces (Ports)  

| **Signal**    | **Dir** | **Width** | **Description**                             |
|---------------|---------|-----------|---------------------------------------------|
| clk_i         | in      | 1         | System clock                                |
| rst_ni        | in      | 1         | Active-low reset                            |
| src_i         | in      | 32        | External interrupt sources                  |
| ext_irq_o     | out     | 1         | Interrupt output to the CPU core            |

### Reset/Init  

An active-low reset (`rst_ni`) is used for the PLIC. When reset is asserted (`rst_ni = 0`), all internal registers are cleared to 0, and the output signal `ext_irq_o` reflects this reset value. All internal registers are reset synchronously with the system clock.  

### Behavior and Timing  

The PLIC continuously monitors the 32 `src_i` interrupt lines. When one or more enabled interrupts are pending, the highest-priority source is selected, and `ext_irq_o` is asserted to signal the CPU core. Once the CPU completes the interrupt, it writes back the interrupt ID, clearing the corresponding pending bit. All operations are synchronous with the system clock, and `ext_irq_o` is asserted one clock cycle after the conditions are met.  

### Programming Model

The PLIC provides three memory-mapped registers:

- **`priority`** – Stores the priority of each interrupt source. Higher values indicate higher priority.  
- **`enable`** – Determines which interrupt sources are enabled for the target CPU core.  
- **`claim`** – Used by the CPU to claim the highest-priority pending interrupt. Reading this register returns the interrupt ID, and writing the same ID back signals completion, clearing the pending bit.

All registers are accessible through the memory-mapped AXI bus at addresses defined in the SoC register map.

### Errors/IRQs

| **IRQ**    | **Source** | **Trigger**                       | **Clear**                           |
|------------|-----------|----------------------------------|-------------------------------------|
| ext_irq_o  | src_i     | One or more enabled interrupts pending | Cleared when CPU claims/completes via claim register |

The PLIC does not generate additional internal error signals; all interrupts come from external sources.

### Performance Targets

- `ext_irq_o` asserts within one clock cycle of a pending, enabled interrupt being detected.  
- All internal registers (priority, enable, claim/complete) update synchronously with the system clock.  
- The PLIC can handle all 32 external sources without loss of pending interrupts.

### Dependencies

The PLIC depends on `clk_i` to update internal registers and monitor interrupt sources, and on `rst_ni` to initialize registers. It also relies on the AXI memory-mapped bus to allow the CPU to access and configure priority, enable, and claim/complete registers. The external interrupt lines (`src_i`) provide all input events, and the PLIC drives the single interrupt output (`ext_irq_o`) to the CPU core.

### Verification Links

Verification for the PLIC is planned through simulation testbenches to confirm correct behavior of priority handling, enable bits, and the claim/complete mechanism. Testbenches will ensure that `ext_irq_o` asserts for the highest-priority pending interrupt, that pending bits are cleared after a claim/complete operation, and that the module responds correctly to reset (`rst_ni`).