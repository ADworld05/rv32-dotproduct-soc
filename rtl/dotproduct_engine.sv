`timescale 1ns/1ps

// Four signed 8-bit lanes, lane 0 in bits [7:0].
// Idle + start edge: capture four 16-bit products and assert busy.
// Following edge: register their 18-bit sum, pulse done, clear busy.
// start while busy (including the completion edge) is ignored.
module dotproduct_engine (
    input logic clk,reset,start,
    input logic [31:0] operand_a,operand_b,
    output logic busy,done,
    output logic signed [31:0] result
);
    logic signed [7:0] a_lane[0:3],b_lane[0:3];
    logic signed [15:0] product_next[0:3],product_reg[0:3];
    logic signed [17:0] extended_product[0:3],sum;
    for(genvar n=0;n<4;n++) begin:lanes
        // A part-select alone is unsigned: explicitly interpret each signed byte.
        assign a_lane[n]=$signed(operand_a[n*8 +: 8]);
        assign b_lane[n]=$signed(operand_b[n*8 +: 8]);
        assign product_next[n]=a_lane[n]*b_lane[n];
        // Widen BEFORE adding so the 16-bit products cannot overflow their sum.
        assign extended_product[n]={{2{product_reg[n][15]}},product_reg[n]};
    end
    assign sum=extended_product[0]+extended_product[1]+extended_product[2]+extended_product[3];
    always_ff @(posedge clk) begin
        if(reset) begin
            busy<=0;done<=0;result<=0;
            for(int n=0;n<4;n++) product_reg[n]<=0;
        end else begin
            done<=0;
            if(busy) begin
                result<={{14{sum[17]}},sum};
                busy<=0;done<=1;
            end else if(start) begin
                for(int n=0;n<4;n++) product_reg[n]<=product_next[n];
                busy<=1;
            end
        end
    end
    // Result holds until another completion or reset. No accumulator across jobs.
    // Use a one-cycle start pulse; a held start can launch again at a later idle edge.
    // The register bank and engine must share synchronous reset.
endmodule
