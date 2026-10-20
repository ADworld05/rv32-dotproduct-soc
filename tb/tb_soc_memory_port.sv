`timescale 1ns/1ps

module soc_port_case #(parameter integer LATENCY=2)(output logic done=0,output integer checks=0);
    logic clk=0,reset=1;
    always #5 clk=~clk;
    logic req_valid=0,req_ready,req_write=0;
    logic [2:0] req_funct3=2;
    logic [31:0] req_addr=0,req_wdata=0;
    logic rsp_valid,rsp_ready=0,rsp_fault,accel_busy,accel_done;
    logic [31:0] rsp_rdata;
    logic [31:0] model_ram[0:15];
    integer backend_accesses=0,start_pulses=0;
    soc_memory_port #(.LATENCY(LATENCY)) dut(.*);
    always @(posedge clk) if(!reset) begin
        if(dut.backend_en) backend_accesses++;
        if(dut.accelerator.start) start_pulses++;
        if(dut.ram_sel && dut.accel_sel) $fatal(1,"Both memory targets selected");
        if(!dut.backend_en && (dut.ram_sel || dut.accel_sel || dut.decode_fault))
            $fatal(1,"Target active outside backend access");
        if(!done) checks+=2;
    end
    task automatic transfer(input bit wr,input logic [2:0] f,input logic [31:0] addr,data,
                            input bit expected_fault,input logic [31:0] expected_data,input integer hold_cycles=2);
        integer before_accesses;
        before_accesses=backend_accesses;
        @(negedge clk);
        if(!req_ready) $fatal(1,"Port was not ready for next request");checks++;
        req_valid=1;req_write=wr;req_funct3=f;req_addr=addr;req_wdata=data;
        @(posedge clk);#1;
        if(req_ready || rsp_valid) $fatal(1,"Request capture phase incorrect");checks+=2;
        @(negedge clk);req_valid=0;
        // Live pins deliberately disagree with the accepted transaction.
        req_write=~wr;req_addr=32'hffffffff;req_wdata=~data;req_funct3=7;
        for(int n=1;n<=LATENCY;n++) begin
            @(posedge clk);#1;
            if(req_ready || rsp_valid!==(n==LATENCY)) $fatal(1,"Response latency mismatch");checks+=2;
        end
        if(rsp_fault!==expected_fault || rsp_rdata!==expected_data || backend_accesses!=before_accesses+1)
            $fatal(1,"Response/access mismatch latency=%0d addr=%h fault=%b data=%h",LATENCY,addr,rsp_fault,rsp_rdata);
        checks+=3;
        // Try presenting another request while holding this response.
        repeat(hold_cycles) begin
            @(negedge clk);req_valid=1;
            @(posedge clk);#1;
            if(req_ready || !rsp_valid || rsp_fault!==expected_fault || rsp_rdata!==expected_data ||
               backend_accesses!=before_accesses+1)
                $fatal(1,"Held response changed/repeated a target access");
            checks+=5;
        end
        @(negedge clk);req_valid=0;rsp_ready=1;
        @(posedge clk);#1;
        if(rsp_valid || !req_ready) $fatal(1,"Response was not consumed");checks+=2;
        @(negedge clk);rsp_ready=0;
    endtask
    task automatic check_memory;
        for(int n=0;n<16;n++) begin
            if(dut.ram_target.ram.words[n]!==model_ram[n]) $fatal(1,"Router RAM word %0d corrupted",n);
            checks++;
        end
    endtask
    function automatic integer reference_dot(input logic [31:0] a,b);
        integer av,bv,total;
        total=0;
        for(int n=0;n<4;n++) begin
            av=(a>>(8*n))&255;bv=(b>>(8*n))&255;
            if(av>=128) av-=256;if(bv>=128) bv-=256;
            total+=av*bv;
        end
        return total;
    endfunction
    task automatic run_dot(input logic [31:0] a,b);
        integer previous_starts;
        transfer(1,2,32'h10000000,a,0,0);
        transfer(1,2,32'h10000004,b,0,0);
        previous_starts=start_pulses;
        transfer(1,2,32'h10000008,1,0,0,8);
        if(start_pulses!=previous_starts+1 || accel_busy || !accel_done)
            $fatal(1,"Held START response repeated/lost the command or blocked computation");checks+=3;
        transfer(0,2,32'h1000000c,0,0,2);
        transfer(0,2,32'h10000010,0,0,reference_dot(a,b));
        check_memory();
    endtask
    task automatic cancel_request(input logic [31:0] address,input logic [31:0] data);
        @(negedge clk);req_valid=1;req_write=1;req_funct3=2;req_addr=address;req_wdata=data;
        @(posedge clk);#1;
        @(negedge clk);reset=1;req_valid=0;
        @(posedge clk);#1;
        if(req_ready || rsp_valid || accel_busy || accel_done) $fatal(1,"Reset did not suppress activity");checks+=4;
        @(negedge clk);reset=0;
        repeat(3) @(negedge clk);
        if(!req_ready || rsp_valid || accel_busy || accel_done || dut.accelerator.operand_a!==0)
            $fatal(1,"Canceled request reappeared after reset");checks+=5;
        check_memory();
    endtask
    logic [31:0] random_word;
    integer word_index;
    initial begin
        for(int n=0;n<16;n++) model_ram[n]=0;
        @(negedge clk);reset=0;
        transfer(1,2,0,32'h80ff7f01,0,0);model_ram[0]=32'h80ff7f01;
        transfer(0,0,3,0,0,32'hffffff80);
        transfer(0,4,3,0,0,32'h80);
        transfer(0,1,2,0,0,32'hffff80ff);
        transfer(1,0,1,32'haa,0,0);model_ram[0]=32'h80ffaa01;
        transfer(1,1,2,32'h1234,0,0);model_ram[0]=32'h1234aa01;
        transfer(0,2,0,0,0,model_ram[0]);
        transfer(1,2,60,32'hdeadbeef,0,0);model_ram[15]=32'hdeadbeef;
        transfer(0,2,60,0,0,32'hdeadbeef);
        transfer(0,2,1,0,1,0); // RAM alignment fault.
        transfer(1,2,64,0,1,0); // First byte beyond RAM is unmapped.
        transfer(0,2,32'hffffffff,0,1,0);
        transfer(1,2,32'h10000020,0,1,0); // First byte beyond accelerator window.
        transfer(0,2,32'h10000014,0,1,0); // Reserved device register.
        transfer(0,2,32'h10000001,0,1,0); // Device alignment.
        transfer(0,0,32'h10000000,0,1,0); // Byte access forbidden by device.
        transfer(1,2,32'h1000000c,0,1,0); // Read-only STATUS.
        transfer(1,2,32'h10000010,0,1,0); // Read-only RESULT.
        transfer(1,2,32'h10000008,2,1,0); // Reserved CONTROL bit.
        check_memory();
        for(int n=0;n<64;n++) begin
            word_index=1+(n%14);random_word=$urandom;
            transfer(1,2,word_index*4,random_word,0,0,n%4);model_ram[word_index]=random_word;
            transfer(0,2,word_index*4,0,0,random_word,n%4);
        end
        run_dot(32'h0403fe01,32'h08f90605);
        run_dot(32'h80808080,32'h80808080);
        run_dot(32'h80808080,32'h7f7f7f7f);
        for(int n=0;n<32;n++) run_dot($urandom,$urandom);
        cancel_request(0,0); // Pending store must not erase previous RAM value.
        cancel_request(32'h10000000,32'hffffffff);
        cancel_request(32'h10000008,1);
        // Reset while a START response is held and the engine has captured products.
        @(negedge clk);req_valid=1;req_write=1;req_funct3=2;req_addr=32'h10000008;req_wdata=1;
        @(posedge clk);#1;
        @(negedge clk);req_valid=0;
        repeat(LATENCY) begin @(posedge clk);#1;end
        if(!rsp_valid || !accel_busy) $fatal(1,"START was not executed before reset scenario");checks+=2;
        @(posedge clk);#1;
        @(negedge clk);reset=1;
        @(posedge clk);#1;
        if(rsp_valid || accel_busy || accel_done || dut.accelerator.engine_busy)
            $fatal(1,"Reset failed to abort engine/held response");checks+=4;
        @(negedge clk);reset=0;
        repeat(4) @(negedge clk);
        transfer(0,2,32'h1000000c,0,0,0);
        transfer(0,2,32'h10000010,0,0,0);
        check_memory();
        run_dot(32'h0403fe01,32'h08f90605);
        done=1;
    end
endmodule

module tb_soc_memory_port;
    wire [2:0] done;
    wire [31:0] checks[0:2];
    soc_port_case #(.LATENCY(1)) l1(done[0],checks[0]);
    soc_port_case #(.LATENCY(2)) l2(done[1],checks[1]);
    soc_port_case #(.LATENCY(4)) l4(done[2],checks[2]);
    initial begin
        wait(&done);#2;
        $display("PASS: %0d SoC memory-router checks; RAM/accelerator routing, latency 1/2/4, held responses, faults and reset",
            checks[0]+checks[1]+checks[2]);$finish;
    end
    initial begin #1000000;$fatal(1,"Router test timeout");end
endmodule
