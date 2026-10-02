`timescale 1ns/1ps
// Tạo immediate 32 bit ở ID từ các bit rời trong Instr.
// ImmSrc: 0=I, 1=S, 2=B, 3=J, 4=U.
// Với I/S/B/J, lặp bit dấu Instr[31] để giữ đúng số âm khi mở rộng.
// Immediate B/J đã có bit 0 bằng 0; bộ cộng đích không dịch thêm.
module extend(
  input [31:0] Instr,
  input [2:0] ImmSrc,
  output reg [31:0] Imm
);
  always @* begin
    case (ImmSrc)
      // I: imm[11:0] nằm liên tiếp ở Instr[31:20] (ADDI, LW, JALR).
      3'd0: Imm = {{20{Instr[31]}}, Instr[31:20]};  // I
      // S: ghép imm[11:5] và imm[4:0] (SW).
      3'd1: Imm = {{20{Instr[31]}}, Instr[31:25], Instr[11:7]};  // S
      // B: imm[12|11|10:5|4:1|0], bit 0 ngầm định bằng 0.
      3'd2: Imm = {{19{Instr[31]}}, Instr[31], Instr[7], Instr[30:25], Instr[11:8], 1'b0};
      // J: imm[20|19:12|11|10:1|0], bit 0 ngầm định bằng 0.
      3'd3: Imm = {{11{Instr[31]}}, Instr[31], Instr[19:12], Instr[20], Instr[30:21], 1'b0};
      // U: đặt 20 bit immediate ở phần cao, 12 bit thấp bằng 0.
      3'd4: Imm = {Instr[31:12], 12'b0};  // U
      default: Imm = 0;
    endcase
  end
endmodule
