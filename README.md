<div align="center">

<picture>
  <img alt="emilro" src="docs/emil_rtl.png" width="30%" height="30%">
</picture>

</div>

# smrtl – Digital RTL for Mobile Genomics and Edge Bioinformatics

`smrtl` is a collection of Verilog RTL components and small systems
focused on **System-on-Chip (SoC) architectures for mobile bioinformatics**.

The emphasis is on blocks that are useful for:

- Nanopore and other sensor-based **signal processing pipelines**
- On-device **deep learning** and classical ML for genomic workloads
- Integration of **custom accelerators** with simple processor cores
- Teaching and experimentation (students can plug accelerators into
  mock CPUs and run them through rich testbenches)

The repository is intentionally small and self-contained so it can be
used both as a research playground and as a teaching resource.

---

## Layout

```text
lib/                 – Reusable IP and verification utilities
  proc/              – Processor-related modules (e.g., RISC-V instruction defs)
    rv-inst.v
  sm/                – Local "SM" library blocks (regs, SRAMs, test memories, etc.)
    sm-arithmetic.v
    sm-bufs.v
    sm-mem-msgs.v
    sm-mem-msgsX.v
    sm-msgs.v
    sm-regfiles.v
    sm-regs.v
    sm-srams.v
    sm-TestMem_*.v
    sm-TestRandDelayMem_*.v
  vc/                – Vendored Verilog components and test infrastructure
    vc-*.v
    vc-*.t.v
    vc.mk
    COPYING          – License for the VC library

max/                 – "Machines": concrete SoCs / accelerators + testbenches
  serial_matmul/     – Example accelerator / SoC ("serial_matmul" design)
    rtl/             – RTL for the accelerator/system
      serial-matmul.v
      AsicCtrl.v
      AsicDpath.v
    tb/              – Test harnesses, test cases, and simulation tops
      asic-test-harness.v
      asic-test-cases-1x2.v
      asic.t.v
    README.md        – Design-specific notes

README.md            – This file