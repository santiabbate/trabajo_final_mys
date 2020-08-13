//Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2019.2 (lin64) Build 2708876 Wed Nov  6 21:39:14 MST 2019
//Date        : Mon Apr 20 21:42:16 2020
//Host        : SANTI-ABBATE running 64-bit Ubuntu 18.04.4 LTS
//Command     : generate_target dds_compiler_wrapper.bd
//Design      : dds_compiler_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module dds_compiler_wrapper
   (M_AXIS_DATA_0_tdata,
    M_AXIS_DATA_0_tready,
    M_AXIS_DATA_0_tvalid,
    S_AXIS_PHASE_0_tdata,
    S_AXIS_PHASE_0_tready,
    S_AXIS_PHASE_0_tvalid,
    aclk_0,
    aclken_0,
    aresetn_0);
  output [31:0]M_AXIS_DATA_0_tdata;
  input M_AXIS_DATA_0_tready;
  output M_AXIS_DATA_0_tvalid;
  input [71:0]S_AXIS_PHASE_0_tdata;
  output S_AXIS_PHASE_0_tready;
  input S_AXIS_PHASE_0_tvalid;
  input aclk_0;
  input aclken_0;
  input aresetn_0;

  wire [31:0]M_AXIS_DATA_0_tdata;
  wire M_AXIS_DATA_0_tready;
  wire M_AXIS_DATA_0_tvalid;
  wire [71:0]S_AXIS_PHASE_0_tdata;
  wire S_AXIS_PHASE_0_tready;
  wire S_AXIS_PHASE_0_tvalid;
  wire aclk_0;
  wire aclken_0;
  wire aresetn_0;

  generator_dds_compiler_0 dds_compiler
       (.M_AXIS_DATA_0_tdata(M_AXIS_DATA_0_tdata),
        .M_AXIS_DATA_0_tready(M_AXIS_DATA_0_tready),
        .M_AXIS_DATA_0_tvalid(M_AXIS_DATA_0_tvalid),
        .S_AXIS_PHASE_0_tdata(S_AXIS_PHASE_0_tdata),
        .S_AXIS_PHASE_0_tready(S_AXIS_PHASE_0_tready),
        .S_AXIS_PHASE_0_tvalid(S_AXIS_PHASE_0_tvalid),
        .aclk_0(aclk_0),
        .aclken_0(aclken_0),
        .aresetn_0(aresetn_0));
endmodule
