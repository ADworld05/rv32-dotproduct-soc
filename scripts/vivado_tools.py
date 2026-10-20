"""Locate Vivado command-line tools without a machine-specific install path."""
import os
import shutil
from pathlib import Path


def find_bin(directory=None):
    candidates = [Path(directory)] if directory else []
    if os.environ.get("XILINX_VIVADO"):
        candidates.append(Path(os.environ["XILINX_VIVADO"]) / "bin")
    executable = shutil.which("xvlog")
    if executable:
        candidates.append(Path(executable).parent)
    for candidate in candidates:
        if all((candidate / (tool + (".bat" if os.name == "nt" else ""))).is_file()
               for tool in ("xvlog", "xelab", "xsim")):
            return candidate.resolve()
    raise FileNotFoundError("Vivado tools not found. Supply --vivado-bin, set "
                            "XILINX_VIVADO, or use a Vivado-configured terminal.")


def tool_path(directory, name):
    return str(directory / (name + (".bat" if os.name == "nt" else "")))
