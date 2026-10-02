`timescale 1ns/1ps
// ALU tổ hợp ở tầng EX. A/B là toán hạng đã được chọn qua các mux;
// ALUOp do control_unit giải mã ở ID rồi đi qua thanh ghi ID/EX.
// Mã ALUOp: 0 ADD, 1 SUB, 2 AND, 3 OR, 4 XOR, 5 SLL,
//           6 SRL, 7 SRA, 8 SLT, 9 SLTU, 10 lấy B (LUI).
// "output reg" cho phép gán Y trong always; always @* vẫn tạo mạch
// tổ hợp, không tạo thanh ghi clock. So sánh branch nằm ở branch_unit.
module alu(
  input [31:0] A,
  B,
  input [3:0] ALUOp,
  output reg [31:0] Y
);
  // Gán Y ở mọi nhánh, kể cả default, để tránh suy ra latch.
  always @* begin
    case (ALUOp)
      4'd0: Y = A + B;
      4'd1: Y = A - B;
      4'd2: Y = A & B;
      4'd3: Y = A | B;
      4'd4: Y = A ^ B;
      // RV32 chỉ dùng 5 bit thấp của B làm số bit dịch (0..31).
      4'd5: Y = A << B[4:0];
      4'd6: Y = A >> B[4:0];
      // Ép A thành số có dấu để >>> điền bit dấu thay vì điền 0.
      4'd7: Y = $signed(A) >>> B[4:0];
      // SLT/SLTU chỉ đặt bit 0 của Y; 31 bit còn lại bằng 0.
      4'd8: Y = {31'b0, $signed(A) < $signed(B)};
      4'd9: Y = {31'b0, A < B};
      // LUI ghi nguyên immediate U, không cần cộng với nguồn A.
      4'd10: Y = B;
      default: Y = 0;
    endcase
  end
endmodule
