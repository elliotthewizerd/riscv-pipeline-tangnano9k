# Kết quả kiểm chứng

Run date: 2026-09-29. Results below are from RTL simulation.

## RTL simulation

Lệnh: `python scripts/test.py`, Python 3.11, Icarus Verilog trên Windows. Trace retirement/store được so sánh với mô hình ISA tuần tự trong `scripts/test.py`; không chỉ kiểm tra một giá trị cuối cùng.

| Bài kiểm tra | Kết quả |
|---|---|
| Directed, chạy liên tục | 79 lệnh hoàn tất, 115 chu kỳ, đúng 6 stall, 13 redirect |
| Directed, ngắt `ce` định kỳ | 79 lệnh, 161 chu kỳ, 46 chu kỳ dừng; cùng 6 stall và 13 redirect |
| Random seed 0..23 | Tất cả retirement, register write và store khớp mô hình |
| Hazard unit | 20.000 vector; priority M/W, x0, source-use, load, redirect/stall |

Directed bao gồm forwarding cả A/B từ M/W; chuỗi nhiều producer cùng rd; WB→ID; load→ALU, store-data, branch, jalr, load-address, store-address; immediate không dùng rs2; x0; signed/unsigned branch; jal link; jalr target; shift/sign extension; lệnh unsupported và hủy store sai đường. Chương trình random có ALU/immediate/shift/load/store/branch/jal và chạy cả có/không pause.

Chưa chạy bộ chứng nhận kiến trúc RISC-V hoặc formal proof. Mô hình ISA và assembler kèm theo là công cụ kiểm tra nội bộ; bộ random không đại diện cho mọi tổ hợp lệnh có thể có.
