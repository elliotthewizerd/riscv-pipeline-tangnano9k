`timescale 1ns/1ps
// Giải mã lệnh ở ID: Op=Instr[6:0], F3=Instr[14:12], F7=Instr[31:25].
// RegW/MemW: cho phép ghi thanh ghi/bộ nhớ khi lệnh đến WB/MEM.
// ALUSrc: chọn B của ALU, 0=rs2 đã forward, 1=immediate.
// ASrc: chọn A của ALU, 0=rs1 đã forward, 1=PC (AUIPC).
// Br: branch có điều kiện; Jmp: JAL hoặc JALR; Jr: chọn đích theo rs1.
// Use1/Use2: lệnh thực sự đọc rs1/rs2, dùng để phát hiện phụ thuộc.
// Legal: mã lệnh được hỗ trợ; core dùng nó để tạo bit valid ở EX.
// ResSrc: 0=ALU, 1=dmem, 2=PC+4 (giá trị ghi về rd).
// ImmSrc: 0=I, 1=S, 2=B, 3=J, 4=U; cách ghép bit nằm ở extend.v.
// ALUOp: mã phép toán 4 bit, xem bảng ở alu.v.
module control_unit(
  input [6:0] Op,
  F7,
  input [2:0] F3,
  output reg RegW,
  MemW,
  ALUSrc,
  ASrc,
  Br,
  Jmp,
  Jr,
  Use1,
  Use2,
  Legal,
  output reg [1:0] ResSrc,
  output reg [2:0] ImmSrc,
  output reg [3:0] ALUOp
);
  always @* begin
    // Đặt đủ giá trị mặc định cho mạch tổ hợp; từng opcode chỉ đổi
    // các tín hiệu cần dùng. ALUOp=0 mặc định là cộng, ImmSrc=0 là I.
    RegW = 0; MemW = 0; ALUSrc = 0; ASrc = 0; Br = 0; Jmp = 0; Jr = 0;
    Use1 = 0; Use2 = 0; Legal = 1; ResSrc = 0; ImmSrc = 0; ALUOp = 0;
    case (Op)
      // OP (R-type) dùng hai thanh ghi; OP-IMM dùng rs1 và immediate.
      7'b0110011, 7'b0010011: begin
        RegW = 1; Use1 = 1; Use2 = (Op == 7'b0110011); ALUSrc = (Op == 7'b0010011);
        case (F3)
          // ADD/ADDI dùng mã mặc định 0; SUB chỉ có ở R-type.
          // Với ADDI, F7 là một phần immediate nên không xét như funct7.
          3'b000: begin
            if (Use2 && F7 == 7'b0100000) ALUOp = 1;
            else if (Use2 && F7 != 0) Legal = 0;
          end
          3'b001: begin ALUOp = 5; if (F7 != 0) Legal = 0; end
          3'b010: ALUOp = 8;
          3'b011: ALUOp = 9;
          3'b100: ALUOp = 4;
          3'b101: begin
            ALUOp = F7 == 7'b0100000 ? 7 : 6;
            if (F7 != 0 && F7 != 7'b0100000) Legal = 0;
          end
          3'b110: ALUOp = 3;
          3'b111: ALUOp = 2;
        endcase
        // Loại các mã R-type chưa hỗ trợ (ví dụ extension M).
        if (Use2 && F3 != 0 && F3 != 5 && F7 != 0) Legal = 0;
      end
      // LW: ALU cộng rs1+imm; dữ liệu dmem được chọn khi về WB.
      7'b0000011: begin  // lw
        RegW = 1; ALUSrc = 1; ResSrc = 1; Use1 = 1; Legal = F3 == 3'b010;
      end
      // SW vẫn dùng rs2 làm dữ liệu ghi dù ngõ B của ALU chọn imm.
      7'b0100011: begin  // sw
        MemW = 1; ALUSrc = 1; ImmSrc = 1; Use1 = 1; Use2 = 1; Legal = F3 == 3'b010;
      end
      // Branch dùng cả hai nguồn và immediate B để tính PC đích.
      7'b1100011: begin  // so sánh ở EX sau forwarding
        Br = 1; ImmSrc = 2; Use1 = 1; Use2 = 1;
        Legal = F3 == 0 || F3 == 1 || F3 >= 4;
      end
      // JAL: đích PC+imm J, rd nhận PC+4; j là JAL với rd=x0.
      7'b1101111: begin RegW = 1; Jmp = 1; ResSrc = 2; ImmSrc = 3; end
      // JALR: đích rs1+imm I; core xóa bit 0 của địa chỉ đích.
      7'b1100111: begin
        RegW = 1; Jmp = 1; Jr = 1; ResSrc = 2; ALUSrc = 1; Use1 = 1; Legal = F3 == 0;
      end
      // LUI lấy nguyên imm U; AUIPC cộng PC của lệnh với imm U.
      7'b0110111: begin RegW = 1; ALUSrc = 1; ImmSrc = 4; ALUOp = 10; end
      7'b0010111: begin RegW = 1; ALUSrc = 1; ASrc = 1; ImmSrc = 4; end
      default: Legal = 0;
    endcase
    // Mã chưa hỗ trợ: vô hiệu hóa mọi tác động; core sẽ bỏ valid.
    // Thiết kế này không phát exception/trap cho illegal instruction.
    if (!Legal) begin
      RegW = 0; MemW = 0; Br = 0; Jmp = 0; Jr = 0; Use1 = 0; Use2 = 0;
    end
  end
endmodule
