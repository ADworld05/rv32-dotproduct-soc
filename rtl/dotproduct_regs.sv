`timescale 1ns/1ps

// Accelerator register bank, not the arithmetic engine or bus handshake.
// access_en is ONE backend-access pulse, not a held CPU request-valid signal.
// Only aligned LW/SW (funct3=010) are accepted. Offsets are byte offsets.
module dotproduct_regs (
    input logic clk,reset,
    input logic access_en,write_en,
    input logic [2:0] funct3,
    input logic [4:0] offset,
    input logic [31:0] wdata,
    output logic [31:0] rdata,
    output logic access_fault,
    output logic [31:0] operand_a,operand_b,
    output logic start,busy,done,
    input logic engine_done,
    input logic [31:0] engine_result
);
    localparam logic [4:0] A=5'h00,B=5'h04,CONTROL=5'h08,STATUS=5'h0c,RESULT=5'h10;
    logic [31:0] result_reg;
    always_comb begin
        rdata=0;access_fault=0;
        if(access_en && !reset) begin
            if(funct3!=3'b010 || offset[1:0]!=0) access_fault=1;
            else case(offset)
                A: if(write_en) access_fault=busy; else rdata=operand_a;
                B: if(write_en) access_fault=busy; else rdata=operand_b;
                CONTROL: if(write_en)
                    access_fault=(wdata[31:1]!=0) || (wdata[0] && busy);
                    // CONTROL reads as zero; writing zero is a no-op.
                STATUS: if(write_en) access_fault=1; else rdata={30'd0,done,busy};
                RESULT: if(write_en) access_fault=1; else rdata=result_reg;
                default: access_fault=1; // Reserved offsets are not registers.
            endcase
        end
    end
    always_ff @(posedge clk) begin
        if(reset) begin
            operand_a<=0;operand_b<=0;result_reg<=0;
            start<=0;busy<=0;done<=0;
        end else begin
            start<=0; // One-cycle command to the future engine.
            if(busy && engine_done) begin
                result_reg<=engine_result;busy<=0;done<=1;
            end
            if(access_en && write_en && !access_fault) begin
                case(offset)
                    A: operand_a<=wdata;
                    B: operand_b<=wdata;
                    CONTROL: if(wdata[0]) begin start<=1;busy<=1;done<=0;end
                    default: ;
                endcase
            end
        end
    end
    // Old result persists until the next completion; done stays set until start/reset.
    // An access sees pre-edge busy: writes remain forbidden on the completion edge.
    // Stray engine_done while idle is ignored. Reset aborts the current operation.
endmodule
