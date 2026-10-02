`timescale 1ns/1ps
// Mux tổ hợp 2 ngõ, mỗi ngõ rộng W bit: S=0 chọn D0, S=1 chọn D1.
// Dùng cho PC kế tiếp và chọn toán hạng ALU; không lưu trạng thái.
module mux2 #(parameter W = 32)(input [W-1:0] D0, D1, input S, output [W-1:0] Y);
  assign Y = S ? D1 : D0;
endmodule
