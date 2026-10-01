"""Integration checks for visible results and deliberately wrong expectations."""
import csv
import re
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"


class SimulationCLI(unittest.TestCase):
    def run_cli(self, *args, source=None):
        return subprocess.run(
            [sys.executable, str(ROOT / "scripts/test.py"), *args, "--no-open"],
            cwd=ROOT / "scripts", input=source, text=True, capture_output=True,
        )

    def test_fixed_cycle_waveform(self):
        proc = self.run_cli()
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        with (BUILD / "waveform/cycles.csv").open() as f:
            rows = list(csv.DictReader(f))
        self.assertEqual(len(rows), 21)
        self.assertTrue(all(v == "True" for row in rows for k, v in row.items() if k.startswith("Match")))
        text = (BUILD / "waveform/wave.vcd").read_text()
        header = text.split("$enddefinitions")[0]
        for name in ("ObsPCF", "ExpPCF", "ObsFwdA", "ExpFwdA", "Mismatch"):
            self.assertRegex(header, rf"\$var \w+ \d+ \S+ {name}(?:\s|\[)")
        self.assertIn("x6              0x0000002a   0x0000002a   yes", proc.stdout)

    def test_wrong_cycle_expectation_is_visible(self):
        BUILD.mkdir(exist_ok=True)
        source = BUILD / "injected_waveform.S"
        source.write_text((ROOT / "tests/waveform.S").read_text(), encoding="utf-8")
        with (ROOT / "tests/waveform.expected.csv").open() as f:
            reader = csv.DictReader(f)
            fields = reader.fieldnames
            rows = list(reader)
        rows[4]["FwdA"] = "0"  # Cycle 5 actually needs WB -> A; intentionally wrong.
        wrong = BUILD / "injected.expected.csv"
        with wrong.open("w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fields)
            writer.writeheader()
            writer.writerows(rows)
        proc = self.run_cli(str(source), "--expected", str(wrong))
        self.assertEqual(proc.returncode, 1)
        self.assertIn("Cycle 5 FwdA: RTL=1, expected=0", proc.stdout)
        vcd = (BUILD / "injected_waveform/wave.vcd").read_text()
        symbol = re.search(r"\$var reg 1 (\S+) Mismatch", vcd).group(1)
        self.assertIn("\n1" + symbol + "\n", vcd)
        self.assertTrue((BUILD / "injected_waveform/cycles.csv").exists())

    def test_typed_asm_reports_actual_state(self):
        proc = self.run_cli("--asm", source=(
            "addi x1,x0,9\naddi x2,x0,4\nadd x3,x1,x2\n"
            "sw x3,0(x0)\nlw x4,0(x0)\n"
            "# expect x3 = 13\n# expect x4 = 13\n# expect mem[0] = 13\nEND\n"))
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("Added 'halt: j halt'", proc.stdout)
        self.assertIn("x3              0x0000000d   0x0000000d   yes", proc.stdout)
        self.assertIn("mem[0]          0x0000000d   0x0000000d   yes", proc.stdout)
        self.assertTrue((BUILD / "input/wave.vcd").exists())

    def test_wrong_user_result_fails_and_keeps_evidence(self):
        source = BUILD / "injected_wrong_result.S"
        source.write_text("addi x3,x0,13\n# expect x3 = 99\n", encoding="utf-8")
        proc = self.run_cli(str(source))
        self.assertEqual(proc.returncode, 1, proc.stdout + proc.stderr)
        self.assertIn("x3: RTL=0x0000000d, expected=0x00000063", proc.stdout)
        self.assertTrue((BUILD / "injected_wrong_result/wave.vcd").exists())
        self.assertTrue((BUILD / "injected_wrong_result/report.txt").exists())


if __name__ == "__main__":
    unittest.main()
