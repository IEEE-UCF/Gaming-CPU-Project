# fb_ctrl - Module Brief (v0.1)

**Owner:** Jay Merveilleux  
**RTL:** `rtl/video/fb_ctrl.sv`

The `fb_ctrl` module implements the display scanout engine for the video subsystem by autonomously reading pixel data from a framebuffer stored in system memory and delivering it to the video output pipeline in precise synchronization with VGA timing. A framebuffer is a memory-resident image buffer in which each location represents the color of a screen pixel; `fb_ctrl` continuously scans this memory in raster order-left to right, top to bottom-using DMA-style AXI reads driven by the active display timing. The module supports configurable base address and stride, enabling flexible memory layout and efficient, cache-aligned access to frame data. To prevent visual artifacts such as tearing, `fb_ctrl` employs double buffering, displaying one framebuffer while another is updated and performing buffer swaps only at vertical sync boundaries. In addition, the controller expands indexed pixel formats via palette or colormap lookup and raises a VSYNC interrupt to coordinate safe rendering and buffer management with software.

---

## Parameters

- **H_RES** (default: 640)  
  Defines the horizontal resolution of the active display area and the number of pixels scanned per line.

- **V_RES** (default: 480)  
  Defines the vertical resolution of the active display area and the total number of visible lines per frame.

- **Pixel format / data width**  
  Number of bits per pixel fetched from framebuffer memory. The default configuration uses 8-bit indexed color expanded to RGB via palette/COLORMAP logic.

- **Address width**  
  Width of framebuffer base address and internal address counters, defining the maximum addressable framebuffer size in system memory.

- **Stride support**  
  Programmable line stride allowing each framebuffer row to begin at a configurable byte offset, supporting padded or cache-line-aligned layouts.

- **AXI burst length / beat size**  
  Controls AXI read burst sizing during scanout to maximize sustained memory bandwidth and minimize bus overhead.

- **Double-buffer enable**  
  Enables front/back framebuffer operation with swaps applied only at VSYNC boundaries.

- **Scaling mode**  
  Optional pixel replication used for resolution upscaling (e.g., 320*200 source scaled to 640*480 output).

---

## Interfaces (Ports)

| Signal           | Dir | Width  | Description                                                               |
|------------------|-----|--------|---------------------------------------------------------------------------|
| `clk_i`          | in  | 1      | System clock driving framebuffer control logic and DMA request generation |
| `rst_ni`         | in  | 1      | Active-low reset; clears internal state and disables scanout              |
| `enable_i`       | in  | 1      | Enables framebuffer scanout                                               |
| `fb_base_i`      | in  | ADDR_W | Base address of active framebuffer in DDR                                 |
| `fb_stride_i`    | in  | STR_W  | Byte stride between successive framebuffer rows                           |
| `fb_swap_i`      | in  | 1      | Requests front/back framebuffer swap (applied at VSYNC)                   |
| `pixel_x_i`      | in  | X_W    | Horizontal pixel coordinate from VGA timing                               |
| `pixel_y_i`      | in  | Y_W    | Vertical pixel coordinate from VGA timing                                 |
| `active_video_i` | in  | 1      | High during visible display region                                        |
| `pixel_index_o`  | out | PIX_W  | Indexed pixel fetched from framebuffer                                    |
| `pixel_rgb_o`    | out | RGB_W  | Expanded RGB pixel output                                                 |
| `axi_ar_*`       | out | -      | AXI read address channel                                                  |
| `axi_r_*`        | in  | -      | AXI read data channel                                                     |
| `vsync_irq_o`    | out | 1      | VSYNC interrupt signaling frame boundary                                  |

---

## Reset / Initialization

The `fb_ctrl` module uses an active-low reset (`rst_ni`) to return all internal state to a known idle condition. When reset is asserted, scanout is disabled, internal registers are cleared, and no AXI memory transactions are issued. Pixel output and VSYNC interrupt generation are suppressed during reset. After reset is deasserted, software programs framebuffer base address, stride, and buffer configuration before enabling scanout. Normal operation begins once enabled, with any buffer swap requests applied on the next VSYNC boundary.

---

## Behavior & Timing

The `fb_ctrl` module operates synchronously on the system clock (`clk_i`) as a continuously running scanout engine. When enabled, it autonomously issues AXI read transactions to fetch pixel data from the active framebuffer in raster order, synchronized to VGA timing. Framebuffer addresses advance horizontally across each line and jump by the programmed stride at line boundaries. Memory fetches are gated during blanking intervals using `active_video_i`. Double-buffer swaps are latched during operation and applied atomically at VSYNC, where an optional interrupt signals frame completion.

---

## Programming Model

The `fb_ctrl` module is configured through memory-mapped control registers defined in `specs/registers/video.yaml`. Software programs framebuffer base address, stride, pixel format, palette configuration, and optional front/back buffers before enabling scanout. Once enabled, hardware autonomously performs pixel fetch, format expansion, and display synchronization. A VSYNC interrupt allows software to safely update frame data or request buffer swaps, which are applied only at VSYNC.

---

## Errors / IRQs

The `fb_ctrl` module does not implement internal error detection for invalid configuration parameters or memory access failures. It assumes valid framebuffer addresses and reliable AXI read responses. No explicit error flags are generated for out-of-bounds access or underruns. An optional VSYNC interrupt is generated at the end of each frame and cleared via control/status registers as defined in `specs/registers/video.yaml`.

---

## Performance Targets

- Sustains continuous scanout at one pixel per pixel clock  
- Operates at standard video pixel clocks (e.g., 25-40+ MHz for VGA modes)  
- AXI bandwidth provisioned for worst-case resolution and pixel format  
- Bounded, deterministic pixel latency through fixed pipeline depth  
- Tear-free full-frame updates via double buffering  
- No jitter introduced into active display timing  

---

## Dependencies

Depends on system clock (`clk_i`), reset (`rst_ni`), AXI memory fabric, and backing DDR. Requires VGA timing signals from `vga_timing.sv`. Software must program valid framebuffer parameters via `specs/registers/video.yaml`. The AXI interconnect arbitrates memory access against other masters and must provide sufficient bandwidth for worst-case scanout.

---

## Verification Links

Verified using directed simulation testbenches validating raster-order scanout, stride handling, blanking behavior, and VSYNC-synchronized buffer swaps. System-level video simulations and test applications validate sustained operation under memory contention. AXI memory models observe read access patterns and burst alignment. Known limitations include reliance on software for bounds checking and the absence of formal verification under extreme contention.
