`timescale 1ns/1ps
// Boolean board: user-supplied 100 MHz mclk pin and SW0 reset.
module boolean_board_top (
    input logic mclk,
    input logic [0:0] sw,
    output logic [15:0] led
);
    wire feedback,clock_raw,core_clk,locked;
    // VCO=100*8=800 MHz; CLKOUT0=800/16=50 MHz.
    // Dedicated internal feedback, then a global buffer on the core clock.
    MMCME2_ADV #(.CLKIN1_PERIOD(10.0),.CLKFBOUT_MULT_F(8.0),.DIVCLK_DIVIDE(1),
      .CLKOUT0_DIVIDE_F(16.0),.COMPENSATION("INTERNAL"),.STARTUP_WAIT("FALSE")) clock_manager
      (.CLKIN1(mclk),.CLKIN2(1'b0),.CLKINSEL(1'b1),.CLKFBIN(feedback),.CLKFBOUT(feedback),
       .CLKOUT0(clock_raw),.LOCKED(locked),.RST(sw[0]),.PWRDWN(1'b0),
       .DADDR(7'd0),.DCLK(1'b0),.DEN(1'b0),.DI(16'd0),.DWE(1'b0),
       .PSCLK(1'b0),.PSEN(1'b0),.PSINCDEC(1'b0));
    BUFG core_clock_buffer(.I(clock_raw),.O(core_clk));
    wire demo_done,demo_error,accel_busy,core_reset;
    wire [7:0] result_low;
    soc_demo_wrapper demo(.core_clk(core_clk),.reset_request(sw[0] || !locked),
      .demo_done(demo_done),.demo_error(demo_error),.accel_busy(accel_busy),
      .core_reset(core_reset),.result_low(result_low));
    assign led={3'b000,core_reset,locked,accel_busy,demo_error,demo_done,result_low};
    // LEDs 7:0=result, 8=success, 9=error, 10=busy, 11=clock locked, 12=reset.
endmodule
