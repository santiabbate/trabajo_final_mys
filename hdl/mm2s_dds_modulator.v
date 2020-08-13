`timescale 1ns / 1ps
/**
 * @file mm2s_dds_modulator.sv
 * @author Santiago Abbate
 * @brief CESE - Trabajo Final - Control de etapa digital de RADAR pulsado multipropósito.
 * AXI4-Lite Memory Mapped DDS IP Cor Modulator for RADAR waveforms signal generation.
 * Top Wrapper for modulator and register instances.
 */

module mm2s_dds_modulator(
    /* AXI4-Lite Clock and reset signals */
    input wire          S_AXI_CLK,
    input wire          S_AXI_ARESETN,

    /* AXI4-lite slave signals */
    /* Write address signals */
    output wire         S_AXI_AWREADY,
    input wire   [31:0] S_AXI_AWADDR,
    input wire          S_AXI_AWVALID,
    /* Write data signals */
    output wire         S_AXI_WREADY,
    input wire   [31:0] S_AXI_WDATA,
    input wire   [3:0]  S_AXI_WSTRB,
    input wire          S_AXI_WVALID,
    /* Write response signals */
    input wire          S_AXI_BREADY,
    output wire  [1:0]  S_AXI_BRESP,
    output wire         S_AXI_BVALID,
    /* Read address signals */
    output wire         S_AXI_ARREADY,
    input wire   [31:0] S_AXI_ARADDR,
    input wire          S_AXI_ARVALID,
    /* Read data signals */	
    input wire          S_AXI_RREADY,
    output wire  [31:0] S_AXI_RDATA,
    output wire  [1:0]  S_AXI_RRESP,
    output wire         S_AXI_RVALID, 

    /* DDS Compiler Signals */
    output wire dds_en_o,
    /* AXI4-Stream Master Signals */
    output wire [71:0] m_axis_modulation_tdata,
    output wire m_axis_modulation_tvalid,
    output wire m_axis_modulation_tlast,
    input wire m_axis_modulation_tready
);

    wire [31:0] config_reg_0;
    wire [31:0] config_reg_1;
    wire [31:0] config_reg_2;
    wire [31:0] config_reg_3;
    wire [31:0] config_reg_4;
    wire [31:0] config_reg_5;

    dds_modulator modulator(
        .clk_i(S_AXI_CLK),
        .resetn_i(S_AXI_ARESETN),
        .dds_en_o(dds_en_o),
        .m_axis_modulation_tdata(m_axis_modulation_tdata),
        .m_axis_modulation_tvalid(m_axis_modulation_tvalid),
        .m_axis_modulation_tlast(m_axis_modulation_tlast),
        .m_axis_modulation_tready(m_axis_modulation_tready),
        .config_reg_0(config_reg_0),
        .config_reg_1(config_reg_1),
        .config_reg_2(config_reg_2),
        .config_reg_3(config_reg_3),
        .config_reg_4(config_reg_4),
        .config_reg_5(config_reg_5)
    );

    axi_lite_mm2dds_mod_registers registers(
        .config_reg_0_o(config_reg_0),
        .config_reg_1_o(config_reg_1),
        .config_reg_2_o(config_reg_2),
        .config_reg_3_o(config_reg_3),
        .config_reg_4_o(config_reg_4),
        .config_reg_5_o(config_reg_5),
        .S_AXI_CLK(S_AXI_CLK),
        .S_AXI_ARESETN(S_AXI_ARESETN),
        .S_AXI_AWREADY(S_AXI_AWREADY),
        .S_AXI_AWADDR(S_AXI_AWADDR),
        .S_AXI_AWVALID(S_AXI_AWVALID),
        .S_AXI_WREADY(S_AXI_WREADY),
        .S_AXI_WDATA(S_AXI_WDATA),
        .S_AXI_WSTRB(S_AXI_WSTRB),
        .S_AXI_WVALID(S_AXI_WVALID),
        .S_AXI_BREADY(S_AXI_BREADY),
        .S_AXI_BRESP(S_AXI_BRESP),
        .S_AXI_BVALID(S_AXI_BVALID),
        .S_AXI_ARREADY(S_AXI_ARREADY),
        .S_AXI_ARADDR(S_AXI_ARADDR),
        .S_AXI_ARVALID(S_AXI_ARVALID),	
        .S_AXI_RREADY(S_AXI_RREADY),
        .S_AXI_RDATA(S_AXI_RDATA),
        .S_AXI_RRESP(S_AXI_RRESP),
        .S_AXI_RVALID(S_AXI_RVALID),
        .dbg_tlast(m_axis_modulation_tlast)
    );

endmodule