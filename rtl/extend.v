`timescale 1ns/1ps
module extend(input [31:0] Instr, input [2:0] ImmSrc, output reg [31:0] Imm);
    always @* begin
        case (ImmSrc)
            3'd0: Imm = {{20{Instr[31]}}, Instr[31:20]}; // I
            3'd1: Imm = {{20{Instr[31]}}, Instr[31:25], Instr[11:7]}; // S
            3'd2: Imm = {{19{Instr[31]}}, Instr[31], Instr[7], Instr[30:25], Instr[11:8], 1'b0}; // B
            3'd3: Imm = {{11{Instr[31]}}, Instr[31], Instr[19:12], Instr[20], Instr[30:21], 1'b0}; // J
            3'd4: Imm = {Instr[31:12], 12'b0}; // U
            default: Imm = 0;
        endcase
    end
endmodule
