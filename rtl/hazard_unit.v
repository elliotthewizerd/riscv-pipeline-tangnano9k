`timescale 1ns/1ps
// Mạch tổ hợp xử lý phụ thuộc dữ liệu và hủy lệnh sai đường.
// Hậu tố D/E/M/W là ID/EX/MEM/WB; Rs1/Rs2 là nguồn, Rd là đích.
// Use1/Use2 cho biết lệnh có dùng nguồn đó; RegWM/WW là quyền ghi
// của lệnh hợp lệ tại MEM/WB. LoadE/LoadM đánh dấu lệnh load.
// FwdAE/BE: 00=RD gốc ở EX, 01=ResultW, 10=FwdM.
// StallF/D giữ PC và IF/ID; FlushD/E xóa IF/ID và ID/EX.
// PCSrcE=1 báo EX đã quyết định đổi hướng PC.
module hazard_unit(
  input [4:0] Rs1D,
  Rs2D,
  Rs1E,
  Rs2E,
  RdE,
  RdM,
  RdW,
  input Use1D,
  Use2D,
  Use1E,
  Use2E,
  RegWM,
  RegWW,
  LoadE,
  LoadM,
  PCSrcE,
  output reg [1:0] FwdAE,
  FwdBE,
  output StallF,
  StallD,
  FlushD,
  FlushE
);
  // Load ở EX chưa có dữ liệu cho lệnh ngay sau ở ID: giữ IF/ID
  // một chu kỳ và chèn bubble vào EX; load vẫn tiến sang MEM.
  // Bỏ x0 và nguồn không dùng để tránh stall do trùng bit immediate.
  wire lwStall = LoadE && RdE != 0 &&
          ((Use1D && Rs1D == RdE) || (Use2D && Rs2D == RdE));
  // Redirect ưu tiên hơn stall vì lệnh ID đang phụ thuộc sẽ bị hủy.
  assign StallF = lwStall && !PCSrcE;
  assign StallD = lwStall && !PCSrcE;
  // Redirect hủy lệnh trẻ hơn ở cả IF/ID; load-use chỉ xóa ID/EX.
  assign FlushD = PCSrcE;
  assign FlushE = lwStall || PCSrcE;
  always @* begin
    FwdAE = 0; FwdBE = 0;
    // MEM chứa kết quả mới hơn WB nên được ưu tiên nếu cùng rd.
    // Nếu MEM là load thì chưa forward được: cũng không lấy bản cũ
    // của cùng rd ở WB. Stall trước đó cho phép chờ dữ liệu đến WB.
    if (Use1E && Rs1E != 0) begin
      if (RegWM && RdM == Rs1E) begin
        if (!LoadM) FwdAE = 2;
      end else if (RegWW && RdW == Rs1E) FwdAE = 1;
    end
    // Cùng quy tắc cho rs2; BE còn dùng cho store và so sánh branch.
    if (Use2E && Rs2E != 0) begin
      if (RegWM && RdM == Rs2E) begin
        if (!LoadM) FwdBE = 2;
      end else if (RegWW && RdW == Rs2E) FwdBE = 1;
    end
  end
endmodule
