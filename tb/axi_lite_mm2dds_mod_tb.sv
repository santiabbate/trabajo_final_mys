`timescale 1ns / 1ps

import dds_modulator_pkg::*;

module axi_lite_mm2dds_mod_tb();
    localparam CLK = 8;

    logic [31:0] config_reg_0;
    logic [31:0] config_reg_1;
    logic [31:0] config_reg_2;
    logic [31:0] config_reg_3;
    logic [31:0] config_reg_4;
    logic [31:0] config_reg_5;

    // ### AXI4-lite slave signals #########################################
    // *** Write address signals ***
    logic         S_AXI_AWREADY;
    logic   [31:0] S_AXI_AWADDR;
    logic          S_AXI_AWVALID;
    // *** Write data signals ***
    logic         S_AXI_WREADY;
    logic   [31:0] S_AXI_WDATA;
    logic   [3:0]  S_AXI_WSTRB;
    logic          S_AXI_WVALID;
    // *** Write response signals ***
    logic          S_AXI_BREADY;
    logic  [1:0]  S_AXI_BRESP;
    logic         S_AXI_BVALID;
    // *** Read address signals ***
    logic         S_AXI_ARREADY;
    logic   [31:0] S_AXI_ARADDR;
    logic          S_AXI_ARVALID;
    // *** Read data signals ***	
    logic          S_AXI_RREADY;
    logic  [31:0] S_AXI_RDATA;
    logic  [1:0]  S_AXI_RRESP;
    logic         S_AXI_RVALID;


    logic [71:0] m_axis_modulation_tdata;
    logic m_axis_modulation_tvalid;
    logic m_axis_modulation_tlast;
    logic m_axis_modulation_tready = 1;

    /**
     * Clock & Reset
     */

    logic clk_i = 0;
    logic resetn_i = 0;
    always #(CLK/2) clk_i = !clk_i;
    initial #20 resetn_i = 1;

    logic [31:0] cfg2 = 0;
    
    int unsigned pinc_low; 
    int unsigned pinc_high; 
    int unsigned delta_pinc;
    
    /**
     * Test
     */
    initial begin
        S_AXI_AWADDR = 0;
        S_AXI_AWVALID = 0;
        
        S_AXI_WDATA = 0;
        S_AXI_WSTRB = 0;
        S_AXI_WVALID = 0;
        
        S_AXI_BREADY = 1;
        
        S_AXI_ARADDR = 0;
        S_AXI_ARVALID = 0;
        
        S_AXI_RREADY = 1;
        
        #50
        // Set operation mode Continuous No Modulation
        axi_write(8'h04,CONT_NO_MOD_TB);
        // Configure frequency 1MHz
        axi_write(8'h0c,(1 * (2 ** PINC_BITS)) / FCLK_MHZ );
        // Enable modulator
        axi_write(8'h00,1);
        #50ns
        // Disable
        axi_write(8'h00,0);
        
        
        #100us
        // Set operation mode Pulsed Frequency Modulation
        axi_write(8'h04,PULS_MOD_FREC);
        // Set period and pulse length
        cfg2 [30:16] = 50 * FCLK_MHZ;
        cfg2 [14:0] = 250 * FCLK_MHZ;
        axi_write(8'h08,cfg2);
        // Set frequency modulation
        pinc_low = (1 * (2 ** PINC_BITS)) / FCLK_MHZ ;
        pinc_high = 5 * ((2 ** PINC_BITS) / FCLK_MHZ) ;
        delta_pinc = (pinc_high - pinc_low) / (50 * FCLK_MHZ);
        config_reg_3 [PINC_BITS-1:0] = pinc_low;
        config_reg_4 [PINC_BITS-1:0] = pinc_high;
        config_reg_5 [PINC_BITS-1:0] = delta_pinc;
        axi_write(8'h0c,pinc_low);
        axi_write(8'h010, pinc_high);
        axi_write(8'h014,delta_pinc);
        
        // Enable modulator with debug
        axi_write(8'h00,3);
        
        #1100us
        $finish;
    end
    
    axi_lite_mm2dds_mod_registers dut(
    // Register outputs
    .config_reg_0_o(config_reg_0),
    .config_reg_1_o(config_reg_1),
    .config_reg_2_o(config_reg_2),
    .config_reg_3_o(config_reg_3),
    .config_reg_4_o(config_reg_4),
    .config_reg_5_o(config_reg_5),

    // ### Clock and reset signals #########################################
    .S_AXI_CLK(clk_i),
    .S_AXI_ARESETN(resetn_i),

    // ### AXI4-lite slave signals #########################################
    // *** Write address signals ***
    .S_AXI_AWREADY,
    .S_AXI_AWADDR,
    .S_AXI_AWVALID,
    // *** Write data signals ***
    .S_AXI_WREADY,
    .S_AXI_WDATA,
    .S_AXI_WSTRB,
    .S_AXI_WVALID,
    // *** Write response signals ***
    .S_AXI_BREADY,
    .S_AXI_BRESP,
    .S_AXI_BVALID,
    // *** Read address signals ***
    .S_AXI_ARREADY,
    .S_AXI_ARADDR,
    .S_AXI_ARVALID,
    // *** Read data signals ***	
    .S_AXI_RREADY,
    .S_AXI_RDATA,
    .S_AXI_RRESP,
    .S_AXI_RVALID,

    .dbg_tlast(m_axis_modulation_tlast) 
);

dds_modulator modulator(
        .clk_i(clk_i),
        .resetn_i(resetn_i),
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

task axi_write;
    input [31:0] awaddr;
    input [31:0] wdata; 
    begin
        // *** Write address ***
        S_AXI_AWADDR = awaddr;
        S_AXI_AWVALID = 1;
        #CLK;
        S_AXI_AWVALID = 0;
        // *** Write data ***
        S_AXI_WDATA = wdata;
        S_AXI_WSTRB = 4'hf;
        S_AXI_WVALID = 1; 
        #CLK;
        S_AXI_WVALID = 0;
        #CLK;
    end
endtask

task axi_read;
    input [31:0] araddr; 
    begin
        // *** Write address ***
        S_AXI_ARADDR = araddr;
        S_AXI_ARVALID = 1;
        #CLK;
        S_AXI_ARVALID = 0;
        // *** Write data ***
        #CLK;
    end
endtask


endmodule
