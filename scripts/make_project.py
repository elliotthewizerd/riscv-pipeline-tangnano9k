"""Generate the portable Gowin GUI project from the RTL directory."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
files=[p.relative_to(ROOT).as_posix() for p in sorted((ROOT/'rtl').glob('*.v'))]
entries='\n'.join(f'        <File path="{p}" type="file.verilog" enable="1"/>' for p in files)
(ROOT/'riscv_pipeline.gprj').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE gowin-fpga-project>
<Project>
    <Template>FPGA</Template>
    <Version>5</Version>
    <Device name="GW1NR-9C" pn="GW1NR-LV9QN88PC6/I5">gw1nr9c-004</Device>
    <FileList>
{entries}
        <File path="constraints/tangnano9k.cst" type="file.cst" enable="1"/>
        <File path="constraints/tangnano9k.sdc" type="file.sdc" enable="1"/>
    </FileList>
</Project>
''',encoding='utf-8')
print('Wrote riscv_pipeline.gprj')
