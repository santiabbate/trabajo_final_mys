`timescale 1ns / 1ps
/**
 * @file axi_lite_mm2dds_mod_registers.sv
 * @author Santiago Abbate
 * @brief CESE - Trabajo Final - Control de etapa digital de RADAR pulsado multipropósito.
 * Custom AXI4-Lite Register bank for DDS Modulator configuration.
 * Provides memory-mapped access from PS side of Xilinx Zynq SoC.
 */

module axi_lite_mm2dds_mod_registers(
    /* Register outputs */ 
    output [31:0] config_reg_0_o,
    output [31:0] config_reg_1_o,
    output [31:0] config_reg_2_o,
    output [31:0] config_reg_3_o,
    output [31:0] config_reg_4_o,
    output [31:0] config_reg_5_o,

    /* AXI4-Lite Clock and reset signals */
    input          S_AXI_CLK,
    input          S_AXI_ARESETN,

    /* AXI4-lite slave signals */
    /* Write address signals */
    output         S_AXI_AWREADY,
    input   [31:0] S_AXI_AWADDR,
    input          S_AXI_AWVALID,
    /* Write data signals */
    output         S_AXI_WREADY,
    input   [31:0] S_AXI_WDATA,
    input   [3:0]  S_AXI_WSTRB,
    input          S_AXI_WVALID,
    /* Write response signals */
    input          S_AXI_BREADY,
    output  [1:0]  S_AXI_BRESP,
    output         S_AXI_BVALID,
    /* Read address signals */
    output         S_AXI_ARREADY,
    input   [31:0] S_AXI_ARADDR,
    input          S_AXI_ARVALID,
    /* Read data signals */
    input          S_AXI_RREADY,
    output  [31:0] S_AXI_RDATA,
    output  [1:0]  S_AXI_RRESP,
    output         S_AXI_RVALID, 

    /* Debug ended signal */
    input logic dbg_tlast
);

localparam ADDR_BITS = 8;

import dds_modulator_pkg::*;

/* AXI Write FSM States */ 
typedef enum logic [1:0] {  WIDLE_S,
                    WDATA_S,
                    WRESP_S
} axi_wstate_e;

/* AXI Read FSM States */ 
typedef enum logic {    RIDLE_S,
                        RDATA_S
} axi_rstate_e;

/* AXI Registers addresses */ 
localparam  REG_0 = 'h0,
            REG_1 = 'h4,
            REG_2 = 'h8,
            REG_3 = 'hc,
            REG_4 = 'h10,
            REG_5 = 'h14;

/* AXI Write */
axi_wstate_e wstate_reg, wstate_next;
logic [ADDR_BITS - 1:0] waddr_reg;

/* AXI Read */ 
axi_rstate_e rstate_reg, rstate_next;
logic [ADDR_BITS - 1:0] raddr_reg;
logic [31:0] rdata_reg;

/* AXI signals */
/* WRITE */
/* 
 * Inform we are ready to receive an address if on idle state
 */
assign S_AXI_AWREADY = (wstate_reg == WIDLE_S);

/* 
 * Inform we are ready to receive data if on write data state
 */
assign S_AXI_WREADY = (wstate_reg == WDATA_S);

/* 
 * Inform we are sending a valid write response if on write response state
 */
assign S_AXI_BVALID = (wstate_reg == WRESP_S);

/*
 * Will have a write address request from master when:
 *     - Slave is ready (S_AXI_AWREADY) -> We are on idle state
 *     - Master writes a valid address (S_AXI_AWVALID)
 */
logic write_address_request;
assign write_address_request = S_AXI_AWREADY && S_AXI_AWVALID;

/*
 * Will have a write request from master when:
 *     - Slave is ready (S_AXI_WREADY) -> We are on write data state
 *     - Master writes a valid data (S_AXI_WVALID)
 */
logic write_data_request;
assign write_data_request = S_AXI_WREADY && S_AXI_WVALID;

/* READ */

/* 
 * Inform we are ready to receive an address if on idle state
 */
assign S_AXI_ARREADY = (rstate_reg == RIDLE_S);

/* 
 * Inform we are sending a valid data if on read response state
 */
assign S_AXI_RVALID = (rstate_reg == RDATA_S);

/*
 * Will have a read address request from master when:
 *     - Slave is ready (S_AXI_ARREADY) -> We are on idle state
 *     - Master writes a valid address (S_AXI_ARVALID)
 */
logic read_request;
assign read_request = S_AXI_ARREADY && S_AXI_ARVALID;

/* Internal registers */
logic [31:0] config_reg_0;
logic [31:0] config_reg_1;
logic [31:0] config_reg_2;
logic [31:0] config_reg_3;
logic [31:0] config_reg_4;
logic [31:0] config_reg_5;

/* I/O Assigns */
assign config_reg_0_o = config_reg_0;
assign config_reg_1_o = config_reg_1;
assign config_reg_2_o = config_reg_2;
assign config_reg_3_o = config_reg_3;
assign config_reg_4_o = config_reg_4;
assign config_reg_5_o = config_reg_5;

assign S_AXI_RDATA = rdata_reg;

/*
 * Not evaluating bus errors. Always OK.
 */
assign S_AXI_BRESP = 2'b00;
assign S_AXI_RRESP = 2'b00;

/* AXI Write FSM */
always_ff @(posedge S_AXI_CLK)
begin
    if (!S_AXI_ARESETN)
        wstate_reg <= WIDLE_S;
    else
        wstate_reg <= wstate_next;
end

/* AXI Write FSM Next State Logic */
always_comb
begin
    case(wstate_reg)
        WIDLE_S:
            // Go to write data state if input address is valid
            wstate_next = S_AXI_AWVALID ? WDATA_S : WIDLE_S;
        WDATA_S:
            // Go to response state if input data is valid
            wstate_next = S_AXI_WVALID ? WRESP_S : WDATA_S;
        WRESP_S:
            // Go to idle state if master is ready to accept response
            wstate_next = S_AXI_BREADY ? WIDLE_S : WRESP_S;
        default:
            wstate_next = WIDLE_S;
    endcase
end

/* AXI Write Incoming address register */
always_ff @(posedge S_AXI_CLK)
begin
    if (!S_AXI_ARESETN)
        waddr_reg <= 0;   
    else if (write_address_request) // Register the incoming address when on a write request
        waddr_reg <= S_AXI_AWADDR[ADDR_BITS - 1:0];
    else
        waddr_reg <= waddr_reg;
end

/* Registers write */
// TODO: Add S_AXI_WSTRB logic
always_ff @(posedge S_AXI_CLK)
begin
    if (!S_AXI_ARESETN)
    begin
        config_reg_0 <= 0;
        config_reg_1 <= 0;
        config_reg_2 <= 0;
        config_reg_3 <= 0;
        config_reg_4 <= 0;
        config_reg_5 <= 0;
    end
    else if (write_data_request) begin
        case(waddr_reg)
            REG_0:
                config_reg_0 <= S_AXI_WDATA;
            REG_1:
                config_reg_1 <= S_AXI_WDATA;
            REG_2:
                config_reg_2 <= S_AXI_WDATA;
            REG_3:
                config_reg_3 <= S_AXI_WDATA;
            REG_4:
                config_reg_4 <= S_AXI_WDATA;
            REG_5:
                config_reg_5 <= S_AXI_WDATA;    
            default:
            begin
                config_reg_0 <= config_reg_0;
                config_reg_1 <= config_reg_1;
                config_reg_2 <= config_reg_2;
                config_reg_3 <= config_reg_3;
                config_reg_4 <= config_reg_4;
                config_reg_5 <= config_reg_5; 
            end
        endcase  
    end

    if (config_reg_0[DEBUG_BIT]) begin
        config_reg_0[DEBUG_BIT] <= ~(config_reg_0[DEBUG_BIT] & dbg_tlast);    
    end
    

end

/* AXI Read FSM */
always_ff @(posedge S_AXI_CLK)
begin
    if (!S_AXI_ARESETN)
        rstate_reg <= RIDLE_S;
    else
        rstate_reg <= rstate_next;
end

/* AXI Read FSM Next State Logic */
always_comb
begin
    case(rstate_reg)
        RIDLE_S:
            // Go to read data state if input address is valid
            rstate_next = S_AXI_ARVALID ? RDATA_S : RIDLE_S;
        RDATA_S:
            // Go to response state if input data is valid
            rstate_next = S_AXI_RREADY ? RIDLE_S : RDATA_S;
        default:
            rstate_next = RIDLE_S;
    endcase
end

/* AXI Read register */ 
always_ff @(posedge S_AXI_CLK)
begin
    if (!S_AXI_ARESETN)
        rdata_reg <= 0;
    else if(read_request)
        case(S_AXI_ARADDR[ADDR_BITS - 1:0])
            REG_0:
                rdata_reg <= config_reg_0;
            REG_1:
                rdata_reg <= config_reg_1;
            REG_2:
                rdata_reg <= config_reg_2;
            REG_3:
                rdata_reg <= config_reg_3;
            REG_4:
                rdata_reg <= config_reg_4;
            REG_5:
                rdata_reg <= config_reg_5; 
            default:
                rdata_reg <= 0;
        endcase
end

endmodule