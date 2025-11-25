//========================================================================
// ASIC Unit Tests
//========================================================================
// Sebastian Claudiusz Magierowski Feb 11 2023

// Top-level testbench module is "top" (see asic-test-harness.v).
// ASIC_IMPL names the DUT module type ("serial_matmul").

`define ASIC_IMPL               serial_matmul    // ASIC module name
`define ASIC_IMPL_STR           "serial_matmul"  // ASIC module name string for macro digest
`define ASIC_TEST_CASES_FILE    "asic-test-cases-1x2.v"

`include "serial-matmul.v"                       // ASIC module's RTL file
`include "asic-test-harness.v" 