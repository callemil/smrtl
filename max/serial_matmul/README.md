# Serial Matrix Multiply "Accelerator"

FSM-controlled multiply-accumulate engine.

## Architecture

Control FSM + datapath (3 register files: X, C, R).

## Files

- `rtl/` — Verilog sources
- `tb/` — Testbench with testvectors and Makefile
- `build/` - Suggested location for your executables

## Status

RTL functional. Synthesis flows pending.

## Quick Start
In `serial_matmul` directory

### Manual Compilation and Execution
```bash
# Make and enter your build directory
% mkdir -p build && cd build
# Compile your executable (elaborate module 'top' as root)
% iverilog -s top -g2012 -Wall -Wno-sensitivity-entire-vector -Wno-sensitivity-entire-array -o asic-exe -I ../../../lib/vc -I ../../../lib/sm -I ../../../lib/proc -I ../rtl -I ../tb ../tb/asic.t.v
# Run a test case
% ./asic-exe +verbose=1 +trace=1 +test-case=1 
```
### Using Makefile
In `serial_matmul/tb`
```bash
# Compile and run all test cases in build directory
% make run
```

## Testbench



## Interfaces

ASIC is connected (via RoCC) to processor (PROC), represented by SRC & SNK test blocks.
ASIC is connected (via RoCC) to memory (L1 cache), represented by MEM test block.

```
SRC & SNK = PROC

SRC ---> UNPACK ---> ASIC ---> PACK ---> SNK
                    /    \
MEM ---> UNPACK ---'      '--> PACK ---> MEM
resp                                     req

SRC ------------cmd_valid_i-----------> ASIC --------resp_valid_o---------> SNK
SRC <-----------cmd_ready_o------------ ASIC <-------resp_ready_i---------- SNK
SRC ->src_msg->,                    .-> ASIC ->,              ,->sink_msg-> SNK
               |-> cmd_rs2_i        |          |resp_rd_o --->|
               |-> cmd_rs1_i        |          'resp_data_o ->'                   
               |-> cmd_inst_funct_i |     
               '-> cmd_inst_opcode_i'
               
MEM ----------mem_resp_valid_i----------> ASIC ----------mem_req_valid_o---------> MEM
MEM <----------------1------------------- ASIC <---------mem_req_ready_i---------- MEM
MEM ->memresp_msg->,                  ,-> ASIC ->,                 ,->memreq_msg-> MEM
                   |-> mem_resp_addr_i|          |mem_req_addr_o ->|
resp               '-> mem_resp_data_i'          'mem_req_data_o ->'               req
```

(c) Sebastian Claudiusz Magierowski
