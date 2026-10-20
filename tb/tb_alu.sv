`timescale 1ns/1ps

module tb_alu;
    logic [31:0] a;
    logic [31:0] b;
    logic [3:0]  op;
    logic [31:0] result;
    int          checks = 0;

    alu dut (.a(a), .b(b), .op(op), .result(result));

    task automatic check_case (
        input logic [3:0]  test_op,
        input logic [31:0] test_a,
        input logic [31:0] test_b,
        input logic [31:0] expected
    );
        a  = test_a;
        b  = test_b;
        op = test_op;
        #1;
        if (result !== expected)
            $fatal(1, "FAIL op=%d a=%h b=%h expected=%h actual=%h",
                   test_op, test_a, test_b, expected, result);
        checks = checks + 1;
    endtask

    initial begin
        // Preserve all 14 checks from the addition/subtraction lesson.
        check_case(4'd0, 32'd0,        32'd0,        32'd0);
        check_case(4'd0, 32'd7,        32'd9,        32'd16);
        check_case(4'd0, 32'hFFFFFFFF, 32'd1,        32'd0);
        check_case(4'd0, 32'h7FFFFFFF, 32'd1,        32'h80000000);
        check_case(4'd0, 32'hFFFFFFFD, 32'd10,       32'd7);
        check_case(4'd0, 32'h80000000, 32'h80000000, 32'd0);
        check_case(4'd1, 32'd0,        32'd0,        32'd0);
        check_case(4'd1, 32'd9,        32'd7,        32'd2);
        check_case(4'd1, 32'd7,        32'd9,        32'hFFFFFFFE);
        check_case(4'd1, 32'd0,        32'd1,        32'hFFFFFFFF);
        check_case(4'd1, 32'h80000000, 32'd1,        32'h7FFFFFFF);
        check_case(4'd1, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'd0);
        check_case(4'd0, 32'd12,       32'd5,        32'd17);
        check_case(4'd1, 32'd12,       32'd5,        32'd7);

        // Bitwise operations: zero, extreme patterns, and mixed bits.
        check_case(4'd2, 32'hFFFFFFFF, 32'd0,        32'd0);
        check_case(4'd2, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF);
        check_case(4'd2, 32'hA5A5A5A5, 32'h0F0F0F0F, 32'h05050505);
        check_case(4'd3, 32'd0,        32'd0,        32'd0);
        check_case(4'd3, 32'hFFFFFFFF, 32'd0,        32'hFFFFFFFF);
        check_case(4'd3, 32'hA5A5A5A5, 32'h0F0F0F0F, 32'hAFAFAFAF);
        check_case(4'd4, 32'd0,        32'd0,        32'd0);
        check_case(4'd4, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'd0);
        check_case(4'd4, 32'hA5A5A5A5, 32'h0F0F0F0F, 32'hAAAAAAAA);


        check_case(4'd2, 32'hA, 32'hC, 32'h8);
        check_case(4'd3, 32'hA, 32'hC, 32'hE);
        check_case(4'd4, 32'hA, 32'hC, 32'h6);
        // Defined fallback for an unused internal ALU operation code.
        check_case(4'd15, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'd0);
        // Shifts: ordinary counts, discarded bits, RV32 count masking,
        // and the distinction between zero-fill and sign-fill.
        check_case(4'd5, 32'd1,        32'd4,  32'd16);
        check_case(4'd5, 32'h80000000, 32'd1,  32'd0);
        check_case(4'd5, 32'd1,        32'd32, 32'd1);
        check_case(4'd6, 32'h80000000, 32'd1,  32'h40000000);
        check_case(4'd6, 32'h80000000, 32'd31, 32'd1);
        check_case(4'd7, 32'h80000000, 32'd1,  32'hC0000000);
        check_case(4'd7, 32'hFFFFFFF8, 32'd2,  32'hFFFFFFFE);
        check_case(4'd7, 32'h7FFFFFFF, 32'd1,  32'h3FFFFFFF);
        // Comparisons: both ordering directions, equality, signed boundaries,
        // two negative operands, and zero versus maximum unsigned value.
        check_case(4'd8, 32'd3,        32'd5,        32'd1);
        check_case(4'd8, 32'd5,        32'd3,        32'd0);
        check_case(4'd8, 32'd5,        32'd5,        32'd0);
        check_case(4'd8, 32'hFFFFFFFF, 32'd1,        32'd1);
        check_case(4'd8, 32'h80000000, 32'h7FFFFFFF, 32'd1);
        check_case(4'd8, 32'hFFFFFFFE, 32'hFFFFFFFF, 32'd1);
        check_case(4'd9, 32'd3,        32'd5,        32'd1);
        check_case(4'd9, 32'd5,        32'd3,        32'd0);
        check_case(4'd9, 32'd5,        32'd5,        32'd0);
        check_case(4'd9, 32'hFFFFFFFF, 32'd1,        32'd0);
        check_case(4'd9, 32'h80000000, 32'h7FFFFFFF, 32'd0);
        check_case(4'd9, 32'd0,        32'hFFFFFFFF, 32'd1);
        $display("PASS: %0d ALU checks", checks);
        $finish;
    end
endmodule
