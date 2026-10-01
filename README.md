# RISC-V pipeline — RTL simulation

CPU RV32 5 tầng **IF → ID → EX → MEM → WB**, viết bằng Verilog, mỗi module một file. Có forwarding **MEM→EX**, **WB→EX**, bypass **WB→ID**, stall **load-use**, và flush khi branch/jump đổi PC. Tên bộ nhớ giữ là `imem`, `dmem`; tên cổng dùng `clk`, `rst`, `A`, `RD`, `WD`, `WE`.

Đây là lõi học tập dùng một phần tập lệnh RV32I, không phải triển khai RV32I đầy đủ. Hỗ trợ `lw`, `sw`, toàn bộ 6 branch, `jal`, `jalr`, `lui`, `auipc`, các phép ALU thanh ghi/immediate. `j label` được assembler chuyển thành `jal x0, label`. Chưa có byte/halfword load/store, CSR, trap, interrupt, `ecall`, `ebreak`, `fence`, extension M/C, cache hay bus có wait-state.


## Sơ đồ tham khảo

[![Figure 7.61: Pipelined processor with full hazard handling](docs/images/harris-figure-7-61.png)](docs/images/harris-figure-7-61.pdf)

**Nguồn:** Sarah L. Harris và David Harris, *Digital Design and Computer Architecture: RISC-V Edition*, ấn bản 1, Morgan Kaufmann / Elsevier, 2021, Chương 7, Figure 7.61: “Pipelined processor with full hazard handling”.
Hình lấy từ [bộ tài nguyên chính thức của tác giả](https://pages.hmc.edu/harris/ddca/ddcarv.html); bản quyền hình thuộc Elsevier. Nhấn vào hình để mở PDF gốc.

**Đối chiếu RTL:** dự án khớp kiến trúc pipeline 5 tầng và cơ chế forwarding, stall load-use, flush branch/jump trong hình. RTL có thêm khối so sánh cho 6 loại branch, đường `jalr`/`auipc`, bypass WB→ID, tín hiệu valid và `ce`; vì vậy hình là sơ đồ tham khảo, không mô tả đầy đủ từng dây của RTL hiện tại. Xem [bảng đối chiếu khối, tín hiệu và đường đi của lệnh](docs/architecture.md).

## Chạy mô phỏng và tự kiểm chứng

Cần Python 3.10+, Icarus Verilog (`iverilog`, `vvp`) và GTKWave trong PATH.

**Xem sóng RTL cạnh sóng kỳ vọng**, chạy từ thư mục gốc:

```cmd
python scripts/test.py
```

Lệnh này chạy bài ASM ngắn, in kết quả cụ thể và tự mở GTKWave với các cặp `Obs...` / `Exp...` đã chọn sẵn. Kỳ vọng lấy từ [bảng 21 chu kỳ tính trước](tests/waveform.expected.csv). `Mismatch = 1` đánh dấu chu kỳ lệch. Xem [bảng giải thích từng chu kỳ và cách đọc sóng](docs/simulation.md).

**Tự nhập ASM trong terminal:**

```cmd
python scripts/test.py --asm
```

Dán các lệnh, kết thúc bằng một dòng `END`. Có thể thêm `# expect x3 = 30` hoặc `# expect mem[0] = 30` để tự đặt giá trị mong đợi. Báo cáo hiển thị giá trị đọc trực tiếp từ RTL cạnh kỳ vọng của bạn.

**Hoặc sửa file [programs/my_program.S](programs/my_program.S) rồi chạy:**

```cmd
python scripts/test.py programs/my_program.S
```

Kết quả gồm mã máy, từng lệnh hoàn tất, các lần ghi bộ nhớ, cả 32 thanh ghi và VCD. Các file nằm trong `build/<tên_chương_trình>/`; bài mặc định dùng `build/waveform/`. Mở `report.txt` để đọc lại kết quả, `cycles.csv` để đối chiếu từng chu kỳ, `wave.vcd` cùng `waves.gtkw` để xem sóng.

Nếu đang ở thư mục `scripts`, dùng `python test.py` thay cho `python scripts/test.py`. Thêm `--no-open` để chỉ xuất file. Bộ test tự động cũ được giữ riêng:

```cmd
python scripts/test.py --regression
```

[Hướng dẫn đầy đủ, chương trình mẫu và cách cố ý tạo sai lệch để kiểm tra công cụ](docs/simulation.md).

## Cấu trúc

| Thư mục / file | Nội dung |
|---|---|
| `rtl/` | 20 module Verilog, mỗi file một module |
| `tests/waveform.S`, `waveform.expected.csv` | Bài mẫu và sóng kỳ vọng cố định |
| `tests/tb_core.v` | Mô phỏng core, lấy mẫu Obs/Exp, xuất trace và trạng thái cuối |
| `tests/tb_hazard.v`, `directed.S` | Test hazard và chương trình regression |
| `tests/test_cli.py` | Kiểm tra nhập ASM và phát hiện kỳ vọng sai |
| `programs/my_program.S` | File để tự sửa lệnh và kết quả mong đợi |
| `scripts/test.py` | Chạy bài sóng, nhập ASM hoặc chạy file ASM |
| `scripts/waveform.py` | Đọc fixture, xuất CSV và chọn tín hiệu GTKWave |
| `scripts/regression.py` | Bộ test tự động và mô hình ISA tuần tự đi kèm |
| `scripts/asm.py` | Assembler cho tập lệnh hỗ trợ |
| `docs/simulation.md` | Hướng dẫn tự quan sát và đối chiếu |
