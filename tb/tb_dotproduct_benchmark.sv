`timescale 1ns/1ps
module benchmark_case #(parameter integer LATENCY=2)(output logic done=0,output integer checks=0);
    localparam integer CASES=73,SW_TRACES=19759,HW_TRACES=1387;
    logic clk=0,reset=1;
    always #5 clk=~clk;
    logic sf,hf,sv,hv,sw,hw;
    logic [63:0] so,ho;
    logic [31:0] sp,hp,si,hi,sd,hd;
    logic [4:0] sr,hr;
    logic [2:0] ss,hs;
    logic [63:0] scount,sret,swait,scycles,swaits,hcount,hret,hwait,hcycles,hwaits;
    logic [111:0] vectors[0:CASES-1];
    logic [165:0] sw_expected[0:SW_TRACES-1],hw_expected[0:HW_TRACES-1];
    logic [1023:0] sw_registers[0:CASES-1],hw_registers[0:CASES-1];
    integer sw_cursor=0,hw_cursor=0,sw_seen=0,hw_seen=0,starts=0,current_case=0;
    logic [31:0] a,b,answer,upper_a,upper_b;
    integer expected_sw_instructions,file_handle;
    soc_top #(.PROGRAM_WORDS(99),.MEMORY_LATENCY(LATENCY),
      .PROGRAM_FILE("programs/software/dotproduct_software.hex")) cpu_sw
      (.clk(clk),.reset(reset),.fault(sf),.state(ss),.trace_valid(sv),.trace_order(so),.trace_pc(sp),
       .trace_instr(si),.trace_rd_write(sw),.trace_rd(sr),.trace_rd_data(sd));
    soc_top #(.PROGRAM_WORDS(19),.MEMORY_LATENCY(LATENCY),
      .PROGRAM_FILE("programs/soc/dotproduct_benchmark.hex")) cpu_hw
      (.clk(clk),.reset(reset),.fault(hf),.state(hs),.trace_valid(hv),.trace_order(ho),.trace_pc(hp),
       .trace_instr(hi),.trace_rd_write(hw),.trace_rd(hr),.trace_rd_data(hd));
    performance_counters sm(.clk(clk),.reset(reset),.active(!sf),.retire_valid(sv),.memory_wait(ss==5),
      .cycle_count(scount),.retired_count(sret),.memory_wait_count(swait),
      .cycles_at_last_retire(scycles),.waits_at_last_retire(swaits));
    performance_counters hm(.clk(clk),.reset(reset),.active(!hf),.retire_valid(hv),.memory_wait(hs==5),
      .cycle_count(hcount),.retired_count(hret),.memory_wait_count(hwait),
      .cycles_at_last_retire(hcycles),.waits_at_last_retire(hwaits));
    always @(negedge clk) if(!reset && !done) begin
        if(sv) begin
            if(sw_cursor>=SW_TRACES || {so,sp,si,sw,sr,sd}!==sw_expected[sw_cursor])
                $fatal(1,"Software dot-product reference trace mismatch case=%0d PC=%h",current_case,sp);
            sw_cursor++;sw_seen++;checks+=6;
        end
        if(hv) begin
            if(hw_cursor>=HW_TRACES || {ho,hp,hi,hw,hr,hd}!==hw_expected[hw_cursor])
                $fatal(1,"Accelerator functional trace mismatch case=%0d PC=%h",current_case,hp);
            hw_cursor++;hw_seen++;checks+=6;
        end
    end
    always @(posedge clk) if(!reset && !done) begin
        if(cpu_sw.data_port.accel_sel) $fatal(1,"Software baseline used the device");
        if(cpu_hw.data_port.accelerator.start) starts++;
    end
    task automatic patch_constants;
        upper_a=(a+32'h800)&32'hfffff000;upper_b=(b+32'h800)&32'hfffff000;
        cpu_sw.fetch_path.program_rom.words[0]=upper_a|(2<<7)|32'h37;
        cpu_sw.fetch_path.program_rom.words[1]={a[11:0],5'd2,3'd0,5'd2,7'h13};
        cpu_sw.fetch_path.program_rom.words[2]=upper_b|(3<<7)|32'h37;
        cpu_sw.fetch_path.program_rom.words[3]={b[11:0],5'd3,3'd0,5'd3,7'h13};
        for(int n=0;n<4;n++) cpu_hw.fetch_path.program_rom.words[n]=cpu_sw.fetch_path.program_rom.words[n];
    endtask
    initial begin
        $readmemh("verification/dotproduct_benchmark/cases.hex",vectors);
        $readmemh("verification/dotproduct_benchmark/software_traces.hex",sw_expected);
        $readmemh("verification/dotproduct_benchmark/accelerator_traces.hex",hw_expected);
        $readmemh("verification/dotproduct_benchmark/software_registers.hex",sw_registers);
        $readmemh("verification/dotproduct_benchmark/accelerator_registers.hex",hw_registers);
        file_handle=$fopen($sformatf("dotproduct_benchmark_%0d.csv",LATENCY),"w");
        if(!file_handle)$fatal(1,"Cannot create benchmark CSV");
        $fdisplay(file_handle,"case,a_hex,b_hex,result,latency,software_instructions,accelerator_instructions,software_cycles,accelerator_cycles,speedup");
        for(int n=0;n<CASES;n++) begin
            @(negedge clk);reset=1;@(posedge clk);#1;
            current_case=n;a=vectors[n][111:80];b=vectors[n][79:48];answer=vectors[n][47:16];
            expected_sw_instructions=vectors[n][15:0];patch_constants();
            sw_seen=0;hw_seen=0;starts=0;
            @(negedge clk);reset=0;
            wait(sf && hf);repeat(2)@(negedge clk);#1;
            if(sw_seen!=expected_sw_instructions || hw_seen!=19 || sret!==expected_sw_instructions || hret!==19 || starts!=1 ||
               scycles!==(3*expected_sw_instructions+6*LATENCY+15) || hcycles!==(84+11*LATENCY) ||
               swaits!==(6*(LATENCY+1)) || hwaits!==(11*(LATENCY+1)) ||
               cpu_sw.accel_busy || cpu_sw.accel_done || cpu_hw.accel_busy || !cpu_hw.accel_done)
                $fatal(1,"Dot-product timing/count mismatch case=%0d latency=%0d sw=%0d hw=%0d",n,LATENCY,scycles,hcycles);
            checks+=13;
            for(int r=1;r<32;r++) begin
                if(cpu_sw.exec_path.rf.regs[r]!==sw_registers[n][r*32 +:32] ||
                   cpu_hw.exec_path.rf.regs[r]!==hw_registers[n][r*32 +:32])
                    $fatal(1,"Dot-product final register mismatch x%0d",r);
                checks+=2;
            end
            for(int w=0;w<16;w++) begin
                if(cpu_sw.data_port.ram_target.ram.words[w]!==((w==0)?a:((w==1)?b:((w==2)?answer:0))) ||
                   cpu_hw.data_port.ram_target.ram.words[w]!==cpu_sw.data_port.ram_target.ram.words[w])
                    $fatal(1,"Dot-product final memory mismatch");
                checks+=2;
            end
            $fdisplay(file_handle,"%0d,%h,%h,%0d,%0d,%0d,%0d,%0d,%0d,%0.6f",n,a,b,$signed(answer),LATENCY,
                sret,hret,scycles,hcycles,real'(scycles)/real'(hcycles));
            if(n<4)$display("DOT result=%0d latency=%0d software=%0d cycles accelerator=%0d cycles speedup=%0.3fx",
                $signed(answer),LATENCY,scycles,hcycles,real'(scycles)/real'(hcycles));
        end
        if(sw_cursor!=SW_TRACES || hw_cursor!=HW_TRACES)$fatal(1,"Missing reference trace records");checks+=2;
        $fclose(file_handle);done=1;
    end
endmodule
module tb_dotproduct_benchmark;
    wire [2:0] done;
    wire [31:0] checks[0:2];
    benchmark_case #(.LATENCY(1)) l1(done[0],checks[0]);
    benchmark_case #(.LATENCY(2)) l2(done[1],checks[1]);
    benchmark_case #(.LATENCY(4)) l4(done[2],checks[2]);
    initial begin wait(&done);#2;
        $display("PASS: %0d dot-product benchmark checks; 73 vector pairs at latency 1/2/4, both execution traces, final state and measured cycles",checks[0]+checks[1]+checks[2]);$finish;end
    initial begin #10000000;$fatal(1,"Benchmark timeout");end
endmodule
