//========================================================================
// max/tb/asic-test-cases-1x2.v
//========================================================================
// Sebastian Claudiusz Magierowski Feb 28 2023

// Test Cases for W(1x2)
// this file is to be `included by asic.t.v
// Test a variety of different behaviours with only a (1x2) W input matrix

// pointers for W,x,r arrays
localparam c_W_src0_ptr = 32'h0000; // byte address, but make these multiples
localparam c_x_src1_ptr = 32'h0010; // of 8 (i.e., # of bytes in a 64b word)
localparam c_r_dest_ptr = 32'h0030; // until we better understand how our 
                                    // mem works, more comments in 
                                    // asic-test-harness.v in load_mem task
//                            k    a      
localparam init         = 32'h0000_0000;
localparam c_M_size     = 1; // # of rows in W, # of elements in o/p r
localparam c_N_size     = 2; // # of cols in W, # of elements in i/p x
localparam size         = {c_N_size[15:0],c_M_size[15:0]};

//------------------------------------------------------------------------
// Basic tests  opcode = 0: r = y' (SWS o/p) opcode = 1: r = z  (ReLU o/p)
//------------------------------------------------------------------------

task init_1x2_op0_pve_sml_raw; // opcode = 0, positive small numbers
begin
  clear_mem;
  load_from_mngr(0, {init,        32'b0000001_000000_000000_000000_0000000});
  load_from_mngr(1, {size,        32'b0000010_000000_000000_000000_0000000});
  load_from_mngr(2, {c_W_src0_ptr,32'b0000100_000000_000000_000000_0000000});
  load_from_mngr(3, {c_x_src1_ptr,32'b0001000_000000_000000_000000_0000000});
  load_from_mngr(4, {c_r_dest_ptr,32'b0010000_000000_000000_000000_0000000});
  init_sink( 37'h01_00000001 ); // what the sink expects to see
  init_pve_sml_data;            // put pos small data in mem & ref array
end
endtask

task init_1x2_op0_pve_sml; // opcode = 0, positive small numbers
begin
  clear_mem;
  // load the src with this data
  inst_src( init,         "cmd f:1, o:0  " ); // cmd.init  + cmd.rs1 = k,a
  inst_src( size,         "cmd f:2, o:0  " ); // cmd.size  + cmd.rs1 = N,M
  inst_src( c_W_src0_ptr, "cmd f:4, o:0  " ); // cmd.addrW + cmd.rs1 = Wptr
  inst_src( c_x_src1_ptr, "cmd f:8, o:0  " ); // cmd.addrX + cmd.rs1 = xptr
  inst_src( c_r_dest_ptr, "cmd f:16, o:0 " ); // cmd.addrR + cmd.rs1 = rptr
  // load the snk with this data (indicator of successful result)
  init_sink( 37'h01_00000001 );
  init_pve_sml_data;            // put pos small data in mem & ref array
end
endtask

//------------------------------------------------------------------------
// initialize source and reference data for basic test
//------------------------------------------------------------------------

task init_pve_sml_data;
begin

  ubmark_name = "positive small data";
  ubmark_dest_size = c_M_size;

  address( c_W_src0_ptr ); // set test harness address
  data( 64'd1 );           // put data in current address and increment address
  data( 64'd2 );

  address( c_x_src1_ptr ); 
  data( 64'd2 );
  data( 64'd3 );

  ref_address( c_r_dest_ptr );
  ref_data( 64'd8 );

end
endtask


//------------------------------------------------------------------------
// Test Case: 1x2 basic
//------------------------------------------------------------------------

`VC_TEST_CASE_BEGIN( 1, "1x2 op0 pos sml raw" ) // +test_case=1
begin
  init_rand_delays( 0, 0, 0 );
  init_1x2_op0_pve_sml_raw;
  $write("W[0,0]=%x\n", th.mem.mem.m[64'h0000>>3]);
  $write("W[0,1]=%x\n", th.mem.mem.m[64'h0008>>3]);
  $write("x[0]  =%x\n", th.mem.mem.m[64'h0010>>3]);
  $write("x[1]  =%x\n", th.mem.mem.m[64'h0018>>3]);
  $write("r[0]  =%x\n", th.mem.mem.m[64'h0030>>3]);
  run_test;
  $write("W[0,0]=%x\n", th.mem.mem.m[64'h0000>>3]);
  $write("W[0,1]=%x\n", th.mem.mem.m[64'h0008>>3]);
  $write("x[0]  =%x\n", th.mem.mem.m[64'h0010>>3]);
  $write("x[1]  =%x\n", th.mem.mem.m[64'h0018>>3]);
  $write("r[0]  =%x\n", th.mem.mem.m[64'h0030>>3]);
  verify;
  $write("W[0,0]=%x\n", th.mem.mem.m[32'h0000>>3]);
  $write("W[0,1]=%x\n", th.mem.mem.m[64'h0008>>3]);
  $write("x[0]  =%x\n", th.mem.mem.m[32'h0010>>3]);
  $write("x[1]  =%x\n", th.mem.mem.m[32'h0018>>3]);
  $write("r[0]  =%x\n", th.mem.mem.m[32'h0030>>3]);
end
`VC_TEST_CASE_END


`VC_TEST_CASE_BEGIN( 2, "1x2 op0 pos sml" ) // +test_case=2
begin
  init_rand_delays( 0, 0, 0 );
  init_1x2_op0_pve_sml;
  $write("W[0,0]=%x\n", th.mem.mem.m[64'h0000>>3]);
  $write("W[0,1]=%x\n", th.mem.mem.m[64'h0008>>3]);
  $write("x[0]  =%x\n", th.mem.mem.m[64'h0010>>3]);
  $write("x[1]  =%x\n", th.mem.mem.m[64'h0018>>3]);
  $write("r[0]  =%x\n", th.mem.mem.m[64'h0030>>3]);
  run_test;
  $write("W[0,0]=%x\n", th.mem.mem.m[64'h0000>>3]);
  $write("W[0,1]=%x\n", th.mem.mem.m[64'h0008>>3]);
  $write("x[0]  =%x\n", th.mem.mem.m[64'h0010>>3]);
  $write("x[1]  =%x\n", th.mem.mem.m[64'h0018>>3]);
  $write("r[0]  =%x\n", th.mem.mem.m[64'h0030>>3]);
  verify;
  $write("W[0,0]=%x\n", th.mem.mem.m[32'h0000>>3]);
  $write("W[0,1]=%x\n", th.mem.mem.m[64'h0008>>3]);
  $write("x[0]  =%x\n", th.mem.mem.m[32'h0010>>3]);
  $write("x[1]  =%x\n", th.mem.mem.m[32'h0018>>3]);
  $write("r[0]  =%x\n", th.mem.mem.m[32'h0030>>3]);
end
`VC_TEST_CASE_END

