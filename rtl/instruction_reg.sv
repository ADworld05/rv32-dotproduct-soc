`timescale 1ns/1ps

// Hold an instruction, its original byte address, and fetch validity together.
// An enabled capture replaces all three fields, even for an invalid fetch.
// The future controller must prevent execution when instr_valid is zero.
module instruction_reg (
    input  logic        clk,
    input  logic        reset,
    input  logic        ir_en,
    input  logic [31:0] fetched_instr,
    input  logic [31:0] fetched_pc,
    input  logic        fetched_valid,
    output logic [31:0] instr,
    output logic [31:0] instr_pc,
    output logic        instr_valid
);
    always_ff @(posedge clk) begin
        if (reset) begin
            instr <= 32'd0;
            instr_pc <= 32'd0;
            instr_valid <= 1'b0;
        end else if (ir_en) begin
            instr <= fetched_instr;
            instr_pc <= fetched_pc;
            instr_valid <= fetched_valid;
        end
        // With ir_en=0 all stored fields retain their previous values.
    end
endmodule
