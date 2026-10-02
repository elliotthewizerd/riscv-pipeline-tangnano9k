`timescale 1ns/1ps
// So sánh branch ở EX bằng A/B sau forwarding, trước mux immediate.
// F3 là funct3 của lệnh branch. Take=1 khi điều kiện so sánh đúng;
// core còn kết hợp Take với BrE và VE mới cho phép đổi PC.
module branch_unit(
  input [31:0] A,
  B,
  input [2:0] F3,
  output reg Take
);
  always @* begin
    case (F3)
      // BEQ/BNE: bằng nhau/khác nhau.
      3'b000: Take = A == B;
      3'b001: Take = A != B;
      // BLT/BGE: so sánh số có dấu (bit 31 là dấu).
      3'b100: Take = $signed(A) < $signed(B);
      3'b101: Take = $signed(A) >= $signed(B);
      // BLTU/BGEU: so sánh không dấu, toàn bộ 32 bit là độ lớn.
      3'b110: Take = A < B;
      3'b111: Take = A >= B;
      default: Take = 0;
    endcase
  end
endmodule
