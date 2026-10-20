`timescale 1ns/1ps

// Standalone branch decode/compare/target block; CPU integration is the next lesson.
// instr_pc must be the branch's original address, not the already-advanced fetch PC.
module branch_unit (
    input  logic [31:0] instr,
    input  logic [31:0] instr_pc,
    input  logic [31:0] rs1_value,
    input  logic [31:0] rs2_value,
    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [31:0] offset,
    output logic [31:0] target,
    output logic        branch_taken,
    output logic        target_misaligned,
    output logic        illegal
);
    logic [31:0] imm_b;
    imm_gen_b immediate_bits (.instr(instr),.imm(imm_b));
    always_comb begin
        rs1=0; rs2=0; offset=0; target=0; branch_taken=0; illegal=1;
        if (instr[6:0]==7'b1100011) begin
            case (instr[14:12])
                3'b000: begin illegal=0; branch_taken=(rs1_value==rs2_value); end // BEQ
                3'b001: begin illegal=0; branch_taken=(rs1_value!=rs2_value); end // BNE
                3'b100: begin illegal=0; branch_taken=($signed(rs1_value)<$signed(rs2_value)); end // BLT
                3'b101: begin illegal=0; branch_taken=($signed(rs1_value)>=$signed(rs2_value)); end // BGE
                3'b110: begin illegal=0; branch_taken=(rs1_value<rs2_value); end // BLTU
                3'b111: begin illegal=0; branch_taken=(rs1_value>=rs2_value); end // BGEU
                default: begin illegal=1; branch_taken=0; end
            endcase
            if (!illegal) begin
                rs1=instr[19:15]; rs2=instr[24:20];
                offset=imm_b; target=instr_pc+imm_b;
            end
        end
    end
    // Current CPU has no compressed instructions: taken targets require four-byte alignment.
    // A not-taken branch must not report a misaligned target fault.
    assign target_misaligned=branch_taken && (target[1:0]!=2'b00);
endmodule
