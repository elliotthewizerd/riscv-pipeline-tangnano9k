`timescale 1ns/1ps
// ROM lệnh đọc tổ hợp: A là PC tính theo byte, RD là mã lệnh 32 bit.
// WORDS là số lệnh chứa được; INIT là đường dẫn file hex cho $readmemh.
// INIT rỗng cho phép testbench tự nạp chương trình vào mảng mem.
// Địa chỉ hợp lệ phải chia hết cho 4 và nằm trong dung lượng ROM.
module imem #(parameter WORDS = 256, parameter INIT = "")
       (input [31:0] A, output [31:0] RD);
  reg [31:0] mem [0:WORDS-1];
  integer i;
  initial begin
    // Lấp chỗ chưa nạp bằng NOP để fetch vượt cuối chương trình
    // không vô tình gặp lệnh ghi thanh ghi/bộ nhớ.
    for (i = 0; i<WORDS; i = i + 1) mem[i] = 32'h00000013;
    if (INIT != "") $readmemh(INIT, mem);
  end
  // Đọc tổ hợp cho IF nhận lệnh trong cùng chu kỳ; địa chỉ lỗi trả NOP.
  // Đổi sang bộ nhớ đọc đồng bộ sẽ cần điều chỉnh độ trễ pipeline.
  assign RD = (A[1:0] == 0 && A[31:2] < WORDS) ? mem[A[31:2]] : 32'h00000013;
endmodule
