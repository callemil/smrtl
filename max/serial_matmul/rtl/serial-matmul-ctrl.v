//=========================================================================
// max/rtl/serial-matmul-ctrl.v
//=========================================================================
// Sebastian Claudiusz Magierowski Feb 16 2023
//
// A part of serial-matmul.v  (look for some definitions there)

`ifndef SERIAL_MATMUL_CTRL_V
`define SERIAL_MATMUL_CTRL_V

//========================================================================
// SERIAL_MATMUL Control
//========================================================================

module serial_matmul_ctrl
(
  input  logic clk,
  input  logic reset,
  // PROC src dataflow signals
  input  logic cmd_valid_i,
  output logic cmd_ready_o,
  // Control: bus enable
  output logic src_bus_en,
  output logic resp_bus_en,
  output logic add_bus_en,
  output logic mul_bus_en,
  output logic sws_bus_en,
  output logic relu_bus_en,
  // Control: X reg file
  output logic               x_wen,
  output logic [`X_ADDR-1:0] x_waddr,
  // Control: C reg file
  output logic               c_wen,
  output logic [`C_ADDR-1:0] c_waddr,
  // Control: R reg file
  output logic               r_wen,
  output logic [`R_ADDR-1:0] r_waddr,
  output logic [`R_ADDR-1:0] r_raddr0,
  output logic [`R_ADDR-1:0] r_raddr1,
  // Control: component en/sel
  output logic a_en,
  output logic b_en,
  output logic [1:0] add_sel,
  output logic comp_sel,
  // Status signals
  input logic a_eq_b,
  input logic [6:0] init,
  // MEM req
  input  logic mem_req_ready_i,
  output logic mem_req_valid_o,
  output logic [4:0] mem_req_cmd_o,
  output logic [2:0] mem_req_typ_o,
  // MEM resp
  input  logic mem_resp_valid_i,
  input  logic [4:0] mem_resp_cmd_i,
  input  logic [2:0] mem_resp_typ_i,
  // PROC snk dataflow signals
  output logic resp_valid_o,
  input  logic resp_ready_i
);

  // TEMPORARY STUFF, BE CAREFUL OF THESE CAUSING ERRORS/WARNINGS AS YOU BUILD CCT
  // *****************************************************************************
  // assign mem_req_cmd_o = 0;
  // *****************************************************************************

  //                               1     2     3     4     5    
  typedef enum logic [5:0] {START, SRC1, SRC2, SRC3, SRC4, SRC5, 
  //                               6     7     8     9     
                                   CPX0, CPX1, RJ00, RJ01, 
  //                               0a    0b    0c    0d
                                   LW0,  LW1,  LX0,  LX1,
  //                               0e    0f    10    11    12    13
                                   MUL0, MUL1, MUL2, ADD0, ADD1, ADD2,
  //                               14    15    16    17    18    19
                                   WI80, WI81, XI80, XI81, JI10, JI11,
  //                               1a    1b    1c    1d    1e    1f
                                   BRN0, BRN1, SWS0, SWS1, REL0, REL1,
  //                               20    21    22    23    24    25
                                   SR0,  SR1,  RI80, RI81, II10, II11,
  //                               26    27    28
                                   BRM0, BRM1, END0} statetype;  
  statetype state, nextstate;

  // State
  always @( posedge clk ) begin
    if ( reset ) begin
      state <= START;
    end
    else begin
      state <= nextstate;
    end
  end

  // State Transitions
  always @(*) begin
    nextstate = state;
    case ( state)
      START:                       nextstate = SRC1; // req W[i,j]
      SRC1 : if (cmd_valid_i)      nextstate = SRC2; //
      SRC2 : if (cmd_valid_i)      nextstate = SRC3; //
      SRC3 : if (cmd_valid_i)      nextstate = SRC4; //
      SRC4 : if (cmd_valid_i)      nextstate = SRC5; //
      SRC5 : if (cmd_valid_i)      nextstate = CPX0; //
      CPX0 :                       nextstate = CPX1; //
      CPX1 :                       nextstate = RJ00; //
      RJ00 :                       nextstate = RJ01; //
      RJ01 :                       nextstate = LW0;  //
      LW0  : if (mem_req_ready_i)  nextstate = LW1;  //
      LW1  : if (mem_resp_valid_i) nextstate = LX0;  //
      LX0  : if (mem_req_ready_i)  nextstate = LX1;  //
      LX1  : if (mem_resp_valid_i) nextstate = MUL0; //
      MUL0 :                       nextstate = MUL1; //
      MUL1 :                       nextstate = MUL2; //
      MUL2 :                       nextstate = ADD0; //
      ADD0 :                       nextstate = ADD1; //
      ADD1 :                       nextstate = ADD2; //
      ADD2 :                       nextstate = WI80; //
      WI80 :                       nextstate = WI81; //
      WI81 :                       nextstate = XI80; //
      XI80 :                       nextstate = XI81; //
      XI81 :                       nextstate = JI10; //
      JI10 :                       nextstate = JI11; //
      JI11 :                       nextstate = BRN0; //
      BRN0 :                       nextstate = BRN1; //
      BRN1 : if (!a_eq_b)          nextstate = LW0;  //
       else  if (a_eq_b)           nextstate = SWS0; //
      SWS0 :                       nextstate = SWS1; //
      SWS1 :                       nextstate = REL0; //
      REL0 :                       nextstate = REL1; //
      REL1 :                       nextstate = SR0;  //
      SR0  : if (mem_req_ready_i)  nextstate = SR1;  //
      SR1  :                       nextstate = RI80; //
      RI80 :                       nextstate = RI81; //
      RI81 :                       nextstate = II10; //
      II10 :                       nextstate = II11; //
      II11 :                       nextstate = BRM0; //
      BRM0 :                       nextstate = BRM1; //
      BRM1 : if (!a_eq_b)          nextstate = CPX0; //
       else  if (a_eq_b)           nextstate = END0; //
      END0 : if (resp_ready_i)     nextstate = START; //                                          
    endcase
  end

  // State Outputs (control signals)
  task cs
  (
    input logic               cs_src_rdy,  //  1 
    input logic               cs_snk_val,  //  2
    input logic               cs_req_val,  //  3
    input logic               cs_src_bus,  //  4
    input logic               cs_resp_bus, //  5
    input logic               cs_add_bus,  //  6
    input logic               cs_sws_bus,  //  7
    input logic               cs_mul_bus,  //  8
    input logic               cs_relu_bus, //  9
    input logic               cs_x_wen,    // 10
    input logic [`X_ADDR-1:0] cs_x_waddr,  // 11
    input logic               cs_c_wen,    // 12
    input logic [`C_ADDR-1:0] cs_c_waddr,  // 13
    input logic               cs_r_wen,    // 14
    input logic [`R_ADDR-1:0] cs_r_waddr,  // 15
    input logic [`R_ADDR-1:0] cs_r_raddr0, // 16
    input logic [`R_ADDR-1:0] cs_r_raddr1, // 17
    input logic [4:0]         cs_req_cmd,  // 18
    input logic [2:0]         cs_req_typ,  // 19
    input logic               cs_a_en,     // 20
    input logic               cs_b_en,     // 21
    input logic [1:0]         cs_add_sel,  // 22
    input logic               cs_comp_sel  // 23
  );
  begin
    cmd_ready_o     = cs_src_rdy;    // 1
    resp_valid_o    = cs_snk_val;    // 2
    mem_req_valid_o = cs_req_val;    // 3
    src_bus_en      = cs_src_bus;    // 4
    resp_bus_en     = cs_resp_bus;   // 5
    add_bus_en      = cs_add_bus;    // 6
    sws_bus_en      = cs_sws_bus;    // 7
    mul_bus_en      = cs_mul_bus;    // 8
    relu_bus_en     = cs_relu_bus;   // 9
    x_wen           = cs_x_wen;      // 10
    x_waddr         = cs_x_waddr;    // 11
    c_wen           = cs_c_wen;      // 12
    c_waddr         = cs_c_waddr;    // 13
    r_wen           = cs_r_wen;      // 14
    r_waddr         = cs_r_waddr;    // 15
    r_raddr0        = cs_r_raddr0;   // 16 rr0 adr
    r_raddr1        = cs_r_raddr1;   // 17
    mem_req_cmd_o   = cs_req_cmd;    // 18
    mem_req_typ_o   = cs_req_typ;    // 19
    a_en            = cs_a_en;       // 20
    b_en            = cs_b_en;       // 21
    add_sel         = cs_add_sel;    // 22
    comp_sel        = cs_comp_sel;   // 23
  end
  endtask

  always @(*) begin
    //  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23
    cs( 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 );
    case ( state )
      //                             1   2   3   4   5   6   7   8   9   10  11  12  13  14  15  16  17  18  19  20  21  22  23
      //                             src snk req src res add sws mul rel x   xw  c   cw  r   rw  rr0 rr1 req req a   b   add comp
      //                             rdy val val bus bus bus bus bus bus wen adr wen adr wen adr adr adr cmd typ en  en  sel sel
      START:                       cs( 1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0 ); //  0
      SRC1: if (cmd_valid_i)       cs( 1,  0,  0,  1,  0,  0,  0,  0,  0,  1,  1,  1,  0,  1,  1,  0,  0,  0,  0,  0,  0,  0,  0 ); //  1 SRC1  only write when src val
       else if (!cmd_valid_i)      cs( 1,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  0,  0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  0 ); //  1 SRC1
      SRC2: if (cmd_valid_i)       cs( 1,  0,  0,  1,  0,  0,  0,  0,  0,  1,  2,  0,  0,  1,  2,  0,  0,  0,  0,  0,  0,  0,  0 ); //  2 SRC2
       else if (!cmd_valid_i)      cs( 1,  0,  0,  1,  0,  0,  0,  0,  0,  0,  2,  0,  0,  0,  2,  0,  0,  0,  0,  0,  0,  0,  0 ); //  2 SRC2
      SRC3: if (cmd_valid_i)       cs( 1,  0,  0,  1,  0,  0,  0,  0,  0,  1,  3,  0,  0,  1,  3,  0,  0,  0,  0,  0,  0,  0,  0 ); //  3 SRC3
       else if (!cmd_valid_i)      cs( 1,  0,  0,  1,  0,  0,  0,  0,  0,  0,  3,  0,  0,  0,  3,  0,  0,  0,  0,  0,  0,  0,  0 ); //  3 SRC3
      SRC4: if (cmd_valid_i)       cs( 1,  0,  0,  1,  0,  0,  0,  0,  0,  1,  4,  0,  0,  1,  4,  0,  0,  0,  0,  0,  0,  0,  0 ); //  4 SRC4
       else if (!cmd_valid_i)      cs( 1,  0,  0,  1,  0,  0,  0,  0,  0,  0,  4,  0,  0,  0,  4,  0,  0,  0,  0,  0,  0,  0,  0 ); //  4 SRC4
      SRC5: if (cmd_valid_i)       cs( 1,  0,  0,  1,  0,  0,  0,  0,  0,  1,  5,  0,  0,  1,  5,  0,  0,  0,  0,  0,  0,  0,  0 ); //  5 SRC5
       else if (!cmd_valid_i)      cs( 1,  0,  0,  1,  0,  0,  0,  0,  0,  0,  5,  0,  0,  0,  5,  0,  0,  0,  0,  0,  0,  0,  0 ); //  5 SRC5
      CPX0:                        cs( 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  4,  0,  0,  1,  1,  0,  0 ); //  6 CPX0
      CPX1:                        cs( 0,  0,  0,  0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  1, 15,  0,  0,  0,  0,  0,  0,  0,  0 ); //  7 CPX1
      RJ00:                        cs( 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  1,  0,  0 ); //  8 RJ00
      RJ01:                        cs( 0,  0,  0,  0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  1, 10,  0,  0,  0,  0,  0,  0,  0,  0 ); //  9 RJ01
      LW0 :                        cs( 0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  3,  0,  0,  1,  0,  0,  0,  0 ); //  a LW0
      LW1 : if (!mem_resp_valid_i) cs( 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  6,  0,  0,  0,  0,  0,  0,  0,  0 ); //  b LW1
       else if ( mem_resp_valid_i) cs( 0,  0,  0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  0,  1,  6,  0,  0,  0,  0,  0,  0,  0,  0 ); //  b LW1
      LX0 :                        cs( 0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 15,  0,  0,  1,  0,  0,  0,  0 ); //  c LX0
      LX1 : if (!mem_resp_valid_i) cs( 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  7,  0,  0,  0,  0,  0,  0,  0,  0 ); //  d LX1
       else if ( mem_resp_valid_i) cs( 0,  0,  0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  0,  1,  7,  0,  0,  0,  0,  0,  0,  0,  0 ); //  d LX1
      MUL0:                        cs( 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  6,  0,  0,  0,  1,  0,  0,  0 ); //  e MUL0
      MUL1:                        cs( 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  7,  0,  0,  0,  1,  0,  0 ); //  f MUL1
      MUL2:                        cs( 0,  0,  0,  0,  0,  0,  0,  1,  0,  0,  0,  0,  0,  1,  8,  0,  0,  0,  0,  0,  0,  0,  0 ); // 10 MUL2
      ADD0:                        cs( 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  8,  0,  0,  0,  1,  0,  0,  0 ); // 11 ADD0
      ADD1:                        cs( 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  9,  0,  0,  0,  1,  0,  0 ); // 12 ADD1
      ADD2:                        cs( 0,  0,  0,  0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  1,  9,  0,  0,  0,  0,  0,  0,  0,  0 ); // 13 ADD2
      WI80:                        cs( 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  3,  0,  0,  0,  1,  0,  0 ); // 14 WI80
      WI81:                        cs( 0,  0,  0,  0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  1,  3,  0,  0,  0,  0,  0,  0,  3,  0 ); // 15 WI81
      XI80:                        cs( 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 15,  0,  0,  0,  1,  0,  0 ); // 16 XI80
      XI81:                        cs( 0,  0,  0,  0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  1, 15,  0,  0,  0,  0,  0,  0,  3,  0 ); // 17 XI81
      JI10:                        cs( 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 10,  0,  0,  0,  1,  0,  0 ); // 18 JI10
      JI11:                        cs( 0,  0,  0,  0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  1, 10,  0,  0,  0,  0,  0,  0,  1,  0 ); // 19 JI11
      BRN0:                        cs( 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  2, 10,  0,  0,  1,  1,  0,  0 ); // 1a BRN0
      BRN1:                        cs( 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  2, 10,  0,  0,  1,  1,  0,  0 ); // 1b BRN1 also don't make this all 0's???
      SWS0:                        cs( 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  9,  1,  0,  0,  1,  1,  0,  0 ); // 1c SWS0
      SWS1:                        cs( 0,  0,  0,  0,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1, 11,  0,  0,  0,  0,  0,  0,  0,  0 ); // 1d SWS1
      REL0:                        cs( 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 11,  0,  0,  0,  1,  0,  0,  0 ); // 1e REL0
      REL1:                        cs( 0,  0,  0,  0,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1, 12,  0,  0,  0,  0,  0,  0,  0,  0 ); // 1f REL1
      SR0 : if (!init[1])          cs( 0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  5, 11,  1,  0,  0,  0,  0,  0 ); // 20 SR0 // writing 64 bits
       else if ( init[1])          cs( 0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  5, 12,  1,  0,  0,  0,  0,  0 ); // 20 SR0 // writing 64 bits
      SR1 : if (!mem_resp_valid_i) cs( 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0 ); // 21 SR1 (refactor this out?)
      SR1 : if ( mem_resp_valid_i) cs( 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0 ); // 21 SR1 (refactor this out?)
      RI80:                        cs( 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  5,  0,  0,  0,  1,  0,  0,  0 ); // 22 RI80
      RI81:                        cs( 0,  0,  0,  0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  1,  5,  0,  0,  0,  0,  0,  0,  3,  0 ); // 23 RI81
      II10:                        cs( 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 13,  0,  0,  0,  1,  0,  0 ); // 24 II10
      II11:                        cs( 0,  0,  0,  0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  1, 13,  0,  0,  0,  0,  0,  0,  1,  0 ); // 25 II11
      BRM0:                        cs( 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  2, 13,  0,  0,  1,  1,  0,  1 ); // 26 BRM0
      BRM1:                        cs( 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  2, 13,  0,  0,  1,  1,  0,  1 ); // 27 BRM1 don't make this all 0's!
      END0:                        cs( 0,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0 ); //
    endcase
  end

endmodule


`endif /* SERIAL_MATMUL_CTRL_V */
