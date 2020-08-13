`timescale 1ns / 1ps

module axi_lite_tb();
    localparam CLK = 8;

    logic [31:0] config_reg_0_o;
    logic [31:0] config_reg_1_o;
    logic [31:0] config_reg_2_o;
    logic [31:0] config_reg_3_o;
    logic [31:0] config_reg_4_o;
    logic [31:0] config_reg_5_o;

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

    logic m_axis_modulation_tlast = 0;

    /**
     * Clock & Reset
     */

    logic clk_i = 0;
    logic resetn_i = 0;
    always #(CLK/2) clk_i = !clk_i;
    initial #20 resetn_i = 1;

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
        
        axi_write(8'h00, 4'h3);
        axi_write(8'h04, 4'h9);
        axi_write(8'h08, 4'h3);
        axi_write(8'h0c, 4'h7);
        axi_write(8'h010, 4'hF);
        axi_write(8'h014, 'hFFFF);
        
        axi_write(8'h54, 4'h5);
        
        axi_read(8'h00);
    
        axi_read(8'h014);

        #300us

        axi_write(8'h00,4'h3);
        axi_read(8'h00);
        #30us
        m_axis_modulation_tlast = 1;
        #CLK
        m_axis_modulation_tlast = 0;
        #CLK
        axi_read(8'h00);

        $finish;
    end
    
    axi_lite_mm2dds_mod_registers dut(
    // Register outputs
    .config_reg_0_o,
    .config_reg_1_o,
    .config_reg_2_o,
    .config_reg_3_o,
    .config_reg_4_o,
    .config_reg_5_o,

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
