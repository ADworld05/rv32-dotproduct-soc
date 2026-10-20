`timescale 1ns/1ps

// Standalone LUI/AUIPC decode/calculation. CPU integration is the next lesson.
// Neither instruction reads a source register or changes control flow.
// rd=x0 is still a recognized instruction; the CPU later suppresses its write.
module upper_imm_unit (
    input  logic [31:0] instr,
    input  logic [31:0] instr_pc,
    output logic [4:0]  rd,
    output logic [31:0] imm,
    output logic [31:0] result,
    output logic        is_upper,
    output logic        illegal
);
    logic [31:0] imm_u;
    imm_gen_u upper_bits (.instr(instr),.imm(imm_u));
    always_comb begin
        rd=0; imm=0; result=0; is_upper=0; illegal=1;
        case(instr[6:0])
            7'b0110111: begin // LUI: copy upper immediate.
                rd=instr[11:7]; imm=imm_u; result=imm_u;
                is_upper=1; illegal=0;
            end
            7'b0010111: begin // AUIPC: add original instruction address.
                rd=instr[11:7]; imm=imm_u; result=instr_pc+imm_u;
                is_upper=1; illegal=0;
            end
            default: begin rd=0; imm=0; result=0; is_upper=0; illegal=1; end
        endcase
    end
endmodule
