"""Run an observable waveform exercise or your own assembly on the RTL."""
import argparse
import csv
import re
import shutil
import subprocess
import sys
from pathlib import Path

from asm import assemble, write_hex
from waveform import (FIELDS, display, load_expected, read_observed,
                      write_cycles, write_expected_hex, write_gtkw)

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"


def find_file(value):
    path = Path(value).expanduser()
    if path.exists():
        return path.resolve()
    path = ROOT / path
    if path.exists():
        return path.resolve()
    raise ValueError(f"File not found: {value}")


def compile_core():
    for tool in ("iverilog", "vvp"):
        if not shutil.which(tool):
            raise ValueError(f"{tool} is missing from PATH")
    rtl = [str(p) for p in sorted((ROOT / "rtl").glob("*.v"))]
    proc = subprocess.run(
        ["iverilog", "-g2012", "-Wall", "-s", "tb_core",
         "-o", str(BUILD / "core.vvp"), *rtl, str(ROOT / "tests/tb_core.v")],
        cwd=ROOT, text=True, capture_output=True,
    )
    if proc.stdout or proc.stderr:
        print(proc.stdout + proc.stderr)
    if proc.returncode:
        raise ValueError("RTL compilation failed")


def get_assertions(source):
    checks = []
    pattern = r"\s*(x(?:[0-9]|[12][0-9]|3[01])|mem\[\s*(0x[0-9a-fA-F]+|\d+)\s*\])\s*=\s*([-+]?(?:0x[0-9a-fA-F]+|\d+))\s*"
    for lineno, line in enumerate(source.splitlines(), 1):
        if "#" not in line:
            continue
        comment = line.split("#", 1)[1].strip()
        if not re.match(r"expect(?:\s|$)", comment):
            continue
        match = re.fullmatch(pattern, comment[6:])
        if not match:
            raise ValueError(f"Line {lineno}: use '# expect x3 = 12' or '# expect mem[0] = 12'")
        target, addr, text = match.groups()
        value = int(text, 0)
        if not -(1 << 31) <= value <= 0xffffffff:
            raise ValueError(f"Line {lineno}: expected value outside 32 bits")
        if addr is not None:
            addr = int(addr, 0)
            if addr % 4 or not 0 <= addr < 256:
                raise ValueError(f"Line {lineno}: memory address must be 0..252, aligned to 4")
        checks.append((target, addr, value & 0xffffffff))
    return checks


def prepare(source):
    words, labels, listing = assemble(source)
    if not words:
        raise ValueError("Program is empty")
    # The bench stops on retirement of a self-loop, after all older writes.
    if "halt" not in labels:
        source = source.rstrip() + "\nhalt:\n    j halt\n"
        words, labels, listing = assemble(source)
        print("Added 'halt: j halt' to the build copy; your source file is unchanged.")
    stop = labels["halt"]
    if stop // 4 >= len(words) or words[stop // 4] != 0x0000006f:
        raise ValueError("Use 'halt: j halt' as the stop marker")
    return source, words, listing, stop


def compare_cycles(observed, expected):
    errors = []
    if len(observed) != len(expected):
        errors.append(f"Cycle count: RTL={len(observed)}, expected={len(expected)}")
    for obs, exp in zip(observed, expected):
        for name, width in FIELDS:
            if obs[name] != exp[name]:
                errors.append(f"Cycle {obs['cycle']} {name}: RTL={display(obs[name], width)}, expected={display(exp[name], width)}")
    return errors


def report_run(listing, words, rows, regs, mem, assertions, expected, errors):
    asm_at = {pc: line for pc, _, line in listing}
    lines = ["ASSEMBLED PROGRAM", "PC        MACHINE   ASM"]
    lines += [f"{pc:08x}  {word:08x}  {line}" for word, (pc, _, line) in zip(words, listing)]
    lines += ["", "OBSERVED RTL EXECUTION (sampled at rising clock edges)",
              "Cycle  PC        Instruction                     Register / memory write"]
    for row in rows:
        if row["RetV"]:
            pc = row["RetPC"]
            instruction = asm_at.get(pc, "(outside source)")
            write = f"x{row['RetRd']} <- {display(row['RetWD'])}" if row["RetWE"] else "-"
            lines.append(f"{row['cycle']:5}  {display(pc)[2:]:8}  {instruction:<30}  {write}")
        if row["MemWE"]:
            lines.append(f"{row['cycle']:5}  MEM       sw at PC={display(row['PCM'])}       mem[{display(row['MemA'])}] <- {display(row['MemWD'])}")
    lines += ["", "FINAL REGISTERS (read directly from dut.rf.regs, after the last edge)"]
    for start in range(0, 32, 4):
        lines.append("  ".join(
            f"x{i:<2}={display(regs.get(i))} ({signed(regs.get(i))})"
            for i in range(start, start + 4)))
    lines += ["", "INITIALIZED MEMORY (read directly from ram.mem; other words remain X)"]
    initialized = [(addr, val) for addr, val in sorted(mem.items()) if val is not None]
    lines += [f"mem[{addr:3}] = {display(val)} ({signed(val)})" for addr, val in initialized]
    if not initialized:
        lines.append("(no initialized words)")
    lines += ["", "YOUR EXPECTATIONS (# expect comments in the ASM file)"]
    if assertions:
        lines.append("Target          Observed     Expected     Match")
        for target, addr, wanted in assertions:
            got = regs.get(int(target[1:])) if addr is None else mem.get(addr)
            ok = got is not None and got == wanted
            lines.append(f"{target:<15} {display(got):12} {display(wanted):12} {'yes' if ok else 'NO'}")
            if not ok:
                errors.append(f"{target}: RTL={display(got)}, expected={display(wanted)}")
    else:
        lines.append("None supplied. Values above are observations, not a claim that your program is correct.")
    if expected:
        lines += ["", f"WAVEFORM CHECK: {len(expected)} committed cycles, {len(FIELDS)} fields per cycle",
                  "Expected values come from the supplied cycle CSV, NOT from this simulation.",
                  "Inspect Obs/Exp pairs and Mismatch in GTKWave; cycle-by-cycle values are in cycles.csv."]
    if errors:
        lines += ["", "CHECK FAILED"] + errors[:40]
        if len(errors) > 40:
            lines.append(f"... {len(errors)-40} more differences; inspect cycles.csv and simulation.trace")
    else:
        lines += ["", "Simulation completed; supplied expectations matched." if (assertions or expected)
                  else "Simulation completed. Review the observed results above."]
    return "\n".join(lines) + "\n"


def signed(value):
    if value is None:
        return "unknown"
    return str(value if value < 0x80000000 else value - 0x100000000)


def open_wave(wave, save):
    exe = shutil.which("gtkwave")
    if not exe:
        print("GTKWave is not in PATH. Open the VCD and .gtkw save file with GTKWave.")
        return
    # GTKWave is the requested interactive viewer; no extra console is needed.
    log = wave.with_name("gtkwave.log")
    with log.open("w", encoding="utf-8") as out:
        subprocess.Popen([exe, str(wave), str(save)], cwd=ROOT,
                         stdout=out, stderr=subprocess.STDOUT)
    print("Opened GTKWave with the signals already selected.")


def simulate(source, name, expected_path=None, pause=0, no_open=False):
    BUILD.mkdir(exist_ok=True)
    source, words, listing, stop = prepare(source)
    assertions = get_assertions(source)
    output = BUILD / name
    output.mkdir(exist_ok=True)
    # Clear only previous outputs of this same run to avoid displaying stale data
    # if the simulator fails before producing a waveform.
    for stale_name in ("wave.vcd", "simulation.trace", "cycles.csv", "report.txt",
                       "registers.csv", "memory.csv", "waves.gtkw"):
        (output / stale_name).unlink(missing_ok=True)
    (output / "program.S").write_text(source, encoding="utf-8")
    write_hex(words, output / "program.hex")
    (output / "program.lst").write_text("\n".join(
        f"{pc:08x}  {w:08x}  {line}"
        for w, (pc, _, line) in zip(words, listing)) + "\n", encoding="utf-8")
    expected = load_expected(expected_path) if expected_path else []
    compile_core()
    wave = output / "wave.vcd"
    args = ["vvp", str(BUILD / "core.vvp"), f"+ROM={output / 'program.hex'}",
            f"+STOP={stop}", f"+PAUSE={pause}", f"+WAVE={wave}", "+DETAIL"]
    if expected:
        write_expected_hex(expected, output / "expected.hex")
        args += [f"+EXPECT={output / 'expected.hex'}", f"+EXP_ROWS={len(expected)}"]
    proc = subprocess.run(args, cwd=ROOT, text=True, capture_output=True)
    trace = proc.stdout + proc.stderr
    (output / "simulation.trace").write_text(trace, encoding="utf-8")
    rows, regs, mem = read_observed(trace)
    errors = compare_cycles(rows, expected) if expected else []
    if proc.returncode:
        errors.append(f"Simulator exited with code {proc.returncode}; see simulation.trace")
        errors += [line for line in trace.splitlines() if "FATAL:" in line or "ERROR:" in line]
    if len(regs) != 32 or len(mem) != 64:
        errors.append("Final RTL state missing: the program did not reach halt normally.")
    write_cycles(rows, expected, output / "cycles.csv")
    for filename, title, values in (("registers.csv", "register", regs), ("memory.csv", "byte_address", mem)):
        with (output / filename).open("w", encoding="utf-8", newline="") as f:
            writer = csv.writer(f)
            writer.writerow([title, "hex", "signed_decimal"])
            for index, value in sorted(values.items()):
                writer.writerow([f"x{index}" if title == "register" else index, display(value), signed(value)])
    report = report_run(listing, words, rows, regs, mem, assertions, expected, errors)
    (output / "report.txt").write_text(report, encoding="utf-8")
    print(report)
    save = output / "waves.gtkw"
    write_gtkw(save, wave, bool(expected))
    print(f"Report:   {output / 'report.txt'}")
    print(f"Cycles:   {output / 'cycles.csv'}")
    print(f"Waveform: {wave}")
    print(f"Open: gtkwave \"{wave}\" \"{save}\"")
    if not no_open and wave.exists():
        open_wave(wave, save)
    return 1 if errors else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("program", nargs="?", help="your assembly file; default: fixed waveform exercise")
    parser.add_argument("--asm", action="store_true", help="type/paste assembly in the terminal, finish with END")
    parser.add_argument("--regression", action="store_true", help="run the old automated regression without a viewer")
    parser.add_argument("--no-open", action="store_true", help="write waveform/report without opening GTKWave")
    parser.add_argument("--wave", action="store_true", help="compatibility option; waveform is now always written")
    parser.add_argument("--pause", type=int, choices=(0, 1), default=0)
    parser.add_argument("--expected", help="hand-written cycle CSV for this program (same columns as waveform.expected.csv)")
    args = parser.parse_args()
    if sum((args.program is not None, args.asm, args.regression)) > 1:
        parser.error("Choose a program file, --asm, or --regression")
    if args.regression:
        if args.expected or args.pause or args.wave:
            parser.error("--regression does not take waveform/pause options")
        from regression import main as regression_main
        regression_main()
        return 0
    try:
        if args.asm:
            print("Enter/paste ASM; a line containing END runs it. Use # expect x3 = 12 to check your result.")
            source_lines = []
            while True:
                try:
                    line = input()
                except EOFError:
                    break
                if line.strip() == "END":
                    break
                source_lines.append(line)
            source, name = "\n".join(source_lines), "input"
        elif args.program:
            path = find_file(args.program)
            source, name = path.read_text(encoding="utf-8-sig"), path.stem
        else:
            source = (ROOT / "tests/waveform.S").read_text(encoding="utf-8")
            name = "waveform"
        expected_path = find_file(args.expected) if args.expected else None
        if not args.program and not args.asm and not args.expected:
            if args.pause:
                parser.error("The fixed cycle fixture uses --pause 0; use a program file for a paused run")
            expected_path = ROOT / "tests/waveform.expected.csv"
        return simulate(source, name, expected_path, args.pause, args.no_open)
    except (ValueError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
