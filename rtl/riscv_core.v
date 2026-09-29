`timescale 1ns/1ps
module riscv_core(input clk, rst, ce,
    output [31:0] PCA, input [31:0] Instr,
    output MemWE, output [31:0] MemA, MemWD, input [31:0] MemRD,
    output RetV, RetWE, output [31:0] RetPC, RetWD, output [4:0] RetRd,
    output StallF, StallD, FlushD, FlushE, output [1:0] FwdAE, FwdBE);
    wire [31:0] PCF, PC4F, PCNext, InstrD, PCD, PC4D, RD1D, RD2D, ImmD;
    wire VD, RegWD, MemWDc, ALUSrcD, ASrcD, BrD, JmpD, JrD, Use1D, Use2D, LegalD;
    wire [1:0] ResSrcD;
    wire [2:0] ImmSrcD;
    wire [3:0] ALUOpD;
    wire [4:0] Rs1D=InstrD[19:15], Rs2D=InstrD[24:20], RdD=InstrD[11:7];
    wire [15:0] CE;
    wire VE, RegWE, MemWEc, ALUSrcE, ASrcE, BrE, JmpE, JrE, Use1E, Use2E;
    wire [1:0] ResSrcE;
    wire [3:0] ALUOpE;
    wire [31:0] RD1E, RD2E, PCE, PC4E, ImmE, AE, BE, SrcAE, SrcBE, ALUE;
    wire [31:0] TargetBase, TargetSum, TargetE;
    wire [4:0] Rs1E, Rs2E, RdE;
    wire [2:0] F3E;
    wire TakeE, PCSrcE;
    wire [4:0] CM;
    wire VM, RegWM, MemWM;
    wire [1:0] ResSrcM;
    wire [31:0] ALUM, WDM, PC4M, PCM, FwdM;
    wire [4:0] RdM;
    wire [3:0] CW;
    wire VW, RegWW;
    wire [1:0] ResSrcW;
    wire [31:0] ALUW, RDW, PC4W, PCW, ResultW;
    wire [4:0] RdW;
    wire LoadE=VE && RegWE && ResSrcE==1;
    wire LoadM=VM && RegWM && ResSrcM==1;

    assign PCA=PCF;
    pc_reg pc(.clk(clk), .rst(rst), .en(ce && !StallF), .D(PCNext), .Q(PCF));
    adder plus4(.A(PCF), .B(32'd4), .Y(PC4F));
    mux2 pc_mux(.D0(PC4F), .D1(TargetE), .S(PCSrcE), .Y(PCNext));
    if_id fd(.clk(clk), .rst(rst), .en(ce && !StallD), .clr(ce && FlushD),
        .VIn(1'b1), .InstrIn(Instr), .PCIn(PCF), .PC4In(PC4F),
        .V(VD), .Instr(InstrD), .PC(PCD), .PC4(PC4D));
    control_unit cu(.Op(InstrD[6:0]), .F7(InstrD[31:25]), .F3(InstrD[14:12]),
        .RegW(RegWD), .MemW(MemWDc), .ALUSrc(ALUSrcD), .ASrc(ASrcD), .Br(BrD),
        .Jmp(JmpD), .Jr(JrD), .Use1(Use1D), .Use2(Use2D), .Legal(LegalD),
        .ResSrc(ResSrcD), .ImmSrc(ImmSrcD), .ALUOp(ALUOpD));
    regfile rf(.clk(clk), .rst(rst), .WE(ce && VW && RegWW && !rst),
        .A1(Rs1D), .A2(Rs2D), .A3(RdW), .WD(ResultW), .RD1(RD1D), .RD2(RD2D));
    extend ext(.Instr(InstrD), .ImmSrc(ImmSrcD), .Imm(ImmD));
    id_ex de(.clk(clk), .rst(rst), .en(ce), .clr(ce && FlushE),
        .CIn({VD && LegalD, RegWD, MemWDc, ALUSrcD, ASrcD, BrD, JmpD, JrD,
              Use1D, Use2D, ResSrcD, ALUOpD}),
        .RD1In(RD1D), .RD2In(RD2D), .PCIn(PCD), .PC4In(PC4D), .ImmIn(ImmD),
        .Rs1In(Rs1D), .Rs2In(Rs2D), .RdIn(RdD), .F3In(InstrD[14:12]),
        .C(CE), .RD1(RD1E), .RD2(RD2E), .PC(PCE), .PC4(PC4E), .Imm(ImmE),
        .Rs1(Rs1E), .Rs2(Rs2E), .Rd(RdE), .F3(F3E));
    assign {VE, RegWE, MemWEc, ALUSrcE, ASrcE, BrE, JmpE, JrE,
            Use1E, Use2E, ResSrcE, ALUOpE}=CE;
    mux3 fwd_a(.D0(RD1E), .D1(ResultW), .D2(FwdM), .S(FwdAE), .Y(AE));
    mux3 fwd_b(.D0(RD2E), .D1(ResultW), .D2(FwdM), .S(FwdBE), .Y(BE));
    mux2 alu_a(.D0(AE), .D1(PCE), .S(ASrcE), .Y(SrcAE));
    mux2 alu_b(.D0(BE), .D1(ImmE), .S(ALUSrcE), .Y(SrcBE));
    alu alu_ex(.A(SrcAE), .B(SrcBE), .ALUOp(ALUOpE), .Y(ALUE));
    branch_unit bu(.A(AE), .B(BE), .F3(F3E), .Take(TakeE));
    mux2 target_mux(.D0(PCE), .D1(AE), .S(JrE), .Y(TargetBase));
    adder target_add(.A(TargetBase), .B(ImmE), .Y(TargetSum));
    assign TargetE=JrE ? {TargetSum[31:1],1'b0} : TargetSum;
    assign PCSrcE=VE && (JmpE || (BrE && TakeE));
    ex_mem em(.clk(clk), .rst(rst), .en(ce), .CIn({VE,RegWE,MemWEc,ResSrcE}),
        .ALUIn(ALUE), .WDIn(BE), .PC4In(PC4E), .PCIn(PCE), .RdIn(RdE),
        .C(CM), .ALU(ALUM), .WD(WDM), .PC4(PC4M), .PC(PCM), .Rd(RdM));
    assign {VM,RegWM,MemWM,ResSrcM}=CM;
    // Forward PC+4 for jal/jalr, never their incidental ALU result.
    assign FwdM=ResSrcM==2 ? PC4M : ALUM;
    assign MemWE=ce && VM && MemWM && !rst;
    assign MemA=ALUM;
    assign MemWD=WDM;
    mem_wb mw(.clk(clk), .rst(rst), .en(ce), .CIn({VM,RegWM,ResSrcM}),
        .ALUIn(ALUM), .RDIn(MemRD), .PC4In(PC4M), .PCIn(PCM), .RdIn(RdM),
        .C(CW), .ALU(ALUW), .RD(RDW), .PC4(PC4W), .PC(PCW), .Rd(RdW));
    assign {VW,RegWW,ResSrcW}=CW;
    mux3 wb_mux(.D0(ALUW), .D1(RDW), .D2(PC4W), .S(ResSrcW), .Y(ResultW));
    hazard_unit hu(.Rs1D(Rs1D), .Rs2D(Rs2D), .Rs1E(Rs1E), .Rs2E(Rs2E),
        .RdE(RdE), .RdM(RdM), .RdW(RdW), .Use1D(VD && Use1D), .Use2D(VD && Use2D),
        .Use1E(VE && Use1E), .Use2E(VE && Use2E), .RegWM(VM && RegWM),
        .RegWW(VW && RegWW), .LoadE(LoadE), .LoadM(LoadM), .PCSrcE(PCSrcE),
        .FwdAE(FwdAE), .FwdBE(FwdBE), .StallF(StallF), .StallD(StallD), .FlushD(FlushD), .FlushE(FlushE));
    assign RetV=ce && VW && !rst;
    assign RetWE=RetV && RegWW && RdW!=0;
    assign RetPC=PCW;
    assign RetWD=ResultW;
    assign RetRd=RdW;
endmodule
