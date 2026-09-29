`timescale 1ns/1ps
module tb_hazard;
    reg [4:0] Rs1D,Rs2D,Rs1E,Rs2E,RdE,RdM,RdW;
    reg Use1D,Use2D,Use1E,Use2E,RegWM,RegWW,LoadE,LoadM,PCSrcE;
    wire [1:0] FwdAE,FwdBE;
    wire StallF,StallD,FlushD,FlushE;
    integer i;
    reg want_stall;
    reg [1:0] want_a,want_b;
    hazard_unit dut(.*);
    initial begin
        for(i=0;i<20000;i=i+1) begin
            Rs1D=$random; Rs2D=$random; Rs1E=$random; Rs2E=$random;
            RdE=$random; RdM=$random; RdW=$random;
            {Use1D,Use2D,Use1E,Use2E,RegWM,RegWW,LoadE,LoadM,PCSrcE}=$random;
            // Force collisions often, including an older WB and newer MEM producer.
            if(i%3==0) begin Rs1E=RdM; Rs2E=RdW; Rs1D=RdE; end
            if(i%5==0) begin RdW=RdM; Rs2D=RdE; end
            #1;
            want_stall=LoadE && RdE!=0 && ((Use1D && Rs1D==RdE)||(Use2D && Rs2D==RdE));
            want_a=0; want_b=0;
            if(Use1E && Rs1E!=0) begin
                if(RegWW && RdW==Rs1E) want_a=1;
                if(RegWM && RdM==Rs1E) want_a=LoadM ? 0 : 2;
            end
            if(Use2E && Rs2E!=0) begin
                if(RegWW && RdW==Rs2E) want_b=1;
                if(RegWM && RdM==Rs2E) want_b=LoadM ? 0 : 2;
            end
            if({StallF,StallD,FlushD,FlushE}!=={want_stall&&!PCSrcE,want_stall&&!PCSrcE,PCSrcE,want_stall||PCSrcE})
                $fatal(1,"stall/flush mismatch at %d",i);
            if(FwdAE!==want_a || FwdBE!==want_b) $fatal(1,"forward mismatch at %d",i);
        end
        $display("PASS hazard: 20000 vectors including redirect priority, x0 and MEM/WB collision");
        $finish;
    end
endmodule
