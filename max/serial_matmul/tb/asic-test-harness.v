//========================================================================
// max/tb/asic-test-harness.v
//========================================================================
// Sebastian Claudiusz Magierowski Feb 28 2023

//=========================================================================
// ASIC Test Harness
//=========================================================================
/* Notes:
 Our exectuable has -test suffix, since VC_TEST_SUITE_BEGIN expects this
 
 SRC ------> UNPACK ---> ASIC ---> PACK -----> SNK
                         |  |
 MEM resp -> UNPACK -----'  '----> PACK -> MEM req
 
*/

`include "vc-TestRandDelaySource.v"
`include "vc-TestRandDelaySink.v"
`include "sm-TestRandDelayMem_1portX.v"
`include "sm-mem-msgsX.v"
`include "sm-msgs.v"
`include "vc-test.v"
`include "vc-trace.v"
`include "rv-inst.v" // define RV instruction types & assembly from text

//------------------------------------------------------------------------
// Helper Module
//------------------------------------------------------------------------

module TestHarness
#(
  parameter p_mem_nbytes  = 1 << 16, // size of physical memory in bytes
  parameter p_num_msgs    = 1024
)(
  input  logic clk,
  input  logic reset,
  input  logic mem_clear,
  input  logic [31:0] src_max_delay,
  input  logic [31:0] mem_max_delay,
  input  logic [31:0] sink_max_delay,  
  output logic done
);

  // Local parameters
  localparam c_req_msg_nbits  = `SM_MEM_REQ_MSG_NBITS(8,40,64);
  localparam c_resp_msg_nbits = `SM_MEM_RESP_MSG_NBITSX(8,40,64);
  localparam c_opaque_nbits   = 8;
  localparam c_data_nbits     = 64;   // size of mem message data in bits
  localparam c_addr_nbits     = 40;   // size of mem message address in bits

  // wires
  // logic [`ASIC_SRC_MSG_NBITS-1:0]   src_msg;
  logic [96-1:0]   src_msg;
  logic                             src_val;
  logic                             src_rdy;
  logic                             src_done;

  logic [5+`ASIC_SNK_MSG_NBITS-1:0] sink_msg; // hack (also in sink & load_to_mngr & init_sink)
  logic                             sink_val;
  logic                             sink_rdy;
  logic                             sink_done;

  //----------------------------------------------------------------------
  // PROC src
  //----------------------------------------------------------------------
  vc_TestRandDelaySource
  #(
    // .p_msg_nbits       (`ASIC_SRC_MSG_NBITS),
    .p_msg_nbits       (96),
    .p_num_msgs        (p_num_msgs)
  )
  src
  (
    .clk       (clk),
    .reset     (reset),
    .max_delay (src_max_delay),
    .val       (src_val),       // SRC -----v-----> ASIC
    .rdy       (src_rdy),       // SRC <----r------ ASIC
    .msg       (src_msg),       // SRC -> UNPACK -> ASIC (src_msg)
    .done      (src_done)
  );

  //----------------------------------------------------------------------
  // Unpack message from PROC src (PROC -> ASIC)
  //----------------------------------------------------------------------
  logic [63:0] cmd_rs1_i;
  logic [6:0]  cmd_inst_funct_i;
  logic [6:0]  cmd_inst_opcode_i;

  sm_RoccCmdUnpack#(64) src_msg_unpack
  (
    .msg             (src_msg),           // src_msg ->|
    .cmd_rs1         (cmd_rs1_i),         //           |-> cmd_rs1_i
    .cmd_inst_funct  (cmd_inst_funct_i),  //           |-> cmd_inst_funct_i
    .cmd_inst_rs2    (),                  //           |
    .cmd_inst_rs1    (),                  //           | 
    .cmd_inst_xd     (),                  //           |
    .cmd_inst_xs1    (),                  //           |
    .cmd_inst_rd     (),                  //           |
    .cmd_inst_opcode (cmd_inst_opcode_i)  //           |-> cmd_inst_opcode_i
  );
  
  //----------------------------------------------------------------------
  // MEM
  //----------------------------------------------------------------------
  logic                        memreq_val;
  logic                        memreq_rdy;
  logic [c_req_msg_nbits-1:0]  memreq_msg;

  logic                        memresp_val;
  logic                        memresp_rdy;
  logic [c_resp_msg_nbits-1:0] memresp_msg;

  sm_TestRandDelayMem_1port
  #(p_mem_nbytes, c_opaque_nbits, c_addr_nbits, c_data_nbits) mem
  (
    .clk         (clk),
    .reset       (reset),
    .mem_clear   (mem_clear),
    .max_delay   (mem_max_delay),
    // MEM req
    .memreq_val  (memreq_val),  //                ASIC ----v----> MEM
    .memreq_rdy  (memreq_rdy),  //                ASIC <---r----- MEM
    .memreq_msg  (memreq_msg),  //                ASIC -> PACK -> MEM
    // MEM resp
    .memresp_val (memresp_val), // MEM ----v----> ASIC 
    .memresp_rdy (1'b1),        // MEM <---r----- 1
    .memresp_msg (memresp_msg)  // MEM ->UNPACK-> ASIC            
  );

  //----------------------------------------------------------------------
  // Pack Memory Request Messages (MEM <- ASIC)
  //----------------------------------------------------------------------
  logic [4:0]  mem_req_cmd_o;
  logic [2:0]  mem_req_typ_o;
  logic [c_addr_nbits-1:0] mem_req_addr_o;
  logic [c_data_nbits-1:0] mem_req_data_o;

  sm_MemReqMsgPack#(8,c_addr_nbits,c_data_nbits) memreq_msg_pack
  (
    .type_  (mem_req_cmd_o),  //                     (set read or write)
    .opaque (8'b0),           //                     (what does this do?)
    .addr   (mem_req_addr_o), // ASIC -> PACK        (addr to read/write)
    .len    (mem_req_typ_o),  //                     (bytes in data)
    .data   (mem_req_data_o), // ASIC -> PACK        (data to write)
    .msg    (memreq_msg)      //         PACK -> MEM
  );

  //----------------------------------------------------------------------
  // Unpack Memory Response Messages (ASIC <- MEM)
  //----------------------------------------------------------------------
  logic [4:0]  mem_resp_cmd_i;
  logic [2:0]  mem_resp_typ_i;
  logic [c_addr_nbits-1:0] mem_resp_addr_i;
  logic [c_data_nbits-1:0] mem_resp_data_i;

  sm_MemRespMsgUnpack#(8,c_addr_nbits,c_data_nbits) memresp_msg_unpack
  (
    .msg    (memresp_msg),    // MEM -> UNPACK
    .opaque (),
    .addr   (mem_resp_addr_i),//        UNPACK -> ASIC    (addr of data)
    .type_  (mem_resp_cmd_i),
    .len    (mem_resp_typ_i),
    .data   (mem_resp_data_i) //        UNPACK -> ASIC    (data to read)
  );

  //----------------------------------------------------------------------
  // Pack message to PROC snk (ASIC -> PROC)
  //----------------------------------------------------------------------
  logic [4:0]  resp_rd_o;
  logic [31:0] resp_data_o;

  sm_RoccCmdPack#(32) snk_msg_pack
  (
    .resp_rd         (resp_rd_o),     // resp_rd_o --->|
    .resp_data       (resp_data_o),   // resp_data_o ->|
                                      //               |
    .msg             (sink_msg)       //               |-> sink_msg
  );

  //----------------------------------------------------------------------
  // ASIC
  //----------------------------------------------------------------------
  `ASIC_IMPL asic
  (
    .clk    (clk),
    .reset  (reset),
    // PROC src
    .cmd_rs1_i         (cmd_rs1_i),
    .cmd_inst_funct_i  (cmd_inst_funct_i),
    .cmd_inst_opcode_i (cmd_inst_opcode_i),
    .cmd_valid_i       (src_val),           // src_val --v--> ctrl
    .cmd_ready_o       (src_rdy),           // src_rdy <--r-- ctrl
    // MEM req
    .mem_req_valid_o  (memreq_val),     // ctrl
    .mem_req_ready_i  (memreq_rdy),     // ctrl
    .mem_req_cmd_o    (mem_req_cmd_o),  // ctrl
    .mem_req_typ_o    (mem_req_typ_o),  // ctrl
    .mem_req_addr_o   (mem_req_addr_o), // dpath
    .mem_req_data_o   (mem_req_data_o), // dpath
    // MEM resp
    .mem_resp_valid_i  (memresp_val),     // ctrl
    .mem_resp_cmd_i    (mem_resp_cmd_i),  // ctrl
    .mem_resp_typ_i    (mem_resp_typ_i),  // ctrl
    .mem_resp_addr_i   (mem_resp_addr_i), // dpath
    .mem_resp_data_i   (mem_resp_data_i), // dpath
    // PROC snk
    .resp_rd_o    (resp_rd_o),
    .resp_data_o  (resp_data_o),
    .resp_valid_o (sink_val),
    .resp_ready_i (sink_rdy)    
  );

  //----------------------------------------------------------------------
  // PROC snk
  //----------------------------------------------------------------------
  vc_TestRandDelaySink
  #(
    .p_msg_nbits       (5+`ASIC_SNK_MSG_NBITS),
    .p_num_msgs        (p_num_msgs)
  )
  sink
  (
    .clk       (clk),
    .reset     (reset),
    .max_delay (sink_max_delay),
    .val       (sink_val),       //       ASIC -> SNK
    .rdy       (sink_rdy),       //       ASIC <- SNK
    .msg       (sink_msg),       //       ASIC -> SNK
    .done      (sink_done)
  );

  assign done = src_done && sink_done;

  logic [740:0] str;

  `VC_TRACE_BEGIN
  begin
    src.trace( trace_str );
    vc_trace.append_str( trace_str, " > " );
    asic.trace( trace_str );
    // $sformat( str, "s=%x t:%x-%x-%x o:%x-%x l:%x", asic.ctrl.state,
    //   mem_req_cmd_o, memreq_msg_pack.sm_MemReqMsgPack.type_, memreq_msg[119:115],
    //   memreq_msg[114:107], memreq_msg_pack.sm_MemReqMsgPack.opaque, memreq_msg[66:64]);
    // vc_trace.append_str( trace_str, str );
    vc_trace.append_str( trace_str, " > " );
    mem.trace( trace_str );
    vc_trace.append_str( trace_str, " > " );
    sink.trace( trace_str );
  end
  `VC_TRACE_END

endmodule

//------------------------------------------------------------------------
// Main Tester Module
//------------------------------------------------------------------------

module top;
  `VC_TEST_SUITE_BEGIN( `ASIC_IMPL_STR )

  rv64_InstTasks rv64();

  //----------------------------------------------------------------------
  // Test setup
  //----------------------------------------------------------------------

  // Instantiate the test harness

  logic         th_reset = 1;
  logic         th_mem_clear;
  logic  [31:0] th_src_max_delay;
  logic  [31:0] th_mem_max_delay;
  logic  [31:0] th_sink_max_delay;
  logic  [31:0] th_inst_asm_str;   // instr binary derived from str
  logic  [31:0] th_addr;
  logic  [31:0] th_src_idx;
  logic  [31:0] th_sink_idx;
  logic         th_done;

  // assign th_addr = 0;

  TestHarness th
  (
    .clk            (clk),
    .reset          (th_reset),
    .mem_clear      (th_mem_clear),
    .src_max_delay  (th_src_max_delay),
    .mem_max_delay  (th_mem_max_delay),
    .sink_max_delay (th_sink_max_delay),
    .done           (th_done)
  );

  //----------------------------------------------------------------------
  // load_mem: helper task to load one word into memory
  //----------------------------------------------------------------------

  task load_mem
  (
    input logic [31:0] addr,
    input logic [31:0] data
  );
  begin
    // Why [addr >> 3]? Because m in sm-TestMem_1port.v is treated as a file
    // with 64b blocks by the memory request logic.  So when (byte) addresses
    // come in they are split into block and offset fields to find the right 
    // byte in memory.  But if we just index m by our address of interest
    // with [ addr ] it will effectively put our data in the block equal to addr
    // not the byte equal to addr (and its the byte equal to addr that we want
    // in a byte addressing)
    th.mem.mem.m[ addr >> 3 ] = data;
    // th.mem.mem.m[ addr >> 2 ] = data;
  end
  endtask

  //----------------------------------------------------------------------
  // load_from_mngr: helper task to load an entry into the from_mngr source
  //----------------------------------------------------------------------

  task load_from_mngr
  (
    input logic [ 9:0]                       i,
    // input logic [`ASIC_SRC_MSG_NBITS-1:0]  msg
    input logic [96-1:0]  msg
  );
  begin
    th.src.src.m[i] = msg;
  end
  endtask

  //----------------------------------------------------------------------
  // load_to_mngr: helper task to load an entry into the to_mngr sink
  //----------------------------------------------------------------------

  task load_to_mngr
  (
    input logic [ 9:0]                         i,
    input logic [5+`ASIC_SNK_MSG_NBITS-1:0]    msg
  );
  begin
    th.sink.sink.m[i] = msg;
  end
  endtask
  
  //----------------------------------------------------------------------
  // clear_mem: clear the contents of memory and test sources and sinks
  //----------------------------------------------------------------------

  task clear_mem;
  begin
    #1;   th_mem_clear = 1'b1;
    #20;  th_mem_clear = 1'b0;
    th_src_idx = 0;
    th_sink_idx = 0;
    // in case there are no srcs/sinks, we set the first elements of them
    // to xs
    load_from_mngr( 0, 32'hxxxxxxxx );
    load_to_mngr(   0, 32'hxxxxxxxx );
  end
  endtask

  //----------------------------------------------------------------------
  // init_sink: add a data to the test sink
  //----------------------------------------------------------------------

  task init_sink
  (
    // input logic [31:0] data
    input logic [5+31:0] data

  );
  begin
    load_to_mngr( th_sink_idx, data );
    th_sink_idx = th_sink_idx + 1;
    // we set the next address with x's so that src/sink stops here if
    // there isn't another call to init_src/sink
    // load_to_mngr( th_sink_idx, 32'hxxxxxxxx );
    load_to_mngr( th_sink_idx, 37'hxx_xxxxxxxx );
  end
  endtask

  //----------------------------------------------------------------------
  // inst_src: assemble & add an instruction to the test src
  //----------------------------------------------------------------------
  // src msg will be { rs1 data , assembled cmd instruction }
  task inst_src
  (
    input logic [63:0]     rs1,
    input logic [25*8-1:0] asm_str
  );
  begin
    th_inst_asm_str = rv64.asm( th_src_idx, asm_str );
    load_from_mngr( th_src_idx, {rs1,th_inst_asm_str} );
    th_src_idx = th_src_idx + 1;
    // we set the next address with x's so that src/sink stops here if
    // there isn't another call to init_src/sink
    // load_from_mngr( th_src_idx, 64'hxxxx_xxxx_xxxx_xxxx );
    load_from_mngr( th_src_idx, 96'hxxxx_xxxx_xxxx_xxxx_xxxx_xxxx );
  end
  endtask

  //----------------------------------------------------------------------
  // inst: assemble and put instruction to next addr
  //----------------------------------------------------------------------

  task inst
  (
    input logic [25*8-1:0] asm_str
  );
  begin
    th_inst_asm_str = rv64.asm( th_addr, asm_str );
    load_mem( th_addr, th_inst_asm_str );
    // increment pc
    th_addr = th_addr + 4;
  end
  endtask

  //----------------------------------------------------------------------
  // data: put data_in to next addr, useful for mem ops
  //----------------------------------------------------------------------

  task data
  (
    input logic [31:0] data_in
  );
  begin
    load_mem( th_addr, data_in );
    // increment pc
    th_addr = th_addr + 8; // assume new data appears every 64b
  end
  endtask

  //----------------------------------------------------------------------
  // address: each consecutive call to inst and data would be put after
  // this address
  //----------------------------------------------------------------------

  task address
  (
    input logic [31:0] addr
  );
  begin
    th_addr = addr;
  end
  endtask

  localparam c_ref_arr_size = 256;

  // reference and ubmark-related regs

  logic [31:0]   ref_addr;
  logic [ 8:0]   ref_arr_idx;
  logic [31:0]   ref_arr [ c_ref_arr_size-1:0 ];
  logic [20*8:0] ubmark_name;
  logic [ 8:0]   ubmark_dest_size;


  // expected and actual data

  logic [31:0] exp_data;
  logic [31:0] actual_data;

  //----------------------------------------------------------------------
  // verify: verify the outputs
  //----------------------------------------------------------------------

  task verify;
  begin
    // set the address to the beginning of the destination
    th_addr = ref_addr;
    // $write("HELLO!\n");
    for ( ref_arr_idx = 0; ref_arr_idx < ubmark_dest_size;
                        ref_arr_idx = ref_arr_idx + 1 ) begin
      exp_data    = ref_arr[ ref_arr_idx ];
      actual_data = th.mem.mem.m[ th_addr >> 3 ];
      // $write("exp_data=%x actual_data=%x\n",exp_data, actual_data);
      // check if the expected and actual are the same
      if ( !( exp_data === actual_data ) ) begin
        $display( "  [ FAILED ] %s : dest[%d] != ref[%d] (%d != %d)",
                  ubmark_name, ref_arr_idx, ref_arr_idx,
                  actual_data, exp_data );
        // exit if we have a failure
        // $finish_and_return(1);
        $finish;
      end

      // increment the address
      th_addr = th_addr + 8;
    end

    // if we didn't exit, we passed
    $display( "  [ passed ] %s", ubmark_name );
  end
  endtask


  //----------------------------------------------------------------------
  // ref_data: add a reference data to be checked in verify
  //----------------------------------------------------------------------

  task ref_data
  (
    // input logic [31:0] data_in
    input logic [63:0] data_in
  );
  begin
    ref_arr[ ref_arr_idx ] = data_in;
    ref_arr_idx = ref_arr_idx + 1;
  end
  endtask


  //----------------------------------------------------------------------
  // ref_address: register the destination address and reset ref_arr_idx
  //----------------------------------------------------------------------

  task ref_address
  (
    input logic [31:0] addr
  );
  begin
    ref_addr = addr;
    ref_arr_idx = 0;
  end
  endtask

  //----------------------------------------------------------------------
  // Helper task to initialize random delay setup
  //----------------------------------------------------------------------

  task init_rand_delays
  (
    input logic [31:0] src_max_delay,
    input logic [31:0] mem_max_delay,
    input logic [31:0] sink_max_delay
  );
  begin
    th_src_max_delay  = src_max_delay;
    th_mem_max_delay  = mem_max_delay;
    th_sink_max_delay = sink_max_delay;
  end
  endtask

  //----------------------------------------------------------------------
  // Helper task to run test
  //----------------------------------------------------------------------

  task run_test;
  begin
    #1;   th_reset = 1'b1;
    #20;  th_reset = 1'b0;

    while ( !th_done && (th.vc_trace.cycles < 60) ) begin
      th.display_trace();
      #10;
    end

    `VC_TEST_NET( th_done, 1'b1 );
  end
  endtask

  //----------------------------------------------------------------------
  // include the actual test cases
  //----------------------------------------------------------------------
  `include `ASIC_TEST_CASES_FILE

  `VC_TEST_SUITE_END
endmodule
