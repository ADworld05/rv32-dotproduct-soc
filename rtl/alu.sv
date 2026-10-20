`timescale 1ns/1ps

// Combinational 32-bit ALU. Arithmetic retains the lowest 32 bits.
// op: 0=ADD, 1=SUB, 2=AND, 3=OR, 4=XOR, 5=SLL, 6=SRL, 7=SRA, 8=SLT, 9=SLTU.
// Other codes return zero. RV32 shifts use only b[4:0] (0 through 31).
module alu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [3:0]  op,
    output logic [31:0] result
);
    always_comb begin
        case (op)
            4'd0:    result = a + b;
            4'd1:    result = a - b;
            4'd2:    result = a & b;
            4'd3:    result = a | b;
            4'd4:    result = a ^ b;
            4'd5:    result = a << b[4:0];
            4'd6:    result = a >> b[4:0];
            4'd7:    result = $signed(a) >>> b[4:0];
            4'd8:    result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            4'd9:    result = (a < b) ? 32'd1 : 32'd0;
            default: result = 32'd0;
        endcase
    end
endmodule
