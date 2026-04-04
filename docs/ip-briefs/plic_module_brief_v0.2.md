# PLIC - Module Brief (v1.0)

**Owner:** Gavin Wiese  
**RTL:** rtl/irq/plic.sv

### Purpose & Role
The Platform-Level Interrupt Controller (PLIC) is placed near the CPU core. The PLIC manages and prioritizes external interrupt requests from up to `NSOURCES` sources, forwarding only the highest-priority pending interrupt to the CPU. This allows the processor to efficiently handle asynchronous external events.

### Parameters  

- Number of interrupt sources: `NSOURCES` (default 8)  
- Priority field width per source: `PRIO_WIDTH` (default 3 bits)  
- Interrupt ID width: `SRC_ID_WIDTH` (default 3 bits)  

### Interfaces (Ports)  

| **Signal**           | **Dir** | **Width** | **Description**                                    |
|----------------------|---------|-----------|----------------------------------------------------|
| clk_i                | in      | 1         | System clock                                       |
| rst_ni               | in      | 1         | Active-low asynchronous reset                     |
| claim_req_i          | in      | 1         | CPU claim request pulse                           |
| complete_i           | in      | 1         | CPU interrupt completion pulse                    |
| src_i                | in      | NSOURCES  | External interrupt sources                         |
| priority_wdata       | in      | NSOURCES × PRIO_WIDTH | Data to write to all priority registers  |
| priority_we          | in      | 1         | Write enable for priority registers               |
| enable_wdata         | in      | NSOURCES  | Data to write to enable register                   |
| enable_we            | in      | 1         | Write enable for enable register                  |
| ext_irq_o            | out     | 1         | Interrupt output to the CPU core                  |
| claim_o              | out     | SRC_ID_WIDTH | Current claimed interrupt ID (1-based, 0 = none) |

### Reset/Init  

An active-low asynchronous reset (`rst_ni`) is used for the PLIC. When reset is asserted (`rst_ni = 0`), all internal registers—including `priorities`, `enable`, `pending`, and claim state—are cleared to 0, and the output signal `ext_irq_o` is deasserted.

### Behavior and Timing  

The PLIC continuously monitors the `src_i` interrupt lines. When one or more enabled interrupts are pending with nonzero priority and no interrupt is currently in service, the highest-priority source is selected and `ext_irq_o` is asserted to signal the CPU core.  

When the CPU asserts `claim_req_i`, the PLIC outputs the highest-priority enabled pending interrupt ID on `claim_o` (1-based) and clears that interrupt’s pending bit. While an interrupt is in service, `ext_irq_o` remains deasserted.  

When the CPU signals completion via `complete_i`, the in-service state is cleared, allowing the next pending interrupt (if any) to be delivered.  

All operations are synchronous with the system clock.

### Programming Model

The PLIC provides two sets of registers controlled via simple write-enable/data inputs:

- **`priority`** – Stores the priority of each interrupt source. Higher values indicate higher priority. Updated via `priority_wdata` and `priority_we`.  
- **`enable`** – Determines which interrupt sources are enabled. Updated via `enable_wdata` and `enable_we`.  

Claim and completion are handled via `claim_req_i` and `complete_i` handshake signals.

### Errors/IRQs

| **IRQ**    | **Source** | **Trigger**                       | **Clear**                           |
|------------|-----------|----------------------------------|-------------------------------------|
| ext_irq_o  | src_i     | One or more enabled interrupts pending with priority > 0 and no active claim | Cleared while in service; may reassert after completion |

The PLIC does not generate additional internal error signals; all interrupts come from external sources.

### Performance Targets

- `ext_irq_o` asserts when an enabled pending interrupt with nonzero priority exists and no interrupt is currently in service.  
- All internal registers (priority, enable, pending, claim state) update synchronously with the system clock.  
- The PLIC can handle all `NSOURCES` external sources without loss of pending interrupts.

### Dependencies

The PLIC depends on `clk_i` to update internal registers and monitor interrupt sources, and on `rst_ni` to initialize registers. External interrupt lines (`src_i`) provide input events, and the PLIC drives the single interrupt output (`ext_irq_o`) to the CPU core. Register updates are controlled via `_we` / `_wdata` inputs, and interrupt servicing uses the `claim_req_i` / `complete_i` handshake.

### Verification Links

Verification for the PLIC is planned through simulation testbenches to confirm correct behavior of priority handling, enable bits, and the claim/complete mechanism. Testbenches will ensure that `ext_irq_o` asserts for the highest-priority pending interrupt, that pending bits are cleared after a claim operation, and that the module responds correctly to reset (`rst_ni`).
