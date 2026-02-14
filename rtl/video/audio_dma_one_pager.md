# audio_dma — Module Brief (v0.1)

**Owner:** Jay Merveilleux  
**RTL:** `rtl/audio/audio_dma.sv`

The `audio_dma` module implements the streaming direct memory access (DMA) engine for the GamingCPU audio subsystem. It autonomously transfers audio sample data from system memory into a local buffering interface that feeds downstream audio output blocks such as `i2s_tx` or `pwm_audio`. Designed around a ring-buffer model, `audio_dma` allows software to continuously produce audio samples into memory while hardware consumes them at a deterministic rate, decoupling real-time audio playback from CPU scheduling and instruction execution. By issuing burst-based AXI read transactions, the module sustains audio throughput with minimal bus overhead and predictable latency.

---

## Parameters

- **Address width**  
  Width of the AXI address bus and internal address counters, defining the maximum addressable audio buffer size in system memory.

- **Data width**  
  Width of AXI read data beats, typically aligned to the system memory and interconnect configuration.

- **Ring buffer size**  
  Defines the total size of the circular audio buffer in bytes or samples.

- **Burst length**  
  Controls the maximum AXI read burst size used when fetching audio data, balancing latency and bus efficiency.

- **FIFO depth**  
  Depth of internal buffering between AXI read responses and the downstream audio sink.

---

## Interfaces (Ports)

| Signal            | Dir | Width | Description                                                          |
|-------------------|-----|-------|----------------------------------------------------------------------|
| `clk_i`           | in  | 1     | System clock driving DMA control logic                               |
| `rst_ni`          | in  | 1     | Active-low reset; clears internal state and halts DMA operation      |
| `enable_i`        | in  | 1     | Enables audio DMA operation                                          |
| `buf_base_i`      | in  | ADDR  | Base address of audio ring buffer in system memory                   |
| `buf_size_i`      | in  | SIZE  | Total size of ring buffer                                            |
| `rd_ptr_i`        | in  | ADDR  | Read pointer supplied by software or internal state                  |
| `axi_ar_*`        | out | —     | AXI read address channel                                             |
| `axi_r_*`         | in  | —     | AXI read data channel                                                |
| `sample_*`        | out | —     | Audio sample stream output to downstream audio blocks                |
| `sample_valid_o`  | out | 1     | Indicates valid audio sample data                                    |
| `sample_ready_i`  | in  | 1     | Backpressure from downstream consumer                                |
| `underrun_o`      | out | 1     | Indicates ring buffer underrun condition                             |
| `irq_o`           | out | 1     | Optional interrupt signaling underrun or threshold events            |

---

## Reset / Initialization

The `audio_dma` module uses an active-low reset (`rst_ni`) to return all internal state to a known idle condition. When reset is asserted, all AXI transactions are halted, internal FIFOs are flushed, address counters are cleared, and no audio samples are emitted. Underrun status is cleared, and interrupt outputs are deasserted. After reset deassertion, software programs the ring buffer base address, buffer size, and initial read/write pointers before enabling DMA operation.

---

## Behavior & Timing

The `audio_dma` module operates synchronously on the system clock (`clk_i`) as a continuously running streaming DMA engine. When enabled, it issues AXI read transactions to fetch audio data from the configured ring buffer in memory. Address generation advances sequentially through the buffer and wraps automatically at the end of the configured buffer region, implementing circular addressing semantics.

Read data returned over the AXI interface is queued into an internal FIFO, decoupling memory access timing from the fixed consumption rate of the downstream audio output block. Data is presented to the consumer using a valid/ready handshake. AXI read bursts are sized to maximize sustained bandwidth while minimizing arbitration overhead on the shared interconnect.

---

## Programming Model

The `audio_dma` module is configured through memory-mapped control registers defined in the audio/DMA register specification. Software initializes the audio ring buffer in memory and programs buffer base address, buffer size, and control flags before enabling DMA operation. During playback, software advances the producer write pointer independently, while `audio_dma` advances the consumer read pointer autonomously. Status registers allow software to monitor buffer occupancy and detect underrun conditions.

---

## Errors / IRQs

The primary error condition detected by `audio_dma` is a buffer underrun, which occurs when the DMA engine attempts to fetch audio data beyond the available produced samples. In this condition, the module asserts an underrun status flag and may generate an interrupt to notify software. Depending on configuration, the DMA engine may stall, continue issuing reads that return invalid data, or output zero-valued samples downstream until the buffer is refilled. Recovery is software-driven and involves replenishing the ring buffer and clearing the underrun status.

---

## Performance Targets

- Sustains continuous audio streaming at the configured sample rate  
- Supports burst-based AXI reads aligned to cache-line boundaries  
- Maintains deterministic sample delivery to downstream audio blocks  
- Tolerates short-term memory latency via internal buffering  
- No audible glitches during steady-state operation  
- Graceful handling of underrun conditions  

---

## Dependencies

Depends on the system clock (`clk_i`), reset (`rst_ni`), AXI memory fabric, and backing system memory. Requires a downstream audio consumer such as `i2s_tx` or `pwm_audio`. Software must configure valid ring buffer parameters via the audio/DMA register specification. The AXI interconnect must provide sufficient bandwidth to sustain real-time audio fetches under worst-case contention.

---

## Verification Links

Verified using directed simulation testbenches validating ring buffer wraparound behavior, AXI burst alignment, and backpressure handling. System-level audio simulations confirm sustained playback under memory contention and proper underrun detection. AXI memory models observe read access patterns and FIFO behavior. Known limitations include reliance on software for correct buffer sizing and the absence of formal verification for extreme arbitration scenarios.
