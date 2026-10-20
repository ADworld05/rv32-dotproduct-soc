"""Generate matched CPU-only/device dot products and functional expected traces."""
from pathlib import Path
import random
from build_soc_programs import constant,immediate,store,lui,beq
from build_software_multiply import program as multiply,reg
from reference_model import run,signed

ROOT=Path(__file__).resolve().parents[1]
MASK=0xffffffff

def dot(a,b):
    return sum(signed(a>>(8*n),8)*signed(b>>(8*n),8) for n in range(4))

def common(a,b):
    return constant(2,a)+constant(3,b)+[store(2,0,0),store(3,0,4),
                                    immediate(2,0,0,2,3),immediate(3,0,4,2,3)]

def software(a,b):
    words=common(a,b)+[immediate(20,0,0)]
    for lane in range(4):
        shift=24-lane*8
        words += [immediate(10,2,shift,1),immediate(10,10,0x418,5),
                  immediate(11,3,shift,1),immediate(11,11,0x418,5)]
        words += multiply(0,0)[2:19]  # Signed magnitude multiply; no input/save prologue.
        words += [reg(20,20,12)]
    return words+[store(20,0,8),immediate(21,0,8,2,3)]

def accelerated(a,b):
    return common(a,b)+[lui(1,0x10000),store(2,1,0),store(3,1,4),
            immediate(4,0,1),store(4,1,8),immediate(5,1,12,2,3),immediate(5,5,2,7),
            beq(5,0,-8),immediate(20,1,16,2,3),store(20,0,8),immediate(21,0,8,2,3)]

def device_prediction(a,b):
    # Functional device oracle, deliberately no Verilog or device clock model.
    # Done is expected by the first status load for this engine/controller pair;
    # the RTL test requires exactly this trace and independently verifies timing.
    answer=dot(a,b)&MASK
    words=accelerated(a,b)
    prefix=run(words[:8]);trace=list(prefix.trace);regs=list(prefix.regs)
    effects=[(1,0x10000000),(0,0),(0,0),(4,1),(0,0),(5,2),(5,2),(0,0),
             (20,answer),(0,0),(21,answer)]
    for index,(rd,value) in enumerate(effects,8):
        trace.append((index,index*4,words[index],int(rd!=0),rd,value))
        if rd:regs[rd]=value
    return trace,regs

def trace_word(t):
    order,pc,ins,wr,rd,data=t
    return f'{((order<<102)|(pc<<70)|(ins<<38)|(wr<<37)|(rd<<32)|data):042x}'

def registers_word(regs):
    return f'{sum(v<<(32*n) for n,v in enumerate(regs)):0256x}'

def main():
    rng=random.Random(42)
    vectors=[(0x0403fe01,0x08f90605),(0x01010101,0xffffffff),
             (0x80808080,0x80808080),(0x80808080,0x7f7f7f7f),(0,0xffffffff)]
    vectors += [(0x80<<(8*n),0x7f<<(8*n)) for n in range(4)]
    vectors += [(rng.getrandbits(32),rng.getrandbits(32)) for _ in range(64)]
    folder=ROOT/'verification/dotproduct_benchmark';folder.mkdir(parents=True,exist_ok=True)
    cases=[];sw_traces=[];hw_traces=[];sw_regs=[];hw_regs=[]
    for a,b in vectors:
        expected=dot(a,b)&MASK
        sw=run(software(a,b))
        assert sw.regs[20]==expected and sw.regs[21]==expected and sw.memory[:3]==[a,b,expected]
        ht,hr=device_prediction(a,b)
        assert hr[20]==expected and hr[21]==expected
        packed=(a<<80)|(b<<48)|(expected<<16)|len(sw.trace)
        cases.append(f'{packed:028x}')
        sw_traces += [trace_word(t) for t in sw.trace]
        hw_traces += [trace_word(t) for t in ht]
        sw_regs.append(registers_word(sw.regs));hw_regs.append(registers_word(hr))
    for name,rows in [('cases',cases),('software_traces',sw_traces),('accelerator_traces',hw_traces),
                      ('software_registers',sw_regs),('accelerator_registers',hw_regs)]:
        (folder/(name+'.hex')).write_text('\n'.join(rows)+'\n', encoding="utf-8", newline="\n")
    (folder/'counts.txt').write_text(f'{len(cases)} {len(sw_traces)} {len(hw_traces)}\n', encoding="utf-8", newline="\n")
    for path,words in [(ROOT/'programs/software/dotproduct_software.hex',software(*vectors[0])),
                       (ROOT/'programs/soc/dotproduct_benchmark.hex',accelerated(*vectors[0]))]:
        path.write_text(''.join(f'{word:08x}\n' for word in words), encoding="utf-8", newline="\n")
    assert len(software(*vectors[0]))==99 and len(accelerated(*vectors[0]))==19
    print(f'PASS: independent dot-product predictions for {len(vectors)} packed input pairs; software=99 ROM words, accelerated=19')

if __name__=='__main__':main()
