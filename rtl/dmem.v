`timescale 1ns/1ps
module dmem #(parameter WORDS = 64)(input clk, WE, input [31:0] A, WD, output [31:0] RD);
  reg [31:0] mem [0:WORDS-1];
  wire hit = A[31:2] < WORDS && A[1:0] == 0;
  // RAM is intentionally not reset. Software must initialize before reading.
  always @(posedge clk) if (WE && hit) mem[A[31:2]] <= WD;
  assign RD = hit ? mem[A[31:2]] : 32'b0;
endmodule
