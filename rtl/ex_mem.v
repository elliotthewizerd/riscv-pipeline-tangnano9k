`timescale 1ns/1ps
module ex_mem(input clk, rst, en, input [4:0] CIn,
    input [31:0] ALUIn, WDIn, PC4In, PCIn, input [4:0] RdIn,
    output reg [4:0] C, output reg [31:0] ALU, WD, PC4, PC, output reg [4:0] Rd);
    always @(posedge clk) begin
        if (rst) begin C<=0; ALU<=0; WD<=0; PC4<=0; PC<=0; Rd<=0; end
        else if (en) begin C<=CIn; ALU<=ALUIn; WD<=WDIn; PC4<=PC4In; PC<=PCIn; Rd<=RdIn; end
    end
endmodule
