# Spartan-7 implementation and board demo

Target: Real Digital Boolean board, Spartan-7 `xc7s50csga324-1`. Vivado 2025.2. The supplied XDC uses the board's 100 MHz oscillator at F14, SW0 at V2 and 16 LED outputs, all LVCMOS33. The board top exposes only those 18 ports.

## Build

From a Vivado-configured terminal:

```powershell
vivado -mode batch -source scripts/implement_boolean.tcl
vivado -mode batch -source scripts/verify_board.tcl
```

Scripts derive the repository root from their own location. The build changes to that directory so the relative program file resolves, then writes generated reports/checkpoints/bitstream under `build/implementation/`. It never opens Hardware Manager or programs hardware. The verification script requires the routed checkpoint from a successful build.

The MMCM uses a 100 MHz input, 800 MHz VCO and divide-by-16 output to generate 50 MHz, distributed by BUFG. SW0 resets the clock manager and core; lack of clock lock also holds core reset. Reset release is synchronized. No fabric-divider clock is used.

## Reported implementation

| Metric | Result |
| --- | ---: |
| LUTs | 1791 / 32600 (5.49%) |
| Flip-flops | 1502 / 65200 (2.30%) |
| LUT RAM | 32, included in total LUT count |
| DSP / block RAM | 0 / 0 |
| MMCM / BUFG | 1 / 1 |
| Routed setup slack | +2.244 ns |
| Routed hold slack | +0.142 ns |
| Failing setup / hold endpoints | 0 / 0 |
| Final DRC violations | 0 |

The tracked [reports](../results/implementation/) describe the fresh clean-checkout build on 21 October 2026; local source-root and host metadata were redacted where present. This build reproduced the earlier implementation results. Resource figures apply to the complete board demo, not incremental accelerator cost. This is 50 MHz routed closure, not measured maximum silicon frequency; the earlier 100 MHz synthesis target failed timing.

The XDC defines the input and generated clocks. Only the external asynchronous reset input is false-pathed; functional CPU paths are not. LEDs have a zero external output delay relative to the core clock as a reporting budget for human-visible outputs, not as an external receiver specification. No unconstrained internal endpoints or missing output delays were reported. No dedicated-clock-routing override or DRC-severity downgrade is used.

## Physical test, when a board is available

**Not yet performed.** Connect the board's PROG/UART USB port using a data-capable cable and follow the official power setup. In Vivado, open Hardware Manager, auto-connect, and use Program Device with `build/implementation/boolean_soc.bit`. JTAG configuration is volatile; persistent flash programming is not needed.

Set SW0 to 1, then 0. Expected completed word is `16'h0904`:

| LED | Meaning |
| --- | --- |
| 7:0 | Low result byte; answer 4 lights LED2 |
| 8 | Success: full 32-bit result equals 4 |
| 9 | Error: wrong result or premature CPU fault |
| 10 | Accelerator busy, too brief to reliably observe by eye |
| 11 | MMCM locked |
| 12 | Core reset |
| 15:13 | Off |

The wrapper checks the final x21 write from the 19-word benchmark program. A later expected invalid fetch does not override a captured success. Results remain until reset. Physical LED observations and hardware timing measurements remain pending.

## Board references

- [Official reference manual](https://www.realdigital.org/doc/02013cd17602c8af749f00561f88ae21)
- [Official schematic](https://www.realdigital.org/downloads/63f9a8205ebd9c2e8c2d265ad25097dc.pdf)
- [Official master constraints](https://www.realdigital.org/downloads/8d5c167add28c014173edcf51db78bb9.txt)

Pin assignments were supplied for this board and independently checked against the final routed design. Configuration voltage properties follow the official schematic's 3.3 V configuration-bank connections. Use these constraints only with the matching board/part.
