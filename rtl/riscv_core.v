`timescale 1ns/1ps
// Lõi pipeline 5 tầng: IF -> ID -> EX -> MEM -> WB.
// Hậu tố F/D/E/M/W chỉ tầng của tín hiệu; V là bit lệnh hợp lệ.
// clk/rst: clock và reset đồng bộ; ce=0 giữ toàn pipeline, chặn ghi.
// PCA/Instr nối imem; MemA/MemWD/MemRD/MemWE nối dmem ở testbench.
// RetV: có lệnh hoàn tất ở WB; RetWE: lệnh đó thực sự ghi rd khác x0.
// RetPC/RetRd/RetWD phục vụ đối chiếu trace, không điều khiển datapath.
// Stall/Flush/Fwd được đưa ra ngoài để quan sát dạng sóng.
// Lưu ý tên: RegWE là RegW ở EX, MemWEc là MemW ở EX;
// MemWE là cổng cho phép ghi dmem, MemWD là DỮ LIỆU ghi dmem.
module riscv_core(
  input clk,
  rst,
  ce,
  output [31:0] PCA,
  input [31:0] Instr,
  output MemWE,
  output [31:0] MemA,
  MemWD,
  input [31:0] MemRD,
  output RetV,
  RetWE,
  output [31:0] RetPC,
  RetWD,
  output [4:0] RetRd,
  output StallF,
  StallD,
  FlushD,
  FlushE,
  output [1:0] FwdAE,
  FwdBE
);
  // IF/ID: giữ PC, mã lệnh và các giá trị được giải mã ở ID.
  wire [31:0] PCF, PC4F, PCNext, InstrD, PCD, PC4D, RD1D, RD2D, ImmD;
  wire VD, RegWD, MemWDc, ALUSrcD, ASrcD, BrD, JmpD, JrD, Use1D, Use2D, LegalD;
  wire [1:0] ResSrcD;
  wire [2:0] ImmSrcD;
  wire [3:0] ALUOpD;
  wire [4:0] Rs1D = InstrD[19:15], Rs2D = InstrD[24:20], RdD = InstrD[11:7];
  // CE/CM/CW là bus điều khiển theo tầng; CE khác với clock-enable ce.
  wire [15:0] CE;
  wire VE, RegWE, MemWEc, ALUSrcE, ASrcE, BrE, JmpE, JrE, Use1E, Use2E;
  wire [1:0] ResSrcE;
  wire [3:0] ALUOpE;
  wire [31:0] RD1E, RD2E, PCE, PC4E, ImmE, AE, BE, SrcAE, SrcBE, ALUE;
  wire [31:0] TargetBase, TargetSum, TargetE;
  wire [4:0] Rs1E, Rs2E, RdE;
  wire [2:0] F3E;
  wire TakeE, PCSrcE;
  // MEM: địa chỉ ALU, dữ liệu store và điều khiển của cùng một lệnh.
  wire [4:0] CM;
  wire VM, RegWM, MemWM;
  wire [1:0] ResSrcM;
  wire [31:0] ALUM, WDM, PC4M, PCM, FwdM;
  wire [4:0] RdM;
  // WB: ba ứng viên kết quả cùng PC/rd để ghi regfile và xuất trace.
  wire [3:0] CW;
  wire VW, RegWW;
  wire [1:0] ResSrcW;
  wire [31:0] ALUW, RDW, PC4W, PCW, ResultW;
  wire [4:0] RdW;
  // ResSrc=1 nhận diện load; bit valid chặn tác động của bubble.
  wire LoadE = VE && RegWE && ResSrcE == 1;
  wire LoadM = VM && RegWM && ResSrcM == 1;

  // IF: thường tăng PC thêm 4; branch/jump ở EX có thể chọn TargetE.
  assign PCA = PCF;
  pc_reg pc(.clk(clk), .rst(rst), .en(ce && !StallF), .D(PCNext), .Q(PCF));
  adder plus4(.A(PCF), .B(32'd4), .Y(PC4F));
  mux2 pc_mux(.D0(PC4F), .D1(TargetE), .S(PCSrcE), .Y(PCNext));
  // IF/ID giữ khi stall, xóa khi redirect; ce=0 giữ cả yêu cầu flush
  // đến lúc pipeline tiếp tục, tránh làm mất lệnh đang pause.
  if_id fd(.clk(clk), .rst(rst), .en(ce && !StallD), .clr(ce && FlushD),
    .VIn(1'b1), .InstrIn(Instr), .PCIn(PCF), .PC4In(PC4F),
    .V(VD), .Instr(InstrD), .PC(PCD), .PC4(PC4D));
  // ID: giải mã, đọc regfile và ghép immediate.
  control_unit cu(.Op(InstrD[6:0]), .F7(InstrD[31:25]), .F3(InstrD[14:12]),
    .RegW(RegWD), .MemW(MemWDc), .ALUSrc(ALUSrcD), .ASrc(ASrcD), .Br(BrD),
    .Jmp(JmpD), .Jr(JrD), .Use1(Use1D), .Use2(Use2D), .Legal(LegalD),
    .ResSrc(ResSrcD), .ImmSrc(ImmSrcD), .ALUOp(ALUOpD));
  // Chỉ ghi khi WB hợp lệ và ce=1; regfile tự bỏ phép ghi x0
  // và bypass dữ liệu WB sang cổng đọc ID trong cùng chu kỳ.
  regfile rf(.clk(clk), .rst(rst), .WE(ce && VW && RegWW && !rst),
    .A1(Rs1D), .A2(Rs2D), .A3(RdW), .WD(ResultW), .RD1(RD1D), .RD2(RD2D));
  extend ext(.Instr(InstrD), .ImmSrc(ImmSrcD), .Imm(ImmD));
  // ID/EX đóng gói control và dữ liệu. Xem id_ex.v để tra từng bit C.
  // LegalD=0 khiến lệnh không được hỗ trợ đi tiếp như bubble.
  id_ex de(.clk(clk), .rst(rst), .en(ce), .clr(ce && FlushE),
    .CIn({VD && LegalD, RegWD, MemWDc, ALUSrcD, ASrcD, BrD, JmpD, JrD,
       Use1D, Use2D, ResSrcD, ALUOpD}),
    .RD1In(RD1D), .RD2In(RD2D), .PCIn(PCD), .PC4In(PC4D), .ImmIn(ImmD),
    .Rs1In(Rs1D), .Rs2In(Rs2D), .RdIn(RdD), .F3In(InstrD[14:12]),
    .C(CE), .RD1(RD1E), .RD2(RD2E), .PC(PCE), .PC4(PC4E), .Imm(ImmE),
    .Rs1(Rs1E), .Rs2(Rs2E), .Rd(RdE), .F3(F3E));
  assign {VE, RegWE, MemWEc, ALUSrcE, ASrcE, BrE, JmpE, JrE,
      Use1E, Use2E, ResSrcE, ALUOpE} = CE;
  // EX: sửa toán hạng cũ bằng kết quả mới ở MEM/WB trước khi tính.
  // AE/BE là hai nguồn sau forwarding; SrcAE/SrcBE là ngõ vào ALU.
  mux3 fwd_a(.D0(RD1E), .D1(ResultW), .D2(FwdM), .S(FwdAE), .Y(AE));
  mux3 fwd_b(.D0(RD2E), .D1(ResultW), .D2(FwdM), .S(FwdBE), .Y(BE));
  // AUIPC chọn PC ở ngõ A; các lệnh immediate/load/store chọn ImmE
  // ở ngõ B. BE vẫn được giữ riêng làm dữ liệu store và nguồn branch.
  mux2 alu_a(.D0(AE), .D1(PCE), .S(ASrcE), .Y(SrcAE));
  mux2 alu_b(.D0(BE), .D1(ImmE), .S(ALUSrcE), .Y(SrcBE));
  alu alu_ex(.A(SrcAE), .B(SrcBE), .ALUOp(ALUOpE), .Y(ALUE));
  // So sánh branch bằng AE/BE, không dùng ngõ B đã chọn immediate.
  branch_unit bu(.A(AE), .B(BE), .F3(F3E), .Take(TakeE));
  // Đích branch/JAL = PCE+ImmE; JALR = (AE+ImmE) & ~1.
  mux2 target_mux(.D0(PCE), .D1(AE), .S(JrE), .Y(TargetBase));
  adder target_add(.A(TargetBase), .B(ImmE), .Y(TargetSum));
  assign TargetE = JrE ? {TargetSum[31:1],1'b0} : TargetSum;
  // Chỉ lệnh EX hợp lệ được đổi PC. PCSrcE đồng thời yêu cầu
  // hazard unit flush IF/ID và ID/EX để hủy hai lệnh sai đường.
  assign PCSrcE = VE && (JmpE || (BrE && TakeE));
  // EX/MEM: dữ liệu store lấy từ BE đã forward, không lấy SrcBE.
  ex_mem em(.clk(clk), .rst(rst), .en(ce), .CIn({VE,RegWE,MemWEc,ResSrcE}),
    .ALUIn(ALUE), .WDIn(BE), .PC4In(PC4E), .PCIn(PCE), .RdIn(RdE),
    .C(CM), .ALU(ALUM), .WD(WDM), .PC4(PC4M), .PC(PCM), .Rd(RdM));
  assign {VM,RegWM,MemWM,ResSrcM} = CM;
  // Giá trị đích của JAL/JALR là PC+4 nên đường forward chọn PC4M.
  // Nếu là load, hazard unit chặn FwdM vì dữ liệu load chưa đến WB.
  assign FwdM = ResSrcM == 2 ? PC4M : ALUM;
  // MEM: ce/rst/valid chặn ghi sai lúc pause/reset hoặc gặp bubble.
  assign MemWE = ce && VM && MemWM && !rst;
  assign MemA = ALUM;
  assign MemWD = WDM;
  // MEM/WB: chốt dữ liệu đọc tổ hợp từ dmem cùng kết quả ALU/PC+4.
  mem_wb mw(.clk(clk), .rst(rst), .en(ce), .CIn({VM,RegWM,ResSrcM}),
    .ALUIn(ALUM), .RDIn(MemRD), .PC4In(PC4M), .PCIn(PCM), .RdIn(RdM),
    .C(CW), .ALU(ALUW), .RD(RDW), .PC4(PC4W), .PC(PCW), .Rd(RdW));
  assign {VW,RegWW,ResSrcW} = CW;
  // WB: ResSrc=0 chọn ALU, 1 chọn dữ liệu load, 2 chọn PC+4.
  mux3 wb_mux(.D0(ALUW), .D1(RDW), .D2(PC4W), .S(ResSrcW), .Y(ResultW));
  // Hazard chỉ xét nguồn/đích của lệnh valid. Các phép so sánh
  // thanh ghi quyết định forwarding; LoadE gây stall; PCSrcE gây flush.
  hazard_unit hu(.Rs1D(Rs1D), .Rs2D(Rs2D), .Rs1E(Rs1E), .Rs2E(Rs2E),
    .RdE(RdE), .RdM(RdM), .RdW(RdW), .Use1D(VD && Use1D), .Use2D(VD && Use2D),
    .Use1E(VE && Use1E), .Use2E(VE && Use2E), .RegWM(VM && RegWM),
    .RegWW(VW && RegWW), .LoadE(LoadE), .LoadM(LoadM), .PCSrcE(PCSrcE),
    .FwdAE(FwdAE),.FwdBE(FwdBE),.StallF(StallF),.StallD(StallD),.FlushD(FlushD),
      .FlushE(FlushE));
  // Trace tại WB: branch/store vẫn retire nhưng RetWE=0.
  // ce=0 không phát lại sự kiện retire của lệnh đang bị giữ.
  assign RetV = ce && VW && !rst;
  assign RetWE = RetV && RegWW && RdW != 0;
  assign RetPC = PCW;
  assign RetWD = ResultW;
  assign RetRd = RdW;
endmodule
