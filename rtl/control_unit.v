`timescale 1ns/1ps
module control_unit(input [6:0] Op, F7, input [2:0] F3,
    output reg RegW, MemW, ALUSrc, ASrc, Br, Jmp, Jr, Use1, Use2, Legal,
    output reg [1:0] ResSrc, output reg [2:0] ImmSrc, output reg [3:0] ALUOp);
    always @* begin
        RegW=0; MemW=0; ALUSrc=0; ASrc=0; Br=0; Jmp=0; Jr=0;
        Use1=0; Use2=0; Legal=1; ResSrc=0; ImmSrc=0; ALUOp=0;
        case (Op)
            7'b0110011, 7'b0010011: begin
                RegW=1; Use1=1; Use2=(Op==7'b0110011); ALUSrc=(Op==7'b0010011);
                case (F3)
                    3'b000: begin
                        if (Use2 && F7==7'b0100000) ALUOp=1;
                        else if (Use2 && F7!=0) Legal=0;
                    end
                    3'b001: begin ALUOp=5; if (F7!=0) Legal=0; end
                    3'b010: ALUOp=8;
                    3'b011: ALUOp=9;
                    3'b100: ALUOp=4;
                    3'b101: begin
                        ALUOp=F7==7'b0100000 ? 7 : 6;
                        if (F7!=0 && F7!=7'b0100000) Legal=0;
                    end
                    3'b110: ALUOp=3;
                    3'b111: ALUOp=2;
                endcase
                if (Use2 && F3!=0 && F3!=5 && F7!=0) Legal=0;
            end
            7'b0000011: begin // lw
                RegW=1; ALUSrc=1; ResSrc=1; Use1=1; Legal=F3==3'b010;
            end
            7'b0100011: begin // sw
                MemW=1; ALUSrc=1; ImmSrc=1; Use1=1; Use2=1; Legal=F3==3'b010;
            end
            7'b1100011: begin // branches, compared in EX after forwarding
                Br=1; ImmSrc=2; Use1=1; Use2=1;
                Legal=F3==0 || F3==1 || F3>=4;
            end
            7'b1101111: begin RegW=1; Jmp=1; ResSrc=2; ImmSrc=3; end
            7'b1100111: begin
                RegW=1; Jmp=1; Jr=1; ResSrc=2; ALUSrc=1; Use1=1; Legal=F3==0;
            end
            7'b0110111: begin RegW=1; ALUSrc=1; ImmSrc=4; ALUOp=10; end
            7'b0010111: begin RegW=1; ALUSrc=1; ASrc=1; ImmSrc=4; end
            default: Legal=0;
        endcase
        // Unsupported encodings act as bubbles, never a register/memory write.
        if (!Legal) begin
            RegW=0; MemW=0; Br=0; Jmp=0; Jr=0; Use1=0; Use2=0;
        end
    end
endmodule
