# Reference assembly for dotproduct_learning.hex: exactly 15 instructions.
# verification/build_soc_programs.py creates the machine words directly.
# The CPU loads the .hex, not this annotated source.

    lui  x1, 0x10000       # Accelerator base = 0x10000000.
    lui  x2, 0x04040
    addi x2, x2, -511     # Packed A = 0x0403FE01 = [1,-2,3,4].
    lui  x3, 0x08F90
    addi x3, x3, 1541     # Packed B = 0x08F90605 = [5,6,-7,8].
    sw   x2, 0(x1)        # A register.
    sw   x3, 4(x1)        # B register.
    addi x4, x0, 1
    sw   x4, 8(x1)        # CONTROL.START = 1.
poll:
    lw   x5, 12(x1)       # STATUS, bit 1 = done.
    andi x5, x5, 2
    beq  x5, x0, poll     # Go back 8 bytes if not finished.
    lw   x6, 16(x1)       # RESULT = 4.
    sw   x6, 0(x0)        # Save result into RAM.
    lw   x7, 0(x0)        # Read it back: x7 = 4.

# No HALT instruction: fetching beyond the configured ROM stops via FAULT.
