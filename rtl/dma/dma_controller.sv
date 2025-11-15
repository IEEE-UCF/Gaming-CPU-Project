//======================================================================
// DMA Controller - Top Level
// Author: Evan Eichholz  
// Description: Multi-channel DMA with scatter-gather support
// References: specs/registers/dma.yaml, docs/dma_operation.md
//======================================================================

module dma_controller import dma_pkg::*; (
    // Clock and reset
    input  logic                    clk_i,
    input  logic                    rst_ni,
    
    // AXI4 Memory Interface (Master) - Write address channel
    output logic [ADDR_W-1:0]       m_axi_awaddr_o,
    output logic [7:0]              m_axi_awlen_o,
    // ... (other AXI ports - truncated for brevity)
    
    // AXI4-Lite Control Interface (Slave)
    input  logic [ADDR_W-1:0]       s_axi_awaddr_i,
    // ... (other AXI-Lite ports)
    
    // Interrupt outputs
    output logic [N_CHANNELS-1:0]   irq_done_o,
    output logic [N_CHANNELS-1:0]   irq_error_o,
    
    // Peripheral request interface
    input  logic [N_CHANNELS-1:0]   periph_req_i,
    output logic [N_CHANNELS-1:0]   periph_ack_o
);

    // Internal signals
    dma_regs_t regs_q, regs_d;
    channel_state_e [N_CHANNELS-1:0] channel_state;
    logic [N_CHANNELS-1:0] channel_grant;

    // Module instances
    dma_channel_arbiter u_channel_arbiter (.*);
    dma_desc_fetch u_desc_fetch (.*);
    dma_xfer_engine u_xfer_engine (.*);
    dma_axi_mux u_axi_mux (.*);
    dma_reg_if u_reg_if (.*);
    dma_irq_ctrl u_irq_ctrl (.*);
    dma_status u_status (.*);

endmodule