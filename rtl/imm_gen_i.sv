`timescale 1ns/1ps

// I-type signed 12-bit constant expanded to 32 bits.
module imm_gen_i (
    input  logic [31:0] instr,
    output logic [31:0] imm
);
    assign imm = {{20{instr[31]}}, instr[31:20]};
endmodule
