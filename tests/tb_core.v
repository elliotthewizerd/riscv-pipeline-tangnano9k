`timescale 1ns/1ps
module tb_core;
    reg clk = 0, rst = 1, ce = 1;
    always #5 clk = ~clk;
    wire [31:0] PC, Instr, A, WD, RD, RetPC, RetWD;
    wire WE, RetV, RetWE, StallF, StallD, FlushD, FlushE;
    wire [4:0] RetRd;
    wire [1:0] FwdAE, FwdBE;
    reg [4095:0] rompath, wavepath, expectpath;
    integer cycles = 0, stalls = 0, flushes = 0;
    integer ma = 0, mb = 0, wa = 0, wb = 0, paused = 0;
    integer stop_pc, pause_mode = 0, unused, i;
    integer expected_rows = 0, mismatch_count = 0;
    reg detailed = 0, expected_enabled = 0;

    // Snapshots are sampled BEFORE nonblocking updates at each rising edge.
    // Obs and Exp therefore describe the SAME cycle, including its writes.
    reg [31:0] ObsPCF, ObsPCD, ObsPCE, ObsPCM, ObsPCW;
    reg ObsStallF, ObsStallD, ObsFlushD, ObsFlushE;
    reg [1:0] ObsFwdA, ObsFwdB;
    reg ObsRedirect, ObsRetV, ObsRetWE;
    reg [31:0] ObsRetPC, ObsRetWD;
    reg [4:0] ObsRetRd;
    reg ObsMemWE;
    reg [31:0] ObsMemA, ObsMemWD;
    reg [304:0] expected_bus;
    reg [304:0] expected_mem [0:9999];
    wire [304:0] observed_bus = {
        ObsPCF, ObsPCD, ObsPCE, ObsPCM, ObsPCW,
        ObsStallF, ObsStallD, ObsFlushD, ObsFlushE, ObsFwdA, ObsFwdB,
        ObsRedirect, ObsRetV, ObsRetWE, ObsRetPC, ObsRetRd, ObsRetWD,
        ObsMemWE, ObsMemA, ObsMemWD
    };
    wire [31:0] ExpPCF, ExpPCD, ExpPCE, ExpPCM, ExpPCW;
    wire ExpStallF, ExpStallD, ExpFlushD, ExpFlushE;
    wire [1:0] ExpFwdA, ExpFwdB;
    wire ExpRedirect, ExpRetV, ExpRetWE;
    wire [31:0] ExpRetPC, ExpRetWD;
    wire [4:0] ExpRetRd;
    wire ExpMemWE;
    wire [31:0] ExpMemA, ExpMemWD;
    reg Compare = 0, Mismatch = 0;
    assign {
        ExpPCF, ExpPCD, ExpPCE, ExpPCM, ExpPCW,
        ExpStallF, ExpStallD, ExpFlushD, ExpFlushE, ExpFwdA, ExpFwdB,
        ExpRedirect, ExpRetV, ExpRetWE, ExpRetPC, ExpRetRd, ExpRetWD,
        ExpMemWE, ExpMemA, ExpMemWD
    } = expected_bus;

    imem #(.INIT("")) rom(.A(PC), .RD(Instr));
    dmem ram(.clk(clk), .WE(WE), .A(A), .WD(WD), .RD(RD));
    riscv_core dut(
        .clk(clk), .rst(rst), .ce(ce), .PCA(PC), .Instr(Instr),
        .MemWE(WE), .MemA(A), .MemWD(WD), .MemRD(RD),
        .RetV(RetV), .RetWE(RetWE), .RetPC(RetPC), .RetWD(RetWD), .RetRd(RetRd),
        .StallF(StallF), .StallD(StallD), .FlushD(FlushD), .FlushE(FlushE),
        .FwdAE(FwdAE), .FwdBE(FwdBE)
    );

    initial begin
        if (!$value$plusargs("ROM=%s", rompath)) $fatal(1, "ROM required");
        if (!$value$plusargs("STOP=%d", stop_pc)) $fatal(1, "STOP required");
        unused = $value$plusargs("PAUSE=%d", pause_mode);
        detailed = $test$plusargs("DETAIL");
        expected_enabled = $value$plusargs("EXPECT=%s", expectpath);
        if (expected_enabled) begin
            if (!$value$plusargs("EXP_ROWS=%d", expected_rows))
                $fatal(1, "EXP_ROWS required with EXPECT");
            if (expected_rows < 1 || expected_rows > 10000)
                $fatal(1, "EXP_ROWS outside 1..10000");
            $readmemh(expectpath, expected_mem, 0, expected_rows - 1);
        end
        #1;
        $readmemh(rompath, rom.mem);
        if ($value$plusargs("WAVE=%s", wavepath)) begin
            $dumpfile(wavepath);
            $dumpvars(0, tb_core);
        end else if ($test$plusargs("VCD")) begin
            $dumpfile("build/core.vcd");
            $dumpvars(0, tb_core);
        end
        repeat (3) @(negedge clk);
        #1 rst = 0;
    end

    always @(negedge clk) begin
        if (!rst) ce = !(pause_mode && (cycles % 7 == 2 || cycles % 7 == 3));
    end

    always @(posedge clk) if (!rst) begin
        cycles = cycles + 1;
        if (!ce) paused = paused + 1;
        if (ce) begin
            if (StallF) stalls = stalls + 1;
            if (FlushD) flushes = flushes + 1;
            if (FwdAE == 2) ma = ma + 1;
            if (FwdBE == 2) mb = mb + 1;
            if (FwdAE == 1) wa = wa + 1;
            if (FwdBE == 1) wb = wb + 1;
        end
        ObsPCF = PC;
        ObsPCD = dut.VD ? dut.PCD : 32'hffffffff;
        ObsPCE = dut.VE ? dut.PCE : 32'hffffffff;
        ObsPCM = dut.VM ? dut.PCM : 32'hffffffff;
        ObsPCW = dut.VW ? dut.PCW : 32'hffffffff;
        ObsStallF = StallF; ObsStallD = StallD;
        ObsFlushD = FlushD; ObsFlushE = FlushE;
        ObsFwdA = FwdAE; ObsFwdB = FwdBE;
        ObsRedirect = dut.PCSrcE;
        ObsRetV = RetV; ObsRetWE = RetWE;
        ObsRetPC = RetV ? RetPC : 0;
        ObsRetRd = RetWE ? RetRd : 0;
        ObsRetWD = RetWE ? RetWD : 0;
        ObsMemWE = WE;
        ObsMemA = WE ? A : 0;
        ObsMemWD = WE ? WD : 0;
        Compare = expected_enabled;
        Mismatch = 0;
        if (expected_enabled) begin
            if (cycles <= expected_rows) expected_bus = expected_mem[cycles - 1];
            else expected_bus = {305{1'bx}};
            // Compare the concatenation directly; continuous wires update later.
            Mismatch = {
                ObsPCF, ObsPCD, ObsPCE, ObsPCM, ObsPCW,
                ObsStallF, ObsStallD, ObsFlushD, ObsFlushE, ObsFwdA, ObsFwdB,
                ObsRedirect, ObsRetV, ObsRetWE, ObsRetPC, ObsRetRd, ObsRetWD,
                ObsMemWE, ObsMemA, ObsMemWD
            } !== expected_bus;
            if (Mismatch) begin
                mismatch_count = mismatch_count + 1;
                $display("MISMATCH cycle=%0d", cycles);
            end
        end
        if (detailed) begin
            $display("C %0d %0d %08x %08x %08x %08x %08x %0d %0d %0d %0d %0d %0d %0d %0d %0d %08x %0d %08x %0d %08x %08x",
                cycles, ce, ObsPCF, ObsPCD, ObsPCE, ObsPCM, ObsPCW,
                ObsStallF, ObsStallD, ObsFlushD, ObsFlushE, ObsFwdA, ObsFwdB,
                ObsRedirect, ObsRetV, ObsRetWE, ObsRetPC, ObsRetRd, ObsRetWD,
                ObsMemWE, ObsMemA, ObsMemWD);
        end
        if (WE) $display("S %08x %08x", A, WD);
        if (RetV) begin
            if (RetWE) $display("R %08x %0d %08x", RetPC, RetRd, RetWD);
            else $display("R %08x 0 00000000", RetPC);
            if (RetPC == stop_pc) begin
                $display("COUNT cycles=%0d stalls=%0d flushes=%0d ma=%0d mb=%0d wa=%0d wb=%0d paused=%0d",
                    cycles, stalls, flushes, ma, mb, wa, wb, paused);
                // Wait for this edge's register/memory writes to settle.
                #1;
                if (detailed) begin
                    for (i = 0; i < 32; i = i + 1)
                        $display("G %0d %08x", i, dut.rf.regs[i]);
                    for (i = 0; i < 64; i = i + 1)
                        $display("D %0d %08x", 4*i, ram.mem[i]);
                end
                if (expected_enabled && (cycles != expected_rows || mismatch_count != 0))
                    $fatal(1, "Golden waveform mismatch: cycles=%0d expected=%0d mismatches=%0d",
                        cycles, expected_rows, mismatch_count);
                $finish;
            end
        end
        if (dut.rf.regs[0] !== 0) $fatal(1, "x0 changed");
        if (cycles > 10000) $fatal(1, "timeout PC=%h", PC);
    end
endmodule
