"""Build signed-byte shift/add multiplication programs and independent trace vectors."""
from pathlib import Path
import random
from build_soc_programs import immediate,store
from reference_model import run

ROOT=Path(__file__).resolve().parents[1]

def reg(rd,rs1,rs2,f3=0,f7=0):
    return f7<<25 | rs2<<20 | rs1<<15 | f3<<12 | rd<<7 | 0x33

def branch(rs1,rs2,offset,f3):
    v=offset&0x1fff
    return ((v>>12)&1)<<31 | ((v>>5)&63)<<25 | rs2<<20 | rs1<<15 | f3<<12 | ((v>>1)&15)<<8 | ((v>>11)&1)<<7 | 0x63

def program(a,b):
    # Exact instruction addresses are documented in software_multiply.S.
    return [immediate(10,0,a),immediate(11,0,b),
            reg(13,10,11,4),reg(13,13,0,2),
            branch(10,0,8,5),reg(10,0,10,0,32),
            branch(11,0,8,5),reg(11,0,11,0,32),
            immediate(12,0,0),immediate(14,0,8),
            immediate(15,11,1,7),branch(15,0,8,0),reg(12,12,10),
            immediate(10,10,1,1),immediate(11,11,1,5),immediate(14,14,-1),
            branch(14,0,-24,1),branch(13,0,8,0),reg(12,0,12,0,32),
            store(12,0,0),immediate(16,0,0,2,3)]

def main():
    programs=ROOT/'programs/software';programs.mkdir(parents=True,exist_ok=True)
    for name,a,b in [('multiply_positive',3,5),('multiply_negative',-3,5)]:
        (programs/(name+'.hex')).write_text(''.join(f'{w:08x}\n' for w in program(a,b)), encoding="utf-8", newline="\n")
    rng=random.Random(41)
    values=[-128,-127,-3,-1,0,1,3,5,127]
    pairs=list(dict.fromkeys([(3,5),(-3,5)]+[(a,b) for a in values for b in values]+
          [(rng.randrange(-128,128),rng.randrange(-128,128)) for _ in range(256)]+
          [(a,[-128,-1,1,127][a%4]) for a in range(-128,128)]))
    output=ROOT/'verification/software_multiply';output.mkdir(parents=True,exist_ok=True)
    cases=[];traces=[]
    for a,b in pairs:
        prediction=run(program(a,b))
        assert prediction.regs[12]==(a*b)&0xffffffff
        assert prediction.regs[16]==(a*b)&0xffffffff
        assert prediction.memory[0]==(a*b)&0xffffffff
        n=len(prediction.trace)
        packed=((a&0xffffffff)<<80)|((b&0xffffffff)<<48)|(((a*b)&0xffffffff)<<16)|n
        cases.append(f'{packed:028x}')
        for order,pc,ins,wr,rd,data in prediction.trace:
            value=(order<<102)|(pc<<70)|(ins<<38)|(wr<<37)|(rd<<32)|data
            traces.append(f'{value:042x}')
    (output/'cases.hex').write_text('\n'.join(cases)+'\n', encoding="utf-8", newline="\n")
    (output/'traces.hex').write_text('\n'.join(traces)+'\n', encoding="utf-8", newline="\n")
    (output/'counts.txt').write_text(f'{len(cases)} {len(traces)}\n', encoding="utf-8", newline="\n")
    print(f'PASS: Python reference multiplication for {len(cases)} cases; {len(traces)} expected instruction reports')

if __name__=='__main__':main()
