# Routed FPGA results

Rebuilt from this published source tree on **21 October 2026**, using Vivado 2025.2, `boolean_board_top`, part `xc7s50csga324-1`, 100 MHz input and 50 MHz generated core clock.

- PASS: synthesis, optimization, placement, physical optimization, routing and bitstream generation.
- PASS: setup slack **+2.244 ns**, hold slack **+0.142 ns**, zero failing setup/hold endpoints.
- PASS: final DRC report has zero violations.
- PASS: all **18** physical ports have the intended pins and LVCMOS33 standards; input/core periods are **10/20 ns**.
- Resources: **1,791 LUTs**, **1,502 flip-flops**, **32 LUT RAM cells included in the LUT total**, **0 DSPs**, **0 block RAMs**, **1 MMCM**, **1 BUFG**.

| Report | Purpose |
| --- | --- |
| [Timing summary](timing_summary.rpt) | Routed setup/hold and constraint coverage |
| [Critical paths](critical_paths.rpt) | Ten reported worst setup paths |
| [Utilization](utilization.rpt) | Complete board-top resource usage |
| [Hierarchical utilization](utilization_hierarchical.rpt) | Resources by instantiated block |
| [Clocks](clocks.rpt) | Input and generated clock definitions |
| [DRC](drc.rpt) | Final design-rule checks |
| [I/O report](io.rpt) | Routed physical I/O assignments |
| [Pin verification](pin_verification.txt) | Independently asserted pins, standards and periods |
| [Build summary](implementation_summary.txt) | Target and final slack values |

These are generated report snapshots, with local repository/host metadata redacted and trailing whitespace normalized. Measurements are unchanged. Source scripts regenerate complete local outputs under ignored `build/implementation/`; checkpoints and bitstreams are intentionally not tracked.

This validates the implementation flow and timing constraints, not physical operation. The board has **not** been programmed or observed. See [FPGA instructions](../../docs/FPGA.md).
