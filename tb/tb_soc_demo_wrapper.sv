`timescale 1ns/1ps
module tb_soc_demo_wrapper;
    logic core_clk=0,reset_request=0;
    always #10 core_clk=~core_clk;
    wire good_done,good_error,good_busy,good_reset;
    wire [7:0] good_result;
    wire wrong_done,wrong_error,wrong_busy,wrong_reset;
    wire [7:0] wrong_result;
    wire fault_done,fault_error,fault_busy,fault_reset;
    wire [7:0] fault_result;
    integer checks=0;
    soc_demo_wrapper good(.core_clk(core_clk),.reset_request(reset_request),.demo_done(good_done),
      .demo_error(good_error),.accel_busy(good_busy),.core_reset(good_reset),.result_low(good_result));
    // Same low byte, different full expected answer: must detect high-bit mismatch.
    soc_demo_wrapper #(.EXPECTED_RESULT(32'h104)) wrong(.core_clk(core_clk),.reset_request(reset_request),
      .demo_done(wrong_done),.demo_error(wrong_error),.accel_busy(wrong_busy),
      .core_reset(wrong_reset),.result_low(wrong_result));
    soc_demo_wrapper #(.PROGRAM_WORDS(3),
      .PROGRAM_FILE("programs/soc/bad_reserved.hex")) bad
      (.core_clk(core_clk),.reset_request(reset_request),.demo_done(fault_done),.demo_error(fault_error),
       .accel_busy(fault_busy),.core_reset(fault_reset),.result_low(fault_result));
    always @(posedge core_clk) begin
        #1;
        if((good_done && good_error) || (wrong_done && wrong_error) || (fault_done && fault_error))
            $fatal(1,"Success and error overlap");checks+=3;
        if(good_reset && (good_done || good_error || good_result!==0 || good_busy))
            $fatal(1,"Reset did not mask demo outputs");checks++;
    end
    task automatic assert_reset;
        #3;reset_request=1;#1;
        if(!good_reset || good_done || good_error || good_result!==0) $fatal(1,"Async reset assertion failed");checks+=4;
        repeat(2)@(negedge core_clk);
        #3;reset_request=0;
        @(posedge core_clk);#1;if(!good_reset)$fatal(1,"Reset released too early");checks++;
        @(posedge core_clk);#1;if(good_reset)$fatal(1,"Reset did not release after two edges");checks++;
    endtask
    task automatic verify_finished;
        wait(good_done && wrong_error && fault_error);@(negedge core_clk);
        if(good_error || good_result!==4 || good_busy || wrong_done || wrong_result!==4 || fault_done || fault_result!==0)
            $fatal(1,"Demo success/mismatch/fault indication failed");checks+=7;
        repeat(5)@(negedge core_clk);
        if(!good_done || good_error || !good.core.fault)$fatal(1,"Expected ROM stop was treated as error");checks+=3;
    endtask
    initial begin
        assert_reset();verify_finished();
        assert_reset();wait(good.core.data_port.accelerator.start);
        assert_reset();verify_finished();
        $display("PASS: %0d demo-wrapper checks; success, full-width mismatch, fault, reset synchronization and restart",checks);$finish;
    end
    initial begin #50000;$fatal(1,"Demo wrapper timeout");end
endmodule
