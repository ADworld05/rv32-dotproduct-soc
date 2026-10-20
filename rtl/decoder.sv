`timescale 1ns/1ps

// Teaching subset: RV32I register-register and all nine immediate ALU instructions.
// reg_write describes instruction intent; the controller must gate
// the actual register-file write enable to the completion cycle.
module decoder (
    input  logic [31:0] instr,
    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [4:0]  rd,
    output logic [3:0]  alu_op,
    output logic        reg_write,
    output logic        alu_src_imm,
    output logic [31:0] imm,
    output logic        illegal
);
    logic [6:0] opcode, funct7;
    logic [2:0] funct3;

    logic [31:0] imm_i;
    imm_gen_i immediate_bits (.instr(instr), .imm(imm_i));
    logic is_shift_imm;
    assign is_shift_imm = (opcode == 7'h13) &&
                          ((funct3 == 3'd1) || (funct3 == 3'd5));
    assign imm = !alu_src_imm ? 32'd0 :
                 (is_shift_imm ? {27'd0, instr[24:20]} : imm_i);

    assign opcode = instr[6:0];
    assign rd     = instr[11:7];
    assign funct3 = instr[14:12];
    assign rs1    = instr[19:15];
    assign rs2    = (opcode == 7'h13) ? 5'd0 : instr[24:20];
    assign funct7 = instr[31:25];

    always_comb begin
        alu_op = 4'd0;
        alu_src_imm = 1'b0;
        illegal = 1'b1;

        if (opcode == 7'b0110011) begin
            case ({funct7, funct3})
                10'b0000000_000: begin alu_op = 4'd0; illegal = 1'b0; end // ADD
                10'b0100000_000: begin alu_op = 4'd1; illegal = 1'b0; end // SUB
                10'b0000000_111: begin alu_op = 4'd2; illegal = 1'b0; end // AND
                10'b0000000_110: begin alu_op = 4'd3; illegal = 1'b0; end // OR
                10'b0000000_100: begin alu_op = 4'd4; illegal = 1'b0; end // XOR
                10'b0000000_001: begin alu_op = 4'd5; illegal = 1'b0; end // SLL
                10'b0000000_101: begin alu_op = 4'd6; illegal = 1'b0; end // SRL
                10'b0100000_101: begin alu_op = 4'd7; illegal = 1'b0; end // SRA
                10'b0000000_010: begin alu_op = 4'd8; illegal = 1'b0; end // SLT
                10'b0000000_011: begin alu_op = 4'd9; illegal = 1'b0; end // SLTU
                default: illegal = 1'b1;
            endcase
        end

        if (opcode == 7'b0010011) begin
            case (funct3)
                3'b000: begin alu_op = 4'd0; illegal = 1'b0; end // ADDI
                3'b111: begin alu_op = 4'd2; illegal = 1'b0; end // ANDI
                3'b110: begin alu_op = 4'd3; illegal = 1'b0; end // ORI
                3'b100: begin alu_op = 4'd4; illegal = 1'b0; end // XORI
                3'b010: begin alu_op = 4'd8; illegal = 1'b0; end // SLTI
                3'b011: begin alu_op = 4'd9; illegal = 1'b0; end // SLTIU
                3'b001: begin // SLLI
                    if (funct7 == 7'b0000000) begin
                        alu_op = 4'd5; illegal = 1'b0;
                    end
                end
                3'b101: begin
                    if (funct7 == 7'b0000000) begin
                        alu_op = 4'd6; illegal = 1'b0; // SRLI
                    end else if (funct7 == 7'b0100000) begin
                        alu_op = 4'd7; illegal = 1'b0; // SRAI
                    end
                end
                default: illegal = 1'b1;
            endcase
            alu_src_imm = !illegal;
        end

        reg_write = !illegal;
    end
endmodule
