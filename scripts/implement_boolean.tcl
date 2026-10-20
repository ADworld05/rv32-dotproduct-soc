# Reproducible Boolean-board implementation; builds a bitstream, never programs hardware.
set root [file normalize [file join [file dirname [info script]] ..]]
cd $root
set output [file join $root build implementation]
file mkdir $output
read_verilog -sv [lsort [glob [file join $root rtl *.sv]]]
read_xdc [list [file join $root constraints boolean_board.xdc]]
synth_design -top boolean_board_top -part xc7s50csga324-1
# Official Boolean schematic: configuration bank and CFGBVS tied to 3.3 V.
# https://www.realdigital.org/downloads/63f9a8205ebd9c2e8c2d265ad25097dc.pdf
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
write_checkpoint -force [file join $output board_synth.dcp]
opt_design
place_design
phys_opt_design
route_design
write_checkpoint -force [file join $output board_routed.dcp]
report_utilization -file [file join $output utilization.rpt]
report_utilization -hierarchical -file [file join $output utilization_hierarchical.rpt]
report_timing_summary -report_unconstrained -file [file join $output timing_summary.rpt]
report_timing -delay_type max -max_paths 10 -file [file join $output critical_paths.rpt]
report_clocks -file [file join $output clocks.rpt]
report_drc -file [file join $output drc.rpt]
set setup [get_timing_paths -delay_type max -max_paths 1]
set hold [get_timing_paths -delay_type min -max_paths 1]
if {[llength $setup]==0 || [llength $hold]==0} {error "Missing timing paths: do not generate bitstream"}
set setup_slack [get_property SLACK [lindex $setup 0]]
set hold_slack [get_property SLACK [lindex $hold 0]]
set summary [open [file join $output implementation_summary.txt] w]
puts $summary "Target: xc7s50csga324-1; top: boolean_board_top"
puts $summary "Input 100 MHz; MMCM core clock 50 MHz"
puts $summary "Routed worst setup slack (ns): $setup_slack"
puts $summary "Routed worst hold slack (ns): $hold_slack"
puts $summary "Hardware programming was NOT performed."
close $summary
if {$setup_slack<0 || $hold_slack<0} {error "Routed timing failed; reports saved, no bitstream generated"}
write_bitstream -force [file join $output boolean_soc.bit]
puts "PASS: Boolean-board routed implementation, timing and bitstream completed; hardware NOT programmed"
