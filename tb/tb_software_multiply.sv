`timescale 1ns/1ps
module software_multiply_case #(parameter integer LATENCY=2)(output logic done=0,output integer checks=0);
    localparam integer CASES=583,TRACES=36959;
    logic clk=0,reset=1;
    always #5 clk=~clk;
    logic fault,trace_valid,trace_rd_write;
    logic [63:0] trace_order;
    logic [31:0] trace_pc,trace_instr,trace_rd_data;
    logic [4:0] trace_rd;
    logic [2:0] state;
    logic [63:0] cycle_count,retired_count,memory_wait_count,cycles_at_last_retire,waits_at_last_retire;
    logic [111:0] vectors[0:CASES-1];
    logic [165:0] expected[0:TRACES-1];
    integer cursor=0,seen=0,report_file,min_cycles=100000,max_cycles=0;
    logic signed [31:0] a,b,answer;
    integer instructions;
    soc_top #(.PROGRAM_WORDS(21),.MEMORY_LATENCY(LATENCY),
      .PROGRAM_FILE("programs/software/multiply_positive.hex")) dut
      (.clk(clk),.reset(reset),.fault(fault),.state(state),.trace_valid(trace_valid),
       .trace_order(trace_order),.trace_pc(trace_pc),.trace_instr(trace_instr),
       .trace_rd_write(trace_rd_write),.trace_rd(trace_rd),.trace_rd_data(trace_rd_data));
    performance_counters meter(.clk(clk),.reset(reset),.active(!fault),.retire_valid(trace_valid),
      .memory_wait(state==5),.cycle_count(cycle_count),.retired_count(retired_count),
      .memory_wait_count(memory_wait_count),.cycles_at_last_retire(cycles_at_last_retire),
      .waits_at_last_retire(waits_at_last_retire));
    always @(negedge clk) if(!reset && !done && trace_valid) begin
        if(cursor>=TRACES || {trace_order,trace_pc,trace_instr,trace_rd_write,trace_rd,trace_rd_data}!==expected[cursor])
            $fatal(1,"Independent instruction trace mismatch L=%0d a=%0d b=%0d order=%0d",LATENCY,a,b,trace_order);
        cursor++;seen++;checks+=6;
    end
    always @(posedge clk) if(!reset && !done && dut.data_port.accel_sel)
        $fatal(1,"Software routine unexpectedly accessed the accelerator");
    initial begin
        $readmemh("verification/software_multiply/cases.hex",vectors);
        $readmemh("verification/software_multiply/traces.hex",expected);
        report_file=$fopen($sformatf("software_multiply_%0d.csv",LATENCY),"w");
        if(!report_file)$fatal(1,"Cannot create results file");
        $fdisplay(report_file,"a,b,result,instructions,cycles,memory_latency");
        for(int n=0;n<CASES;n++) begin
            @(negedge clk);reset=1;
            @(posedge clk);#1;
            a=vectors[n][111:80];b=vectors[n][79:48];answer=vectors[n][47:16];instructions=vectors[n][15:0];
            // Change only the input-constant instructions while reset is active.
            // This is testbench ROM initialization, not self-modifying CPU code.
            dut.fetch_path.program_rom.words[0]={a[11:0],5'd0,3'd0,5'd10,7'h13};
            dut.fetch_path.program_rom.words[1]={b[11:0],5'd0,3'd0,5'd11,7'h13};
            seen=0;
            @(negedge clk);reset=0;
            wait(fault);repeat(2)@(negedge clk);#1;
            if(seen!=instructions || retired_count!==instructions ||
               dut.exec_path.rf.regs[12]!==answer || dut.exec_path.rf.regs[16]!==answer ||
               dut.data_port.ram_target.ram.words[0]!==answer ||
               cycles_at_last_retire!==(3*instructions+2*LATENCY+5) ||
               waits_at_last_retire!==(2*(LATENCY+1)) || dut.accel_busy || dut.accel_done)
                $fatal(1,"Software multiply final result/cycle mismatch a=%0d b=%0d",a,b);
            checks+=9;
            if(cycles_at_last_retire<min_cycles) min_cycles=cycles_at_last_retire;
            if(cycles_at_last_retire>max_cycles) max_cycles=cycles_at_last_retire;
            $fdisplay(report_file,"%0d,%0d,%0d,%0d,%0d,%0d",a,b,answer,instructions,cycles_at_last_retire,LATENCY);
            if(n<2 || (a==-128 && (b==-128 || b==127)))
                $display("MULTIPLY a=%0d b=%0d result=%0d instructions=%0d cycles=%0d latency=%0d",
                    a,b,answer,instructions,cycles_at_last_retire,LATENCY);
        end
        if(cursor!=TRACES)$fatal(1,"Not all reference traces consumed");checks++;
        $fclose(report_file);
        $display("SOFTWARE SUMMARY latency=%0d cases=%0d min_cycles=%0d max_cycles=%0d",LATENCY,CASES,min_cycles,max_cycles);
        done=1;
    end
endmodule
module tb_software_multiply;
    wire [2:0] done;
    wire [31:0] checks[0:2];
    software_multiply_case #(.LATENCY(1)) l1(done[0],checks[0]);
    software_multiply_case #(.LATENCY(2)) l2(done[1],checks[1]);
    software_multiply_case #(.LATENCY(4)) l4(done[2],checks[2]);
    initial begin wait(&done);#2;
        $display("PASS: %0d software-multiply checks; 583 input pairs at latency 1/2/4, independent Python traces, signed results and cycle counts",checks[0]+checks[1]+checks[2]);
        $finish;
    end
    initial begin #10000000;$fatal(1,"Software multiplication test timeout");end
endmodule
