`timescale 1ns/1ps
// Bộ cộng tổ hợp 32 bit: Y = A + B, chỉ giữ 32 bit thấp.
// Core dùng hai instance để tính PC+4 và địa chỉ đích branch/jump.
module adder(
  input [31:0] A,
  B,
  output [31:0] Y
);
  assign Y = A + B;
endmodule
