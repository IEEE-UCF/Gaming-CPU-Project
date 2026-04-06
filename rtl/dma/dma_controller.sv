//======================================================================
// DMA Controller - Top Level
// Author: Evan Eichholz
// Description: Multi-channel DMA with scatter-gather support
// References: specs/registers/dma.yaml, docs/dma_operation.md
//======================================================================

module dma_controller
    import dma_pkg::*;
(
    input  logic                    clk_i,
    input  logic                    rst_ni,

    output logic [ADDR_W-1:0]       m_axi_awaddr_o,
    output logic [7:0]              m_axi_awlen_o,
    output logic [2:0]              m_axi_awsize_o,
    output logic [1:0]              m_axi_awburst_o,
    output logic                    m_axi_awvalid_o,
    input  logic                    m_axi_awready_i,

    output logic [DATA_W-1:0]       m_axi_wdata_o,
    output logic [DATA_W/8-1:0]     m_axi_wstrb_o,
    output logic                    m_axi_wlast_o,
    output logic                    m_axi_wvalid_o,
    input  logic                    m_axi_wready_i,

    input  logic [1:0]              m_axi_bresp_i,
    input  logic                    m_axi_bvalid_i,
    output logic                    m_axi_bready_o,

    output logic [ADDR_W-1:0]       m_axi_araddr_o,
    output logic [7:0]              m_axi_arlen_o,
    output logic [2:0]              m_axi_arsize_o,
    output logic [1:0]              m_axi_arburst_o,
    output logic                    m_axi_arvalid_o,
    input  logic                    m_axi_arready_i,

    input  logic [DATA_W-1:0]       m_axi_rdata_i,
    input  logic [1:0]              m_axi_rresp_i,
    input  logic                    m_axi_rlast_i,
    input  logic                    m_axi_rvalid_i,
    output logic                    m_axi_rready_o,

    input  logic [ADDR_W-1:0]       s_axi_awaddr_i,
    input  logic                    s_axi_awvalid_i,
    output logic                    s_axi_awready_o,

    input  logic [DATA_W-1:0]       s_axi_wdata_i,
    input  logic [DATA_W/8-1:0]     s_axi_wstrb_i,
    input  logic                    s_axi_wvalid_i,
    output logic                    s_axi_wready_o,

    output logic [1:0]              s_axi_bresp_o,
    output logic                    s_axi_bvalid_o,
    input  logic                    s_axi_bready_i,

    input  logic [ADDR_W-1:0]       s_axi_araddr_i,
    input  logic                    s_axi_arvalid_i,
    output logic                    s_axi_arready_o,

    output logic [DATA_W-1:0]       s_axi_rdata_o,
    output logic [1:0]              s_axi_rresp_o,
    output logic                    s_axi_rvalid_o,
    input  logic                    s_axi_rready_i,

    output logic [N_CHANNELS-1:0]   irq_done_o,
    output logic [N_CHANNELS-1:0]   irq_error_o,

    input  logic [N_CHANNELS-1:0]   periph_req_i,
    output logic [N_CHANNELS-1:0]   periph_ack_o
);

    dma_regs_t                   regs;
    logic [N_CHANNELS-1:0]       ch_req;
    logic [N_CHANNELS-1:0]       ch_grant;
    logic [CHANNEL_W-1:0]        grant_ch;
    logic                        grant_valid;
    ch_status_t [N_CHANNELS-1:0] ch_status;
    xfer_req_t                   xfer_req;
    xfer_resp_t                  xfer_resp;
    desc_fetch_req_t             desc_req;
    desc_fetch_resp_t            desc_resp;
    irq_type_e [N_CHANNELS-1:0] irq_type;

    dma_reg_if       u_reg_if          (.*);
    dma_channel_arbiter u_channel_arbiter (.*);
    dma_desc_fetch   u_desc_fetch      (.*);
    dma_xfer_engine  u_xfer_engine     (.*);
    dma_axi_mux      u_axi_mux         (.*);
    dma_irq_ctrl     u_irq_ctrl        (.*);
    dma_status       u_status          (.*);

endmodule
