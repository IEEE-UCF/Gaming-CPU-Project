# GamingCPU — DMA Controller

**Owner:** Evan Eichholz | **RTL Target:** rtl/dma/dma_controller.sv | **Version:** v0.

## Purpose & Role

High-performance Direct Memory Access controller for autonomous data transfers between
memory and peripherals. Offloads bulk data movement from CPU, enabling concurrent
computation during video/audio/storage operations.

## Design Specifications

**AXI4 Master** - Full bus master for memory access **Multi-Channel** - 4 independent channels
with priority arbitration
**Scatter-Gather** - Linked list descriptor support **Burst Optimization** - Maximum bus
efficiency **Interrupt Driven** - Completion/error signaling

## Implementation Tasks

```
Task Decision Deliverable
```
```
Channel Arbitration Fixed priority Bandwidth allocation
```
```
Descriptor Fetch Hardware managed Automatic chain loading
```
```
Burst Control Adaptive sizing Optimal bus utilization
```
```
Error Handling Abort + interrupt Transfer recovery
```
```
Register Interface AXI-Lite Control/status access
```
## Channel Configuration

```
Channel Priority Use Case Burst Size
```
```
0 Highest Video Frame Buffer 16 beats
```
```
1 High Audio Sample Stream 8 beats
```
```
2 Medium SD Card Storage 4 beats
```
```
3 Low General Purpose Configurable
```
# INTERFACE DEFINITION

**Module:** dma_controller **Parameters:** CHANNELS = 4, DATA_W = 32

**Ports:**

```
clk_i, rst_ni - Clock and active-low reset
m_axi_awaddr[31:0] - AXI write address
m_axi_awlen[7:0] - AXI write burst length
m_axi_awvalid - AXI write address valid
```

m_axi_awready - AXI write address ready
m_axi_araddr[31:0] - AXI read address
m_axi_arlen[7:0] - AXI read burst length
m_axi_arvalid - AXI read address valid
m_axi_arready - AXI read address ready
s_axi_araddr[31:0] - Control read address
s_axi_arvalid - Control read valid
s_axi_arready - Control read ready
s_axi_awaddr[31:0] - Control write address
s_axi_awvalid - Control write valid
s_axi_awready - Control write ready
irq_done_o[CHANNELS-1:0] - Transfer complete interrupts
irq_error_o[CHANNELS-1:0] - Error interrupts
