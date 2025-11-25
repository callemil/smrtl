# Brute-Force Matrix Accelerator

FSM-controlled multiply-accumulate engine.

## Architecture

Control FSM + datapath (3 register files: X, C, R).

## Files

- `rtl/` — Verilog sources
- `tb/` — Testbench with processor emulation
- `build/` - Suggested location for your executables

## Status

RTL functional. Synthesis flows pending.

## Quick Start
In `brute`

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
In `brute/tb`
```bash
# Compile and run all test cases in build directory
% make run
```
