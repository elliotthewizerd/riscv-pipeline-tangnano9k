"""Compile RTL, compare retirement/store traces with a sequential ISA model."""
import random
import re
import subprocess
from pathlib import Path
from asm import assemble, write_hex

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build'
MASK = 0xffffffff

def sx(n, bits):
    return (n & ((1 << (bits-1))-1)) - (n & (1 << (bits-1)))

def reference(words, stop):
    regs, mem, trace, stores = [0]*32, {}, [], []
    pc = 0
    for _ in range(5000):
        w = words[pc//4]
        op, rd, f3 = w&127, (w>>7)&31, (w>>12)&7
        rs1, rs2, f7 = (w>>15)&31, (w>>20)&31, w>>25
        a,b = regs[rs1],regs[rs2]
        imm = sx(w>>20,12)
        nxt, result, legal = pc+4, None, True
        if op in (0x33,0x13):
            b = b if op==0x33 else imm & MASK
            if op==0x33 and f7 not in (0,32): legal=False
            elif op==0x33 and f7==32 and f3 not in (0,5): legal=False
            elif f3==0: result=a-b if op==0x33 and f7==32 else a+b
            elif f3==1: result=a<<(b&31)
            elif f3==2: result=int(sx(a,32)<sx(b,32))
            elif f3==3: result=int(a<b)
            elif f3==4: result=a^b
            elif f3==5: result=sx(a,32)>>(b&31) if f7==32 else a>>(b&31)
            elif f3==6: result=a|b
            elif f3==7: result=a&b
        elif op==3:
            addr=(a+imm)&MASK
            result=mem[addr] if addr<256 and addr%4==0 else 0
        elif op==0x23:
            offset=sx((w>>25)<<5 | ((w>>7)&31),12)
            addr=(a+offset)&MASK
            stores.append((addr,b))
            if addr<256 and addr%4==0: mem[addr]=b
        elif op==0x63:
            off=sx(((w>>31)&1)<<12 | ((w>>7)&1)<<11 | ((w>>25)&63)<<5 | ((w>>8)&15)<<1,13)
            take={0:a==b,1:a!=b,4:sx(a,32)<sx(b,32),5:sx(a,32)>=sx(b,32),6:a<b,7:a>=b}[f3]
            if take: nxt=pc+off
        elif op==0x6f:
            off=sx(((w>>31)&1)<<20 | ((w>>12)&255)<<12 | ((w>>20)&1)<<11 | ((w>>21)&1023)<<1,21)
            result,nxt=pc+4,pc+off
        elif op==0x67: result,nxt=pc+4,((a+imm)&MASK)&~1
        elif op==0x37: result=w&0xfffff000
        elif op==0x17: result=pc+(w&0xfffff000)
        else: legal=False
        if legal:
            if result is not None and rd:
                regs[rd]=result&MASK
                trace.append((pc,rd,regs[rd]))
            else: trace.append((pc,0,0))
        if pc==stop: return trace,stores,regs
        pc=nxt&MASK
    raise AssertionError('reference timeout')

def run(args):
    proc=subprocess.run(args,cwd=ROOT,text=True,capture_output=True)
    if proc.returncode:
        raise RuntimeError(proc.stdout+proc.stderr)
    return proc.stdout+proc.stderr

def check(name, source, pause=0, expected_stalls=None):
    words, labels, _=assemble(source)
    path=BUILD/(name+'.hex')
    write_hex(words,path)
    expected, stores, regs=reference(words,labels['halt'])
    out=run(['vvp',str(BUILD/'core.vvp'),f'+ROM=build/{name}.hex',f'+STOP={labels["halt"]}',f'+PAUSE={pause}'])
    (BUILD/(name+'.trace')).write_text(out)
    actual, actual_stores=[],[]
    for line in out.splitlines():
        t=line.split()
        if t[0]=='R': actual.append((int(t[1],16),int(t[2]),int(t[3],16)))
        if t[0]=='S': actual_stores.append(tuple(int(x,16) for x in t[1:]))
    if actual!=expected:
        for i,(a,e) in enumerate(zip(actual,expected)):
            if a!=e: raise AssertionError(f'{name}: retirement {i}: RTL {a}, expected {e}')
        raise AssertionError(f'{name}: trace lengths {len(actual)} != {len(expected)}')
    assert actual_stores==stores,(name,'store mismatch',actual_stores,stores)
    counts={k:int(v) for k,v in re.findall(r'(\w+)=(\d+)',out)}
    if expected_stalls is not None: assert counts['stalls']==expected_stalls,(name,counts)
    return len(actual),counts,regs

def randomized(seed):
    r=random.Random(seed)
    lines=['addi x1,x0,0']
    for i in range(1,16): lines.append(f'addi x{i},x0,{r.randint(-100,100)}')
    for i in range(16): lines.append(f'sw x{r.randint(1,15)},{i*4}(x0)')
    for i in range(100):
        rd,ra,rb=(r.randint(0,15) for _ in range(3))
        kind=r.randrange(7)
        if kind==0: lines.append(f'{r.choice(["add","sub","xor","or","and","sll","srl","sra","slt","sltu"])} x{rd},x{ra},x{rb}')
        elif kind==1: lines.append(f'{r.choice(["addi","andi","ori","xori","slti","sltiu"])} x{rd},x{ra},{r.randint(-2048,2047)}')
        elif kind==2: lines.append(f'{r.choice(["slli","srli","srai"])} x{rd},x{ra},{r.randrange(32)}')
        elif kind==3:
            lines.extend([f'lw x{rd},{r.randrange(16)*4}(x0)',f'add x{rb},x{rd},x{ra}'])
        elif kind==4: lines.append(f'sw x{ra},{r.randrange(16)*4}(x0)')
        elif kind==5:
            lines.extend([f'{r.choice(list({"beq":0,"bne":1,"blt":4,"bge":5,"bltu":6,"bgeu":7}))} x{ra},x{rb},L{i}',f'addi x{rd},x{rd},1',f'L{i}: nop'])
        else: lines.extend([f'jal x{rd},L{i}',f'sw x0,{r.randrange(16)*4}(x0)',f'L{i}: add x{rb},x{rd},x0'])
    lines.append('halt: j halt')
    return '\n'.join(lines)

def main():
    BUILD.mkdir(exist_ok=True)
    rtl=[str(p.relative_to(ROOT)) for p in sorted((ROOT/'rtl').glob('*.v'))]
    for name in ('core','board','hazard'):
        print(run(['iverilog','-g2012','-Wall','-s','tb_'+name,'-o',str(BUILD/(name+'.vvp')),*rtl,f'tests/tb_{name}.v']).strip())
    demo,_,_=assemble((ROOT/'programs/demo.S').read_text())
    write_hex(demo,ROOT/'programs/demo.hex')
    results=[]
    directed=(ROOT/'tests/directed.S').read_text()
    for pause in (0,1):
        n,c,regs=check('directed'+str(pause),directed,pause,6)
        assert regs[31]==0, 'reached bad label'
        assert all(c[k]>0 for k in ('ma','mb','wa','wb','flushes'))
        results.append(f'PASS directed pause={pause}: {n} retirements; {c}')
    for seed in range(24):
        n,c,_=check('random'+str(seed),randomized(seed),seed%2)
        results.append(f'PASS random seed={seed}: {n} retirements, {c["stalls"]} stalls')
    results.append(run(['vvp',str(BUILD/'hazard.vvp')]).strip())
    results.append(run(['vvp',str(BUILD/'board.vvp')]).strip())
    report='\n'.join(results)+'\n'
    (BUILD/'test_results.txt').write_text(report)
    print(report)

if __name__=='__main__': main()
