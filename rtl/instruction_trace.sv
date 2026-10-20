`timescale 1ns/1ps

// Registered report of a successfully completed instruction.
// Observe outputs AFTER the rising edge. Payload holds while trace_valid=0.
// This teaching interface is not the complete RISC-V RVFI interface.
module instruction_trace (
    input logic clk,reset,
    input logic complete,
    input logic [31:0] pc,instr,
    input logic rd_write,
    input logic [4:0] rd,
    input logic [31:0] rd_data,
    output logic trace_valid,
    output logic [63:0] trace_order,
    output logic [31:0] trace_pc,trace_instr,
    output logic trace_rd_write,
    output logic [4:0] trace_rd,
    output logic [31:0] trace_rd_data
);
    logic [63:0] next_order;
    always_ff @(posedge clk) begin
        if(reset) begin
            next_order<=0;trace_valid<=0;trace_order<=0;
            trace_pc<=0;trace_instr<=0;trace_rd_write<=0;trace_rd<=0;trace_rd_data<=0;
        end else begin
            trace_valid<=complete;
            if(complete) begin
                trace_order<=next_order;
                next_order<=next_order+64'd1;
                trace_pc<=pc;trace_instr<=instr;
                trace_rd_write<=rd_write && (rd!=0);
                trace_rd<=(rd_write && (rd!=0)) ? rd : 5'd0;
                trace_rd_data<=(rd_write && (rd!=0)) ? rd_data : 32'd0;
            end
        end
    end
endmodule
