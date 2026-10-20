`timescale 1ns/1ps
// Board-independent demo logic. core_clk must already be stable/conditioned.
module soc_demo_wrapper #(
    parameter integer PROGRAM_WORDS=19,MEMORY_LATENCY=2,
    parameter string PROGRAM_FILE="programs/soc/dotproduct_benchmark.hex",
    parameter logic [31:0] EXPECTED_RESULT=32'd4
) (
    input logic core_clk,reset_request,
    output logic demo_done,demo_error,accel_busy,core_reset,
    output logic [7:0] result_low
);
    (* ASYNC_REG="TRUE" *) logic [1:0] reset_sync;
    always_ff @(posedge core_clk or posedge reset_request) begin
        if(reset_request) reset_sync<=2'b11;
        else reset_sync<={reset_sync[0],1'b0};
    end
    assign core_reset=reset_sync[1];
    logic fault,trace_valid,trace_rd_write,device_busy,finished;
    logic [31:0] trace_pc,trace_rd_data,result_full;
    logic [4:0] trace_rd;
    soc_top #(.PROGRAM_WORDS(PROGRAM_WORDS),.PROGRAM_FILE(PROGRAM_FILE),.MEMORY_LATENCY(MEMORY_LATENCY)) core
      (.clk(core_clk),.reset(core_reset),.fault(fault),.trace_valid(trace_valid),
       .trace_pc(trace_pc),.trace_rd_write(trace_rd_write),.trace_rd(trace_rd),
       .trace_rd_data(trace_rd_data),.accel_busy(device_busy));
    always_ff @(posedge core_clk) begin
        if(core_reset) begin finished<=0;result_full<=0;end
        else if(!finished && trace_valid && trace_pc==32'((PROGRAM_WORDS-1)*4) &&
                trace_rd_write && trace_rd==5'd21) begin
            result_full<=trace_rd_data;finished<=1;
        end
    end
    // A final result report is captured on the same edge that discovers end of ROM.
    // That expected stop is not an error; a premature fault or wrong answer is.
    assign demo_done=!core_reset && finished && result_full==EXPECTED_RESULT;
    assign demo_error=!core_reset && ((finished && result_full!=EXPECTED_RESULT) || (fault && !finished));
    assign result_low=core_reset ? 8'd0 : result_full[7:0];
    assign accel_busy=!core_reset && device_busy;
endmodule
