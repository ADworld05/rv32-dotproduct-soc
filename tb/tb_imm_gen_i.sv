`timescale 1ns/1ps

module tb_imm_gen_i;
    logic [31:0] instr, imm;
    int expected, checks = 0;
    imm_gen_i dut (.instr(instr), .imm(imm));

    initial begin
        // Independent numerical reference, rather than repeating sign-extension RTL.
        for (int value = 0; value < 4096; value++) begin
            instr = {value[11:0], 20'd0};
            expected = (value < 2048) ? value : value - 4096;
            #1;
            if (imm !== expected)
                $fatal(1, "Immediate FAIL raw=%h expected=%h actual=%h",
                       value[11:0], expected, imm);
            checks = checks + 1;
        end
        $display("PASS: %0d I-immediate checks", checks);
        $finish;
    end
endmodule
