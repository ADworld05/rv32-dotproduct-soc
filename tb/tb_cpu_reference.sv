`timescale 1ns/1ps

// Trace collection only. The independent Python model checks these records.
// run_reference.py generates a top that instantiates this for each program/delay.
module reference_capture_case #(
    parameter integer WORDS=3,LATENCY=2,
    parameter string NAME="memory_learning",
    parameter string FILE="programs/memory_learning.hex",
    parameter bit PRINT_TRACE=0
) (output logic done=0);
    logic clk=0,reset=1;
    always #5 clk=~clk;
    logic fault,trace_valid,trace_rd_write;
    logic [63:0] trace_order;
    logic [31:0] trace_pc,trace_instr,trace_rd_data;
    logic [4:0] trace_rd;
    integer handle;
    string directory;
    soc_top #(.PROGRAM_WORDS(WORDS),.PROGRAM_FILE(FILE),.MEMORY_LATENCY(LATENCY)) dut
        (.clk(clk),.reset(reset),.fault(fault),.trace_valid(trace_valid),
         .trace_order(trace_order),.trace_pc(trace_pc),.trace_instr(trace_instr),
         .trace_rd_write(trace_rd_write),.trace_rd(trace_rd),.trace_rd_data(trace_rd_data));
    initial begin
        // A relative default also works for a manually launched learning simulation.
        if(!$value$plusargs("OUT_DIR=%s",directory)) directory=".";
        handle=$fopen($sformatf("%s/%s_%0d.txt",directory,NAME,LATENCY),"w");
        if(!handle) $fatal(1,"Cannot open reference trace output");
        repeat(2) @(posedge clk);
        #1;reset=0;
    end
    always @(negedge clk) if(!reset && !done) begin
        if(trace_valid) begin
            $fdisplay(handle,"T %h %h %h %h %h %h",trace_order,trace_pc,trace_instr,
                      trace_rd_write,trace_rd,trace_rd_data);
            if(PRINT_TRACE) $display("order %0d: PC=%0d instruction=%h write=%b x%0d=%0d",
                      trace_order,trace_pc,trace_instr,trace_rd_write,trace_rd,trace_rd_data);
        end
        if(fault) begin
            $fdisplay(handle,"R 0 00000000");
            for(int n=1;n<32;n++) $fdisplay(handle,"R %0d %h",n,dut.exec_path.rf.regs[n]);
            for(int n=0;n<16;n++) $fdisplay(handle,"M %0d %h",n,dut.data_port.ram_target.ram.words[n]);
            $fdisplay(handle,"STOP");$fclose(handle);done=1;
        end
    end
endmodule
