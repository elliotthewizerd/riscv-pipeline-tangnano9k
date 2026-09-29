# Kiến trúc và tín hiệu

## Pipeline

| Tầng | Khối và công việc | Thanh ghi cuối tầng |
|---|---|---|
| IF / F | PC, `imem`, PC+4, mux chọn PC | `if_id` |
| ID / D | `control_unit`, `regfile`, `extend` | `id_ex` |
| EX / E | forwarding mux, ALU, so sánh branch, tính target | `ex_mem` |
| MEM / M | `dmem`, MMIO LED | `mem_wb` |
| WB / W | mux ALU/RD/PC4, ghi `regfile` | — |

`riscv_core.v` nối datapath. `soc.v` nối `imem`, `dmem` và thanh ghi LED. `tangnano9k_top.v` đồng bộ reset và đảo mức LED. Tất cả state của CPU dùng cùng `clk`; không dùng clock chia bằng logic. `ce=0` giữ toàn bộ pipeline, chặn ghi RAM/thanh ghi/LED; top của board luôn nối `ce=1`.

Các thanh ghi pipeline mang theo valid bit. Bubble có valid=0 nên không ghi register, không ghi memory và không chuyển hướng PC. `RetV`, `RetPC`, `RetWE`, `RetRd`, `RetWD` là cổng trace cho mô phỏng, không đưa ra pin FPGA. Store ghi ở MEM, trước khi lệnh đó được báo hoàn tất ở WB.

## Tên ngắn

| Tên | Ý nghĩa |
|---|---|
| `RegW` | Cho phép ghi regfile |
| `MemW` | Cho phép ghi dmem/MMIO |
| `ResSrc[1:0]` | `00`: ALU, `01`: RD, `10`: PC+4 |
| `ALUSrc` | Chọn B của ALU: `0`=BE, `1`=Imm |
| `ASrc` | Chọn A của ALU: `0`=AE, `1`=PC (auipc) |
| `ALUOp[3:0]` | Mã phép tính ALU |
| `ImmSrc[2:0]` | `0`=I, `1`=S, `2`=B, `3`=J, `4`=U |
| `Br`, `Jmp`, `Jr` | Branch, jump, chọn target kiểu jalr |
| `Use1`, `Use2` | Lệnh thực sự đọc rs1/rs2 |
| `PCSrcE` | Đổi PC sang target tính ở EX |
| `FwdAE`, `FwdBE` | `00`: RD từ ID/EX; `01`: ResultW; `10`: FwdM |
| `StallF/D` | Giữ PC và IF/ID |
| `FlushD/E` | Xóa IF/ID và ID/EX |
| `A`, `WD`, `RD`, `WE` | Địa chỉ, dữ liệu ghi, dữ liệu đọc, cho phép ghi |

Hậu tố F/D/E/M/W chỉ tầng. `ALUOp`: 0 add, 1 sub, 2 and, 3 or, 4 xor, 5 sll, 6 srl, 7 sra, 8 slt, 9 sltu, 10 pass B. `PC4` là PC+4. Bus `C` trong các thanh ghi pipeline gói các bit điều khiển; thứ tự pack/unpack nằm cạnh nhau trong `riscv_core.v`.

## Forwarding

Hai mux forwarding đặt **trước** mux chọn immediate. Vì vậy BE vừa đi vào ALU (khi cần), vừa là dữ liệu `sw`, vừa đi tới bộ so sánh branch. AE còn dùng làm base của `jalr`. Khi hai lệnh ở M và W cùng ghi một thanh ghi, M mới hơn nên ưu tiên M. x0 không tạo dependency. `FwdM` dùng PC4M cho `jal`/`jalr`, ALUM cho các lệnh ALU; load chưa có dữ liệu hợp lệ ở đầu MEM nên không được forward ALUM như dữ liệu load.

`regfile` có bypass riêng WB→ID khi đọc và ghi cùng địa chỉ trong một chu kỳ. Điều này xử lý trường hợp consumer cách producer ba lệnh mà EX forwarding không còn thấy producer.

## Stall load-use

```text
lwStall = LoadE & (RdE != 0) &
          ((Use1D & Rs1D == RdE) | (Use2D & Rs2D == RdE))
StallF = StallD = lwStall & !PCSrcE
FlushE = lwStall | PCSrcE
FlushD = PCSrcE
```

`Use1/Use2` tránh stall sai vì bit immediate trùng số thanh ghi. `lw x0,...` không gây stall. Thiết kế dùng một stall cho cả `lw→sw` khi phụ thuộc dữ liệu store; không có tối ưu forwarding riêng WB→MEM.

| Lệnh | C1 | C2 | C3 | C4 | C5 | C6 | C7 |
|---|---|---|---|---|---|---|---|
| `lw x5,0(x1)` | IF | ID | EX | MEM | WB | | |
| `add x6,x5,x2` | | IF | ID | ID giữ | EX (WB→EX) | MEM | WB |
| Bubble | | | | EX | MEM | WB | |

## Control hazard

Mặc định fetch PC+4 (predict not taken). EX dùng AE/BE sau forwarding để quyết định branch. `PCSrcE = VE & (JmpE | (BrE & TakeE))`. Branch taken hoặc jump cập nhật PC và flush hai lệnh trẻ hơn tại IF, ID: penalty 2 chu kỳ. Branch not taken không flush. Redirect được ưu tiên hơn stall của lệnh sắp bị hủy. Không có delay slot.

| Tình huống | PC kế tiếp | IF/ID | ID/EX |
|---|---|---|---|
| Bình thường | PC+4 | Nhận lệnh | Nhận lệnh |
| Load-use | Giữ PC | Giữ lệnh | Bubble |
| Taken branch / jump | TargetE | Bubble | Bubble |
| `rst=1` | 0 | Bubble | Bubble |

Branch có target `PCE + ImmE`; `jal` cũng vậy. `jalr` có target `(AE + ImmE) & ~1`. Phần mềm phải dùng địa chỉ lệnh chia hết cho 4 vì lõi không hỗ trợ compressed instruction hay trap misalignment.

## Đường đi của sáu nhóm lệnh

| Lệnh | ID | EX | MEM | WB |
|---|---|---|---|---|
| `lw rd,off(rs1)` | RD1, Imm I | AE+Imm | Đọc dmem tại ALUM | RD→rd |
| `sw rs2,off(rs1)` | RD1/RD2, Imm S | AE+Imm; BE→WD | Ghi WD tại ALUM | Không ghi |
| `j label` | Imm J, rd=x0 | PCE+Imm; flush D/E | Không truy cập | PC4 bị x0 loại bỏ |
| `beq/bne/blt/bge/bltu/bgeu` | RD1/RD2, Imm B | So sánh AE/BE, tính PCE+Imm | Không truy cập | Không ghi |
| `add rd,rs1,rs2` | RD1/RD2 | AE+BE | Truyền ALU | ALU→rd |
| `addi rd,rs1,imm` | RD1, Imm I | AE+Imm | Truyền ALU | ALU→rd |

## Bộ nhớ và giới hạn

Harvard: `imem` và `dmem` độc lập, cùng địa chỉ số nhưng khác không gian. Không có structural hazard tranh cổng giữa fetch và load/store.

| Vùng | Địa chỉ byte | Quy tắc |
|---|---|---|
| imem | `0x00000000..0x000003ff` | 256 word, khởi tạo từ hex, PC bắt đầu ở 0 |
| dmem | `0x00000000..0x000000ff` | 64 word, phần mềm ghi trước khi đọc |
| LED | `0x10000000` | bits [5:0]; bit 1 nghĩa LED sáng |

RTL memory có giao diện đọc tổ hợp, ghi ở cạnh lên. Không tự thêm thanh ghi đọc BSRAM vào RTL: làm vậy sẽ thay đổi latency và cần sửa pipeline/hazard. Gowin có thể hấp thụ thanh ghi pipeline liền kề khi ánh xạ memory; phải giữ nguyên hành vi quan sát được.

RAM không bị xóa bởi reset để tránh chi phí reset toàn mảng và giữ khả năng suy diễn RAM. Register x1..x31 được xóa khi reset, x0 luôn 0. Nạp cấu hình khởi tạo ROM; reset nút nhấn chạy lại chương trình từ đầu. `demo.S` tự ghi dữ liệu trước khi load.

Load/store ngoài vùng RAM hoặc không aligned: RAM trả 0/bỏ ghi; riêng địa chỉ LED do SoC xử lý. Fetch sai alignment hoặc ngoài ROM trả NOP. Encoding không hỗ trợ bị bỏ như bubble và không có side effect. Đây là quy ước của lõi học tập, **không phải cơ chế exception theo chuẩn RISC-V**. Không dùng lõi này để chạy một binary RV32I bất kỳ mà chưa kiểm tra tập lệnh và memory map.
