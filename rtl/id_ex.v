`timescale 1ns/1ps
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
