`timescale 1ns/1ps
module if_id(input clk, rst, en, clr, input VIn,
    input [31:0] InstrIn, PCIn, PC4In,
    output reg V, output reg [31:0] Instr, PC, PC4);
    always @(posedge clk) begin
        if (rst || clr) begin V<=0; Instr<=32'h13; PC<=0; PC4<=0; end
        else if (en) begin V<=VIn; Instr<=InstrIn; PC<=PCIn; PC4<=PC4In; end
    end
endmodule
