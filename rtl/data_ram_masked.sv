`timescale 1ns/1ps

// Aligned word RAM with per-byte writes. Lane 0 is bits [7:0].
// The adapter supplies an aligned address, positioned write data and byte mask.
module data_ram_masked #(
    parameter integer WORD_COUNT=16
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        mem_en,
    input  logic        write_en,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    input  logic [3:0]  byte_en,
    output logic [31:0] rdata,
    output logic        access_fault
);
    logic [31:0] words [0:WORD_COUNT-1];
    logic valid_addr;
    initial begin
        for(int n=0;n<WORD_COUNT;n++) words[n]=0;
    end
    assign valid_addr=(addr[1:0]==0) && ((addr>>2)<WORD_COUNT);
    always_comb begin
        rdata=0; access_fault=0;
        if (!reset && mem_en) begin
            access_fault=!valid_addr;
            if (valid_addr && !write_en) rdata=words[addr>>2];
        end
    end
    always_ff @(posedge clk) begin
        if (!reset && mem_en && write_en && valid_addr)
            for(int lane=0;lane<4;lane++)
                if (byte_en[lane]) words[addr>>2][lane*8+:8] <= wdata[lane*8+:8];
    end
    // No assignment to unselected bytes: they retain their old values.
    // Reset blocks access without erasing memory; initialization starts it at zero.
endmodule
