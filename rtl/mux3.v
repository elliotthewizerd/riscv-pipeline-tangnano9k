`timescale 1ns/1ps
// Mux tổ hợp 3 ngõ rộng W bit: S=00 chọn D0, 01 chọn D1, 10 chọn D2.
// Mã 11 cũng trả D0 theo biểu thức dưới, không phải ngõ dữ liệu thứ tư.
// Forwarding: D0=RD ở EX, D1=ResultW, D2=FwdM.
// Writeback:  D0=ALU, D1=dữ liệu load, D2=PC+4.
module mux3 #(parameter W = 32)(input [W-1:0] D0, D1, D2, input [1:0] S, output [W-1:0] Y);
  assign Y = S == 2'b10 ? D2 : S == 2'b01 ? D1 : D0;
endmodule
