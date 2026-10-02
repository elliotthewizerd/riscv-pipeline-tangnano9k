`timescale 1ns/1ps
// 32 thanh ghi 32 bit, hai cổng đọc tổ hợp và một cổng ghi cạnh lên.
// A1/A2: rs1/rs2 ở ID; RD1/RD2: dữ liệu đọc.
// A3: rd ở WB; WD: dữ liệu ghi; WE: cho phép ghi.
// rst đồng bộ đưa toàn bộ về 0. x0 luôn đọc 0 và không nhận phép ghi.
module regfile(
  input clk,
  rst,
  WE,
  input [4:0] A1,
  A2,
  A3,
  input [31:0] WD,
  output [31:0] RD1,
  RD2
);
  reg [31:0] regs [0:31];
  integer i;
  always @(posedge clk) begin
    if (rst) begin
      for (i = 0; i<32; i = i + 1) regs[i] <= 0;
    end else if (WE && A3 != 0) regs[A3] <= WD;
  end
  // WB -> ID bypass: khi địa chỉ đọc trùng địa chỉ đang ghi,
  // trả thẳng WD thay vì giá trị cũ trong mảng regs trước cạnh clock.
  // Ưu tiên A1/A2=0 để x0 luôn bằng 0, kể cả khi A3 cũng bằng 0.
  assign RD1 = A1 == 0 ? 0 : WE && A3 == A1 ? WD : regs[A1];
  assign RD2 = A2 == 0 ? 0 : WE && A3 == A2 ? WD : regs[A2];
endmodule
