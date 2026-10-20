"""Generate this lesson's small RV32I programs. No external assembler required."""
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]

def lui(rd,value):
    return ((value & 0xfffff)<<12) | rd<<7 | 0x37

def immediate(rd,rs1,value,f3=0,opcode=0x13):
    return (value & 0xfff)<<20 | rs1<<15 | f3<<12 | rd<<7 | opcode

def store(rs2,rs1,offset):
    return ((offset & 0xfff)>>5)<<25 | rs2<<20 | rs1<<15 | 2<<12 | (offset & 31)<<7 | 0x23

def beq(rs1,rs2,offset):
    value=offset & 0x1fff
    return ((value>>12)&1)<<31 | ((value>>5)&63)<<25 | rs2<<20 | rs1<<15 | ((value>>1)&15)<<8 | ((value>>11)&1)<<7 | 0x63

def constant(rd,value):
    # Round the upper part because ADDI sign-extends the low 12 bits.
    return [lui(rd,((value+0x800)>>12)&0xfffff), immediate(rd,rd,value&0xfff)]

def program(a,b):
    return ([lui(1,0x10000)] + constant(2,a) + constant(3,b) +
            [store(2,1,0),store(3,1,4),immediate(4,0,1),store(4,1,8),
             immediate(5,1,12,2,3),immediate(5,5,2,7),beq(5,0,-8),
             immediate(6,1,16,2,3),store(6,0,0),immediate(7,0,0,2,3)])

def main():
    output=ROOT/'programs/soc'
    output.mkdir(parents=True,exist_ok=True)
    vectors={'dotproduct_learning':(0x0403fe01,0x08f90605),
             'dotproduct_negative':(0x01010101,0xffffffff),
             'dotproduct_maximum':(0x80808080,0x80808080),
             'dotproduct_minimum':(0x80808080,0x7f7f7f7f)}
    for name,(a,b) in vectors.items():
        words=program(a,b)
        (output/(name+'.hex')).write_text(''.join(f'{word:08x}\n' for word in words), encoding="utf-8", newline="\n")
    faults={'bad_reserved':immediate(6,1,20,2,3),
            'bad_readonly':store(6,1,12),
            'bad_width':immediate(6,1,0,0,3),
            'bad_alignment':immediate(6,1,1,2,3),
            'bad_unmapped':immediate(6,1,0,2,3),
            'bad_control':store(6,1,8)}
    for name,operation in faults.items():
        words=[lui(1,0x20000 if name=='bad_unmapped' else 0x10000),immediate(6,0,77),operation]
        (output/(name+'.hex')).write_text(''.join(f'{word:08x}\n' for word in words), encoding="utf-8", newline="\n")
    print('Generated four 15-word accelerator programs and six 3-word fault programs.')

if __name__=='__main__':
    main()
