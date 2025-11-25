//========================================================================
// RV Instruction Type
//========================================================================
// Sebastian Claudiusz Magierowski Feb 11 2023
/*
 Instruction types are similar to message types but are strictly used
 for communication within a RV-based processor. Instruction
 "messages" can be unpacked into the various fields as defined by the
 RV ISA, as well as be constructed from specifying each field
 explicitly. The 32-bit instruction has different fields depending on
 the format of the instruction used. The following are the various
 instruction encoding formats used in the RV ISA.
 
   31          25 24   20 19   15 14    12 11          7 6      0
  | funct7       | rs2   | rs1   | funct3 | rd          | opcode |  R-type
  | imm[11:0]            | rs1   | funct3 | rd          | opcode |  I-type, I-imm
  | imm[11:5]    | rs2   | rs1   | funct3 | imm[4:0]    | opcode |  S-type, S-imm
  | imm[12|10:5] | rs2   | rs1   | funct3 | imm[4:1|11] | opcode |  SB-type,B-imm
  | imm[31:12]                            | rd          | opcode |  U-type, U-imm
  | imm[20|10:1|11|19:12]                 | rd          | opcode |  UJ-type,J-imm
*/
`ifndef TINY_RV2_INST_V
`define TINY_RV2_INST_V

`include "vc-trace.v"

//------------------------------------------------------------------------
// Instruction fields
//------------------------------------------------------------------------

`define RV64_INST_OPCODE  6:0
`define RV64_INST_RD      11:7
`define RV64_INST_RS1     19:15
`define RV64_INST_RS2     24:20
`define RV64_INST_FUNCT3  14:12
`define RV64_INST_FUNCT7  31:25
`define RV64_INST_CSR     31:20

//------------------------------------------------------------------------
// Field sizes
//------------------------------------------------------------------------

`define RV64_INST_NBITS          32
`define RV64_INST_OPCODE_NBITS   7
`define RV64_INST_RD_NBITS       5
`define RV64_INST_RS1_NBITS      5
`define RV64_INST_RS2_NBITS      5
`define RV64_INST_FUNCT3_NBITS   3
`define RV64_INST_FUNCT7_NBITS   7
`define RV64_INST_CSR_NBITS      12

`define ROCC_RS1_NBITS           64

//------------------------------------------------------------------------
// Instruction opcodes
//------------------------------------------------------------------------

// Basic instructions

`define RV64_INST_CSRR  32'b???????_?????_?????_010_?????_1110011
`define RV64_INST_CSRW  32'b???????_?????_?????_001_?????_1110011
`define RV64_INST_NOP   32'b0000000_00000_00000_000_00000_0010011
`define RV64_ZERO       32'b0000000_00000_00000_000_00000_0000000

// Command instructions

`define RV64_INST_CMDI  32'b0000001_?????_?????_???_?????_???????
`define RV64_INST_CMDS  32'b0000010_?????_?????_???_?????_???????
`define RV64_INST_CMDW  32'b0000100_?????_?????_???_?????_???????
`define RV64_INST_CMDX  32'b0001000_?????_?????_???_?????_???????
`define RV64_INST_CMDR  32'b0010000_?????_?????_???_?????_???????


// Register-register arithmetic, logical, and comparison instructions

`define RV64_INST_ADD   32'b0000000_?????_?????_000_?????_0110011
`define RV64_INST_SUB   32'b0100000_?????_?????_000_?????_0110011
`define RV64_INST_AND   32'b0000000_?????_?????_111_?????_0110011
`define RV64_INST_OR    32'b0000000_?????_?????_110_?????_0110011
`define RV64_INST_XOR   32'b0000000_?????_?????_100_?????_0110011
`define RV64_INST_SLT   32'b0000000_?????_?????_010_?????_0110011
`define RV64_INST_SLTU  32'b0000000_?????_?????_011_?????_0110011
`define RV64_INST_MUL   32'b0000001_?????_?????_000_?????_0110011

// Register-immediate arithmetic, logical, and comparison instructions

`define RV64_INST_ADDI  32'b???????_?????_?????_000_?????_0010011
`define RV64_INST_ANDI  32'b???????_?????_?????_111_?????_0010011
`define RV64_INST_ORI   32'b???????_?????_?????_110_?????_0010011
`define RV64_INST_XORI  32'b???????_?????_?????_100_?????_0010011
`define RV64_INST_SLTI  32'b???????_?????_?????_010_?????_0010011
`define RV64_INST_SLTIU 32'b???????_?????_?????_011_?????_0010011

// Shift instructions

`define RV64_INST_SRA   32'b0100000_?????_?????_101_?????_0110011
`define RV64_INST_SRL   32'b0000000_?????_?????_101_?????_0110011
`define RV64_INST_SLL   32'b0000000_?????_?????_001_?????_0110011
`define RV64_INST_SRAI  32'b0100000_?????_?????_101_?????_0010011
`define RV64_INST_SRLI  32'b0000000_?????_?????_101_?????_0010011
`define RV64_INST_SLLI  32'b0000000_?????_?????_001_?????_0010011

// Other instructions

`define RV64_INST_LUI   32'b???????_?????_?????_???_?????_0110111
`define RV64_INST_AUIPC 32'b???????_?????_?????_???_?????_0010111

// Memory instructions

`define RV64_INST_LW    32'b???????_?????_?????_010_?????_0000011
`define RV64_INST_SW    32'b???????_?????_?????_010_?????_0100011

// Unconditional jump instructions

`define RV64_INST_JAL   32'b???????_?????_?????_???_?????_1101111
`define RV64_INST_JALR  32'b???????_?????_?????_000_?????_1100111

// Conditional branch instructions

`define RV64_INST_BEQ   32'b???????_?????_?????_000_?????_1100011
`define RV64_INST_BNE   32'b???????_?????_?????_001_?????_1100011
`define RV64_INST_BLT   32'b???????_?????_?????_100_?????_1100011
`define RV64_INST_BGE   32'b???????_?????_?????_101_?????_1100011
`define RV64_INST_BLTU  32'b???????_?????_?????_110_?????_1100011
`define RV64_INST_BGEU  32'b???????_?????_?????_111_?????_1100011

//------------------------------------------------------------------------
// Coprocessor registers
//------------------------------------------------------------------------

`define RV64_CPR_PROC2MNGR  12'h7C0
`define RV64_CPR_MNGR2PROC  12'hFC0
`define RV64_CPR_COREID     12'hF14
`define RV64_CPR_NUMCORES   12'hFC1
`define RV64_CPR_STATS_EN   12'h7C1

//------------------------------------------------------------------------
// Helper Tasks
//------------------------------------------------------------------------

module rv64_InstTasks();

  //----------------------------------------------------------------------
  // Assembly functions for each format type
  //----------------------------------------------------------------------

  function [`RV64_INST_NBITS-1:0] asm_fmt_r
  (
    input [`RV64_INST_OPCODE_NBITS-1:0] opcode,
    input [`RV64_INST_RD_NBITS-1:0]     rd,
    input [`RV64_INST_RS1_NBITS-1:0]    rs1,
    input [`RV64_INST_RS2_NBITS-1:0]    rs2
  );
  begin
    asm_fmt_r[`RV64_INST_OPCODE] = opcode;
    asm_fmt_r[`RV64_INST_RD]     = rd;
    asm_fmt_r[`RV64_INST_RS1]    = rs1;
    asm_fmt_r[`RV64_INST_RS2]    = rs2;
  end
  endfunction

  function [`RV64_INST_NBITS-1:0] asm_fmt_cmd
  (
    input [`RV64_INST_FUNCT7_NBITS-1:0] f7,
    input [`RV64_INST_OPCODE_NBITS-1:0] opcode
  );
  begin
    asm_fmt_cmd[`RV64_INST_FUNCT7] = f7;
    asm_fmt_cmd[`RV64_INST_RS2]    = 0;
    asm_fmt_cmd[`RV64_INST_RS1]    = 0;
    asm_fmt_cmd[`RV64_INST_FUNCT3] = 0;
    asm_fmt_cmd[`RV64_INST_RD]     = 0;
    asm_fmt_cmd[`RV64_INST_OPCODE] = opcode;
  end
  endfunction

  function [`RV64_INST_NBITS-1:0] asm_fmt_immi
  (
    input [`RV64_INST_OPCODE_NBITS-1:0] opcode,
    input [`RV64_INST_RD_NBITS-1:0]     rd,
    input [`RV64_INST_RS1_NBITS-1:0]    rs1,
    input [11:0]                        immi
  );
  begin
    asm_fmt_immi[`RV64_INST_OPCODE] = opcode;
    asm_fmt_immi[`RV64_INST_RD]     = rd;
    asm_fmt_immi[`RV64_INST_RS1]    = rs1;
    { asm_fmt_immi[31], asm_fmt_immi[30:25], asm_fmt_immi[24:21], asm_fmt_immi[20] } = immi;
  end
  endfunction

  //----------------------------------------------------------------------
  // Assembly functions for basic instructions
  //----------------------------------------------------------------------

  function [`RV64_INST_NBITS-1:0] asm_nop( input dummy );
  begin
    asm_nop = asm_fmt_immi( 6'b000000, 5'd0, 5'd0, 12'h0 );
  end
  endfunction

  function [`RV64_INST_NBITS-1:0] asm_cmd
  (
    input [`RV64_INST_FUNCT7_NBITS-1:0] f7,
    input [`RV64_INST_OPCODE_NBITS-1:0] opcode
  );
  begin
    asm_cmd = asm_fmt_cmd( f7, opcode );
  end
  endfunction


  //----------------------------------------------------------------------
  // Assembly from string
  //----------------------------------------------------------------------

  integer e;
  reg [10*8-1:0] inst_str;

  reg [`RV64_INST_OPCODE_NBITS-1:0] opcode;
  reg [`RV64_INST_RD_NBITS-1:0]     rd;
  reg [`RV64_INST_RS1_NBITS-1:0]    rs1;
  reg [`RV64_INST_RS2_NBITS-1:0]    rs2;

  reg [4:0]      ra;
  reg [4:0]      rb;
  reg [4:0]      rc;

  reg [6:0]  op;
  reg [6:0]  f7;
  
  function [`RV64_INST_NBITS-1:0] asm
  (
    input  [31:0]                 pc,
    input  [25*8-1:0]             str
  );
  begin
    e = $sscanf( str, "%s ", inst_str );
    case ( inst_str )
      "nop"   : begin                                                 asm = asm_nop  (0);        end
      "cmd"   : begin e = $sscanf( str, " cmd f:%d, o:%d ", f7, op ); asm = asm_cmd  ( f7, op ); end  // WOW!!!! VCS needs that space...
      default : asm = {`RV64_INST_NBITS{1'bx}};                       // ... between the " and cmd, otherwise it doesn't pass vals to f7
    endcase
    $write("str = %s\n",str);
    if ( e == 0 )
      asm = {`RV64_INST_NBITS{1'bx}};

    ra  = 5'bx;
    rb  = 5'bx;
    rc  = 5'bx;

  end
  endfunction

endmodule


`endif