`timescale 1ns/1ps

module tb_decoder;
    logic [31:0] instr;
    logic [4:0] rs1, rs2, rd;
    logic [3:0] alu_op;
    logic reg_write, illegal, alu_src_imm;
    logic [31:0] imm;
    int checks = 0;

    decoder dut (.instr(instr), .rs1(rs1), .rs2(rs2), .rd(rd),
                 .alu_op(alu_op), .reg_write(reg_write), .illegal(illegal),
                 .alu_src_imm(alu_src_imm), .imm(imm));

    task automatic check_instr (
        input logic [31:0] word,
        input logic [3:0] expected_op,
        input logic expected_valid,
        input logic [4:0] expected_rd,
        input logic [4:0] expected_rs1,
        input logic [4:0] expected_rs2,
        input logic expected_use_imm = 1'b0,
        input logic [31:0] expected_imm = 32'd0
    );
        instr = word;
        #1;
        if ({illegal, reg_write, alu_op, rd, rs1, rs2, alu_src_imm, imm} !==
            {!expected_valid, expected_valid, expected_op,
             expected_rd, expected_rs1, expected_rs2, expected_use_imm, expected_imm})
            $fatal(1, "Decode FAIL instr=%h op=%0d illegal=%b write=%b rd=%0d rs1=%0d rs2=%0d",
                   instr, alu_op, illegal, reg_write, rd, rs1, rs2);
        checks = checks + 1;
    endtask

    // Independent expected mapping for the exhaustive function-field sweep.
    function automatic logic [3:0] reference_op(input int f7, input int f3);
        reference_op = 4'd0;
        if (f7 == 0) begin
            case (f3)
                0: reference_op = 4'd0;
                1: reference_op = 4'd5;
                2: reference_op = 4'd8;
                3: reference_op = 4'd9;
                4: reference_op = 4'd4;
                5: reference_op = 4'd6;
                6: reference_op = 4'd3;
                7: reference_op = 4'd2;
            endcase
        end else if (f7 == 32 && f3 == 0)
            reference_op = 4'd1;
        else if (f7 == 32 && f3 == 5)
            reference_op = 4'd7;
    endfunction

    // Numerically classify OP-IMM encodings, independently of RTL bit tests.
    function automatic logic reference_i_valid(input int raw, input int f3);
        if (f3 == 1) reference_i_valid = (raw < 32);
        else if (f3 == 5)
            reference_i_valid = (raw < 32) || (raw >= 1024 && raw < 1056);
        else reference_i_valid = 1'b1;
    endfunction

    function automatic logic [3:0] reference_i_op(input int raw, input int f3);
        if (!reference_i_valid(raw, f3)) reference_i_op = 4'd0;
        else if (f3 == 5 && raw >= 1024) reference_i_op = 4'd7;
        else reference_i_op = reference_op(0, f3);
    endfunction

    function automatic logic [31:0] reference_i_imm(input int raw, input int f3);
        if (!reference_i_valid(raw, f3)) reference_i_imm = 32'd0;
        else if (f3 == 1 || f3 == 5) reference_i_imm = raw % 32;
        else reference_i_imm = (raw < 2048) ? raw : raw - 4096;
    endfunction

    initial begin
        // Literal encodings of rd=x5, rs1=x2, rs2=x3.
        check_instr(32'h003102B3, 4'd0, 1'b1, 5'd5, 5'd2, 5'd3); // ADD
        check_instr(32'h403102B3, 4'd1, 1'b1, 5'd5, 5'd2, 5'd3); // SUB
        check_instr(32'h003172B3, 4'd2, 1'b1, 5'd5, 5'd2, 5'd3); // AND
        check_instr(32'h003162B3, 4'd3, 1'b1, 5'd5, 5'd2, 5'd3); // OR
        check_instr(32'h003142B3, 4'd4, 1'b1, 5'd5, 5'd2, 5'd3); // XOR
        check_instr(32'h003112B3, 4'd5, 1'b1, 5'd5, 5'd2, 5'd3); // SLL
        check_instr(32'h003152B3, 4'd6, 1'b1, 5'd5, 5'd2, 5'd3); // SRL
        check_instr(32'h403152B3, 4'd7, 1'b1, 5'd5, 5'd2, 5'd3); // SRA
        check_instr(32'h003122B3, 4'd8, 1'b1, 5'd5, 5'd2, 5'd3); // SLT
        check_instr(32'h003132B3, 4'd9, 1'b1, 5'd5, 5'd2, 5'd3); // SLTU

        // x0 destinations are legal; the register file ignores their writes.
        check_instr(32'h00000033, 4'd0, 1'b1, 5'd0, 5'd0, 5'd0);
        check_instr(32'h01FF8FB3, 4'd0, 1'b1, 5'd31, 5'd31, 5'd31);

        // All 128 x 8 function combinations under the OP opcode.
        // This rejects M-extension operations and unsupported encodings.
        for (int f7 = 0; f7 < 128; f7++) begin
            for (int f3 = 0; f3 < 8; f3++) begin
                check_instr({f7[6:0], f3[4:0], f7[4:0], f3[2:0], 5'd31, 7'h33},
                            reference_op(f7, f3),
                            (f7 == 0) || ((f7 == 32) && ((f3 == 0) || (f3 == 5))),
                            5'd31, f7[4:0], f3[4:0]);
            end
        end

        // OP and OP-IMM are supported; other opcode families fail closed.
        for (int code = 0; code < 128; code++) begin
            check_instr({7'd0, 5'd3, 5'd2, 3'd0, 5'd5, code[6:0]},
                        4'd0, (code == 7'h33 || code == 7'h13), 5'd5, 5'd2,
                        (code == 7'h13) ? 5'd0 : 5'd3,
                        code == 7'h13, (code == 7'h13) ? 32'd3 : 32'd0);
        end

        // Non-shift immediate instructions: positive/negative constants.
        check_instr(32'h00A10293, 4'd0, 1'b1, 5'd5, 5'd2, 5'd0, 1'b1, 32'd10);
        check_instr(32'hFFD10293, 4'd0, 1'b1, 5'd5, 5'd2, 5'd0, 1'b1, 32'hFFFFFFFD);
        check_instr(32'h00F17293, 4'd2, 1'b1, 5'd5, 5'd2, 5'd0, 1'b1, 32'd15);
        check_instr(32'h01016293, 4'd3, 1'b1, 5'd5, 5'd2, 5'd0, 1'b1, 32'd16);
        check_instr(32'hFFF14293, 4'd4, 1'b1, 5'd5, 5'd2, 5'd0, 1'b1, 32'hFFFFFFFF);
        check_instr(32'hFFF12293, 4'd8, 1'b1, 5'd5, 5'd2, 5'd0, 1'b1, 32'hFFFFFFFF);
        check_instr(32'hFFF13293, 4'd9, 1'b1, 5'd5, 5'd2, 5'd0, 1'b1, 32'hFFFFFFFF);

        // Sweep all 4096 immediate patterns and all eight funct3 values.
        // Shift patterns validate their upper bits; only their five-bit amount is supplied.
        for (int raw = 0; raw < 4096; raw++) begin
            for (int f3 = 0; f3 < 8; f3++) begin
                check_instr({raw[11:0], raw[4:0], f3[2:0], 5'd31, 7'h13},
                            reference_i_op(raw, f3),
                            reference_i_valid(raw, f3), 5'd31, raw[4:0], 5'd0,
                            reference_i_valid(raw, f3), reference_i_imm(raw, f3));
            end
        end

        // Valid shifts and explicit unsupported encodings.
        check_instr(32'h00311293, 4'd5, 1'b1, 5'd5, 5'd2, 5'd0, 1'b1, 32'd3);
        check_instr(32'h00315293, 4'd6, 1'b1, 5'd5, 5'd2, 5'd0, 1'b1, 32'd3);
        check_instr(32'h40315293, 4'd7, 1'b1, 5'd5, 5'd2, 5'd0, 1'b1, 32'd3);
        check_instr(32'h02011293, 4'd0, 1'b0, 5'd5, 5'd2, 5'd0);
        check_instr(32'h40311293, 4'd0, 1'b0, 5'd5, 5'd2, 5'd0);
        check_instr(32'h42315293, 4'd0, 1'b0, 5'd5, 5'd2, 5'd0);

        $display("PASS: %0d decoder checks", checks);
        $finish;
    end
endmodule
