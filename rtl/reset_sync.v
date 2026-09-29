`timescale 1ns/1ps
module reset_sync(input clk, rst_n, output rst);
    reg [1:0] sync_ff=0;
    reg [7:0] por=0;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) sync_ff<=0;
        else sync_ff<={sync_ff[0],1'b1};
    end
    always @(posedge clk) begin
        if (!sync_ff[1]) por<=0;
        else if (!(&por)) por<=por+1'b1;
    end
    assign rst=!(&por);
endmodule
