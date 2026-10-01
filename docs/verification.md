# Kiểm tra luồng mô phỏng

Kiểm tra ngày 2026-10-01, Python 3.11 và Icarus Verilog trên Windows.

## Các bằng chứng người dùng có thể xem

- `python scripts/test.py`: bài mẫu [waveform.S](../tests/waveform.S) chạy 21 chu kỳ; so sánh 20 trường mỗi chu kỳ với [waveform.expected.csv](../tests/waveform.expected.csv). Giá trị kỳ vọng được tính trước, lưu trong Git.
- `python scripts/test.py programs/my_program.S`: trình bày mã máy, trace thực thi và trạng thái thanh ghi/bộ nhớ đọc từ RTL. Các chú thích `# expect` chứa giá trị cuối do người viết ASM đặt.
- VCD, bảng so sánh từng chu kỳ và log vẫn được ghi ra khi có sai lệch, để người dùng xem được nguyên nhân.

Cách đọc tín hiệu và bảng tính tay nằm trong [hướng dẫn mô phỏng](simulation.md).

## Kiểm tra công cụ có phát hiện lỗi

Lệnh: `python -m unittest discover -s tests -p test_cli.py -v`.

| Trường hợp | Kết quả kiểm tra |
|---|---|
| Bài sóng mẫu | 21 chu kỳ khớp; các tín hiệu Obs/Exp có trong VCD |
| Nhập trực tiếp ASM: 9 + 4, store rồi load | Giá trị thực x3=13, x4=13, mem[0]=13; tự thêm nhãn halt vào bản build |
| Cố ý đổi kỳ vọng FwdA chu kỳ 5 từ 1 thành 0 | Trả mã lỗi 1, báo đúng trường/chu kỳ, Mismatch lên 1 trong VCD |
| Cố ý đặt x3 kỳ vọng 99 trong khi ASM ghi 13 | Trả mã lỗi 1, báo giá trị thực 13 và kỳ vọng 99; giữ VCD/report |

GTKWave đã nạp được VCD và preset `waves.gtkw` bằng lệnh kiểm tra `gtkwave --exit`.

## Regression bổ sung

Lệnh: `python scripts/test.py --regression`. Trace retirement/store được so sánh với mô hình tuần tự trong [regression.py](../scripts/regression.py).

| Bài kiểm tra | Kết quả |
|---|---|
| Directed chạy liên tục | 79 lệnh hoàn tất, 115 chu kỳ, 6 stall, 13 redirect |
| Directed ngắt ce định kỳ | 79 lệnh, 161 chu kỳ, 46 chu kỳ dừng; cùng 6 stall và 13 redirect |
| Random seed 0..23 | Retirement, register write và store khớp mô hình |
| Hazard unit | 20.000 vector: priority M/W, x0, source-use, load, redirect/stall |

Mô hình tuần tự và assembler là công cụ đi kèm dự án, không phải bộ chứng nhận ISA độc lập. Chưa chạy formal proof hoặc bộ chứng nhận RISC-V. Các kết quả trên chỉ xác nhận những trường hợp đã kiểm tra.
