The purpose of the VGA timing module is to generate the horizontal and vertical synchronization pulses and pixel coordinate signals required for standard VGA resolutions (e.g., 640×480 @ 60 Hz). It defines when each pixel should be drawn, when blanking intervals occur, and when sync pulses are active essentially acting as the heartbeat of the display pipeline. Other video blocks, such as the framebuffer controller or DAC driver, use these timing signals to know when to fetch and output video data.

Parameters

| Name      | Default | Description                                 |
| ----------| ------- | --------------------------------------------|
| H_RES     | 640     | Active horizontal pixels per line           |
| V_RES     | 480     | Active vertical pixels per frame            |
| H_FP      | 16      | Horizontal front porch (pixels)             |
| H_SYNC    | 96      | Horizontal sync pulse width (pixels)        |
| H_BP      | 48      | Horizontal back porch (pixels)              |
| V_FP      | 10      | Vertical front porch (lines)                |
| V_SYNC    | 2       | Vertical sync pulse width (lines)           |
| V_BP      | 2       | Vertical back porch (lines)                 |
| PIXEL_CLK | 25*10^6 | Pixel clock frequency for 640 by 480 @ 60Hz |

Interfaces (Ports)

| Signal       | Dir    | Width | Description                                                                                                 |
| ----         | ----   | ----  |-------------------------------------------------------------------------------------------------------------|
| clk          | Input  | 1     | Main pixel clock. Ensures timing logic and display pipeline stay synchronized                               |
| reset        | Input  | 1     | Active-low synchronous reset                                                                                |
| hsync        | Output | 1     | Horizontal sync pulse. Signals the end of a frame (start of new refresh)                                    |
| vsync        | Output | 1     | Vertical sync pulse. Signals the end of a frame (start of new fresh)                                        |
| x            | Output | 10    | Horizontal pixel counter (0-639 during active display)                                                      |
| y            | Output | 10    | Vertical pixel counter (0-479 during active display)                                                        |
| active_video | Output | 1     | High during visible display time; low during blanking intervals (used to gate pixel output or blank screen) |

Reset/Initialization

- On reset (reset = 0), all internal counters (x,y) reset to zero and both sync outputs (hsync, vsync) are deserted
- The module begins normal operation as soon as reset is released and a valid clk is present
- No external configuration sequence is required timing parameters are static or parametrized at synthesis

Behavior and Timing

- The module implements two nested counters:
  - The horizontal counter (x) increments every clock cycle
  - When x reaches the total pixels per line, it resets to zero and increments the vertical counter (y)
- hsync is asserted low for H_SYNC cycles after the active + front porch interval
- vsync is asserted low for V_SYNC lines after the active + front porch period
- The signal active_video is high only when both x and y are within the active display area
- The structure guarantees a 60 Hz refresh at 640 \* 480 with a 25 MHz pixel clock

Errors / IRQs

- This module does not generate interrupts or error signals
- It operates continuously as long as a valid clock is provided
- Any display synchronization or VSYNC interrupt is usually handled by the framebuffer controller

Dependencies

- Clock: Requires a stable pixel clock (typically 25 MHz).
- Reset: Synchronous, active-low (reset).
- Upstream IP: Clock generation block (PLL or divider).
- Downstream IP: Framebuffer controller or video DAC/encoder that consumes timing signals.

Summary

- The VGA timing generator defines the temporal structure of a video frame by driving sync pulses, counters, and valid video windows. It forms the foundation for raster-scan display logic and provides synchronization for all downstream video pipeline modules
