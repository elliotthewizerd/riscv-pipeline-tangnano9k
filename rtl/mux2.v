`timescale 1ns/1ps
module mux2 #(parameter W = 32)(input [W-1:0] D0, D1, input S, output [W-1:0] Y);
    assign Y = S ? D1 : D0;
endmodule
