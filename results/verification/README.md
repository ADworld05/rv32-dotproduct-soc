# Clean-checkout verification

Validated 21 October 2026 using Vivado 2025.2 on Windows. These tests ran from the separately prepared GitHub checkout, with relative ROM/vector paths and the current `soc_top`.

## Full RTL regression

| Simulation top | Result | Passing checks |
| --- | --- | ---: |
| `tb_address_decoder` | PASS | 6,810 |
| `tb_alu` | PASS | 47 |
| `tb_boolean_board` | PASS | 354 |
| `tb_branch_unit` | PASS | 12,597 |
| `tb_decoder` | PASS | 33,945 |
| `tb_dotproduct_accelerator` | PASS | 70,496 |
| `tb_dotproduct_benchmark` | PASS | 404,067 |
| `tb_dotproduct_engine` | PASS | 599,227 |
| `tb_dotproduct_regs` | PASS | 16,489 |
| `tb_imm_gen_i` | PASS | 4,096 |
| `tb_instruction_fetch` | PASS | 97 |
| `tb_instruction_reg` | PASS | 274 |
| `tb_jump_unit` | PASS | 25,809 |
| `tb_load_store_decode` | PASS | 102,534 |
| `tb_memory_access` | PASS | 31,457 |
| `tb_memory_controller` | PASS | 15,421 |
| `tb_memory_lane_unit` | PASS | 9,328 |
| `tb_pc` | PASS | 2,015 |
| `tb_regfile` | PASS | 204 |
| `tb_shift_imm` | PASS | 576 |
| `tb_soc_demo_wrapper` | PASS | 1,250 |
| `tb_soc_memory_port` | PASS | 42,577 |
| `tb_soc_top` | PASS | 33,242 |
| `tb_software_multiply` | PASS | 681,006 |
| `tb_upper_imm_unit` | PASS | 6,622 |

All 25 self-checking tops passed. The machine-readable [summary](simulation-summary.json) records each testbench PASS message. Check counts are test comparisons, not functional coverage percentages.

## Independent reference and reproducibility checks

- PASS: **6,547** Python software-reference checks; **84** program/delay cases; **405** completed instructions, including intentional corrupt-trace rejection. The reference capture helper targets the current SoC.
- PASS: regenerated ROM programs and expected vectors match their input hashes exactly.
- PASS: all three fresh dot-product benchmark CSVs match the published datasets byte-for-byte after text newline normalization.

Commands:

```text
python scripts/run_tests.py --suite full --vivado-bin <Vivado-bin-directory>
python verification/run_reference.py --vivado-bin <Vivado-bin-directory>
python verification/build_soc_programs.py
python verification/build_software_multiply.py
python verification/build_dotproduct_benchmark.py
```

Detailed simulator working files are excluded from Git and regenerated under `build/` or `verification/results/`. Physical board testing remains pending.
