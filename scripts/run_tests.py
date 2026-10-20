"""Run self-checking Vivado simulations from any checkout location."""
import argparse
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from vivado_tools import find_bin, tool_path

ROOT = Path(__file__).resolve().parents[1]
SMOKE = ["tb_soc_top", "tb_dotproduct_benchmark", "tb_soc_demo_wrapper"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", choices=["smoke", "full"], default="smoke")
    parser.add_argument("--top", help="Run one self-checking testbench instead")
    parser.add_argument("--vivado-bin", type=Path)
    parser.add_argument("--list", action="store_true")
    args = parser.parse_args()
    # tb_cpu_reference contains a capture helper; run_reference.py supplies its top.
    available = sorted(p.stem for p in (ROOT / "tb").glob("tb_*.sv")
                       if p.stem != "tb_cpu_reference")
    if args.list:
        print("\n".join(available))
        return
    tops = [args.top] if args.top else (available if args.suite == "full" else SMOKE)
    if any(top not in available for top in tops):
        parser.error("Unknown test top; use --list")
    directory = find_bin(args.vivado_bin)
    output = ROOT / "build" / "simulation"
    output.mkdir(parents=True, exist_ok=True)
    run = output / "run.tcl"
    run.write_text("run all\nquit\n", encoding="utf-8")

    def command(tool, log, *arguments):
        with log.open("w", encoding="utf-8") as handle:
            result = subprocess.run([tool_path(directory, tool), *map(str, arguments)],
                                    cwd=ROOT, stdout=handle, stderr=subprocess.STDOUT)
        if result.returncode:
            raise RuntimeError(f"{tool} failed; see {log}")
        return log.read_text(encoding="utf-8", errors="replace")

    sources = sorted((ROOT / "rtl").glob("*.sv")) + sorted((ROOT / "tb").glob("*.sv"))
    board = "tb_boolean_board" in tops
    if board:
        sources.append(directory.parent / "data/verilog/src/glbl.v")
    command("xvlog", output / "compile.console.log", "--sv", *sources,
            "--log", output / "compile.log")
    records = []
    for top in tops:
        snapshot = top + "_run"
        extra = ["-L", "unisims_ver", "glbl"] if top == "tb_boolean_board" else []
        command("xelab", output / f"{top}.elaborate.console.log", top, *extra,
                "-s", snapshot, "--log", output / f"{top}.elaborate.log")
        transcript = command("xsim", output / f"{top}.console.log", snapshot,
                             "-tclbatch", run.relative_to(ROOT).as_posix(),
                             "--log", output / f"{top}.log")
        passes = [line.strip() for line in transcript.splitlines() if "PASS:" in line]
        if not passes or re.search(r"\b(FATAL|ERROR)\b", transcript, re.IGNORECASE):
            raise AssertionError(f"Simulation failed or missing PASS; see {output / (top + '.log')}")
        records.append({"top": top, "status": "PASS", "messages": passes})
        print("\n".join(passes), flush=True)
    (output / "summary.json").write_text(json.dumps({
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "suite": args.top or args.suite, "tests": records,
    }, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: {len(records)} testbench simulations; logs: {output}")


if __name__ == "__main__":
    main()
