`timescale 1ns/1ps

// Asynchronous instruction ROM. Each array entry is one 32-bit instruction word.
// PROGRAM_FILE is a simulation/elaboration setting, not a run-time input signal.
// Supply exactly WORD_COUNT words when using a file; valid range is set by that count.
module instruction_rom #(
    parameter integer WORD_COUNT=4,
    parameter string PROGRAM_FILE=""
) (
    input  logic [31:0] addr,
    output logic [31:0] instr,
    output logic        instr_valid
);
    logic [31:0] words [0:WORD_COUNT-1];
    initial begin
        for (int n=0; n<WORD_COUNT; n++) words[n]=32'd0;
        if (PROGRAM_FILE!="") begin
            $readmemh(PROGRAM_FILE,words);
        end else begin
            // Preserve our original demo and existing testbenches by default.
            if (WORD_COUNT>0) words[0]=32'h00700093;
            if (WORD_COUNT>1) words[1]=32'h00a00113;
            if (WORD_COUNT>2) words[2]=32'h002081b3;
            if (WORD_COUNT>3) words[3]=32'h00119213;
        end
    end

    always_comb begin
        instr=32'd0; instr_valid=1'b0;
        // Byte address -> word index. Check high address bits BEFORE indexing.
        if ((addr[1:0]==2'b00) && ((addr>>2)<WORD_COUNT)) begin
            instr=words[addr>>2];
            instr_valid=1'b1;
        end
    end
endmodule
