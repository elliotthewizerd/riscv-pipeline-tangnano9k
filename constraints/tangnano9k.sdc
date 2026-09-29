create_clock -name clk -period 37.037 [get_ports {clk}]
# External push button is asynchronous; reset_sync handles deassertion.
set_false_path -from [get_ports {rst_n}]
