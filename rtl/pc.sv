`timescale 1ns/1ps

// PC stores a byte address. This core uses fixed-width 32-bit instructions.
// The controller will enable updates; a later mux will select sequential/branch PC.
module pc (
    input  logic        clk,
    input  logic        reset,
    input  logic        pc_en,
    input  logic [31:0] next_pc,
    output logic [31:0] pc_addr,
    output logic [31:0] pc_plus4
);
    assign pc_plus4 = pc_addr + 32'd4;

    always_ff @(posedge clk) begin
        if (reset)
            pc_addr <= 32'd0;
        else if (pc_en)
            pc_addr <= next_pc;
        // Otherwise the PC retains its address while an instruction is executing.
    end
endmodule
