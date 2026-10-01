"""Waveform fixture encoding and GTKWave signal selection (no CPU model)."""
import csv
from pathlib import Path

# Order also defines tests/tb_core.v's 305-bit comparison bus.
FIELDS = [
    ("PCF", 32), ("PCD", 32), ("PCE", 32), ("PCM", 32), ("PCW", 32),
    ("StallF", 1), ("StallD", 1), ("FlushD", 1), ("FlushE", 1),
    ("FwdA", 2), ("FwdB", 2), ("Redirect", 1),
    ("RetV", 1), ("RetWE", 1), ("RetPC", 32), ("RetRd", 5), ("RetWD", 32),
    ("MemWE", 1), ("MemA", 32), ("MemWD", 32),
]


def number(token, base=10):
    if any(c in token.lower() for c in "xz"):
        return None
    return int(token, base)


def load_expected(path):
    rows = []
    with Path(path).open(encoding="utf-8", newline="") as f:
        for line in csv.DictReader(f):
            row = {"cycle": int(line["cycle"])}
            if row["cycle"] != len(rows) + 1:
                raise ValueError("Expected waveform cycles must start at 1 and be contiguous")
            for name, width in FIELDS:
                token = line[name]
                value = 0xffffffff if token == "-" else int(token, 0)
                if not 0 <= value < (1 << width):
                    raise ValueError(f"{name}={token} does not fit {width} bits")
                row[name] = value
            rows.append(row)
    if not 1 <= len(rows) <= 10000:
        raise ValueError("Expected waveform needs 1..10000 rows")
    return rows


def write_expected_hex(rows, path):
    lines = []
    for row in rows:
        bits = 0
        for name, width in FIELDS:
            bits = (bits << width) | row[name]
        lines.append(f"{bits:077x}")
    path.write_text("\n".join(lines) + "\n", encoding="ascii")


def read_observed(output):
    rows, regs, mem = [], {}, {}
    for line in output.splitlines():
        t = line.split()
        if not t:
            continue
        if t[0] == "C":
            row = {"cycle": int(t[1]), "ce": int(t[2])}
            for (name, width), value in zip(FIELDS, t[3:]):
                row[name] = number(value, 16 if width == 32 else 10)
            if len(t[3:]) != len(FIELDS):
                raise ValueError("Malformed cycle trace")
            rows.append(row)
        elif t[0] == "G":
            regs[int(t[1])] = number(t[2], 16)
        elif t[0] == "D":
            mem[int(t[1])] = number(t[2], 16)
    return rows, regs, mem


def display(value, width=32):
    if value is None:
        return "X"
    return f"0x{value:08x}" if width == 32 else str(value)


def write_cycles(rows, expected, path):
    headers = ["cycle", "ce"]
    for name, _ in FIELDS:
        headers += [f"Obs{name}"]
        if expected:
            headers += [f"Exp{name}", f"Match{name}"]
    with path.open("w", encoding="utf-8", newline="") as f:
        out = csv.DictWriter(f, fieldnames=headers)
        out.writeheader()
        for i in range(max(len(rows), len(expected))):
            obs = rows[i] if i < len(rows) else {}
            exp = expected[i] if i < len(expected) else {}
            row = {"cycle": i + 1, "ce": obs.get("ce", "")}
            for name, width in FIELDS:
                row[f"Obs{name}"] = display(obs.get(name), width)
                if expected:
                    row[f"Exp{name}"] = display(exp.get(name), width)
                    row[f"Match{name}"] = name in obs and name in exp and obs[name] == exp[name]
            out.writerow(row)


def write_gtkw(path, wave, compare):
    lines = [
        "[*] RTL snapshots: Obs = measured, Exp = committed cycle fixture",
        f'[dumpfile] "{wave.resolve().as_posix()}"',
        "[size] 1400 850",
        "[pos] -1 -1",
        "*-20.000000 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0",
        "@28", "tb_core.clk", "tb_core.rst", "tb_core.ce",
        "@22", "tb_core.cycles[31:0]",
    ]
    if compare:
        lines += ["@28", "tb_core.Compare", "tb_core.Mismatch"]
    for name, width in FIELDS:
        suffix = f"[{width-1}:0]" if width > 1 else ""
        lines += ["@28" if width == 1 else "@22", f"tb_core.Obs{name}{suffix}"]
        if compare:
            lines += [f"tb_core.Exp{name}{suffix}"]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
