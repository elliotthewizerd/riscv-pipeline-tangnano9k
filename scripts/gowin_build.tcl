# Run from repository root: gw_sh scripts/gowin_build.tcl
set_device -name GW1NR-9C GW1NR-LV9QN88PC6/I5
foreach f [glob rtl/*.v] { add_file $f }
add_file constraints/tangnano9k.cst
add_file constraints/tangnano9k.sdc
set_option -top_module tangnano9k_top
set_option -verilog_std v2001
set_option -output_base_name riscv_pipeline
run all
