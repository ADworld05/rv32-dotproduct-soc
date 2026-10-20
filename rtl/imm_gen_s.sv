`timescale 1ns/1ps

// S-type store offset: reconstruct split fields, then sign-extend 12 -> 32 bits.
module imm_gen_s (
    input  logic [31:0] instr,
    output logic [31:0] imm
);
    assign imm={{20{instr[31]}},instr[31:25],instr[11:7]};
endmodule
