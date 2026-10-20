`timescale 1ns/1ps

// Check decoder-to-ALU behavior for all shift amounts on six operand patterns.
module tb_shift_imm;
    logic [31:0] instr, operand_a, imm, result;
    logic [4:0] rs1, rs2, rd;
    logic [3:0] alu_op;
    logic reg_write, illegal, alu_src_imm;
    int checks = 0;

    decoder dec (.instr(instr), .rs1(rs1), .rs2(rs2), .rd(rd),
                 .alu_op(alu_op), .reg_write(reg_write), .illegal(illegal),
                 .alu_src_imm(alu_src_imm), .imm(imm));
    alu calc (.a(operand_a), .b(imm), .op(alu_op), .result(result));

    task automatic run_case (
        input logic [3:0] mode,
        input logic [31:0] value,
        input logic [4:0] amount
    );
        logic [31:0] expected;
        logic [6:0] encoding_top;
        logic [2:0] encoding_function;
        encoding_top = (mode == 4'd7) ? 7'h20 : 7'd0;
        encoding_function = (mode == 4'd5) ? 3'd1 : 3'd5;
        instr = {encoding_top, amount, 5'd2, encoding_function, 5'd5, 7'h13};
        operand_a = value;

        // Independent bit-by-bit reference: do not repeat the ALU shift operators.
        expected = 32'd0;
        for (int bit_index = 0; bit_index < 32; bit_index++) begin
            if (mode == 4'd5) begin
                if (bit_index >= amount)
                    expected[bit_index] = value[bit_index - amount];
            end else begin
                if (bit_index + amount < 32)
                    expected[bit_index] = value[bit_index + amount];
                else if (mode == 4'd7)
                    expected[bit_index] = value[31];
            end
        end
        #1;
        if ({illegal, reg_write, alu_src_imm, rs1, rs2, rd, alu_op, imm} !==
            {1'b0, 1'b1, 1'b1, 5'd2, 5'd0, 5'd5, mode, {27'd0, amount}})
            $fatal(1, "Shift instruction decode failed: instr=%h", instr);
        if (result !== expected)
            $fatal(1, "Shift result failed: instr=%h a=%h expected=%h actual=%h",
                   instr, value, expected, result);
        checks = checks + 1;
    endtask

    initial begin
        for (int mode = 5; mode <= 7; mode++) begin
            for (int amount = 0; amount < 32; amount++) begin
                run_case(mode, 32'd0, amount);
                run_case(mode, 32'hFFFFFFFF, amount);
                run_case(mode, 32'h80000000, amount);
                run_case(mode, 32'h7FFFFFFF, amount);
                run_case(mode, 32'h12345678, amount);
                run_case(mode, 32'hA5A5A5A5, amount);
            end
        end
        $display("PASS: %0d immediate-shift integration checks", checks);
        $finish;
    end
endmodule
