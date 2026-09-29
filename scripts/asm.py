"""Small two-pass assembler for the implemented RV32 subset; no external packages."""
import argparse
import re
from pathlib import Path

R = {'add': (0, 0), 'sub': (0, 32), 'sll': (1, 0), 'slt': (2, 0),
     'sltu': (3, 0), 'xor': (4, 0), 'srl': (5, 0), 'sra': (5, 32),
     'or': (6, 0), 'and': (7, 0)}
I = {'addi': 0, 'slti': 2, 'sltiu': 3, 'xori': 4, 'ori': 6, 'andi': 7}
B = {'beq': 0, 'bne': 1, 'blt': 4, 'bge': 5, 'bltu': 6, 'bgeu': 7}

def reg(s):
    if not re.fullmatch(r'x(?:[0-9]|[12][0-9]|3[01])', s):
        raise ValueError(f'Expected x0..x31, got {s}')
    return int(s[1:])

def signed(n, bits):
    if not -(1 << (bits-1)) <= n < (1 << (bits-1)):
        raise ValueError(f'{n} does not fit signed {bits} bits')
    return n & ((1 << bits)-1)

def assemble(source):
    labels, lines = {}, []
    pc = 0
    for lineno, line in enumerate(source.splitlines(), 1):
        line = line.split('#')[0].strip()
        if not line:
            continue
        if ':' in line:
            label, line = line.split(':', 1)
            if label.strip() in labels:
                raise ValueError(f'Duplicate label {label}')
            labels[label.strip()] = pc
            line = line.strip()
        if line:
            lines.append((pc, lineno, line))
            pc += 4
    words = []
    for pc, lineno, line in lines:
        try:
            t = re.sub(r'[,()]', ' ', line).split()
            op, a = t[0].lower(), t[1:]
            value = lambda s: labels[s] if s in labels else int(s, 0)
            offset = lambda s: labels[s]-pc if s in labels else int(s, 0)
            if op == 'nop': op, a = 'addi', ['x0', 'x0', '0']
            if op == 'j': op, a = 'jal', ['x0', a[0]]
            if op == 'mv': op, a = 'addi', [a[0], a[1], '0']
            if op == 'ret': op, a = 'jalr', ['x0', '0', 'x1']
            if op == '.word': w = value(a[0]) & 0xffffffff
            elif op in R:
                f3, f7 = R[op]
                w = f7<<25 | reg(a[2])<<20 | reg(a[1])<<15 | f3<<12 | reg(a[0])<<7 | 0x33
            elif op in I or op in ('slli', 'srli', 'srai'):
                imm = value(a[2])
                if op in I: imm, f3 = signed(imm, 12), I[op]
                else:
                    if not 0 <= imm <= 31: raise ValueError('shift must be 0..31')
                    f3 = 1 if op == 'slli' else 5
                    if op == 'srai': imm |= 0x400
                w = imm<<20 | reg(a[1])<<15 | f3<<12 | reg(a[0])<<7 | 0x13
            elif op in ('lw', 'jalr'):
                w = signed(value(a[1]),12)<<20 | reg(a[2])<<15 | (2 if op=='lw' else 0)<<12 | reg(a[0])<<7 | (3 if op=='lw' else 0x67)
            elif op == 'sw':
                imm = signed(value(a[1]),12)
                w = (imm>>5)<<25 | reg(a[0])<<20 | reg(a[2])<<15 | 2<<12 | (imm&31)<<7 | 0x23
            elif op in B:
                off = offset(a[2])
                if off % 4: raise ValueError('branch target must be 4-byte aligned')
                imm = signed(off,13)
                w = (imm>>12)<<31 | ((imm>>5)&63)<<25 | reg(a[1])<<20 | reg(a[0])<<15 | B[op]<<12 | ((imm>>1)&15)<<8 | ((imm>>11)&1)<<7 | 0x63
            elif op == 'jal':
                off = offset(a[1])
                if off % 4: raise ValueError('jump target must be 4-byte aligned')
                imm = signed(off,21)
                w = (imm>>20)<<31 | ((imm>>1)&1023)<<21 | ((imm>>11)&1)<<20 | ((imm>>12)&255)<<12 | reg(a[0])<<7 | 0x6f
            elif op in ('lui','auipc'):
                imm = value(a[1])
                if not 0 <= imm < (1<<20): raise ValueError('U immediate must be 0..0xfffff')
                w = imm<<12 | reg(a[0])<<7 | (0x37 if op=='lui' else 0x17)
            else: raise ValueError(f'Unsupported mnemonic {op}')
            words.append(w)
        except (ValueError, IndexError) as e:
            raise ValueError(f'Line {lineno}: {line}: {e}') from e
    return words, labels, lines

def write_hex(words, path, depth=256):
    if len(words) > depth: raise ValueError(f'Program exceeds {depth} words')
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(''.join(f'{w:08x}\n' for w in words+[0x13]*(depth-len(words))), encoding='ascii')

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('source', type=Path)
    p.add_argument('output', type=Path)
    args = p.parse_args()
    words, labels, lines = assemble(args.source.read_text(encoding='utf-8'))
    write_hex(words, args.output)
    args.output.with_suffix('.lst').write_text('\n'.join(f'{pc:08x}  {w:08x}  {line}' for w, (pc, _, line) in zip(words, lines))+'\n', encoding='utf-8')
    print(f'{len(words)} instructions -> {args.output}')
