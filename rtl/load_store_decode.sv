`timescale 1ns/1ps

// RV32I load/store decoder: LB/LH/LW/LBU/LHU and SB/SH/SW.
// Unsupported by this decoder does not mean unsupported by the entire CPU.
module load_store_decode (
    input  logic [31:0] instr,
    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [4:0]  rd,
    output logic [31:0] offset,
    output logic        is_load,
    output logic        is_store,
    output logic        illegal
);
    logic [31:0] imm_i,imm_s;
    logic load_format,store_format;
    imm_gen_i load_offset (.instr(instr),.imm(imm_i));
    imm_gen_s store_offset (.instr(instr),.imm(imm_s));
    assign load_format=(instr[14:12]==0 || instr[14:12]==1 || instr[14:12]==2 ||
                        instr[14:12]==4 || instr[14:12]==5);
    assign store_format=(instr[14:12]==0 || instr[14:12]==1 || instr[14:12]==2);
    always_comb begin
        rs1=0; rs2=0; rd=0; offset=0; is_load=0; is_store=0; illegal=1;
        if (instr[6:0]==7'h03 && load_format) begin
            rs1=instr[19:15]; rd=instr[11:7]; offset=imm_i; is_load=1; illegal=0;
        end else if (instr[6:0]==7'h23 && store_format) begin
            rs1=instr[19:15]; rs2=instr[24:20]; offset=imm_s; is_store=1; illegal=0;
        end
    end
endmodule
