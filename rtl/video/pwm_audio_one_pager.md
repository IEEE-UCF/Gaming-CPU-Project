# pwm_audio — Module Brief (v0.1)

**Owner:** Jay Merveilleux  
**RTL:** `rtl/audio/pwm_audio.sv`

The `pwm_audio` module implements a simple pulse-width modulation (PWM) based audio output for the GamingCPU SoC. It provides a low-complexity, hardware-minimal audio path by converting digital audio sample amplitudes into a single-bit PWM waveform suitable for direct output to a GPIO pin or simple external low-pass filter. This module serves as a fallback or development-friendly audio solution when a full I2S DAC is unavailable, enabling basic sound output without additional external hardware. Once configured and enabled, `pwm_audio` operates autonomously, continuously converting incoming audio samples into a time-averaged analog signal via PWM duty-cycle modulation.

---

## Parameters

- **Sample width** (default: 8–16 bits)  
  Defines the resolution of the input audio sample used to compute the PWM duty cycle.

- **PWM counter width**  
  Determines the resolution of the PWM waveform and the effective audio dynamic range.

- **PWM carrier frequency**  
  Sets the PWM switching frequency relative to the system clock, trading off audio fidelity against output pin bandwidth and filtering requirements.

- **Sample update rate**  
  Defines how often a new audio sample is latched and applied to the PWM duty cycle.

---

## Interfaces (Ports)

| Signal          | Dir | Width | Description                                                    |
|-----------------|-----|-------|----------------------------------------------------------------|
| `clk_i`         | in  | 1     | System clock driving PWM generation and sample update logic    |
| `rst_ni`        | in  | 1     | Active-low reset; clears PWM state and disables output         |
| `enable_i`      | in  | 1     | Enables PWM audio output                                       |
| `sample_i`      | in  | N     | Digital audio sample input                                     |
| `sample_valid`  | in  | 1     | Indicates availability of a new audio sample                   |
| `sample_ready`  | out | 1     | Backpressure to upstream sample producer                       |
| `pwm_o`         | out | 1     | PWM audio output signal                                        |
| `underrun_o`    | out | 1     | Indicates sample underrun condition                            |
| `irq_o`         | out | 1     | Optional interrupt signaling underrun event                    |

---

## Reset / Initialization

The `pwm_audio` module uses an active-low reset (`rst_ni`) to return all internal state to a known idle condition. When reset is asserted, the PWM output is driven low, internal counters are cleared, and any latched audio sample state is discarded. No PWM waveform is generated during reset. After reset deassertion, software programs the desired PWM configuration parameters and enables audio output. Normal operation begins once valid audio samples are provided.

---

## Behavior & Timing

The `pwm_audio` module operates synchronously on the system clock (`clk_i`). Incoming audio samples are latched at the configured sample update rate and mapped to a PWM duty cycle proportional to the sample amplitude. A free-running PWM counter compares against the latched duty value to generate a single-bit output waveform. The time-averaged value of this waveform, when passed through an external low-pass filter or speaker inertia, produces an analog audio signal.

The PWM carrier frequency is fixed relative to the system clock and is independent of the audio sample rate. Internal buffering allows limited decoupling between sample production and PWM generation, ensuring stable output timing.

---

## Programming Model

The `pwm_audio` module is configured through memory-mapped control registers defined in the audio/PWM register specification. Software selects PWM resolution, enables the output path, and supplies audio samples either directly or via a shared audio buffering mechanism. Once enabled, the module continuously generates PWM output using the most recent valid sample until updated.

---

## Errors / IRQs

The primary error condition detected by `pwm_audio` is a sample underrun, which occurs when a new audio sample is required but no valid data is available. In this condition, the module maintains the previous duty cycle or drives the output to a safe default level and asserts an underrun status flag. An optional interrupt may be generated to notify software. Recovery is software-driven and involves supplying new audio samples and clearing the underrun condition.

---

## Performance Targets

- Supports basic mono audio output for diagnostics and fallback use  
- Deterministic PWM carrier frequency with stable duty-cycle generation  
- Tolerates moderate sample jitter via internal latching  
- Minimal hardware resource utilization  
- No audible glitches during steady-state operation  
- Graceful degradation during underrun conditions  

---

## Dependencies

Depends on the system clock (`clk_i`) and reset (`rst_ni`) and requires an upstream audio sample source, typically shared with the main audio pipeline. Optional interrupt signaling is routed through the platform interrupt controller. External filtering or speaker characteristics are required to convert the PWM signal into an analog waveform suitable for listening.

---

## Verification Links

Verified using directed simulation testbenches validating duty-cycle generation, sample latching behavior, and reset operation. System-level tests confirm audible output on hardware platforms using external passive filtering. Known limitations include reduced audio fidelity compared to I2S-based output and reliance on external filtering for acceptable sound quality.
