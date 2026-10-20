`timescale 1ns/1ps

module tb_dotproduct_engine;
    logic clk=0,reset=1,start=0;
    always #5 clk=~clk;
    logic [31:0] operand_a=0,operand_b=0;
    logic busy,done;
    logic signed [31:0] result;
    integer checks=0,jobs=0;
    dotproduct_engine dut(.*);
    // Software-style signed conversion independent of the RTL's packed casts.
    function automatic integer reference_dot(input logic [31:0] a,b);
        integer av,bv,total;
        total=0;
        for(int n=0;n<4;n++) begin
            av=(a>>(n*8)) & 255;bv=(b>>(n*8)) & 255;
            if(av>=128) av=av-256;
            if(bv>=128) bv=bv-256;
            total=total+av*bv;
        end
        return total;
    endfunction
    task automatic check_state(input bit busy_expected,done_expected,input integer result_expected);
        if(busy!==busy_expected || done!==done_expected || result!==result_expected)
            $fatal(1,"Engine mismatch: busy=%b done=%b result=%0d expected=%0d",
                busy,done,result,result_expected);
        checks+=3;
    endtask
    task automatic run_job(input logic [31:0] a,b);
        integer expected,old_result;
        expected=reference_dot(a,b);old_result=result;
        @(negedge clk);operand_a=a;operand_b=b;start=1;
        @(posedge clk);#1;check_state(1,0,old_result);
        // Deliberately alter operands and keep start asserted while busy.
        // Neither may replace the captured job on its completion edge.
        @(negedge clk);operand_a=~a;operand_b=~b;
        @(posedge clk);#1;check_state(0,1,expected);
        @(negedge clk);start=0;
        @(posedge clk);#1;check_state(0,0,expected);
        jobs++;
    endtask
    initial begin
        @(posedge clk);#1;check_state(0,0,0);
        @(negedge clk);reset=0;
        run_job(32'h0403fe01,32'h08f90605); // 4, mixed signs and lanes.
        run_job(32'h01010101,32'hffffffff); // -4.
        run_job(32'h80808080,32'h80808080); // 65536, proves 18-bit sum needed.
        run_job(32'h80808080,32'h7f7f7f7f); // -65024.
        run_job(32'h00000000,32'hffffffff);
        run_job(32'h7f7f7f7f,32'h7f7f7f7f);
        // Isolate each lane, so cross-lane wiring errors cannot hide in repeated bytes.
        for(int lane=0;lane<4;lane++) begin
            run_job(32'h80<<(lane*8),32'h7f<<(lane*8));
            run_job(32'h7f<<(lane*8),32'h80<<(lane*8));
            run_job(32'hff<<(lane*8),32'hff<<(lane*8));
        end
        // Every possible byte pair repeated in all lanes exercises multiplication
        // and accumulation over the entire signed 8-bit operand range.
        for(int a=0;a<256;a++) for(int b=0;b<256;b++)
            run_job({4{a[7:0]}},{4{b[7:0]}});
        for(int n=0;n<1024;n++) run_job($urandom,$urandom);
        // Reset during a captured operation cancels completion and clears result.
        @(negedge clk);operand_a=32'h80808080;operand_b=32'h80808080;start=1;
        @(posedge clk);#1;if(!busy) $fatal(1,"Reset scenario did not launch");checks++;
        @(negedge clk);reset=1;
        @(posedge clk);#1;check_state(0,0,0); // Reset takes priority over busy/start.
        @(negedge clk);reset=0;start=0;
        repeat(3) begin @(posedge clk);#1;check_state(0,0,0);end
        run_job(32'h0403fe01,32'h08f90605);
        $display("PASS: %0d dot-product engine checks; %0d jobs, all 65536 byte pairs, mixed lanes, extrema, busy-start and reset",checks,jobs);
        $finish;
    end
    initial begin #3000000;$fatal(1,"Engine test timeout");end
endmodule
