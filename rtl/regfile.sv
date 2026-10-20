`timescale 1ns/1ps

// Two combinational read ports and one rising-edge write port.
// Architectural x0 is a constant; only x1 through x31 require storage.
module regfile (
    input  logic        clk,
    input  logic        reset,
    input  logic        we,
    input  logic [4:0]  waddr,
    input  logic [31:0] wdata,
    input  logic [4:0]  raddr1,
    input  logic [4:0]  raddr2,
    output logic [31:0] rdata1,
    output logic [31:0] rdata2
);
    logic [31:0] regs [1:31];

    always_comb begin
        rdata1 = (raddr1 == 5'd0) ? 32'd0 : regs[raddr1];
        rdata2 = (raddr2 == 5'd0) ? 32'd0 : regs[raddr2];
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 1; i < 32; i++)
                regs[i] <= 32'd0;
        end else if (we && (waddr != 5'd0)) begin
            regs[waddr] <= wdata;
        end
    end
endmodule
