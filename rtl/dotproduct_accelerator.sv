`timescale 1ns/1ps

// Complete accelerator target: register interface + real arithmetic engine.
// Backend access pulses only; CPU request/response routing is a later layer.
module dotproduct_accelerator (
    input logic clk,reset,
    input logic access_en,write_en,
    input logic [2:0] funct3,
    input logic [4:0] offset,
    input logic [31:0] wdata,
    output logic [31:0] rdata,
    output logic access_fault,
    output logic busy,done
);
    logic [31:0] operand_a,operand_b;
    logic start,engine_busy,engine_done;
    logic signed [31:0] engine_result;
    dotproduct_regs regs (
        .clk(clk),.reset(reset),.access_en(access_en),.write_en(write_en),
        .funct3(funct3),.offset(offset),.wdata(wdata),.rdata(rdata),.access_fault(access_fault),
        .operand_a(operand_a),.operand_b(operand_b),.start(start),.busy(busy),.done(done),
        .engine_done(engine_done),.engine_result(engine_result)
    );
    dotproduct_engine engine (
        .clk(clk),.reset(reset),.start(start),.operand_a(operand_a),.operand_b(operand_b),
        .busy(engine_busy),.done(engine_done),.result(engine_result)
    );
    // busy/done outputs describe the register bank's software-visible state.
    // Engine done pulses; register-bank done remains set until start/reset.
endmodule
