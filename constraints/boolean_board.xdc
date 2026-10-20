# Pin assignments supplied by the user for the Boolean Spartan-7 board.
set_property -dict {PACKAGE_PIN F14 IOSTANDARD LVCMOS33} [get_ports mclk]
create_clock -name board_clk -period 10.000 [get_ports mclk]
set_property -dict {PACKAGE_PIN V2 IOSTANDARD LVCMOS33} [get_ports {sw[0]}]
set_property -dict {PACKAGE_PIN G1 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN G2 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN F1 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN F2 IOSTANDARD LVCMOS33} [get_ports {led[3]}]
set_property -dict {PACKAGE_PIN E1 IOSTANDARD LVCMOS33} [get_ports {led[4]}]
set_property -dict {PACKAGE_PIN E2 IOSTANDARD LVCMOS33} [get_ports {led[5]}]
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports {led[6]}]
set_property -dict {PACKAGE_PIN E5 IOSTANDARD LVCMOS33} [get_ports {led[7]}]
set_property -dict {PACKAGE_PIN E6 IOSTANDARD LVCMOS33} [get_ports {led[8]}]
set_property -dict {PACKAGE_PIN C3 IOSTANDARD LVCMOS33} [get_ports {led[9]}]
set_property -dict {PACKAGE_PIN B2 IOSTANDARD LVCMOS33} [get_ports {led[10]}]
set_property -dict {PACKAGE_PIN A2 IOSTANDARD LVCMOS33} [get_ports {led[11]}]
set_property -dict {PACKAGE_PIN B3 IOSTANDARD LVCMOS33} [get_ports {led[12]}]
set_property -dict {PACKAGE_PIN A3 IOSTANDARD LVCMOS33} [get_ports {led[13]}]
set_property -dict {PACKAGE_PIN B4 IOSTANDARD LVCMOS33} [get_ports {led[14]}]
set_property -dict {PACKAGE_PIN A4 IOSTANDARD LVCMOS33} [get_ports {led[15]}]
# Explicitly name the 100/2 generated clock; MMCM jitter is still modeled.
create_generated_clock -name core_clk -source [get_pins clock_manager/CLKIN1] -divide_by 2 [get_pins clock_manager/CLKOUT0]
# SW0 is used ONLY as asynchronous reset (MMCM + reset synchronizer).
# It is not a synchronous data input. No functional CPU paths are excepted.
set_false_path -from [get_ports {sw[0]}]
# LED outputs are human-visible, with no external capture clock. A zero external
# delay defines a conservative one-core-period reporting budget, not a board spec.
set_output_delay -clock [get_clocks core_clk] 0.000 [get_ports {led[*]}]
