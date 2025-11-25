//=========================================================================
// serial_matmul/rtl/serial-matmul.v
//=========================================================================
// Sebastian Claudiusz Magierowski Feb 28 2023
// To run: see notes in asic-test-harness.v 

`ifndef SERIAL_MATMUL
`define SERIAL_MATMUL

`include "vc-trace.v"

`define ASIC_SRC_MSG_NBITS 64
`define ASIC_SNK_MSG_NBITS 32


`define X_BITS     8 // bits per entry of X reg file
`define X_ENTRIES  8 // entries in X reg file
`define X_ADDR    $clog2(`X_ENTRIES)

`define C_BITS     8 // bits per entry of C reg file
`define C_ENTRIES  4 // entries in C reg file
`define C_ADDR    $clog2(`C_ENTRIES)

`define R_BITS    64 // bits per entry of R reg file
`define R_ENTRIES 16 // entries in R reg file
`define R_ADDR    $clog2(`R_ENTRIES)

`include "serial-matmul-ctrl.v"
`include "serial-matmul-dpath.v"

//========================================================================
// ASIC System
//========================================================================

module serial_matmul
(
  input logic clk,
  input logic reset,
  // PROC src
  input  logic [63:0] cmd_rs1_i,
  input  logic [6:0]  cmd_inst_funct_i,
  input  logic [6:0]  cmd_inst_opcode_i,      
  input  logic        cmd_valid_i,
  output logic        cmd_ready_o,
  // MEM req               
  output logic                            mem_req_valid_o,
  input  logic                            mem_req_ready_i,
  output logic [4:0]                      mem_req_cmd_o,
  output logic [2:0]                      mem_req_typ_o,
  output logic [39:0]                     mem_req_addr_o,
  output logic [63:0]                     mem_req_data_o,
  // MEM resp
  input  logic                            mem_resp_valid_i,
  input  logic [4:0]                      mem_resp_cmd_i,
  input  logic [2:0]                      mem_resp_typ_i,
  input  logic [39:0]                     mem_resp_addr_i,
  input  logic [63:0]                     mem_resp_data_i,
  // PROC snk       
  output logic [4:0]                      resp_rd_o,
  output logic [`ASIC_SNK_MSG_NBITS-1:0]  resp_data_o,
  output logic                            resp_valid_o,
  input  logic                            resp_ready_i
);

  //----------------------------------------------------------------------
  // data mem req/resp
  //----------------------------------------------------------------------

  logic src_bus_en;
  logic resp_bus_en;
  logic add_bus_en;
  logic mul_bus_en;
  logic sws_bus_en;
  logic relu_bus_en;

  logic x_wen; // X register file's write enable
  logic [`X_ADDR-1:0] x_waddr;
  logic [`X_BITS-1:0] x_wdata;
  logic [`X_ADDR-1:0] x_raddr;

  logic c_wen; // C register file's write enable
  logic [`C_ADDR-1:0] c_waddr;
  logic [`C_BITS-1:0] c_wdata;
  logic [`C_ADDR-1:0] c_raddr;

  logic r_wen; // R register file's write enable
  logic [`R_ADDR-1:0] r_waddr;
  logic [`R_BITS-1:0] r_wdata;
  logic [`R_ADDR-1:0] r_raddr0;
  logic [`R_BITS-1:0] r_rdata0;
  logic [`R_ADDR-1:0] r_raddr1;
  logic [`R_BITS-1:0] r_rdata1;

  logic a_en;
  logic b_en;
  logic [1:0] add_sel;
  logic comp_sel;

  logic a_eq_b;
  logic [6:0] init;
  logic [`C_BITS-1:0] c_rdata;
  assign init = c_rdata[6:0];

  // TEMPORARY STUFF, BE CAREFUL OF THESE CAUSING ERRORS/WARNINGS AS YOU BUILD CCT
  // *****************************************************************************
  assign c_raddr = 0;
  // *****************************************************************************


  //========================================================================
  // ASIC Unit Control
  //========================================================================

  serial_matmul_ctrl ctrl
  (
    .clk       (clk),
    .reset     (reset),
    // PROC src dataflow signals
    .cmd_valid_i (cmd_valid_i),
    .cmd_ready_o (cmd_ready_o),
    // Control: bus enable
    .src_bus_en  (src_bus_en),
    .resp_bus_en (resp_bus_en),
    .add_bus_en  (add_bus_en),
    .mul_bus_en  (mul_bus_en),
    .sws_bus_en  (sws_bus_en),
    .relu_bus_en (relu_bus_en),
    // Control: X reg file
    .x_wen     (x_wen),
    .x_waddr   (x_waddr),
    // Control: C reg file
    .c_wen     (c_wen),
    .c_waddr   (c_waddr),
    // Control: R reg file
    .r_wen     (r_wen),
    .r_waddr   (r_waddr),
    .r_raddr0  (r_raddr0),
    .r_raddr1  (r_raddr1),
    // Control: component en/sel
    .a_en      (a_en),
    .b_en      (b_en),
    .add_sel   (add_sel),
    .comp_sel  (comp_sel),
    // Status:
    .a_eq_b    (a_eq_b),
    .init      (init),
    // MEM req
    .mem_req_ready_i (mem_req_ready_i),
    .mem_req_valid_o (mem_req_valid_o),
    .mem_req_cmd_o   (mem_req_cmd_o),
    .mem_req_typ_o   (mem_req_typ_o),
    // MEM resp
    .mem_resp_valid_i (mem_resp_valid_i),
    .mem_resp_cmd_i   (mem_resp_cmd_i),
    .mem_resp_typ_i   (mem_resp_typ_i),
    // PROC snk dataflow signals
    .resp_valid_o (resp_valid_o),
    .resp_ready_i (resp_ready_i)
  );

  serial_matmul_dpath dpath 
  (
    .clk      (clk),
    .reset    (reset),
    // PROC src
    .cmd_rs1_i         (cmd_rs1_i),
    .cmd_inst_funct_i  (cmd_inst_funct_i),
    .cmd_inst_opcode_i (cmd_inst_opcode_i),
    // Control: bus enable
    .src_bus_en  (src_bus_en),
    .resp_bus_en (resp_bus_en),
    .add_bus_en  (add_bus_en),
    .mul_bus_en  (mul_bus_en),
    .sws_bus_en  (sws_bus_en),
    .relu_bus_en (relu_bus_en),
    // Control: X reg file
    .x_wen    (x_wen),
    .x_waddr  (x_waddr),
    .x_raddr  (x_raddr),
    // Control: C reg file
    .c_wen    (c_wen),
    .c_waddr  (c_waddr),
    .c_raddr  (c_raddr),
    // Control: R reg file
    .r_wen    (r_wen),
    .r_waddr  (r_waddr),
    .r_raddr0 (r_raddr0),
    .r_raddr1 (r_raddr1),
    // Control: component en/sel
    .a_en      (a_en),
    .b_en      (b_en),
    .add_sel   (add_sel),
    .comp_sel  (comp_sel),
    // Status:
    .a_eq_b    (a_eq_b),
    .c_rdata   (c_rdata),
    // MEM req
    .mem_req_addr_o (mem_req_addr_o),
    .mem_req_data_o (mem_req_data_o),
    // MEM resp
    .mem_resp_addr_i (mem_resp_addr_i),
    .mem_resp_data_i (mem_resp_data_i),
    // PROC snk
    .resp_rd_o    (resp_rd_o),
    .resp_data_o  (resp_data_o)
  );

  //----------------------------------------------------------------------
  // Line Tracing
  //----------------------------------------------------------------------

  `ifndef SYNTHESIS

  // logic [`VC_TRACE_NBITS_TO_NCHARS(16)*8-1:0] str;
  logic [740:0] str;

  `VC_TRACE_BEGIN
  begin
    
    // check what's in rfile and what's going into rfile
    // $sformat( str, "%x en=%x adr=%x dat=%x R[2=%x 3=%x 4=%x 6=%x 7=%x 8=%x 9=%x 10=%x]", 
    //           ctrl.state, r_wen, r_waddr, dpath.r_wdata[7:0],
    //           dpath.rfile.rfile[2][43:32],
    //           dpath.rfile.rfile[3][11:0], dpath.rfile.rfile[4][11:0],
    //           dpath.rfile.rfile[6][11:0], dpath.rfile.rfile[7][11:0], 
    //           dpath.rfile.rfile[8][11:0], dpath.rfile.rfile[9][11:0],
    //           dpath.rfile.rfile[10][11:0] );

    // check what's going into adder
    // $sformat( str, "s=%x in0=%x in1=%x out=%x R[8]=%x R[9]=%x",
    //   ctrl.state,
    //   dpath.adder.in0[15:0],dpath.adder.in1[15:0],dpath.adder.out[15:0],
    //   dpath.rfile.rfile[8][15:0],dpath.rfile.rfile[9][15:0]);

    // $sformat( str, "s=%x respv=%x r_wen=%x r_waddr=%x r_wdata=%x", ctrl.state, mem_resp_valid_i, r_wen, r_waddr, dpath.mem_resp_data_i[31:0]);

    // $sformat( str, "mem=%x, %x", th.mem.mem.m[32'h0010][31:0], th.mem.mem.block_offset_M);

    // check mem req/resp
    // $sformat( str, "%x rd0:%x-%x c:%x t:%x req(t:%x l:%x a:%x,d:%x) resp(a:%x d:%x)", ctrl.state,
    //           dpath.r_rdata0[15:0],mem_req_addr_o[15:0],
    //           mem_req_cmd_o[4:0], mem_req_typ_o[2:0],
    //           th.mem.mem.memreq_msg_type_M[4:0],th.mem.mem.memreq_msg_len_M[2:0],
    //           mem_req_addr_o[15:0], dpath.r_rdata1[15:0], //th.mem.mem.memreq_msg_addr_M[15:0],th.mem.mem.memreq_msg_data_M[15:0],
    //           th.mem.mem_memresp_msg[67+15:67], th.mem.mem_memresp_msg[15:0]);               // th.mem.mem.read_data_M[15:0]);
                                      // th.mem.mem.physical_byte_addr_M[7:0],
                                      // th.mem.mem.physical_block_addr_M[7:0],
                                      // th.mem.mem.block_offset_M[2:0]);

    $sformat( str, "%x a=b:%x R2:%x R13:%x comp:%x %x", ctrl.state, 
      dpath.a_eq_b,
      dpath.rfile.rfile[2], dpath.rfile.rfile[13],
      dpath.comp.in0, dpath.comp.in1);
      // dpath.mem_req_addr_o[7:0], th.mem.mem.m[64'h0008>>3][7:0] );

    // $sformat( str, "s=%x c:%x-%x-%x-%x-%x-%x-%x-%x", ctrl.state,
    //           mem_req_cmd_o[4:0],
    //           th.mem_req_cmd_o[4:0],
    //           th.memreq_msg[119:115],
    //           th.mem.memreq_msg[119:115],
    //           th.mem.rand_req_delay.in_msg[119:115],
    //           th.mem.rand_req_delay.out_msg[119:115],
    //           th.mem.mem_memreq_msg[119:115],
    //           th.mem.mem.memreq_msg_M[119:115]);


    vc_trace.append_str( trace_str, str );


  end
  `VC_TRACE_END

  `endif /* SYNTHESIS */


endmodule

`endif /* SERIAL_MATMUL */
