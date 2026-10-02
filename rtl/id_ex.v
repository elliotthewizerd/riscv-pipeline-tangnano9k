`timescale 1ns/1ps
// Thanh ghi pipeline ID -> EX. Các ngõ ...In nhận dữ liệu ở ID;
// ngõ ra giữ dữ liệu cho EX đến cạnh clock tiếp theo được cho phép.
// RD1/RD2: giá trị đọc từ regfile, chưa qua mux forwarding ở EX.
// PC/PC4/Imm: PC của lệnh, PC+4, immediate đã extend.
// Rs1/Rs2/Rd: chỉ số thanh ghi cho hazard/ghi về; F3: loại branch.
// Bus điều khiển C[15:0] (được đóng/gỡ gói trong riscv_core.v):
//   [15] V, [14] RegW, [13] MemW, [12] ALUSrc, [11] ASrc,
//   [10] Br, [9] Jmp, [8] Jr, [7] Use1, [6] Use2,
//   [5:4] ResSrc, [3:0] ALUOp.
// rst/clr đồng bộ, ưu tiên hơn en; en=0 giữ nguyên thanh ghi.
module id_ex(
  input clk,
  rst,
  en,
  clr,
  input [15:0] CIn,
  input [31:0] RD1In,
  RD2In,
  PCIn,
  PC4In,
  ImmIn,
  input [4:0] Rs1In,
  Rs2In,
  RdIn,
  input [2:0] F3In,
  output reg [15:0] C,
  output reg [31:0] RD1,
  RD2,
  PC,
  PC4,
  Imm,
  output reg [4:0] Rs1,
  Rs2,
  Rd,
  output reg [2:0] F3
);
  always @(posedge clk) begin
    // Xóa C làm V, RegW, MemW, Br/Jmp bằng 0: bubble không gây
    // tác động. Load-use và redirect đều có thể yêu cầu clr.
    if (rst || clr) begin
      C <= 0;
      RD1 <= 0;
      RD2 <= 0;
      PC <= 0;
      PC4 <= 0;
      Imm <= 0;
      Rs1 <= 0;
      Rs2 <= 0;
      Rd <= 0;
      F3 <= 0;
    end else if (en) begin
      C <= CIn; RD1 <= RD1In; RD2 <= RD2In; PC <= PCIn; PC4 <= PC4In; Imm <= ImmIn;
      Rs1 <= Rs1In;
      Rs2 <= Rs2In;
      Rd <= RdIn;
      F3 <= F3In;
    end
  end
endmodule
