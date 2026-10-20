"""Instruction-level model of our teaching CPU's implemented RV32I subset.

No clock or HDL is used. RAM is 64 little-endian bytes, initially zero.
Faults stop execution; there are no CSRs, traps, interrupts or HALT yet.
"""
from dataclasses import dataclass

MASK = 0xffffffff


def signed(value, bits=32):
    value &= (1 << bits) - 1
    return value - (1 << bits) if value & (1 << (bits - 1)) else value


class StopModel(Exception):
    pass


@dataclass
class Outcome:
    trace: list
    regs: list
    memory: list
    reason: str
    stop_pc: int


def run(words, max_steps=1000):
    regs = [0] * 32
    memory = bytearray(64)
    pc = 0
    trace = []
    try:
        for _ in range(max_steps):
            if pc % 4 or pc // 4 >= len(words):
                raise StopModel("instruction fetch outside ROM or misaligned")
            ins = words[pc // 4]
            op, rd, f3 = ins & 127, (ins >> 7) & 31, (ins >> 12) & 7
            rs1, rs2, f7 = (ins >> 15) & 31, (ins >> 20) & 31, ins >> 25
            a, b = regs[rs1], regs[rs2]
            imm = signed(ins >> 20, 12)
            next_pc, value, writes = (pc + 4) & MASK, 0, False

            if op in (0x13, 0x33):
                writes = True
                operand = (imm & MASK) if op == 0x13 else b
                shift = (rs2 if op == 0x13 else b) & 31
                if op == 0x33 and not (f7 == 0 or (f7 == 32 and f3 in (0, 5))):
                    raise StopModel("illegal register arithmetic")
                if op == 0x13 and ((f3 == 1 and f7 != 0) or
                                          (f3 == 5 and f7 not in (0, 32))):
                    raise StopModel("illegal immediate shift")
                if f3 == 0:
                    value = a - operand if op == 0x33 and f7 == 32 else a + operand
                elif f3 == 1:
                    value = a << shift
                elif f3 == 2:
                    value = int(signed(a) < signed(operand))
                elif f3 == 3:
                    value = int(a < operand)
                elif f3 == 4:
                    value = a ^ operand
                elif f3 == 5:
                    value = (signed(a) if f7 == 32 else a) >> shift
                elif f3 == 6:
                    value = a | operand
                elif f3 == 7:
                    value = a & operand
            elif op in (0x03, 0x23):
                load = op == 0x03
                widths = {0: 1, 1: 2, 2: 4, 4: 1, 5: 2} if load else {0: 1, 1: 2, 2: 4}
                if f3 not in widths:
                    raise StopModel("illegal memory instruction")
                offset = imm if load else signed(((ins >> 25) << 5) | ((ins >> 7) & 31), 12)
                addr, width = (a + offset) & MASK, widths[f3]
                if addr % width or addr + width > len(memory):
                    raise StopModel("misaligned or out-of-range data access")
                if load:
                    value = int.from_bytes(memory[addr:addr + width], "little")
                    if f3 in (0, 1):
                        value = signed(value, width * 8)
                    writes = True
                else:
                    memory[addr:addr + width] = (b & ((1 << (8 * width)) - 1)).to_bytes(width, "little")
            elif op == 0x63:
                conditions = {0: a == b, 1: a != b, 4: signed(a) < signed(b),
                              5: signed(a) >= signed(b), 6: a < b, 7: a >= b}
                if f3 not in conditions:
                    raise StopModel("illegal branch")
                offset = signed(((ins >> 31) << 12) | (((ins >> 7) & 1) << 11) |
                                (((ins >> 25) & 63) << 5) | (((ins >> 8) & 15) << 1), 13)
                if conditions[f3]:
                    next_pc = (pc + offset) & MASK
            elif op in (0x6f, 0x67):
                writes, value = True, next_pc
                if op == 0x6f:
                    offset = signed(((ins >> 31) << 20) | (((ins >> 12) & 255) << 12) |
                                    (((ins >> 20) & 1) << 11) | (((ins >> 21) & 1023) << 1), 21)
                    next_pc = (pc + offset) & MASK
                else:
                    if f3 != 0:
                        raise StopModel("illegal JALR")
                    next_pc = ((a + imm) & MASK) & ~1
            elif op in (0x37, 0x17):
                value = (ins & 0xfffff000) + (pc if op == 0x17 else 0)
                writes = True
            else:
                raise StopModel("unsupported/illegal instruction")

            # Check a taken branch/jump before committing any destination write.
            if next_pc % 4:
                raise StopModel("misaligned control-flow target")
            actual_write = writes and rd != 0
            value &= MASK
            if actual_write:
                regs[rd] = value
            trace.append((len(trace), pc, ins, int(actual_write), rd if actual_write else 0,
                          value if actual_write else 0))
            pc = next_pc
        raise RuntimeError("Reference model exceeded instruction limit (possible loop)")
    except StopModel as stop:
        ram_words = [int.from_bytes(memory[n:n + 4], "little") for n in range(0, 64, 4)]
        return Outcome(trace, regs, ram_words, str(stop), pc)


def read_program(path):
    return [int(line, 16) for line in path.read_text().splitlines() if line.strip()]
