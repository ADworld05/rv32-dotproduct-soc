`timescale 1ns/1ps

// Passive performance monitor for the CPU's REGISTERED completion trace.
// active/memory_wait describe the cycle ending at this rising edge.
// retire_valid describes completion at the PREVIOUS edge, so snapshot the
// pre-increment counters to align with that instruction's actual completion.
module performance_counters (
    input logic clk,reset,
    input logic active,
    input logic retire_valid,
    input logic memory_wait,
    output logic [63:0] cycle_count,
    output logic [63:0] retired_count,
    output logic [63:0] memory_wait_count,
    output logic [63:0] cycles_at_last_retire,
    output logic [63:0] waits_at_last_retire
);
    always_ff @(posedge clk) begin
        if(reset) begin
            cycle_count<=0;retired_count<=0;memory_wait_count<=0;
            cycles_at_last_retire<=0;waits_at_last_retire<=0;
        end else begin
            if(active) begin
                cycle_count<=cycle_count+64'd1;
                if(memory_wait) memory_wait_count<=memory_wait_count+64'd1;
            end
            // A final registered report can arrive even after active goes low.
            if(retire_valid) begin
                retired_count<=retired_count+64'd1;
                cycles_at_last_retire<=cycle_count;
                waits_at_last_retire<=memory_wait_count;
            end
        end
    end
    // Snapshot payloads persist until the next retirement; reset clears all.
    // Counters wrap modulo 2^64. CPI division belongs in reporting software/TB.
endmodule
