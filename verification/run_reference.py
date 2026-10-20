"""Run Vivado traces and compare them with the instruction-level Python model."""
import argparse
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from reference_model import read_program, run

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from vivado_tools import find_bin, tool_path


def compare(path, expected):
    trace, regs, ram, stopped = [], {}, {}, False
    for line in path.read_text().splitlines():
        fields = line.split()
        if fields[0] == "T":
            trace.append(tuple(int(x, 16) for x in fields[1:]))
        elif fields[0] in ("R", "M"):
            (regs if fields[0] == "R" else ram)[int(fields[1])] = int(fields[2], 16)
        elif fields[0] == "STOP":
            stopped = True
        else:
            raise AssertionError(f"Unknown record: {line}")
    if not stopped:
        raise AssertionError(f"{path.name}: missing stop record")
    if trace != expected.trace:
        for n in range(max(len(trace), len(expected.trace))):
            actual = trace[n] if n < len(trace) else "missing"
            want = expected.trace[n] if n < len(expected.trace) else "no instruction expected"
            if actual != want:
                raise AssertionError(f"{path.name}: instruction {n}: got {actual}; expected {want}")
    if regs != dict(enumerate(expected.regs)):
        raise AssertionError(f"{path.name}: final register file differs")
    if ram != dict(enumerate(expected.memory)):
        raise AssertionError(f"{path.name}: final RAM differs")
    return len(trace) * 6 + 32 + 16 + 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--learning", action="store_true", help="Run only the three-instruction program")
    parser.add_argument("--vivado-bin", type=Path)
    args = parser.parse_args()
    args.vivado_bin = find_bin(args.vivado_bin)
    programs = [ROOT / "programs/memory_learning.hex"] if args.learning else sorted((ROOT / "programs").glob("*.hex"))
    # The model must terminate successfully before any simulation starts.
    predictions = {p.stem: run(read_program(p)) for p in programs}
    output = ROOT / "verification/results" / datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    output.mkdir(parents=True)
    generated = output / "tb_reference_run.sv"
    lines = ["`timescale 1ns/1ps", "module tb_reference_run;",
             f"wire [{len(programs)*3-1}:0] done;"]
    for n, program in enumerate(programs):
        for k, latency in enumerate((1, 2, 4)):
            lines.append(f'  reference_capture_case #(.WORDS({len(read_program(program))}), .LATENCY({latency}), '
                         f'.NAME("{program.stem}"), .FILE("{program.as_posix()}")) '
                         f'case_{n}_{k}(.done(done[{n*3+k}]));')
    lines += ['initial begin wait(&done); #2; $display("PASS: reference trace capture complete"); $finish; end',
              'initial begin #100000; $fatal(1,"Reference capture timeout"); end', "endmodule"]
    generated.write_text("\n".join(lines) + "\n")
    (output / "run.tcl").write_text("run all\nquit\n")

    def command(tool, *arguments):
        with (output / (tool + ".console.log")).open("w") as log:
            result = subprocess.run([tool_path(args.vivado_bin, tool), *map(str, arguments)],
                                    cwd=output, stdout=log, stderr=subprocess.STDOUT)
        if result.returncode:
            raise RuntimeError(f"{tool} failed; see {output / (tool + '.console.log')}")

    command("xvlog", "--sv", *sorted((ROOT / "rtl").glob("*.sv")),
            ROOT / "tb/tb_cpu_reference.sv", generated)
    command("xelab", "tb_reference_run", "-s", "reference_run")
    # Keep the redirected console log separate from xsim's own default log.
    command("xsim", "reference_run", "-tclbatch", "run.tcl")
    # xsim can return zero on a testbench fatal: require successful completion too.
    if "PASS: reference trace capture complete" not in (output / "xsim.log").read_text():
        raise AssertionError(f"Simulation did not complete; see {output}")
    checks = events = 0
    for program in programs:
        prediction = predictions[program.stem]
        for latency in (1, 2, 4):
            checks += compare(output / f"{program.stem}_{latency}.txt", prediction)
            events += len(prediction.trace)
    # Prove the comparator detects corruption, rather than only running passing data.
    good = output / f"{programs[0].stem}_1.txt"
    corrupt = output / "intentional_bad_trace.txt"
    rows = good.read_text().splitlines()
    index = next(i for i, row in enumerate(rows) if row.startswith("T "))
    parts = rows[index].split()
    parts[-1] = f"{int(parts[-1], 16) ^ 1:08x}"
    rows[index] = " ".join(parts)
    corrupt.write_text("\n".join(rows) + "\n")
    try:
        compare(corrupt, predictions[programs[0].stem])
    except AssertionError:
        checks += 1
    else:
        raise AssertionError("Comparator accepted an intentionally corrupted trace")
    print(f"PASS: {checks} software-reference checks; {len(programs)*3} program/delay cases; "
          f"{events} completed instructions; corrupted trace rejected")
    print(f"Results: {output}")


if __name__ == "__main__":
    main()
