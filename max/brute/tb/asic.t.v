//========================================================================
// ASIC Unit Tests
//========================================================================
// Sebastian Claudiusz Magierowski Feb 11 2023

// Top-level testbench module is "top" (see asic-test-harness.v).
// ASIC_IMPL names the DUT module ("asic").

`define ASIC_IMPL               asic    // name of DUT
`define ASIC_IMPL_STR           "asic"
`define ASIC_TEST_CASES_FILE    "asic-test-cases-1x2.v"

`include "asic.v"
`include "asic-test-harness.v" 