# CLINT - Module Brief (v0.3)

**Owner:** Gavin Wiese  
**RTL:** rtl/irq/clint.sv  

### Purpose & Role
The Core Local Interruptor (CLINT) is placed near the CPU core, as interrupts are sent directly to the core via memory. The CLINT provides two types of interrupts: **timer-based** (`timer_irq_o`) and **software-based** (`soft_irq_o`). It ensures that events from the timer or software are recognized promptly by the CPU.

### Parameters  

- Timer Width: 64 bits (`mtime` and `mtimecmp` registers)  
- Software interrupt width: 1 bit (`msip`)  
- Software interrupt output width: 1 bit (`soft_irq_o`)  
- Timer interrupt output width: 1 bit (`timer_irq_o`)  

### Interfaces (Ports)  

| **Signal**     | **Dir** | **Width** | **Description**                  |
|----------------|---------|-----------|----------------------------------|
| mtime_o        | out     | 64        | Current timer value              |
| timer_irq_o    | out     | 1         | Timer interrupt output           |
| soft_irq_o     | out     | 1         | Software interrupt output        |
| clk_i          | in      | 1         | System clock                     |
| rst_ni         | in      | 1         | Active-low reset                 |
| msip_we        | in      | 1         | Write enable for `msip` register |
| msip_wdata     | in      | 1         | Data to write to `msip`          |
| mtimecmp_we    | in      | 1         | Write enable for `mtimecmp` register |
| mtimecmp_wdata | in      | 64        | Data to write to `mtimecmp`      |

### Reset/Init  

An active-low reset (`rst_ni`) is used for the CLINT. When reset is asserted (`rst_ni = 0`), all internal registers—`mtime`, `mtimecmp`, and `msip`—are cleared to 0, and output signals (`mtime_o`, `timer_irq_o`, `soft_irq_o`) reflect these reset values. All values are reset synchronously with the system clock. Once reset is deasserted (`rst_ni = 1`), the `mtime` counter begins incrementing every clock cycle, and the interrupt outputs (`timer_irq_o` and `soft_irq_o`) update according to the current register states.

### Behavior and Timing

`mtime` increments by one on every rising edge of the system clock. When `mtime` becomes greater than or equal to `mtimecmp`, the timer interrupt output `timer_irq_o` is asserted and remains asserted until a new, greater `mtimecmp` value is written. The software interrupt output `soft_irq_o` directly reflects the state of the `msip` register. All operations are synchronous with the system clock, and outputs update on the cycle following their trigger conditions.

### Programming Model

The CLINT exposes three memory-mapped registers:

- **`msip`** – Software interrupt pending. Writing a `1` to bit 0 asserts `soft_irq_o` until cleared.  
- **`mtimecmp`** – Timer compare register. When the internal 64-bit counter `mtime` reaches or exceeds this value, `timer_irq_o` is asserted until a new, greater value is written.  
- **`mtime`** – A 64-bit free-running counter that increments at the system clock rate. Software can read this register for timing purposes.

All registers are accessible via write-enable and data inputs (`*_we`, `*_wdata`).

### Errors/IRQs

| **IRQ**        | **Source** | **How it's triggered**          | **How it's cleared**                            |
|----------------|------------|--------------------------------|------------------------------------------------|
| timer_irq_o    | mtimecmp   | Asserted when mtime >= mtimecmp | Cleared when a new, greater mtimecmp is written |
| soft_irq_o     | msip       | Reflects the value of the msip register | Cleared by writing 0 to msip          |

The CLINT does not generate additional error signals.

### Performance Targets

- `mtime` increments every clock cycle in sync with the system clock.  
- Timer and software interrupts (`timer_irq_o` and `soft_irq_o`) are asserted within one clock cycle of their triggering condition.

### Dependencies

The CLINT depends on `clk_i` to increment `mtime` and `rst_ni` to initialize internal registers. Write-enable (`*_we`) and write-data (`*_wdata`) inputs are required to update the `msip` and `mtimecmp` registers. It must be connected to the CPU core so software can receive the interrupt outputs.

### Verification Links

Verification for the CLINT is planned through simulation testbenches to confirm correct behavior of the internal 64-bit timer (`mtime`), timer compare (`mtimecmp`), and software interrupt (`msip`) functionality. Testbenches will ensure that `timer_irq_o` and `soft_irq_o` assert under the correct conditions and that the module responds correctly to reset (`rst_ni`).  
