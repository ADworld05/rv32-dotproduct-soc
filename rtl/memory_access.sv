`timescale 1ns/1ps

// Subword memory subsystem: CPU byte address -> lane formatter -> masked RAM.
// CPU integration comes next; asynchronous reads keep this interface simple.
module memory_access #(
    parameter integer WORD_COUNT=16
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        mem_en,
    input  logic        write_en,
    input  logic [2:0]  funct3,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    output logic [31:0] rdata,
    output logic        access_fault
);
    logic [31:0] word_addr,write_word,read_word,load_value;
    logic [3:0] byte_en;
    logic illegal,misaligned,ram_fault,ram_en;
    memory_lane_unit lanes (
        .addr(addr),.store_data(wdata),.read_word(read_word),.funct3(funct3),.is_store(write_en),
        .word_addr(word_addr),.write_word(write_word),.byte_en(byte_en),.load_value(load_value),
        .illegal(illegal),.misaligned(misaligned)
    );
    assign ram_en=!reset && mem_en && !illegal && !misaligned;
    data_ram_masked #(.WORD_COUNT(WORD_COUNT)) ram (
        .clk(clk),.reset(reset),.mem_en(ram_en),.write_en(write_en),.addr(word_addr),
        .wdata(write_word),.byte_en(byte_en),.rdata(read_word),.access_fault(ram_fault)
    );
    assign access_fault=!reset && mem_en && (illegal || misaligned || ram_fault);
    assign rdata=(!reset && mem_en && !write_en && !access_fault) ? load_value : 32'd0;
endmodule
