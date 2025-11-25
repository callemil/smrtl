# Matrix Accelerators (max)

Processor-interfaced matrix multiply units.

## Variants

### [serial_matmul/](serial_matmul/)
FSM-based multiply-accumulate with register files. Simple architecture, low throughput.

**Status:** getting there  
**Throughput:** ~1 MAC/cycle  
**Use case:** Small matrices, teaching example

---

## Planned

- **systolic/** — 2D systolic array for dense matrices
- **sparse/** — Skip-zero optimization for sparse tensors
