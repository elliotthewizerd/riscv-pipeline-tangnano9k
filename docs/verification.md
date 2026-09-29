# Kết quả kiểm chứng

Ngày chạy: 2026-09-29. Đây là kết quả mô phỏng và build, chưa phải biên bản kiểm thử board vật lý.

## RTL simulation

Lệnh: `python scripts/test.py`, Python 3.11, Icarus Verilog trên Windows. Trace retirement/store được so sánh với mô hình ISA tuần tự trong `scripts/test.py`; không chỉ kiểm tra một giá trị cuối cùng.

| Bài kiểm tra | Kết quả |
|---|---|
| Directed, chạy liên tục | 79 lệnh hoàn tất, 115 chu kỳ, đúng 6 stall, 13 redirect |
| Directed, ngắt `ce` định kỳ | 79 lệnh, 161 chu kỳ, 46 chu kỳ dừng; cùng 6 stall và 13 redirect |
| Random seed 0..23 | Tất cả retirement, register write và store khớp mô hình |
| Hazard unit | 20.000 vector; priority M/W, x0, source-use, load, redirect/stall |
| Board top | Power-on, self-check demo, LED polarity, nhấn reset, chạy lại đều PASS |

Directed bao gồm forwarding cả A/B từ M/W; chuỗi nhiều producer cùng rd; WB→ID; load→ALU, store-data, branch, jalr, load-address, store-address; immediate không dùng rs2; x0; signed/unsigned branch; jal link; jalr target; shift/sign extension; lệnh unsupported và hủy store sai đường. Chương trình random có ALU/immediate/shift/load/store/branch/jal và chạy cả có/không pause.

Chưa chạy bộ chứng nhận kiến trúc RISC-V hoặc formal proof. Mô hình ISA và assembler kèm theo là công cụ kiểm tra nội bộ; bộ random không đại diện cho mọi tổ hợp lệnh có thể có.

## Gowin synthesis và place & route

Lệnh: `gw_sh scripts/gowin_build.tcl`. Tool **V1.9.11.03 Education**, device **GW1NR-9C / GW1NR-LV9QN88PC6/I5**, chương trình `programs/demo.hex`.

| Chỉ tiêu | Kết quả |
|---|---:|
| Clock constraint | 27,000 MHz / 37,037 ns |
| Fmax báo cáo | 28,465 MHz |
| Worst setup slack | +1,907 ns |
| Setup violated endpoints | 0 |
| Hold violated endpoints | 0 |
| Logic | 1.658 / 8.640 (20%) |
| FF | 559 / 6.480 |
| Latch | 0 |
| BSRAM | 4 / 26 |
| I/O | 8 |
| Bitstream | `impl/pnr/riscv_pipeline.fs` đã tạo |

Nguồn số liệu là report cục bộ của Gowin. ROM cố định có thể khiến synthesis tối ưu bớt logic/register không thể được chương trình sử dụng; không coi số liệu demo là mức sử dụng cho mọi ROM. Phải kiểm tra timing và tài nguyên sau mỗi thay đổi. Các output LED là tín hiệu hiển thị tĩnh, không có yêu cầu timing giao tiếp ngoài; reset bất đồng bộ được đặt false path và đồng bộ nhả reset trong RTL.

Đã thử mô phỏng netlist với Icarus nhưng netlist do bản Gowin Education này xuất dùng `pragma protect` mã hóa, Icarus không đọc được. Vì vậy kết quả mô phỏng nêu trên là **RTL simulation**, không phải gate-level/post-route simulation. Không sửa hoặc bỏ lớp mã hóa netlist.

Để tái lập, dùng file nguồn/constraint đã commit, chạy lại test và script build. Tool có thể ghi cache vào thư mục người dùng ngoài repo; trên môi trường sandbox cần quyền ghi cache bình thường của Gowin.
