# Architecture

## Current integration

`boolean_board_top` -> `soc_demo_wrapper` -> `soc_top` is the board hierarchy. Direct CPU simulations instantiate `soc_top`.

| Module | Inputs / outputs and role |
| --- | --- |
| `soc_top` | Inputs `clk`, `reset`; parameters `PROGRAM_WORDS`, `PROGRAM_FILE`, `MEMORY_LATENCY`. Outputs PC/instruction/state, ALU/writeback debug, completion trace and accelerator busy/done. |
| `instruction_fetch` | Clock/reset, PC enable and next PC -> current address, PC+4, instruction and fetch validity. Contains `pc` and `instruction_rom`. |
| `instruction_reg` | Fetch instruction, original PC and validity, gated by `ir_en` -> held instruction/PC/valid. |
| `execution_datapath` | Held instruction/PC, execute enable and captured load data -> register-write effect, arithmetic result, memory address/data/width, branch/jump classification and targets. Contains `decoder`, `regfile`, `alu`, immediate generators and instruction-specific helpers. |
| `memory_controller` | Fetch/decode validity, instruction class and bus handshakes/fault -> state, PC/IR/execute enables, request valid, response ready and fault. |
| `soc_memory_port` | Request valid/write/width/address/data and response ready -> request ready, response valid/data/fault. Captures one request and routes it after configurable latency. |
| `address_decoder` | Access enable/address -> RAM select, accelerator select, offset and decode fault. |
| `memory_access` | RAM access enable/write/width/address/data -> read data/fault. Combines byte-lane logic and masked-write RAM. |
| `dotproduct_accelerator` | Backend access/write/width/offset/data -> read data/fault plus busy/done. Combines register bank and arithmetic engine. |
| `instruction_trace` | Successful completion, original PC/instruction and register-write effect -> registered trace event and sequence number. |
| `performance_counters` | Active, trace valid and memory-wait state -> cycle, retirement and wait counts, including last-retirement snapshots. Instantiated in tests, outside `soc_top`. |

## Execution and completion

```text
FETCH -> DECODE -> EXECUTE -> FETCH                    arithmetic/control flow
                         -> MEM_REQ -> MEM_WAIT -> FETCH           store
                                               -> MEM_WB -> FETCH load
Invalid fetch/decode/target/access -> FAULT until reset
```

FETCH captures the instruction and its original PC while advancing the sequential PC. Taken branches and jumps redirect the PC at execution. All required instruction fields remain held while a memory instruction waits.

A request transfers only when valid and ready are both high. A response transfers only when response-valid and response-ready are both high. Loads capture response data before the following writeback edge; stores complete only on a successful consumed response. Each request triggers one backend action, including when a response is held.

The trace reports completed instructions after the completion edge. Faulting operations do not retire. No-write events have destination/data zero; `x0` remains zero. This is a project-specific trace, not full RVFI.

Instruction ROM is separate from the 64-byte data RAM, so address zero exists in both spaces. Data RAM is little-endian; byte/halfword loads apply the required signed/unsigned extension and stores use byte masks. Reset clears CPU/device control and cancels pending accesses; it does not erase the RAM contents.

## Accelerator registers

Data RAM occupies `0x00000000..0x0000003F`. Accelerator addresses occupy `0x10000000..0x1000001F`, with only the following aligned registers implemented:

| Offset | Register | Semantics |
| --- | --- | --- |
| `0x00` | A | Readable; writable only while idle. Four packed signed bytes. |
| `0x04` | B | Same as A. |
| `0x08` | CONTROL | Reads zero. Write 1 starts; write 0 is a no-op, including while busy. Reserved bits must be zero. Starting while busy faults. |
| `0x0C` | STATUS | Read only: busy bit 0, sticky done bit 1. |
| `0x10` | RESULT | Read-only signed result, retained until a new job completes. |

Only `LW`/`SW` accesses are accepted by the accelerator. Reserved offsets, read-only writes, unaligned/unsupported accesses and writes while busy fault. A new accepted START clears done; reset aborts and clears device state. Completion and a failing concurrent bus access are handled independently.

The engine captures four signed 8x8 products, then adds explicitly sign-extended products on the next edge. A product needs 16 bits; the full sum needs 18 bits (`-65024..65536`). The result is sign-extended to 32 bits. Each start computes a fresh dot product, without accumulation between jobs. Software-visible completion includes the register-bank/engine handoff and is later than the engine's own done pulse.

## Board wrapper

`mclk` -> MMCM -> BUFG -> 50 MHz core clock. Reset is asserted by SW0 or an unlocked MMCM. A two-flop synchronizer asynchronously asserts reset and synchronously releases it.

The wrapper watches the final benchmark instruction's x21 write, checks the full 32-bit result against 4, and latches success/error. The subsequent intentional end-of-ROM fault is accepted only after the final result is captured. LEDs display the low result byte plus status; see [FPGA documentation](FPGA.md).
