# PLIC - Module Brief (v0.3)

**Owner:** Gavin Wiese  
**RTL:** rtl/irq/plic.sv

### Purpose & Role
The Platform-Level Interrupt Controller (PLIC) is placed near the CPU core. The PLIC manages and prioritizes external interrupt requests from up to 32 sources, forwarding only the highest-priority pending interrupt to the CPU. This allows the processor to efficiently handle asynchronous external events.

### Parameters  

- Number of interrupt sources: 32 (`NSOURCES`)  
- Priority field width per source: 3 bits (`PRIO_WIDTH`)  
- Interrupt ID width for claim/complete operations: `$clog2(NSOURCES)`  

### Interfaces (Ports)  

| **Signal**           | **Dir** | **Width** | **Description**                                    |
|----------------------|---------|-----------|----------------------------------------------------|
| clk_i                | in      | 1         | System clock                                       |
| rst_ni               | in      | 1         | Active-low asynchronous reset                     |
| src_i                | in      | 32        | External interrupt sources                         |
| priority_wdata       | in      | 96        | Data to write to all priority registers (32 × 3)  |
| priority_we          | in      | 1         | Write enable for priority registers               |
| enable_wdata         | in      | 32        | Data to write to enable register                   |
| enable_we            | in      | 1         | Write enable for enable register                  |
| claim_wdata          | in      | 5         | Claim complete input                               |
| claim_we             | in      | 1         | Write enable for claim completion                 |
| ext_irq_o            | out     | 1         | Interrupt output to the CPU core                  |
| claim_o              | out     | 5         | Current claimed interrupt ID                      |

### Reset/Init  

An active-low asynchronous reset (`rst_ni`) is used for the PLIC. When reset is asserted (`rst_ni = 0`), all internal registers—including `priorities`, `enable`, `pending`, and `claim`—are cleared to 0, and the output signal `ext_irq_o` is deasserted.

### Behavior and Timing  

The PLIC continuously monitors the 32 `src_i` interrupt lines. When one or more enabled interrupts are pending, the highest-priority source is selected, and `ext_irq_o` is asserted to signal the CPU core. Once the CPU completes the interrupt (signaled via `claim_we`), the pending bit for that interrupt is cleared and `ext_irq_o` deasserts. All operations are synchronous with the system clock, and `ext_irq_o` asserts one clock cycle after the conditions are met.  

### Programming Model

The PLIC provides three sets of registers controlled via simple write-enable/data inputs:

- **`priority`** – Stores the priority of each interrupt source. Higher values indicate higher priority. Updated via `priority_wdata` and `priority_we`.  
- **`enable`** – Determines which interrupt sources are enabled. Updated via `enable_wdata` and `enable_we`.  
- **`claim`** – Contains the currently claimed interrupt ID. Writing to this register with `claim_wdata` and `claim_we` signals completion, clearing the pending bit.  

All registers are accessible through the `_we` / `_wdata` inputs in this bus-free implementation.

### Errors/IRQs

| **IRQ**    | **Source** | **Trigger**                       | **Clear**                           |
|------------|-----------|----------------------------------|-------------------------------------|
| ext_irq_o  | src_i     | One or more enabled interrupts pending | Cleared when CPU signals completion via claim input |

The PLIC does not generate additional internal error signals; all interrupts come from external sources.

### Performance Targets

- `ext_irq_o` asserts within one clock cycle of a pending, enabled interrupt being detected.  
- All internal registers (priority, enable, claim/complete, pending) update synchronously with the system clock.  
- The PLIC can handle all 32 external sources without loss of pending interrupts.

### Dependencies

The PLIC depends on `clk_i` to update internal registers and monitor interrupt sources, and on `rst_ni` to initialize registers. External interrupt lines (`src_i`) provide input events, and the PLIC drives the single interrupt output (`ext_irq_o`) to the CPU core. Register updates are controlled via `_we` / `_wdata` inputs.

### Verification Links

Verification for the PLIC is planned through simulation testbenches to confirm correct behavior of priority handling, enable bits, and the claim/complete mechanism. Testbenches will ensure that `ext_irq_o` asserts for the highest-priority pending interrupt, that pending bits are cleared after a claim/complete operation, and that the module responds correctly to reset (`rst_ni`).  
