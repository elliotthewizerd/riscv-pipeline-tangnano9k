`timescale 1ns/1ps
module mem_wb(input clk, rst, en, input [3:0] CIn,
    input [31:0] ALUIn, RDIn, PC4In, PCIn, input [4:0] RdIn,
    output reg [3:0] C, output reg [31:0] ALU, RD, PC4, PC, output reg [4:0] Rd);
    always @(posedge clk) begin
        if (rst) begin C<=0; ALU<=0; RD<=0; PC4<=0; PC<=0; Rd<=0; end
        else if (en) begin C<=CIn; ALU<=ALUIn; RD<=RDIn; PC4<=PC4In; PC<=PCIn; Rd<=RdIn; end
    end
endmodule
