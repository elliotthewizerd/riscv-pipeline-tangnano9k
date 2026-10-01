# RISC-V pipeline — RTL simulation

CPU RV32 5 tầng **IF → ID → EX → MEM → WB**, viết bằng Verilog, mỗi module một file. Có forwarding **MEM→EX**, **WB→EX**, bypass **WB→ID**, stall **load-use**, và flush khi branch/jump đổi PC. Tên bộ nhớ giữ là `imem`, `dmem`; tên cổng dùng `clk`, `rst`, `A`, `RD`, `WD`, `WE`.

Đây là lõi học tập dùng một phần tập lệnh RV32I, không phải triển khai RV32I đầy đủ. Hỗ trợ `lw`, `sw`, toàn bộ 6 branch, `jal`, `jalr`, `lui`, `auipc`, các phép ALU thanh ghi/immediate. `j label` được assembler chuyển thành `jal x0, label`. Chưa có byte/halfword load/store, CSR, trap, interrupt, `ecall`, `ebreak`, `fence`, extension M/C, cache hay bus có wait-state.

## Chạy mô phỏng

Cần Python 3.10+ và Icarus Verilog (`iverilog`, `vvp`) trong PATH. Chạy từ thư mục gốc dự án:

```powershell
python scripts/test.py
```

Tests compare retired instructions and memory stores against a sequential reference model.

Để xem sóng của test directed (địa chỉ dừng lấy từ label `halt`):

```powershell
python scripts/asm.py tests/directed.S build/directed.hex
python -c "import sys; sys.path.insert(0,'scripts'); from asm import assemble; from pathlib import Path; print(assemble(Path('tests/directed.S').read_text())[1]['halt'])"
# Thay HALT_PC bằng số vừa in:
vvp build/core.vvp +ROM=build/directed.hex +STOP=HALT_PC +VCD
# Mở build/core.vcd bằng GTKWave.
```

## Cấu trúc

| Thư mục / file | Nội dung |
|---|---|
| `rtl/` | 20 module Verilog, mỗi file một module |
| `tests/` | Core and hazard testbenches, assembly programs |
| `scripts/` | Assembly assembler and simulation runner |
