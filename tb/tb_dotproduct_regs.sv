`timescale 1ns/1ps

module tb_dotproduct_regs;
    logic clk=0,reset=1;
    always #5 clk=~clk;
    logic access_en=0,write_en=0;
    logic [2:0] funct3=2;
    logic [4:0] offset=0;
    logic [31:0] wdata=0,rdata,operand_a,operand_b;
    logic access_fault,start,busy,done,engine_done=0;
    logic [31:0] engine_result=0;
    integer checks=0;
    dotproduct_regs dut(.*);
    task automatic access(input bit en,wr,input logic [2:0] f,input logic [4:0] off,
                          input logic [31:0] data,input bit fault_expected,input logic [31:0] read_expected);
        @(negedge clk);access_en=en;write_en=wr;funct3=f;offset=off;wdata=data;
        #1;if(access_fault!==fault_expected || rdata!==read_expected)
            $fatal(1,"Bus mismatch en=%b wr=%b f=%0d off=%h fault=%b data=%h",en,wr,f,off,access_fault,rdata);
        checks+=2;
        @(posedge clk);#1;
    endtask
    task automatic state_check(input logic [31:0] a,b,res,input bit busy_exp,done_exp,start_exp);
        if(operand_a!==a || operand_b!==b || dut.result_reg!==res ||
           busy!==busy_exp || done!==done_exp || start!==start_exp)
            $fatal(1,"Stored state mismatch");
        checks+=6;
    endtask
    task automatic matrix(input bit busy_phase);
        bit bad;
        logic [31:0] expected;
        for(int off=0;off<32;off++) for(int wr=0;wr<2;wr++) for(int f=0;f<8;f++) begin
            bad=(f!=2) || (off!=0 && off!=4 && off!=8 && off!=12 && off!=16);
            if(wr && (off==12 || off==16 || (busy_phase && (off==0 || off==4)))) bad=1;
            expected=0;
            if(!bad && !wr) case(off)
                0: expected=32'h0403fe01;
                4: expected=32'h08f90605;
                12: expected=busy_phase ? 1 : 0;
                default: expected=0;
            endcase
            // Valid operand writes repeat the same value; CONTROL receives a no-op.
            access(1,wr,f,off,(off==0)?32'h0403fe01:((off==4)?32'h08f90605:0),bad,expected);
            state_check(32'h0403fe01,32'h08f90605,0,busy_phase,0,0);
            access(0,wr,f,off,32'hffffffff,0,0);
            state_check(32'h0403fe01,32'h08f90605,0,busy_phase,0,0);
        end
    endtask
    initial begin
        @(posedge clk);#1;state_check(0,0,0,0,0,0);
        @(negedge clk);reset=0;
        // Idle engine completions must not change the result or done flag.
        engine_done=1;engine_result=32'hdeadbeef;
        @(posedge clk);#1;state_check(0,0,0,0,0,0);
        @(negedge clk);engine_done=0;
        access(1,1,2,0,32'h0403fe01,0,0);
        access(1,1,2,4,32'h08f90605,0,0);
        matrix(0);
        access(1,1,2,8,2,1,0); // Reserved CONTROL bits.
        state_check(32'h0403fe01,32'h08f90605,0,0,0,0);
        access(1,1,2,8,1,0,0);
        state_check(32'h0403fe01,32'h08f90605,0,1,0,1);
        access(0,0,2,0,0,0,0);state_check(32'h0403fe01,32'h08f90605,0,1,0,0);
        matrix(1);
        access(1,1,2,8,1,1,0); // Cannot start twice.
        state_check(32'h0403fe01,32'h08f90605,0,1,0,0);
        // A rejected write and a legitimate completion may coincide.
        @(negedge clk);engine_done=1;engine_result=32'hfffffff6;
        access_en=1;write_en=1;funct3=2;offset=0;wdata=0;
        #1;if(!access_fault) $fatal(1,"Completion-edge operand write must still fault");checks++;
        @(posedge clk);#1;state_check(32'h0403fe01,32'h08f90605,32'hfffffff6,0,1,0);
        @(negedge clk);engine_done=0;access_en=0;
        access(1,0,2,12,0,0,2);
        access(1,0,2,16,0,0,32'hfffffff6);
        access(1,1,2,8,0,0,0);state_check(32'h0403fe01,32'h08f90605,32'hfffffff6,0,1,0);
        access(1,1,2,8,1,0,0);state_check(32'h0403fe01,32'h08f90605,32'hfffffff6,1,0,1);
        // Reset aborts work and suppresses even an invalid access/completion.
        @(negedge clk);reset=1;engine_done=1;engine_result=99;
        access_en=1;write_en=1;offset=31;funct3=7;
        #1;if(access_fault || rdata!==0) $fatal(1,"Reset must suppress bus activity");checks+=2;
        @(posedge clk);#1;state_check(0,0,0,0,0,0);
        @(negedge clk);reset=0;access_en=0;
        @(posedge clk);#1;state_check(0,0,0,0,0,0); // Stray old completion ignored.
        @(negedge clk);engine_done=0;
        access(1,1,2,8,1,0,0);state_check(0,0,0,1,0,1);
        @(negedge clk);access_en=0;engine_done=1;engine_result=4;
        @(posedge clk);#1;state_check(0,0,4,0,1,0);
        @(negedge clk);engine_done=0;
        access(1,0,2,16,0,0,4);
        $display("PASS: %0d dot-product register checks; all offsets/widths/directions, idle/busy, faults, completion and reset",checks);
        $finish;
    end
    initial begin #50000;$fatal(1,"Register test timeout");end
endmodule
