`timescale 1ns/1ps
// Thanh ghi pipeline IF -> ID: giữ Instr, PC và PC+4 của cùng một lệnh.
// V đánh dấu lệnh hợp lệ; V=0 biểu thị bubble (ô trống trong pipeline).
// rst/clr được xét tại cạnh lên và ưu tiên hơn en.
// en=0 giữ lệnh ở ID khi load-use stall; clr=1 hủy lệnh khi redirect.
module if_id(
  input clk,
  rst,
  en,
  clr,
  input VIn,
  input [31:0] InstrIn,
  PCIn,
  PC4In,
  output reg V,
  output reg [31:0] Instr,
  PC,
  PC4
);
  always @(posedge clk) begin
    // 0x00000013 là NOP (addi x0,x0,0); V=0 mới là dấu hiệu bubble.
    if (rst || clr) begin V <= 0; Instr <= 32'h13; PC <= 0; PC4 <= 0; end
    else if (en) begin V <= VIn; Instr <= InstrIn; PC <= PCIn; PC4 <= PC4In; end
  end
endmodule
