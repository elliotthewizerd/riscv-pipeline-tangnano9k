# Chạy trên Tang Nano 9K

## 1. Chuẩn bị

Dùng Tang Nano 9K, cáp USB-C có dữ liệu, Gowin IDE Education và Gowin Programmer. Board dùng clock 27 MHz. Project đã chọn `GW1NR-9C`, part `GW1NR-LV9QN88PC6/I5`, package QN88P. Đối chiếu marking của board nếu revision khác.

Thông tin chân và mức điện áp được đối chiếu với [schematic Sipeed](https://dl.sipeed.com/fileList/TANG/Nano%209K/2_Schematic/Tang_Nano_9k_3672_Schematic.pdf); quy trình IDE/Programmer tham khảo [hướng dẫn LED của Sipeed](https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-9K/examples/led.html). LED và nút ở bank 1,8 V; clock ở bank 3,3 V.

| Cổng top | Chân | IO_TYPE | Chức năng |
|---|---:|---|---|
| `clk` | 52 | LVCMOS33 | Clock 27 MHz |
| `rst_n` | 3 | LVCMOS18 | Nút S1, nhấn = reset |
| `led[0..5]` | 10, 11, 13, 14, 15, 16 | LVCMOS18 | LED active-low |

Không dùng nút ở chân 4 làm reset cho project này. `reset_sync` đồng bộ nhả reset và giữ reset thêm 255 chu kỳ sau đồng bộ; có khởi tạo lúc cấu hình FPGA. CPU dùng reset active-high nội bộ.

## 2. Tạo ROM và kiểm tra

Mở PowerShell tại thư mục gốc repo:

```powershell
python scripts/asm.py programs/demo.S programs/demo.hex
python scripts/test.py
```

`demo.hex` luôn đủ 256 dòng; mỗi dòng là một word 32-bit, không đảo thứ tự byte. Phần ROM còn trống được điền `00000013` (NOP). `demo.lst` ghi địa chỉ byte, mã máy và ASM để dò lỗi.

Assembler kèm theo nhận thanh ghi `x0..x31`, số thập phân/hex, label và comment `#`. Hỗ trợ `nop`, `mv`, `j`, `ret`; không phải GNU assembler, không nhận section/linker script hay mọi pseudo-instruction. Với `lui`, immediate là 20 bit phía trên: `lui x20,0x10000` tạo `0x10000000`.

## 3. Build bằng command line (đã kiểm tra)

```powershell
& 'C:\Gowin\Gowin_V1.9.11.03_Education_x64\IDE\bin\gw_sh.exe' scripts/gowin_build.tcl
```

Đổi đường dẫn theo nơi cài Gowin. **Chạy từ thư mục gốc repo** vì `$readmemh` dùng `programs/demo.hex`. Script thêm mọi file RTL, `.cst`, `.sdc`, đặt top `tangnano9k_top`, rồi chạy synthesis và place & route.

File nạp: `impl/pnr/riscv_pipeline.fs`. Report: `impl/pnr/riscv_pipeline.rpt.txt`, `riscv_pipeline_tr_content.html`. Kiểm tra Fmax ≥27 MHz và số setup/hold violated endpoints bằng 0 trước khi nạp. Bản demo đã đạt các điều kiện này; khi sửa chương trình/RTL hãy build và kiểm tra lại.

## 4. Hoặc mở bằng Gowin IDE

1. Mở `riscv_pipeline.gprj` ở thư mục gốc.
2. Kiểm tra Device đúng chip, top là `tangnano9k_top` (Set as Top Module nếu IDE chưa tự chọn).
3. Kiểm tra cả 20 file `rtl/*.v`, file pin và file timing xuất hiện trong project. Không thêm các file `tests/` làm source synthesis.
4. Chạy Synthesize, rồi Place & Route/Generate Bitstream.
5. Nếu IDE báo không tìm thấy `demo.hex`, dùng luồng command line ở bước 3 để đảm bảo working directory; không tiếp tục nạp một build thiếu ROM.

File `.gprj` liệt kê source/device/constraint; script Tcl là cấu hình build có top và tên output được đặt tường minh. Tên output khi build GUI có thể theo tên project.

## 5. Nạp và quan sát

1. Cắm board qua USB-C. Mở Gowin Programmer, chọn cable/debugger của Tang Nano 9K và Scan Device.
2. Chọn chip phát hiện được. Thêm `impl/pnr/riscv_pipeline.fs` ở mục bitstream.
3. Lần đầu chọn thao tác **SRAM Program** (tên hiển thị có thể kèm JTAG), rồi Program/Run. Cấu hình này mất khi rút nguồn.
4. Chương trình tự kiểm tra add, store/load, load-use và branch; nếu qua, LED hiển thị bộ đếm nhị phân 6 bit, bắt đầu từ 1, tăng khoảng mỗi 0,155 giây tại 27 MHz.
5. Nhấn S1 để chạy lại. Mỗi bit 1 trong giá trị LED bật một đèn; top đã đảo mức điện cho LED active-low. Giá trị 63 là cả sáu đèn sáng, xuất hiện bình thường khi đếm; nếu đứng mãi ở 63 thì chương trình đang ở nhánh `fail`.
6. Muốn tự chạy sau bật nguồn, chọn thao tác **External Flash Mode / exFlash Erase, Program** tương ứng cấu hình Programmer của board, chọn đúng flash được nhận diện rồi nạp cùng bitstream. Thao tác này thay nội dung cấu hình đang lưu trong flash. Tắt/bật nguồn để kiểm tra.

Repo cung cấp bitstream tạo được tại máy build trong `impl/` (không commit file sinh); chưa có xác nhận nạp/chạy vật lý. Không cần nối dây ngoài cho demo LED này.

## 6. Thay chương trình

Sửa `programs/demo.S`, assemble lại, chạy test của chương trình mới rồi build/nạp lại. ROM được nhúng trong bitstream; chỉ sửa `.hex` mà không build lại không đổi chương trình trên FPGA. Ghi LED bằng:

```asm
lui  x20, 0x10000
addi x1, x0, 21
sw   x1, 0(x20)     # 010101: bật LED 0, 2, 4
done: j done
```

Giới hạn demo: ROM 1 KiB, RAM 256 B. Không đọc RAM chưa khởi tạo. Địa chỉ `lw`/`sw` phải chia hết cho 4. Dùng bảng tập lệnh và quy tắc tại [architecture.md](architecture.md).
