# Matched software / accelerator benchmark

Both programs run on the same CPU/router with the same configured memory delay. They construct identical packed constants, store input words at RAM addresses 0/4, load them, compute the four-lane signed dot product, store the answer at address 8 and read it into x21.

The software uses four unrolled lane extractions and signed eight-iteration shift/add multiplication. It has 99 ROM words and a data-dependent executed instruction count. It does not access the accelerator. The 19-word accelerator program includes device-address setup, operand stores, START, status polling and RESULT read. For this CPU the device completes before the first status read; the polling branch is not taken in the measured jobs.

## Measurement boundaries

Cycles begin at the first active instruction fetch and end at the last successful instruction completion. The final stopping invalid fetch is excluded. Registered performance snapshots account for the trace reporting delay. Transfers and polling are included; timing is not stopped at arithmetic-engine completion.

For A=`0403FE01`, B=`08F90605`, answer=4:

| Memory latency | Software cycles | Accelerated cycles | Speedup |
| --- | ---: | ---: | ---: |
| 1 | 810 | 95 | 8.526x |
| 2 | 816 | 106 | 7.698x |
| 4 | 828 | 128 | 6.469x |

At latency 2 this example executes 263 software instructions versus 19 accelerator-program instructions. Across 73 vectors the software takes 807..888 cycles versus 106 accelerated cycles, an observed speedup of 7.613..8.377x (mean per-vector ratio 7.915x).

The dataset includes mixed signs, zero, extrema +65536/-65024, isolated lanes and 64 seeded random pairs. At latencies 1/2/4, 219 paired comparisons execute 438 complete programs. Every completion and final CPU/RAM state is checked; one START per accelerated run and no device use by the baseline are enforced.

At latency L and software retired count N, checked cycle totals are `3*N + 6*L + 15` for software and `84 + 11*L` for accelerated code. The shared setup has six RAM operations; the accelerated program has eleven total data operations including MMIO. Increased memory delay therefore reduces the observed speedup.

The smaller 15-word accelerator integration example is a different program and is not used for this comparison.

## Evidence and interpretation

[Per-vector CSVs](../results/benchmark/dotproduct_benchmark/) include operands, answer, latency, retired counts, cycle totals and ratios. [Software multiplication CSVs](../results/benchmark/software_multiply/) provide the earlier single-product baseline. These measurements were originally collected with Vivado 2025.2 on 20 October 2026. Clean-checkout regression evidence is recorded separately under [verification results](../results/verification/).

Python instruction-model predictions check the software. A separate functional oracle predicts the fixed accelerator program's MMIO effects; it is not a general concurrent peripheral simulator. The generated vectors are tracked and can be regenerated using `verification/build_dotproduct_benchmark.py`.

This comparison uses a straightforward software baseline without an M extension, not an optimized multiplication library. It supports a simulation cycle-count claim for these programs; it does not demonstrate board wall-clock speedup, incremental accelerator area, maximum clock frequency or power savings.
