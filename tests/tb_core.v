`timescale 1ns/1ps
module tb_core;
    reg clk=0, rst=1, ce=1;
    always #5 clk=~clk;
    wire [31:0] PC, Instr, A, WD, RD, RetPC, RetWD;
    wire WE, RetV, RetWE, StallF, StallD, FlushD, FlushE;
    wire [4:0] RetRd;
    wire [1:0] FwdAE,FwdBE;
    reg [1023:0] rompath;
    integer cycles=0, stalls=0, flushes=0, ma=0, mb=0, wa=0, wb=0, paused=0;
    integer stop_pc, pause_mode=0, unused;
    imem #(.INIT("")) rom(.A(PC),.RD(Instr));
    dmem ram(.clk(clk),.WE(WE),.A(A),.WD(WD),.RD(RD));
    riscv_core dut(.clk(clk),.rst(rst),.ce(ce),.PCA(PC),.Instr(Instr),
        .MemWE(WE),.MemA(A),.MemWD(WD),.MemRD(RD),
        .RetV(RetV),.RetWE(RetWE),.RetPC(RetPC),.RetWD(RetWD),.RetRd(RetRd),
        .StallF(StallF),.StallD(StallD),.FlushD(FlushD),.FlushE(FlushE),.FwdAE(FwdAE),.FwdBE(FwdBE));
    initial begin
        if (!$value$plusargs("ROM=%s",rompath)) $fatal(1,"ROM required");
        if (!$value$plusargs("STOP=%d",stop_pc)) $fatal(1,"STOP required");
        unused=$value$plusargs("PAUSE=%d",pause_mode);
        #1; $readmemh(rompath,rom.mem);
        if ($test$plusargs("VCD")) begin $dumpfile("build/core.vcd"); $dumpvars(0,tb_core); end
        repeat(3) @(negedge clk);
        rst=0;
    end
    always @(negedge clk) begin
        if (!rst) ce=!(pause_mode && (cycles%7==2 || cycles%7==3));
    end
    always @(posedge clk) if (!rst) begin
        cycles=cycles+1;
        if (!ce) paused=paused+1;
        if (ce) begin
            if (StallF) stalls=stalls+1;
            if (FlushD) flushes=flushes+1;
            if (FwdAE==2) ma=ma+1;
            if (FwdBE==2) mb=mb+1;
            if (FwdAE==1) wa=wa+1;
            if (FwdBE==1) wb=wb+1;
        end
        if (WE) $display("S %08x %08x",A,WD);
        if (RetV) begin
            if (RetWE) $display("R %08x %0d %08x",RetPC,RetRd,RetWD);
            else $display("R %08x 0 00000000",RetPC);
            if (RetPC==stop_pc) begin
                $display("COUNT cycles=%0d stalls=%0d flushes=%0d ma=%0d mb=%0d wa=%0d wb=%0d paused=%0d",cycles,stalls,flushes,ma,mb,wa,wb,paused);
                $finish;
            end
        end
        if (dut.rf.regs[0]!==0) $fatal(1,"x0 changed");
        if (cycles>10000) $fatal(1,"timeout PC=%h",PC);
    end
endmodule
