# Verification

Use `python scripts/run_tests.py --suite full` for the 25 self-checking testbench tops. Use `python verification/run_reference.py` separately for Python-model comparison of the RAM instruction programs against `soc_top` at memory latencies 1/2/4. Both accept `--vivado-bin`; otherwise tools are found through PATH or XILINX_VIVADO.

## Layers

- Unit tests: ALU, register file, decoder, immediates, PC/fetch/IR, branch/jump/upper-immediate handling, load/store decoding, byte lanes, RAM access and controller.
- Accelerator tests: register permissions and state, signed arithmetic, combined engine/register behavior, busy/done and reset/restart.
- Router tests: captured payload, latency 1/2/4, backpressure, exactly-once side effects, response stability, faults and cancellation on reset.
- SoC tests: CPU programs writing START and reading results, end-state checks, invalid MMIO programs, and reset while launching a job.
- Software tests: signed multiply and matched dot-product baseline, reference traces, registers, RAM, instruction counts and measured cycles.
- Board tests: full-width result comparison, early faults, real vendor MMCM simulation, clock period and held LED status.

The arithmetic engine tests cover 66,579 jobs, including all 65,536 signed-byte pairs repeated across lanes. This does not exhaust every possible pair of packed 32-bit inputs. Check counts refer to testbench comparisons, not functional coverage percentages.

## Trace/reference checker

`tb_cpu_reference.sv` supplies a capture module; Python generates a simulation top for the selected programs. Records contain order, original PC, machine instruction and register-write effect. Final registers/RAM and stopping state are compared. A deliberately corrupted trace must be rejected. The model predicts functional effects, not cycle timing, and does not model the accelerator registers, architectural traps, CSRs or interrupts.

`run_reference.py --learning` retains a short three-instruction model test even though the separate teaching testbench directory is not published.

## Reproduction and evidence

The simulation runner compiles tracked RTL/testbench sources, elaborates a chosen top and runs it to completion. It rejects missing PASS or fatal/error output even if xsim returns zero. It includes the vendor unisims/glbl resources for the physical board top. Do not run multiple copies of the simulation runner concurrently in the same checkout, because Vivado's compilation workspace is shared.

Logs and a JSON summary are written under ignored `build/simulation/`. The paired benchmark also emits temporary per-latency CSVs at the repository root. Expected programs/vectors under `programs/` and `verification/` are tracked; simulator outputs are not.

Selected fresh results for this published checkout are in [results/verification](../results/verification/). This is simulation-based verification, without formal proof or official ISA compliance certification.
