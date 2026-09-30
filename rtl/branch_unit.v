`timescale 1ns/1ps
module branch_unit(
  input [31:0] A,
  B,
  input [2:0] F3,
  output reg Take
);
  always @* begin
    case (F3)
      3'b000: Take = A == B;
      3'b001: Take = A != B;
      3'b100: Take = $signed(A) < $signed(B);
      3'b101: Take = $signed(A) >= $signed(B);
      3'b110: Take = A < B;
      3'b111: Take = A >= B;
      default: Take = 0;
    endcase
  end
endmodule
