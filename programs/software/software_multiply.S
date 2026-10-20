# Signed 8-bit inputs, sign-extended into x10/x11. Output x12; RAM copy x16.
# Magnitude arithmetic uses 32-bit registers, so abs(-128)=128 is safe.
# Clobbers x10,x11,x13,x14,x15. Inline routine, not yet an ABI function.
    addi x10,x0,3       # Replace with -3 for the negative example.
    addi x11,x0,5
    xor  x13,x10,x11    # Sign bit differs when signs differ.
    slt  x13,x13,x0     # x13=1 if result must be negative.
    bge  x10,x0,abs_b
    sub  x10,x0,x10
abs_b:
    bge  x11,x0,setup
    sub  x11,x0,x11
setup:
    addi x12,x0,0      # Product accumulator.
    addi x14,x0,8      # Exactly eight multiplier bits.
loop:
    andi x15,x11,1     # Inspect lowest multiplier bit.
    beq  x15,x0,skip
    add  x12,x12,x10   # Add the current shifted multiplicand.
skip:
    slli x10,x10,1
    srli x11,x11,1
    addi x14,x14,-1
    bne  x14,x0,loop
    beq  x13,x0,save
    sub  x12,x0,x12    # Restore sign.
save:
    sw   x12,0(x0)
    lw   x16,0(x0)
# End-of-ROM FAULT stops this demonstration; no MUL instruction is used.
