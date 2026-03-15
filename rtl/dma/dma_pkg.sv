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

    parameter logic [ADDR_W-1:0] REG_CTRL_OFFSET = 32'h0000_0000;
    parameter logic [ADDR_W-1:0] REG_STATUS_OFFSET = 32'h0000_0004;
    parameter logic [ADDR_W-1:0] REG_CHANNEL_ENABLE = 32'h0000_0008;
    parameter logic [ADDR_W-1:0] REG_DESC_PTR_BASE = 32'h0000_0100;
    parameter int CTRL_GLOBAL_ENABLE_BIT = 0;
    parameter int CTRL_IRQ_ENABLE_BIT = 1;
    parameter int STATUS_BUSY_BIT = 0;
    parameter int STATUS_ERROR_BIT = 1;

    typedef enum logic [1:0] {
        IRQ_NONE = 2'b00,
        IRQ_DONE = 2'b01,
        IRQ_ERROR = 2'b10
    } irq_type_e;

    typedef struct packed {
        channel_state_e state;
        logic done;
        logic error;
    } ch_status_t;

    typedef struct packed {
        logic valid;         
        logic [ADDR_W-1:0] addr;          
    } desc_fetch_req_t;
    typedef struct packed {
        logic valid;              
        dma_desc_t desc;                
    } desc_fetch_resp_t;

    typedef struct packed {
        logic valid;         
        logic [ADDR_W-1:0] src_addr;
        logic [ADDR_W-1:0] dst_addr;
        logic [23:0] length;
        logic is_last;
    } xfer_req_t;
    typedef struct packed {
        logic done;
        logic error;
    } xfer_resp_t;

    parameter int unsigned MAX_BURST_BEATS = 16;
    parameter int unsigned MAX_BURST_BYTES = MAX_BURST_BEATS * (DATA_W/8);

    function automatic [7:0] calc_axi_len(input int unsigned bytes);
        if (bytes > MAX_BURST_BYTES)
            return MAX_BURST_BEATS - 1;
        else
            return (bytes / (DATA_W/8)) - 1;
    endfunction
endpackage
