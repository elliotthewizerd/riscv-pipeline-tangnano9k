`timescale 1ns/1ps
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
