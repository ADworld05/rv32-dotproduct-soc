`timescale 1ns/1ps

// J-type signed byte offset. Bit zero is implicit zero.
module imm_gen_j (
    input  logic [31:0] instr,
    output logic [31:0] imm
);
    assign imm={{11{instr[31]}},instr[31],instr[19:12],instr[20],instr[30:21],1'b0};
endmodule
