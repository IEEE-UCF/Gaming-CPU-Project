### **axi_crossbar — Module Brief (v0.2)**
|**Owner:** Sebastian Candelaria and Bus System Team | **RTL:** rtl/bus/axi/axi_crossbar.sv |
| :-|-: |
---
### **Purpose & Role**
Central AXI4 interconnect between managers and subordinates. Performs address decode, per-subordinate channel arbitration, and ID-based routing so multiple transactions can be outstanding concurrently. Common widths/IDs are defined in **rtl/bus/interconnect_pkg.sv.**

---

### **System Context (Managers/Subordinates)**
- **Managers:** I$ port **axi_icache_port.sv**, D$ port **axi_dcache_port.sv**, DMA **axi_dma.sv**, and the MMU Page Table Walker **rtl/cpu/mmu/ptw.sv.**
- **Subordinates:** DDR via **rtl/mem/ddr/mig_axi_wrap.sv**, peripheral MMIO via **rtl/bus/axi/axi_to_axi_lite.sv** into **rtl/subsys/periph_axi_shell.sv.**
- **CDC:** When a clock crossing is required, channels use **axi_async_fifo.sv.**
***
### **Interfaces (Ports)**
---

| Signal/Bundle | Dir | Width | Description |
|---|:---:|:---:|---|
| `s_axi_*[N_M]` | In | — | Subordinate-side inputs from managers (I\$, D\$, DMA, PTW). |
| `m_axi_*[N_S]` | Out | — | manager-side outputs to subordinates (DDR, AXI-Lite bridge, etc.). |
| `clk_i`, `rst_ni` | In | 1 | Fabric clock and active-low reset. |
---

### Parameters & Configuration 
- Number of managers/subordinates, ID width, and data/address widths are set via **interconnect_pkg.sv.**
- Address windows correspond to the SoC memory map (DDR and MMIO ranges).
---

### Errors/IRQs

- **IRQs:** None as the crossbar does not raise any interrupts. The interrupts would come from the peripherals.
- **Errors:** Conveyed only though AXI response codes and the crossbar should either pass through a subordinate's error or generate one itself for decode/feature violations.
---

### Performance Targets

- **Clock:** **TBD** MHz (ASIC), **TBD** MHz (FPGA)
- **Throughput:** **1 beat/cycle** once granted (R & W)
- **Latency (xbar-only):** addr → grant ≤ 2 cycles; read addr → first data ≤ 3 cycles beyond subordinate; last-W → B ≤ 3 cycles
- **Arbitration:** **Round-robin;** starvation ≤ **N_M grants**
- **Bursts:** **INCR**, max len **TBD**
- **Outstanding:** per-manager **TBD R/TBD W**; backpressure only
- **CDC:** each crossing adds **+TBD cycles;** throughput unchanged
- **Reset:** READY may assert within ≤ **TBD cycles** after `rst_ni` deassert 
---

### Behavior & Timing

- Per-subordinate arbitration and decode; maintains AXI ready/valid ordering on all channels (AW/W/B/AR/R).
- Supports multiple outstanding transactions using `AXI ID` tagging; responses are routed back by ID.
- Designed for the system clock domain; CDC handled externally via **axi_async_fifo.sv** where required.
---

### Dependencies
- **Clocks/Reset:** clk_i, rst_ni (system domain; sync release).
- **Upstream managers (initiate AXI):** I$ port, D$ port, SMA engine, Page Table Walker.
- **Downstream subordinates (serve AXI):** DDR controller, AXI → AXI-Lite bridge into Peripheral Shell.
- **Configuration source:** address windows, ID/Data/Addr widths defined in the interconnect package.
- **CDC:** any clock crossings are handled *outside* the crossbar via AXI async FIFOs on the affected ports.
---

### Verification Links
- **AXI memory model testbench:** sim/common/tb_axi_mem.sv
- **System integration (exercises crossbar paths):** sim/cocotb/test_sd_spi.py, sim/cocotb/test_video_scanout.py, sim/cocotb/test_audio_i2s.py, sim/cocotb/test_mmu_sv32.py
