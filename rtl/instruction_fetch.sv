`timescale 1ns/1ps

// PC selects a ROM word. The future controller will drive pc_en and next_pc.
// This block fetches instructions; it does not execute them.
module instruction_fetch #(
    parameter integer WORD_COUNT=4,
    parameter string PROGRAM_FILE=""
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        pc_en,
    input  logic [31:0] next_pc,
    output logic [31:0] pc_addr,
    output logic [31:0] pc_plus4,
    output logic [31:0] instr,
    output logic        instr_valid
);
    pc address_reg (.*);
    instruction_rom #(.WORD_COUNT(WORD_COUNT), .PROGRAM_FILE(PROGRAM_FILE)) program_rom (.addr(pc_addr), .instr(instr),
                                 .instr_valid(instr_valid));
endmodule
