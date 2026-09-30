`timescale 1ns/1ps
module mux3 #(parameter W = 32)(input [W-1:0] D0, D1, D2, input [1:0] S, output [W-1:0] Y);
  assign Y = S == 2'b10 ? D2 : S == 2'b01 ? D1 : D0;
endmodule
