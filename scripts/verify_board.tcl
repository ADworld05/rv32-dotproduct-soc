# Verify the final checkpoint's actual physical ports before releasing a bitstream.
set root [file normalize [file join [file dirname [info script]] ..]]
set directory [file join $root build implementation]
open_checkpoint [file join $directory board_routed.dcp]
set expected [list mclk F14 {sw[0]} V2]
set pins {G1 G2 F1 F2 E1 E2 E3 E5 E6 C3 B2 A2 B3 A3 B4 A4}
for {set n 0} {$n<16} {incr n} {lappend expected [format {led[%d]} $n] [lindex $pins $n]}
set report [open [file join $directory pin_verification.txt] w]
foreach {name pin} $expected {
    set port [get_ports $name]
    set actual [get_property PACKAGE_PIN $port]
    set standard [get_property IOSTANDARD $port]
    if {$actual ne $pin || $standard ne "LVCMOS33"} {error "Pin mismatch $name: got $actual/$standard, expected $pin/LVCMOS33"}
    puts $report "$name $actual $standard"
}
if {[get_property PERIOD [get_clocks core_clk]]!=20.0} {error "Core clock is not 50 MHz"}
if {[get_property PERIOD [get_clocks board_clk]]!=10.0} {error "Input clock is not 100 MHz"}
puts $report "PASS: all 18 physical ports and both clock periods match the Boolean-board constraints"
close $report
report_io -file [file join $directory io.rpt]
puts "PASS: Boolean-board final pin and clock verification completed"
