`timescale 1ns/1ps
module tb_board;
    reg clk=0, rst_n=0;
    wire [5:0] led;
    always #5 clk=~clk;
    tangnano9k_top dut(.clk(clk),.rst_n(rst_n),.led(led));
    initial begin
        repeat(3) @(negedge clk); rst_n=1;
        repeat(350) @(negedge clk);
        if (led!==6'b111110) $fatal(1,"Demo did not reach LED=1: %b",led);
        rst_n=0;
        repeat(5) @(negedge clk);
        if (led!==6'b111111) $fatal(1,"Reset did not clear LED");
        rst_n=1;
        repeat(350) @(negedge clk);
        if (led!==6'b111110) $fatal(1,"Restart failed: %b",led);
        $display("PASS board: power-on, demo self-check, LED polarity, button reset, restart");
        $finish;
    end
endmodule
