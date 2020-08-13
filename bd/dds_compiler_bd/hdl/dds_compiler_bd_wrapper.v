//Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2019.2 (lin64) Build 2708876 Wed Nov  6 21:39:14 MST 2019
//Date        : Sat Jul  4 19:25:57 2020
//Host        : SANTI-ABBATE running 64-bit Ubuntu 18.04.4 LTS
//Command     : generate_target dds_compiler_bd_wrapper.bd
//Design      : dds_compiler_bd_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module dds_compiler_bd_wrapper
   (M_AXIS_DATA_0_tdata,
    M_AXIS_DATA_0_tready,
    M_AXIS_DATA_0_tvalid,
    S_AXIS_PHASE_tdata,
    S_AXIS_PHASE_tready,
    S_AXIS_PHASE_tvalid,
    aclk,
    aclken,
    aresetn);
  output [31:0]M_AXIS_DATA_0_tdata;
  input M_AXIS_DATA_0_tready;
  output M_AXIS_DATA_0_tvalid;
  input [71:0]S_AXIS_PHASE_tdata;
  output S_AXIS_PHASE_tready;
  input S_AXIS_PHASE_tvalid;
  input aclk;
  input aclken;
  input aresetn;

  wire [31:0]M_AXIS_DATA_0_tdata;
  wire M_AXIS_DATA_0_tready;
  wire M_AXIS_DATA_0_tvalid;
  wire [71:0]S_AXIS_PHASE_tdata;
  wire S_AXIS_PHASE_tready;
  wire S_AXIS_PHASE_tvalid;
  wire aclk;
  wire aclken;
  wire aresetn;

  dds_compiler_bd dds_compiler_bd_i
       (.M_AXIS_DATA_0_tdata(M_AXIS_DATA_0_tdata),
        .M_AXIS_DATA_0_tready(M_AXIS_DATA_0_tready),
        .M_AXIS_DATA_0_tvalid(M_AXIS_DATA_0_tvalid),
        .S_AXIS_PHASE_tdata(S_AXIS_PHASE_tdata),
        .S_AXIS_PHASE_tready(S_AXIS_PHASE_tready),
        .S_AXIS_PHASE_tvalid(S_AXIS_PHASE_tvalid),
        .aclk(aclk),
        .aclken(aclken),
        .aresetn(aresetn));
endmodule
