//======================================================================
// DMA Package - Types and Parameters
// Author: Evan Eichholz
// Description: Common types, parameters and definitions for DMA controller
// References: specs/registers/dma.yaml
//======================================================================

package dma_pkg;

    // Channel count and sizing
    parameter int unsigned N_CHANNELS  = 4;
    parameter int unsigned DATA_W      = 32;
    parameter int unsigned ADDR_W      = 32;
    parameter int unsigned DESC_ADDR_W = 32;
    parameter int unsigned CHANNEL_W   = $clog2(N_CHANNELS);

    // DMA channel states
    typedef enum logic [2:0] {
        CH_IDLE,
        CH_DESC_FETCH,
        CH_XFER_READ,
        CH_XFER_WRITE, 
        CH_COMPLETE,
        CH_ERROR
    } channel_state_e;

    // Descriptor structure (64-bit aligned for AXI efficiency)
    typedef struct packed {
        logic [DESC_ADDR_W-1:0] next_desc;  // 32 bits
        logic [ADDR_W-1:0]      src_addr;   // 32 bits  
        logic [ADDR_W-1:0]      dst_addr;   // 32 bits
        logic [23:0]            length;     // 24 bits
        logic [7:0]             control;    // 8 bits (last + config)
    } dma_desc_t;

    // Control field bit assignments
    parameter int CTRL_LAST_BIT = 7;
    parameter int CTRL_CONFIG_MSB = 6;
    parameter int CTRL_CONFIG_LSB = 0;

    // Register structure
    typedef struct packed {
        logic [31:0] ctrl;
        logic [31:0] status;
        logic [31:0] channel_enable;
    } dma_regs_t;

endpackage