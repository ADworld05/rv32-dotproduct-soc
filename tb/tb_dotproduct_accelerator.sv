`timescale 1ns/1ps

module tb_dotproduct_accelerator;
    logic clk=0,reset=1;
    always #5 clk=~clk;
    logic access_en=0,write_en=0;
    logic [2:0] funct3=2;
    logic [4:0] offset=0;
    logic [31:0] wdata=0,rdata;
    logic access_fault,busy,done;
    integer checks=0,jobs=0;
    dotproduct_accelerator dut(.*);
    function automatic integer reference_dot(input logic [31:0] a,b);
        integer av,bv,total;
        total=0;
        for(int n=0;n<4;n++) begin
            av=(a>>(n*8))&255;bv=(b>>(n*8))&255;
            if(av>=128) av-=256;
            if(bv>=128) bv-=256;
            total+=av*bv;
        end
        return total;
    endfunction
    task automatic access(input bit en,wr,input logic [2:0] f,input logic [4:0] off,
                          input logic [31:0] data,input bit expected_fault,input logic [31:0] expected_read);
        @(negedge clk);access_en=en;write_en=wr;funct3=f;offset=off;wdata=data;
        #1;
        if(access_fault!==expected_fault || rdata!==expected_read)
            $fatal(1,"Accelerator access mismatch en=%b wr=%b f=%0d off=%h fault=%b read=%h expected=%h",
                en,wr,f,off,access_fault,rdata,expected_read);
        checks+=2;
        @(posedge clk);#1;
    endtask
    task automatic state_check(input logic [31:0] a,b,result_expected,
                               input bit busy_expected,done_expected,eb,ed,s);
        if(dut.operand_a!==a || dut.operand_b!==b || dut.regs.result_reg!==result_expected ||
           busy!==busy_expected || done!==done_expected || dut.engine_busy!==eb ||
           dut.engine_done!==ed || dut.start!==s)
            $fatal(1,"Accelerator stored state/timing mismatch");
        checks+=8;
    endtask
    task automatic run_job(input logic [31:0] a,b);
        integer expected,old_result;
        expected=reference_dot(a,b);old_result=dut.regs.result_reg;
        access(1,1,2,0,a,0,0);
        access(1,1,2,4,b,0,0);
        access(1,1,2,8,1,0,0); // T: command accepted.
        state_check(a,b,old_result,1,0,0,0,1);
        access(1,1,2,0,~a,1,0); // T+1: operand capture; protected A write.
        state_check(a,b,old_result,1,0,1,0,0);
        access(1,1,2,8,1,1,0); // T+2: real engine result; duplicate START rejected.
        state_check(a,b,old_result,1,0,0,1,0);
        access(1,1,2,4,~b,1,0); // T+3: capture result despite independent access fault.
        state_check(a,b,expected,0,1,0,0,0);
        access(1,0,2,12,0,0,2);
        access(1,0,2,16,0,0,expected);
        access(1,1,2,8,0,0,0); // No-op preserves sticky done and result.
        state_check(a,b,expected,0,1,0,0,0);
        jobs++;
    endtask
    task automatic reset_in_phase(input integer phase);
        access(1,1,2,0,32'h80808080,0,0);
        access(1,1,2,4,32'h80808080,0,0);
        access(1,1,2,8,1,0,0);
        repeat(phase) access(0,0,2,0,0,0,0);
        // phase 0: before engine capture; 1: products captured; 2: result awaiting bank capture.
        @(negedge clk);reset=1;access_en=1;write_en=1;funct3=7;offset=31;
        #1;if(access_fault || rdata!==0) $fatal(1,"Reset did not suppress interface");checks+=2;
        @(posedge clk);#1;state_check(0,0,0,0,0,0,0,0);
        @(negedge clk);reset=0;access_en=0;
        repeat(4) begin
            @(posedge clk);#1;state_check(0,0,0,0,0,0,0,0);
        end
    endtask
    bit bad;
    initial begin
        @(posedge clk);#1;state_check(0,0,0,0,0,0,0,0);
        @(negedge clk);reset=0;
        // Integrated decoding/protection matrix with zero operand writes and no-op CONTROL.
        for(int off=0;off<32;off++) for(int wr=0;wr<2;wr++) for(int f=0;f<8;f++) begin
            bad=(f!=2) || (off!=0 && off!=4 && off!=8 && off!=12 && off!=16) ||
                (wr && (off==12 || off==16));
            access(1,wr,f,off,0,bad,0);state_check(0,0,0,0,0,0,0,0);
            access(0,wr,f,off,32'hffffffff,0,0);state_check(0,0,0,0,0,0,0,0);
        end
        access(1,1,2,8,2,1,0);state_check(0,0,0,0,0,0,0,0);
        run_job(32'h0403fe01,32'h08f90605);
        run_job(32'h01010101,32'hffffffff);
        run_job(32'h80808080,32'h80808080);
        run_job(32'h80808080,32'h7f7f7f7f);
        run_job(0,32'hffffffff);
        for(int lane=0;lane<4;lane++) run_job(32'h80<<(lane*8),32'h7f<<(lane*8));
        for(int n=0;n<1024;n++) run_job($urandom,$urandom);
        for(int phase=0;phase<3;phase++) begin
            reset_in_phase(phase);
            run_job(32'h0403fe01,32'h08f90605);
        end
        $display("PASS: %0d integrated accelerator checks; %0d real calculations, register protection, command timing and reset in all phases",checks,jobs);
        $finish;
    end
    initial begin #1000000;$fatal(1,"Integrated accelerator test timed out");end
endmodule
