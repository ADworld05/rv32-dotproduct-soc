# Matched benchmark: RAM[0]=packed A, RAM[4]=packed B, RAM[8]=answer.
    lui x2,0x04040
    addi x2,x2,-511
    lui x3,0x08f90
    addi x3,x3,1541
    sw x2,0(x0)
    sw x3,4(x0)
    lw x2,0(x0)
    lw x3,4(x0)
    lui x1,0x10000
    sw x2,0(x1)
    sw x3,4(x1)
    addi x4,x0,1
    sw x4,8(x1)
poll:
    lw x5,12(x1)
    andi x5,x5,2
    beq x5,x0,poll
    lw x20,16(x1)
    sw x20,8(x0)
    lw x21,8(x0)
# End-of-ROM FAULT stops this demo.
