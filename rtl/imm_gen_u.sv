`timescale 1ns/1ps

// U-type immediate: instruction upper 20 bits followed by twelve zeros.
module imm_gen_u (
    input  logic [31:0] instr,
    output logic [31:0] imm
);
    assign imm={instr[31:12],12'b0};
endmodule
