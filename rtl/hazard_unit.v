`timescale 1ns/1ps
module hazard_unit(
  input [4:0] Rs1D,
  Rs2D,
  Rs1E,
  Rs2E,
  RdE,
  RdM,
  RdW,
  input Use1D,
  Use2D,
  Use1E,
  Use2E,
  RegWM,
  RegWW,
  LoadE,
  LoadM,
  PCSrcE,
  output reg [1:0] FwdAE,
  FwdBE,
  output StallF,
  StallD,
  FlushD,
  FlushE
);
  wire lwStall = LoadE && RdE != 0 &&
          ((Use1D && Rs1D == RdE) || (Use2D && Rs2D == RdE));
  // A taken redirect kills D; it must override a dependency in that instruction.
  assign StallF = lwStall && !PCSrcE;
  assign StallD = lwStall && !PCSrcE;
  assign FlushD = PCSrcE;
  assign FlushE = lwStall || PCSrcE;
  always @* begin
    FwdAE = 0; FwdBE = 0;
    if (Use1E && Rs1E != 0) begin
      if (RegWM && RdM == Rs1E) begin
        if (!LoadM) FwdAE = 2;
      end else if (RegWW && RdW == Rs1E) FwdAE = 1;
    end
    if (Use2E && Rs2E != 0) begin
      if (RegWM && RdM == Rs2E) begin
        if (!LoadM) FwdBE = 2;
      end else if (RegWW && RdW == Rs2E) FwdBE = 1;
    end
  end
endmodule
