`timescale 1ns/1ps
module alu(input [31:0] A, B, input [3:0] ALUOp, output reg [31:0] Y);
    always @* begin
        case (ALUOp)
            4'd0: Y = A + B;
            4'd1: Y = A - B;
            4'd2: Y = A & B;
            4'd3: Y = A | B;
            4'd4: Y = A ^ B;
            4'd5: Y = A << B[4:0];
            4'd6: Y = A >> B[4:0];
            4'd7: Y = $signed(A) >>> B[4:0];
            4'd8: Y = {31'b0, $signed(A) < $signed(B)};
            4'd9: Y = {31'b0, A < B};
            4'd10: Y = B;
            default: Y = 0;
        endcase
    end
endmodule
