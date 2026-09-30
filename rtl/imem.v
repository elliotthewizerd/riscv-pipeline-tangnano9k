`timescale 1ns/1ps
module imem #(parameter WORDS = 256, parameter INIT = "programs/demo.hex")
       (input [31:0] A, output [31:0] RD);
  reg [31:0] mem [0:WORDS-1];
  integer i;
  initial begin
    for (i = 0; i<WORDS; i = i + 1) mem[i] = 32'h00000013;
    if (INIT != "") $readmemh(INIT, mem);
  end
  // Small asynchronous ROM; changing to synchronous BSRAM changes the pipeline.
  assign RD = (A[1:0] == 0 && A[31:2] < WORDS) ? mem[A[31:2]] : 32'h00000013;
endmodule
