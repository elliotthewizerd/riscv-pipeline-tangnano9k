`timescale 1ns/1ps
// Bộ nhớ dữ liệu dùng cho lw/sw: WORDS từ, mỗi từ 32 bit.
// A là địa chỉ BYTE; A[31:2] chọn từ, A[1:0] phải bằng 0.
// WE=1 ghi WD ở cạnh lên; RD đọc tổ hợp từ địa chỉ A.
// Ngoài vùng hoặc lệch hàng: đọc trả 0, ghi bị bỏ qua; không phát trap.
module dmem #(parameter WORDS = 64)(input clk, WE, input [31:0] A, WD, output [31:0] RD);
  reg [31:0] mem [0:WORDS-1];
  // Bỏ hai bit địa chỉ byte thấp để đổi sang chỉ số từ 32 bit.
  wire hit = A[31:2] < WORDS && A[1:0] == 0;
  // RAM không reset: ô chưa ghi có thể là X trong mô phỏng.
  // Chương trình cần khởi tạo bằng SW trước khi LW từ ô đó.
  always @(posedge clk) if (WE && hit) mem[A[31:2]] <= WD;
  assign RD = hit ? mem[A[31:2]] : 32'b0;
endmodule
