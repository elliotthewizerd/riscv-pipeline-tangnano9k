# Tự chạy và kiểm chứng kết quả

Có hai cách kiểm tra chính: đối chiếu sóng RTL với bảng kỳ vọng đã viết trước, và chạy ASM do bạn nhập để xem kết quả thực. Bộ regression ngẫu nhiên nằm ở lệnh riêng.

## 1. Xem sóng thực và sóng kỳ vọng

Cần Python 3.10+, Icarus Verilog (`iverilog`, `vvp`) và GTKWave trong PATH. Từ thư mục gốc:

```cmd
python scripts/test.py
```

Nếu terminal đang ở thư mục `scripts`, dùng `python test.py`.

Lệnh mặc định chạy [waveform.S](../tests/waveform.S), in kết quả và tự mở GTKWave. Các tín hiệu đã được chọn sẵn, từng cặp thực/kỳ vọng nằm cạnh nhau:

- `Obs...`: mẫu đo từ RTL.
- `Exp...`: giá trị lấy từ [waveform.expected.csv](../tests/waveform.expected.csv), được tính trước từ chương trình và lịch pipeline.
- `Compare = 1`: đang đối chiếu với bảng kỳ vọng.
- `Mismatch = 1`: ít nhất một trường của chu kỳ đang lệch, gồm cả giá trị X.
- `cycles`: số chu kỳ tương ứng hàng trong CSV.

Hai bộ tín hiệu là các mẫu tại **cùng cạnh lên, trước khi các thanh ghi RTL cập nhật bằng nonblocking assignment**. Mẫu chu kỳ 1 ở 35 ns, chu kỳ 2 ở 45 ns; công thức là `35 + 10*(cycle-1)` ns. `ObsRet*` và `ObsMem*` ghi lại tác vụ ghi diễn ra tại cạnh đó. Mẫu giữ đến cạnh kế tiếp để dễ xem.

Các tín hiệu bên trong `dut` vẫn có trong VCD. Chúng thay đổi sau cạnh clock; vì vậy đừng so trực tiếp trạng thái sau cạnh của `dut` với ảnh chụp trước cạnh `Obs...` mà không tính thời điểm lấy mẫu.

Trong GTKWave, dùng **Zoom Fit** nếu chưa thấy toàn bài test; nhấn vào mốc thời gian để đọc giá trị. `ffffffff` ở PC của tầng D/E/M/W biểu thị bubble. Mã forwarding: 0 = dữ liệu gốc, 1 = WB, 2 = MEM. `RetWE`/`MemWE` bằng 0 thì các trường dữ liệu ghi tương ứng được chuẩn hóa thành 0.

## Bảng tính tay của bài mẫu

PC dưới đây là địa chỉ byte ở hệ thập phân; waveform mặc định hiển thị hex.

| Chu kỳ | F | D | E | M | W | Sự kiện kỳ vọng |
|---:|---:|---:|---:|---:|---:|---|
| 1 | 0 | - | - | - | - | Bắt đầu fetch |
| 2 | 4 | 0 | - | - | - | |
| 3 | 8 | 4 | 0 | - | - | |
| 4 | 12 | 8 | 4 | 0 | - | |
| 5 | 16 | 12 | 8 | 4 | 0 | FwdA=1, FwdB=2; x1=5 |
| 6 | 20 | 16 | 12 | 8 | 4 | FwdB=2 cho store; x2=7 |
| 7 | 24 | 20 | 16 | 12 | 8 | StallF/D=1, FlushE=1; x3=12; mem[0]=12 |
| 8 | 24 | 20 | - | 16 | 12 | PC và ID giữ lại, EX là bubble |
| 9 | 28 | 24 | 20 | - | 16 | FwdA=1 từ load; x4=12 |
| 10 | 32 | 28 | 24 | 20 | - | FwdA=2; branch x5==0 không taken |
| 11 | 36 | 32 | 28 | 24 | 20 | FwdA/B=1; branch x5==x5 taken, FlushD/E=1; x5=17 |
| 12 | 40 | - | - | 28 | 24 | Hủy hai lệnh sai đường |
| 13 | 44 | 40 | - | - | 28 | |
| 14 | 48 | 44 | 40 | - | - | |
| 15 | 52 | 48 | 44 | 40 | - | Jump đến PC=56, FlushD/E=1 |
| 16 | 56 | - | - | 44 | 40 | x6=42 |
| 17 | 60 | 56 | - | - | 44 | |
| 18 | 64 | 60 | 56 | - | - | |
| 19 | 68 | 64 | 60 | 56 | - | mem[4]=42; jump halt, FlushD/E=1 |
| 20 | 60 | - | - | 60 | 56 | |
| 21 | 64 | 60 | - | - | 60 | Lệnh halt retire, kết thúc mô phỏng |

Kết quả tính từ chương trình: `x3 = 5+7 = 12`, `x4 = mem[0] = 12`, `x5 = 12+5 = 17`. Nhánh đúng đặt `x6 = 42`. Các store sai đường không được chạy, nên `mem[0]` vẫn là 12 và `mem[4] = 42`.

CSV chứa 20 trường mỗi chu kỳ, bao gồm PC các tầng, forwarding, stall/flush, redirect, retirement và ghi bộ nhớ. `test.py` chỉ đóng gói CSV thành dữ liệu đọc cho testbench; không tính lại kỳ vọng từ RTL hay mô hình Python.

## 2. Tự nhập ASM

Nhập hoặc dán trực tiếp trong terminal:

```cmd
python scripts/test.py --asm
```

Ví dụ nội dung nhập; dòng `END` là lệnh kết thúc nhập, không thuộc assembly:

```asm
addi x1,x0,10
addi x2,x0,20
add x3,x1,x2
sw x3,0(x0)
lw x4,0(x0)
addi x5,x4,1
# expect x3 = 30
# expect x4 = 30
# expect x5 = 31
# expect mem[0] = 30
END
```

Bạn sẽ thấy mã máy của từng lệnh, các lần retire/ghi bộ nhớ kèm số chu kỳ, cả 32 thanh ghi và bộ nhớ đã khởi tạo. Các giá trị này được testbench đọc trực tiếp từ `dut.rf.regs` và `ram.mem`. Lệnh store ghi bộ nhớ ở MEM rồi retire ở WB, nên hai dòng tương ứng xuất hiện ở hai chu kỳ.

Bảng `YOUR EXPECTATIONS` đặt giá trị quan sát cạnh số bạn tự khai báo. Ví dụ trên phải cho x3=30, x4=30, x5=31 và mem[0]=30. Nếu không có `# expect`, chương trình chỉ trình bày kết quả, không tự kết luận ASM của bạn đúng.

Với ASM tự nhập, GTKWave chọn các tín hiệu `Obs...`. Muốn thêm sóng kỳ vọng theo chu kỳ, tự tạo CSV theo cấu trúc bài mẫu rồi dùng `--expected duong_dan.csv`. Kỳ vọng giá trị cuối bằng `# expect` được đối chiếu trong terminal/report; nó không tự sinh lịch kỳ vọng cho từng chu kỳ.

## 3. Sửa và chạy một file ASM

Có sẵn [programs/my_program.S](../programs/my_program.S) để sửa:

```cmd
python scripts/test.py programs/my_program.S
```

Chạy lại lệnh sau mỗi lần lưu file. Nhãn dừng có dạng:

```asm
halt:
    j halt
```

Nếu thiếu nhãn `halt`, công cụ thêm đoạn trên vào **bản sao trong build**, không sửa file gốc. Nhãn phải đến được; vòng lặp vô hạn trước đó sẽ timeout và giữ lại VCD để xem. `halt` là quy ước của testbench, không phải lệnh ISA.

Assembler dùng thanh ghi `x0..x31`, immediate số thập phân/hex, label và chú thích `#`. Hỗ trợ các lệnh ghi trong README cùng pseudo `j`, `nop`, `mv`, `ret`. Không nhận cú pháp GNU đầy đủ như `.text`, `.data`, ABI register names hay `li`. Dùng `addi` hoặc `lui` phù hợp để tạo hằng số.

Bộ nhớ dữ liệu có địa chỉ word-aligned 0..252, chưa được khởi tạo mặc định. Hãy `sw` trước khi `lw` ô đó; giá trị chưa khởi tạo hiện là `X`, không bị đổi thành 0 trong báo cáo.

## Tự kiểm tra công cụ có bắt lỗi không

Trong bản sao chương trình mẫu, đổi `# expect x3 = 30` thành `# expect x3 = 99`, giữ nguyên lệnh. Chạy lại: dòng x3 phải hiện RTL=30, Expected=99, Match=NO và chương trình trả mã lỗi 1. VCD và báo cáo vẫn được giữ.

Để thử so sánh sóng, sao chép `tests/waveform.expected.csv`, đổi FwdA ở chu kỳ 5 từ 1 sang 0:

```cmd
python scripts/test.py tests/waveform.S --expected ban_sao.expected.csv
```

Kết quả phải báo `Cycle 5 FwdA: RTL=1, expected=0`; tín hiệu `Mismatch` lên 1 ở mẫu chu kỳ 5. Không sửa fixture chuẩn nếu chưa kiểm tra lại bằng tay.

## Các file kết quả

Mỗi chương trình có thư mục `build/<tên_file>/`; nhập bằng `--asm` dùng `build/input/`. Bài mặc định dùng `build/waveform/`. Chạy lại cùng tên sẽ ghi đè kết quả lần trước.

| File | Nội dung |
|---|---|
| `program.S`, `program.hex`, `program.lst` | Bản ASM thực sự chạy, mã máy và địa chỉ từng lệnh |
| `wave.vcd` | Sóng RTL, các mẫu Obs và Exp khi có fixture |
| `waves.gtkw` | Danh sách tín hiệu đã chọn; mở cùng VCD trong GTKWave |
| `cycles.csv` | Giá trị từng chu kỳ; thêm cột Exp/Match nếu có kỳ vọng |
| `report.txt` | Mã máy, các lệnh thực sự chạy, kết quả và sai lệch |
| `registers.csv`, `memory.csv` | Trạng thái cuối đọc trực tiếp từ RTL |
| `simulation.trace` | Log thô của testbench, kể cả khi có lỗi |

Chỉ xuất file, không mở GTKWave: thêm `--no-open`. Nếu GTKWave chưa ở PATH, mở `wave.vcd` rồi nạp `waves.gtkw` bằng giao diện.

Regression bổ sung, không mở cửa sổ:

```cmd
python scripts/test.py --regression
python -m unittest discover -s tests -p test_cli.py -v
```

Regression cũ dùng assembler/mô hình Python đi kèm và không phải trình kiểm chứng ISA độc lập. Bài waveform có bảng kỳ vọng cố định; kỳ vọng ASM của bạn do bạn nhập. Các lớp kiểm tra này hỗ trợ nhau và không chứng minh mọi tổ hợp lệnh đều đúng.
