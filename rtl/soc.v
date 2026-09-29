`timescale 1ns/1ps
module soc #(parameter INIT="programs/demo.hex")
    (input clk, rst, ce, output reg [5:0] LED,
     output [31:0] PC, output StallF, FlushD);
    wire [31:0] Instr, A, WD, RD, RAMRD;
    wire WE;
    wire LEDHit=A==32'h10000000;
    imem #(.INIT(INIT)) rom(.A(PC), .RD(Instr));
    dmem ram(.clk(clk), .WE(WE), .A(A), .WD(WD), .RD(RAMRD));
    assign RD=LEDHit ? {26'b0,LED} : RAMRD;
    always @(posedge clk) begin
        if (rst) LED<=0;
        else if (WE && LEDHit) LED<=WD[5:0];
    end
    riscv_core cpu(.clk(clk), .rst(rst), .ce(ce), .PCA(PC), .Instr(Instr),
        .MemWE(WE), .MemA(A), .MemWD(WD), .MemRD(RD),
        .RetV(), .RetWE(), .RetPC(), .RetWD(), .RetRd(),
        .StallF(StallF), .StallD(), .FlushD(FlushD), .FlushE(), .FwdAE(), .FwdBE());
endmodule
