# Matched benchmark: RAM[0]=packed A, RAM[4]=packed B, RAM[8]=answer.
    lui x2,0x04040
    addi x2,x2,-511
    lui x3,0x08f90
    addi x3,x3,1541
    sw x2,0(x0)
    sw x3,4(x0)
    lw x2,0(x0)
    lw x3,4(x0)
    addi x20,x0,0 # Sum of four signed products.

# Lane 0: move selected byte to sign position, then sign-extend.
    slli x10,x2,24
    srai x10,x10,24
    slli x11,x3,24
    srai x11,x11,24
    xor  x13,x10,x11    # Sign bit differs when signs differ.
    slt  x13,x13,x0     # x13=1 if result must be negative.
    bge  x10,x0,abs_b_0
    sub  x10,x0,x10
abs_b_0:
    bge  x11,x0,setup_0
    sub  x11,x0,x11
setup_0:
    addi x12,x0,0      # Product accumulator.
    addi x14,x0,8      # Exactly eight multiplier bits.
loop_0:
    andi x15,x11,1     # Inspect lowest multiplier bit.
    beq  x15,x0,skip_0
    add  x12,x12,x10   # Add the current shifted multiplicand.
skip_0:
    slli x10,x10,1
    srli x11,x11,1
    addi x14,x14,-1
    bne  x14,x0,loop_0
    beq  x13,x0,save_0
    sub  x12,x0,x12    # Restore sign.
save_0:
    add x20,x20,x12

# Lane 1: move selected byte to sign position, then sign-extend.
    slli x10,x2,16
    srai x10,x10,24
    slli x11,x3,16
    srai x11,x11,24
    xor  x13,x10,x11    # Sign bit differs when signs differ.
    slt  x13,x13,x0     # x13=1 if result must be negative.
    bge  x10,x0,abs_b_1
    sub  x10,x0,x10
abs_b_1:
    bge  x11,x0,setup_1
    sub  x11,x0,x11
setup_1:
    addi x12,x0,0      # Product accumulator.
    addi x14,x0,8      # Exactly eight multiplier bits.
loop_1:
    andi x15,x11,1     # Inspect lowest multiplier bit.
    beq  x15,x0,skip_1
    add  x12,x12,x10   # Add the current shifted multiplicand.
skip_1:
    slli x10,x10,1
    srli x11,x11,1
    addi x14,x14,-1
    bne  x14,x0,loop_1
    beq  x13,x0,save_1
    sub  x12,x0,x12    # Restore sign.
save_1:
    add x20,x20,x12

# Lane 2: move selected byte to sign position, then sign-extend.
    slli x10,x2,8
    srai x10,x10,24
    slli x11,x3,8
    srai x11,x11,24
    xor  x13,x10,x11    # Sign bit differs when signs differ.
    slt  x13,x13,x0     # x13=1 if result must be negative.
    bge  x10,x0,abs_b_2
    sub  x10,x0,x10
abs_b_2:
    bge  x11,x0,setup_2
    sub  x11,x0,x11
setup_2:
    addi x12,x0,0      # Product accumulator.
    addi x14,x0,8      # Exactly eight multiplier bits.
loop_2:
    andi x15,x11,1     # Inspect lowest multiplier bit.
    beq  x15,x0,skip_2
    add  x12,x12,x10   # Add the current shifted multiplicand.
skip_2:
    slli x10,x10,1
    srli x11,x11,1
    addi x14,x14,-1
    bne  x14,x0,loop_2
    beq  x13,x0,save_2
    sub  x12,x0,x12    # Restore sign.
save_2:
    add x20,x20,x12

# Lane 3: move selected byte to sign position, then sign-extend.
    slli x10,x2,0
    srai x10,x10,24
    slli x11,x3,0
    srai x11,x11,24
    xor  x13,x10,x11    # Sign bit differs when signs differ.
    slt  x13,x13,x0     # x13=1 if result must be negative.
    bge  x10,x0,abs_b_3
    sub  x10,x0,x10
abs_b_3:
    bge  x11,x0,setup_3
    sub  x11,x0,x11
setup_3:
    addi x12,x0,0      # Product accumulator.
    addi x14,x0,8      # Exactly eight multiplier bits.
loop_3:
    andi x15,x11,1     # Inspect lowest multiplier bit.
    beq  x15,x0,skip_3
    add  x12,x12,x10   # Add the current shifted multiplicand.
skip_3:
    slli x10,x10,1
    srli x11,x11,1
    addi x14,x14,-1
    bne  x14,x0,loop_3
    beq  x13,x0,save_3
    sub  x12,x0,x12    # Restore sign.
save_3:
    add x20,x20,x12
    sw x20,8(x0)
    lw x21,8(x0)
# End-of-ROM FAULT stops this demo.
