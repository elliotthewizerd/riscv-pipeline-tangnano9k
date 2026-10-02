`timescale 1ns/1ps
// Thanh ghi PC: Q là PC hiện tại, D là PC kế tiếp do mux PC chọn.
// Reset đồng bộ ở cạnh lên đưa PC về 0. en=0 giữ nguyên PC;
// core đặt en=ce && !StallF để dừng fetch khi pause hoặc load-use.
module pc_reg(
  input clk,
  rst,
  en,
  input [31:0] D,
  output reg [31:0] Q
);
  always @(posedge clk) begin
    if (rst) Q <= 0;
    else if (en) Q <= D;
  end
endmodule
