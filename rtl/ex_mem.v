`timescale 1ns/1ps
// Thanh ghi pipeline EX -> MEM, chốt tại cạnh lên khi en=1.
// ALU: kết quả tính toán/địa chỉ; WD: dữ liệu rs2 đã forward cho sw.
// PC4: địa chỉ trả về của JAL/JALR; PC: theo lệnh để xuất trace; Rd: đích.
// Bus C[4:0] = {V, RegW, MemW, ResSrc[1:0]}.
// rst đồng bộ ưu tiên hơn en; en=0 giữ nguyên mọi trường.
// Không flush tầng này khi branch ở EX: lệnh branch và các lệnh già
// hơn vẫn đi tiếp; chỉ các lệnh trẻ hơn ở IF/ID bị hủy.
module ex_mem(
  input clk,
  rst,
  en,
  input [4:0] CIn,
  input [31:0] ALUIn,
  WDIn,
  PC4In,
  PCIn,
  input [4:0] RdIn,
  output reg [4:0] C,
  output reg [31:0] ALU,
  WD,
  PC4,
  PC,
  output reg [4:0] Rd
);
  always @(posedge clk) begin
    if (rst) begin C <= 0; ALU <= 0; WD <= 0; PC4 <= 0; PC <= 0; Rd <= 0; end
    else if (en) begin
      C <= CIn;
      ALU <= ALUIn;
      WD <= WDIn;
      PC4 <= PC4In;
      PC <= PCIn;
      Rd <= RdIn;
    end
  end
endmodule
