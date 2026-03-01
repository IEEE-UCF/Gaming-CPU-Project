# i2s_tx — Module Brief (v0.1)

**Owner:** Jay Merveilleux  
**RTL:** `rtl/audio/i2s_tx.sv`

The `i2s_tx` module implements the digital audio transmit engine for the GamingCPU audio subsystem by converting parallel PCM audio samples into a serial I2S-compliant data stream for an external digital-to-analog converter (DAC). Acting as the timing master for the audio output path, `i2s_tx` generates the I2S bit clock (BCLK) and left/right word select (LRCLK) signals and shifts out audio sample data in strict alignment with these clocks. Audio samples are provided by an upstream buffering mechanism, typically fed by the audio DMA engine, allowing continuous real-time playback without CPU involvement on a per-sample basis. The module is designed for deterministic operation, ensuring stable audio timing and glitch-free output under sustained load.

---

## Parameters

- **Sample width** (default: 16 bits)  
  Defines the bit width of each PCM audio sample per channel.

- **Channel count** (default: 2)  
  Number of audio channels supported. The default configuration operates in stereo (left and right).

- **Clock divider configuration**  
  Controls derivation of the I2S bit clock and word select clock from the system clock, determining the effective audio sample rate.

- **Internal buffering depth**  
  Defines the amount of elastic buffering between the audio producer (DMA or FIFO) and the I2S shifter to absorb short-term timing variation.

- **Frame format**  
  Specifies I2S framing behavior, including MSB-first transmission and left-channel-first ordering.

---

## Interfaces (Ports)

| Signal          | Dir | Width | Description                                                    |
|-----------------|-----|-------|----------------------------------------------------------------|
| `clk_i`         | in  | 1     | System clock driving I2S timing generation and shift logic     |
| `rst_ni`        | in  | 1     | Active-low reset; clears internal state and disables output    |
| `sample_*`      | in  | —     | Audio sample input interface from DMA or buffering logic       |
| `sample_valid`  | in  | 1     | Indicates availability of a new stereo audio frame             |
| `sample_ready`  | out | 1     | Backpressure signal to upstream producer                       |
| `i2s_sdata_o`   | out | 1     | I2S serial data output                                         |
| `i2s_bclk_o`    | out | 1     | I2S bit clock                                                  |
| `i2s_lrclk_o`   | out | 1     | I2S left/right word select clock                               |
| `underrun_o`    | out | 1     | Indicates audio underrun condition                             |
| `irq_o`         | out | 1     | Optional interrupt signaling underrun event                    |

---

## Reset / Initialization

The `i2s_tx` module uses an active-low reset (`rst_ni`) to return all internal state to a known idle condition. When reset is asserted, I2S clock generation is halted, internal counters and shift registers are cleared, and the serial data output is driven to a benign state. No audio data is transmitted during reset, and underrun status is cleared. After reset deassertion, software configures the audio clocking parameters and enables the upstream audio pipeline before initiating audio transmission.

---

## Behavior & Timing

The `i2s_tx` module operates synchronously on the system clock (`clk_i`) and functions as a continuously running audio serializer once enabled. Audio samples are transmitted using standard I2S framing, with the left channel transmitted first, followed by the right channel, and data shifted out MSB-first. The module derives the I2S bit clock and word select clock internally, ensuring a fixed relationship between data transitions and clock edges. Sample words are loaded into internal shift registers at channel boundaries and transmitted serially at the programmed bit rate. Internal buffering allows limited decoupling between the audio producer and the strict timing requirements of the I2S interface.

---

## Programming Model

The `i2s_tx` module is configured through memory-mapped control registers defined in the audio/I2S register specification. Software programs the desired audio sample rate, enables the audio output path, and maintains the upstream audio ring buffer through the audio DMA engine. Once enabled, the module operates autonomously, continuously transmitting audio samples as long as valid data is supplied. Status registers allow software to monitor underrun conditions and overall audio health.

---

## Errors / IRQs

The primary error condition detected by `i2s_tx` is an audio underrun, which occurs when a new sample frame is required but no valid data is available from the upstream buffer. In this condition, the module outputs zero-valued samples to maintain valid I2S signaling and asserts an underrun status flag. An optional interrupt may be generated to notify software of the condition. Recovery is software-driven and involves refilling the audio buffer and clearing the underrun status.

---

## Performance Targets

- Sustains continuous real-time audio output at the configured sample rate  
- Supports 16-bit stereo PCM audio as the default operating mode  
- Maintains stable, jitter-free I2S clock generation  
- Tolerates short-term producer latency via internal buffering  
- Zero audible artifacts during steady-state operation  
- Graceful degradation to silence on underrun conditions  

---

## Dependencies

Depends on the system clock (`clk_i`), reset (`rst_ni`), and upstream audio buffering logic, typically provided by `audio_dma.sv`. Requires software configuration via the audio/I2S register set and relies on the platform interrupt controller for underrun notification. Proper operation assumes that the audio DMA and memory subsystem can sustain the required sample throughput.

---

## Verification Links

Verified using directed simulation testbenches that validate correct I2S framing, clock generation, and data ordering under normal operation. System-level audio simulations exercise continuous playback and underrun recovery behavior. Audio sink models observe serialized output for timing correctness and frame alignment. Known limitations include reliance on software for buffer sizing and the absence of formal timing verification across all possible clock divider configurations.
