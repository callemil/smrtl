//=========================================================================
// max/rtl/serial-matmul-dpath.v
//=========================================================================
// Sebastian Claudiusz Magierowski Feb 16 2023

// A part of serial-matmul.v  (look for some definitions there)
`ifndef SERIAL_MATMUL_DPATH_V
`define SERIAL_MATMUL_DPATH_V

`include "sm-bufs.v"
`include "sm-arithmetic.v"
`include "vc-arithmetic.v"
`include "vc-regfiles.v"
`include "sm-regfiles.v"

//========================================================================
// SERIAL_MATMUL Datapath
//========================================================================

module serial_matmul_dpath
(
  input logic clk,
  input logic reset,
  // PROC src
  input logic [63:0] cmd_rs1_i,
  input logic [6:0]  cmd_inst_funct_i,
  input logic [6:0]  cmd_inst_opcode_i,
  // Control: bus enable
  input logic src_bus_en,
  input logic resp_bus_en,
  input logic add_bus_en,
  input logic mul_bus_en,
  input logic sws_bus_en,
  input logic relu_bus_en,
  // X reg file
  input logic        x_wen,
  input logic  [`X_ADDR-1:0] x_waddr,
  input logic  [`X_ADDR-1:0] x_raddr,
  output logic [`X_BITS-1:0] x_rdata,
  // C reg file
  input logic        c_wen,
  input logic  [`C_ADDR-1:0] c_waddr,
  input logic  [`C_ADDR-1:0] c_raddr,
  output logic [`C_BITS-1:0] c_rdata,  
  // R reg file
  input logic         r_wen,
  input logic  [`R_ADDR-1:0] r_waddr,
  input logic  [`R_ADDR-1:0] r_raddr0,
  output logic [`R_BITS-1:0] r_rdata0,
  input logic  [`R_ADDR-1:0] r_raddr1,
  output logic [`R_BITS-1:0] r_rdata1,
  // Control: component en/sel
  input logic a_en,
  input logic b_en,
  input logic [1:0] add_sel,
  input logic comp_sel,
  // Status:
  output logic a_eq_b,
  // MEM req
  output logic [39:0] mem_req_addr_o,
  output logic [63:0] mem_req_data_o,
  // MEM resp
  input logic [39:0] mem_resp_addr_i,
  input logic [63:0] mem_resp_data_i,
  // PROC snk
  output logic [4:0] resp_rd_o,
  output logic [`ASIC_SNK_MSG_NBITS-1:0]   resp_data_o
);

  // wires
  logic [`X_BITS-1:0] x_wdata; assign x_wdata = cmd_inst_funct_i;
  logic [`C_BITS-1:0] c_wdata; assign c_wdata = cmd_inst_opcode_i;
  tri   [`R_BITS-1:0] r_wdata;
  logic [`R_BITS-1:0] bus_a;
  logic [`R_BITS-1:0] bus_b;

  logic [`R_BITS-1:0] add_o;
  logic [`R_BITS-1:0] mul_o;
  logic [`R_BITS-1:0] sws_o;
  logic [`R_BITS-1:0] relu_o;

  logic [`R_BITS-1:0] add0_i;
  logic [15:0]        comp0_i;

  assign mem_req_addr_o = r_rdata0[39:0];
  assign mem_req_data_o = r_rdata1;

  assign resp_rd_o = 1;
  assign resp_data_o = 1;

  // TEMPORARY STUFF, BE CAREFUL OF THESE CAUSING ERRORS/WARNINGS AS YOU BUILD CCT
  // *****************************************************************************
  // *****************************************************************************

  //----------------------------------------------------------------------
  // register files
  //----------------------------------------------------------------------

  // memory: 8b data, 16 entries, on reset set all values to 1
  vc_ResetRegfile_1r1w#(`X_BITS, `X_ENTRIES, 1) xfile
  (
    .clk        (clk),
    .reset      (reset),
    .write_en   (x_wen),
    .write_addr (x_waddr),
    .write_data (x_wdata),

    .read_addr  (x_raddr),
    .read_data  (x_rdata)
  );

  // memory: 8b data, 2 entries, on reset all values to 0
  vc_ResetRegfile_1r1w#(`C_BITS, `C_ENTRIES, 0) cfile
  (
    .clk        (clk),
    .reset      (reset),
    .write_en   (c_wen),
    .write_addr (c_waddr),
    .write_data (c_wdata),

    .read_addr  (c_raddr),
    .read_data  (c_rdata)
  );

  // memory: 32b data, 16 entries
  sm_Regfile_2r1w#(`R_BITS, `R_ENTRIES) rfile
  (
    .clk        (clk),
    .reset      (reset),
    .write_en   (r_wen),
    .write_addr (r_waddr),
    .write_data (r_wdata),

    .read_addr0 (r_raddr0),
    .read_data0 (r_rdata0),
    .read_addr1 (r_raddr1),
    .read_data1 (r_rdata1)
  );

  //----------------------------------------------------------------------
  // A & B resigers
  //----------------------------------------------------------------------
  
  vc_EnResetReg#(`R_BITS,0) reg_a
  (
    .clk   (clk),
    .reset (reset),
    .d     (r_rdata0),
    .q     (bus_a),
    .en    (a_en)
  );

  vc_EnResetReg#(`R_BITS,0) reg_b
  (
    .clk   (clk),
    .reset (reset),
    .d     (r_rdata1),
    .q     (bus_b),
    .en    (b_en)
  );


  //----------------------------------------------------------------------
  // arithmetic components (and their supports)
  //----------------------------------------------------------------------

  vc_SimpleAdder#(`R_BITS) adder
  (
    .in0 (add0_i),
    .in1 (bus_b),
    .out (add_o)
  );

  vc_Mux4#(`R_BITS) mux_toadd
  (
    .in0 (bus_a),         // connection from a_reg
    .in1 (`R_BITS'd1),
    .in2 (`R_BITS'd2),
    .in3 (`R_BITS'd8),
    .sel (add_sel),
    .out (add0_i)
  );

  vc_EqComparator#(16) comp 
  (
    .in0 (comp0_i),     // N or M
    .in1 (bus_b[15:0]), // j or i
    .out (a_eq_b)       // 1 if in0 == in1
  );

  vc_Mux2#(16) mux_tocomp
  (
    .in0 (bus_a[31:16]),   // N
    .in1 (bus_a[15:0]),    // M
    .sel (comp_sel),       // if sel is 0 choose
    .out (comp0_i)
  );


  sm_SimpleMultiplier#(`R_BITS) multiplier
  (
    .in0 (bus_a),
    .in1 (bus_b),
    .out (mul_o)
  );

  sm_SubWordSampler8#(`R_BITS) sws
  ( 
    .in       (bus_a),
    .startbit (bus_b[15:0]),
    .out      (sws_o)
  );

  sm_ReLu#(`R_BITS) relu
  (
    .in  (bus_b),
    .out (relu_o)
  );

  //----------------------------------------------------------------------
  // r_wdata bus buffers
  //----------------------------------------------------------------------

  sm_Buf#(`R_BITS) src_buf
  (
    .in  (cmd_rs1_i),
    .en  (src_bus_en),
    .out (r_wdata)
  );
  sm_Buf#(`R_BITS) resp_buf
  (
    .in  (mem_resp_data_i),
    .en  (resp_bus_en),
    .out (r_wdata)
  );
  sm_Buf#(`R_BITS) add_buf
  (
    .in  (add_o),
    .en  (add_bus_en),
    .out (r_wdata)
  );
  sm_Buf#(`R_BITS) mul_buf
  (
    .in  (mul_o),
    .en  (mul_bus_en),
    .out (r_wdata)
  );
  sm_Buf#(`R_BITS) sws_buf
  (
    .in  (sws_o),
    .en  (sws_bus_en),
    .out (r_wdata)
  );
  sm_Buf#(`R_BITS) relu_buf
  (
    .in  (relu_o),
    .en  (relu_bus_en),
    .out (r_wdata)
  );

endmodule

`endif /* SERIAL_MATMUL_DPATH_V */
