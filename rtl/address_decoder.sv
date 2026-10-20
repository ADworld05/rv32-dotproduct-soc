`timescale 1ns/1ps

// Byte-address routing for the planned SoC. No storage or handshake here.
// RAM: 64 bytes at 0. Accelerator: reserved 32-byte register window.
// Selection is not permission: targets must still validate operation/alignment.
module address_decoder (
    input  logic        access_en,
    input  logic [31:0] addr,
    output logic        ram_sel,
    output logic        accel_sel,
    output logic        decode_fault,
    output logic [4:0]  accel_offset
);
    localparam logic [31:0] RAM_FIRST=32'h00000000, RAM_LAST=32'h0000003f;
    localparam logic [31:0] ACCEL_FIRST=32'h10000000, ACCEL_LAST=32'h1000001f;
    always_comb begin
        ram_sel=0;accel_sel=0;decode_fault=0;accel_offset=0;
        if(access_en) begin
            if(addr>=RAM_FIRST && addr<=RAM_LAST) ram_sel=1;
            else if(addr>=ACCEL_FIRST && addr<=ACCEL_LAST) begin
                accel_sel=1;
                // Base is aligned to 32 bytes: low five bits are byte offset.
                accel_offset=addr[4:0];
            end else decode_fault=1;
        end
    end
endmodule
