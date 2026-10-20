`timescale 1ns/1ps

// B-type byte offset: bit 0 is implicit zero; reconstruct then sign-extend.
module imm_gen_b (
    input  logic [31:0] instr,
    output logic [31:0] imm
);
    assign imm={{19{instr[31]}},instr[31],instr[7],instr[30:25],instr[11:8],1'b0};
endmodule
