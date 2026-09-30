`timescale 1ns/1ps
module tangnano9k_top(
  input clk,
  rst_n,
  output [5:0] led
);
  wire rst;
  wire [5:0] LED;
  reset_sync reset_gen(.clk(clk), .rst_n(rst_n), .rst(rst));
  soc system(.clk(clk), .rst(rst), .ce(1'b1), .LED(LED), .PC(), .StallF(), .FlushD());
  assign led = ~LED;  // On-board LEDs are active low.
endmodule
