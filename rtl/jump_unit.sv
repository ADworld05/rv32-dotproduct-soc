`timescale 1ns/1ps

// Standalone jump decoder/calculator; not connected to the CPU yet.
// Link data is calculated even for rd=x0 or a misaligned target.
// Future integration discards x0 writes and suppresses all effects on target faults.
module jump_unit (
    input  logic [31:0] instr,
    input  logic [31:0] instr_pc,
    input  logic [31:0] rs1_value,
    output logic [4:0]  rs1,
    output logic [4:0]  rd,
    output logic [31:0] offset,
    output logic [31:0] target,
    output logic [31:0] link_data,
    output logic        is_jump,
    output logic        target_misaligned,
    output logic        illegal
);
    logic [31:0] imm_j,imm_i;
    imm_gen_j direct_offset (.instr(instr),.imm(imm_j));
    imm_gen_i register_offset (.instr(instr),.imm(imm_i));
    always_comb begin
        rs1=0; rd=0; offset=0; target=0; link_data=0; is_jump=0; illegal=1;
        if (instr[6:0]==7'b1101111) begin // JAL: no source register.
            rd=instr[11:7]; offset=imm_j; target=instr_pc+imm_j;
            link_data=instr_pc+32'd4; is_jump=1; illegal=0;
        end else if (instr[6:0]==7'b1100111 && instr[14:12]==3'b000) begin // JALR
            rs1=instr[19:15]; rd=instr[11:7]; offset=imm_i;
            target=(rs1_value+imm_i) & 32'hfffffffe;
            link_data=instr_pc+32'd4; is_jump=1; illegal=0;
        end
    end
    // Clearing JALR bit 0 does NOT clear bit 1. Our CPU still requires 4-byte targets.
    assign target_misaligned=is_jump && (target[1:0]!=2'b00);
endmodule
