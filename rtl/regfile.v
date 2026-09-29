`timescale 1ns/1ps
module regfile(input clk, rst, WE, input [4:0] A1, A2, A3,
               input [31:0] WD, output [31:0] RD1, RD2);
    reg [31:0] regs [0:31];
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i=0; i<32; i=i+1) regs[i] <= 0;
        end else if (WE && A3 != 0) regs[A3] <= WD;
    end
    // Explicit WB -> ID bypass: defined behavior on a simultaneous read/write.
    assign RD1 = A1 == 0 ? 0 : WE && A3 == A1 ? WD : regs[A1];
    assign RD2 = A2 == 0 ? 0 : WE && A3 == A2 ? WD : regs[A2];
endmodule
